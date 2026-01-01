//
//  CompanyManager.swift
//  PetShop
//
//  Company management for multi-tenant support
//

import Foundation
import Combine

class CompanyManager: ObservableObject {
    static let shared = CompanyManager()
    
    @Published var companies: [Company] = []
    @Published var currentCompany: Company?
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let githubService = GitHubService.shared
    private let companiesKey = "SavedCompanies"
    private let currentCompanyIdKey = "CurrentCompanyId"
    
    private init() {
        Task {
            // Önce encryption key'i yükle (firmaları yüklemeden önce)
            await EncryptionService.shared.loadEncryptionKey()
            // Sonra firmaları yükle
            await loadCompanies()
            // Son kullanılan firmayı yükle
            if let companyId = UserDefaults.standard.string(forKey: currentCompanyIdKey) {
                currentCompany = companies.first { $0.id == companyId }
            }
        }
    }
    
    // MARK: - Company Management
    
    /// Yeni firma kaydı oluştur
    func registerCompany(name: String, username: String, password: String) async throws {
        // Kullanıcı adı kontrolü
        if companies.contains(where: { $0.username.lowercased() == username.lowercased() }) {
            throw CompanyError.usernameExists
        }
        
        let company = Company(name: name, username: username, password: password)
        
        await MainActor.run {
            companies.append(company)
        }
        
        // GitHub'a kaydet
        try await saveCompaniesToGitHub()
        
        // Firma için DB klasörü oluştur
        try await createCompanyDatabase(companyId: company.id)
        
        await MainActor.run {
            currentCompany = company
            UserDefaults.standard.set(company.id, forKey: currentCompanyIdKey)
        }
    }
    
    /// Firma seç
    func selectCompany(_ company: Company) {
        currentCompany = company
        UserDefaults.standard.set(company.id, forKey: currentCompanyIdKey)
        
        // Firma değiştiğinde DataManager'ı temizle ve yeni verileri yükle
        Task {
            await DataManager.shared.clearAndReloadForNewCompany()
        }
    }
    
    /// Firma girişi - deneme süresi kontrolü ile
    func loginCompany(username: String, password: String) async throws -> Bool {
        // Encryption key'i GitHub'dan zorla yükle (local key'i atla)
        await EncryptionService.shared.loadEncryptionKey(forceReload: true)
        
        guard let company = companies.first(where: { $0.username.lowercased() == username.lowercased() }) else {
            print("Login failed: Company not found for username: \(username)")
            throw CompanyError.companyNotFound
        }
        
        // Deneme süresi bitmiş mi kontrol et
        if company.isTrialExpired {
            print("Login failed: Trial expired for username: \(username)")
            // Deneme süresi biten firmayı sil
            do {
                try await deleteCompany(company)
                print("✅ Deleted expired trial company: \(company.name)")
            } catch {
                print("❌ Error deleting expired company: \(error)")
            }
            throw CompanyError.trialExpired
        }
        
        let isValid = await company.verifyPassword(password)
        print("Password verification result for \(username): \(isValid)")
        
        if isValid {
            selectCompany(company)
            return true
        }
        
        print("Login failed: Invalid password for username: \(username)")
        throw CompanyError.invalidCredentials
    }
    
    /// Firma parolasını değiştir
    func changePassword(currentPassword: String, newPassword: String) async throws {
        guard let company = currentCompany else {
            throw CompanyError.companyNotFound
        }
        
        // Mevcut parolayı doğrula
        guard await company.verifyPassword(currentPassword) else {
            throw CompanyError.invalidCredentials
        }
        
        // Yeni parola kontrolü
        guard !newPassword.isEmpty else {
            throw CompanyError.invalidCredentials
        }
        
        // Firmayı bul ve güncelle
        guard let index = companies.firstIndex(where: { $0.id == company.id }) else {
            throw CompanyError.companyNotFound
        }
        
        await MainActor.run {
            companies[index].updatePassword(newPassword)
            // currentCompany'yi de güncelle
            currentCompany = companies[index]
        }
        
        // GitHub'a kaydet
        try await saveCompaniesToGitHub()
    }
    
    // MARK: - GitHub Operations
    
    /// Firmaları GitHub'dan yükle
    func loadCompanies() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            // Token yoksa local'den yükle
            loadCompaniesFromLocal()
            await MainActor.run {
                lastError = "GitHub bağlantısı yok. Local veriler yüklendi."
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            let data = try await githubService.getFileContent(path: "companies/companies.json")
            
            if !data.isEmpty {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let loadedCompanies = try decoder.decode([Company].self, from: data)
                
                await MainActor.run {
                    companies = loadedCompanies
                    saveCompaniesToLocal()
                    lastError = nil
                }
            } else {
                // Dosya boşsa local'den yükle
                loadCompaniesFromLocal()
            }
        } catch {
            await MainActor.run {
                lastError = "GitHub'dan yükleme hatası: \(error.localizedDescription). Local veriler yüklendi."
                loadCompaniesFromLocal()
            }
            print("Error loading companies from GitHub: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Firmaları manuel olarak yeniden yükle
    func refreshCompanies() async {
        await loadCompanies()
    }
    
    /// Firmaları GitHub'a kaydet
    func saveCompaniesToGitHub() async throws {
        // Token veya API URL kontrolü - yoksa hata fırlat
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            // Local'e kaydet ama hata da fırlat ki kullanıcı bilsin
            saveCompaniesToLocal()
            throw CompanyError.githubConnectionFailed
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(companies)
        try await githubService.putFileContent(path: "companies/companies.json", content: data, message: "Update companies")
        
        // Başarılı olduysa local'e de kaydet
        saveCompaniesToLocal()
    }
    
    /// Firma için DB klasörü oluştur
    private func createCompanyDatabase(companyId: String) async throws {
        // Boş products.json oluştur
        let emptyProducts: [Product] = []
        let productsEncoder = JSONEncoder()
        productsEncoder.outputFormatting = .prettyPrinted
        let productsData = try productsEncoder.encode(emptyProducts)
        try await githubService.putFileContent(
            path: "companies/\(companyId)/products.json",
            content: productsData,
            message: "Create company database - products"
        )
        
        // Boş sales.json oluştur
        let emptySales: [Sale] = []
        let salesEncoder = JSONEncoder()
        salesEncoder.dateEncodingStrategy = .iso8601
        salesEncoder.outputFormatting = .prettyPrinted
        let salesData = try salesEncoder.encode(emptySales)
        try await githubService.putFileContent(
            path: "companies/\(companyId)/sales.json",
            content: salesData,
            message: "Create company database - sales"
        )
    }
    
    // MARK: - Local Cache
    
    private func saveCompaniesToLocal() {
        if let encoded = try? JSONEncoder().encode(companies) {
            UserDefaults.standard.set(encoded, forKey: companiesKey)
        }
    }
    
    private func loadCompaniesFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: companiesKey) else {
            companies = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            companies = try decoder.decode([Company].self, from: data)
        } catch {
            print("Error loading companies from local: \(error)")
            companies = []
        }
    }
    
    /// Firmayı sil (admin için veya deneme süresi bitince)
    func deleteCompany(_ company: Company) async throws {
        // Eğer silinen firma şu anki firma ise, currentCompany'yi temizle
        if currentCompany?.id == company.id {
            await MainActor.run {
                currentCompany = nil
                UserDefaults.standard.removeObject(forKey: currentCompanyIdKey)
            }
        }
        
        // Firmayı listeden kaldır
        await MainActor.run {
            companies.removeAll { $0.id == company.id }
        }
        
        // GitHub'a kaydet
        try await saveCompaniesToGitHub()
        
        // Firma veritabanını sil (products.json ve sales.json dosyalarını boş içerikle yaz)
        try await deleteCompanyDatabase(companyId: company.id)
    }
    
    /// Firma veritabanını sil (products.json ve sales.json'ı boş içerikle yazar)
    private func deleteCompanyDatabase(companyId: String) async throws {
        // Boş products.json yaz
        let emptyProducts: [Product] = []
        let productsEncoder = JSONEncoder()
        productsEncoder.outputFormatting = .prettyPrinted
        let productsData = try productsEncoder.encode(emptyProducts)
        try await githubService.putFileContent(
            path: "companies/\(companyId)/products.json",
            content: productsData,
            message: "Delete company database - products"
        )
        
        // Boş sales.json yaz
        let emptySales: [Sale] = []
        let salesEncoder = JSONEncoder()
        salesEncoder.dateEncodingStrategy = .iso8601
        salesEncoder.outputFormatting = .prettyPrinted
        let salesData = try salesEncoder.encode(emptySales)
        try await githubService.putFileContent(
            path: "companies/\(companyId)/sales.json",
            content: salesData,
            message: "Delete company database - sales"
        )
        
        print("✅ Company database deleted: \(companyId)")
    }
    
    /// Deneme süresi biten firmaları kontrol et ve sil
    func checkAndDeleteExpiredTrials() async {
        let expiredCompanies = companies.filter { $0.isTrialExpired }
        
        if expiredCompanies.isEmpty {
            print("✅ No expired trial companies found")
            return
        }
        
        print("⚠️ Found \(expiredCompanies.count) expired trial companies, deleting...")
        
        for company in expiredCompanies {
            do {
                try await deleteCompany(company)
                print("✅ Deleted expired trial company: \(company.name) (\(company.username))")
            } catch {
                print("❌ Error deleting expired company \(company.name): \(error)")
            }
        }
    }
    
    /// Firma deneme süresini uzat (admin için) - 409 hatası için merge stratejisi ile
    func extendTrialPeriod(for companyId: String, days: Int) async throws {
        // Önce GitHub'dan en güncel companies listesini çek ve merge et
        print("🔄 Fetching latest companies from GitHub for merge...")
        do {
            let data = try await githubService.getFileContent(path: "companies/companies.json")
            
            if !data.isEmpty {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let remoteCompanies = try decoder.decode([Company].self, from: data)
                
                // Local companies ile merge et (local öncelikli - ID bazlı)
                var mergedCompanies = remoteCompanies
                for localCompany in companies {
                    if let index = mergedCompanies.firstIndex(where: { $0.id == localCompany.id }) {
                        // Local versiyon öncelikli (daha güncel)
                        mergedCompanies[index] = localCompany
                    } else {
                        // Yeni local firma ekle
                        mergedCompanies.append(localCompany)
                    }
                }
                
                await MainActor.run {
                    companies = mergedCompanies
                }
                print("✅ Companies merged: \(mergedCompanies.count) companies")
            }
        } catch {
            print("⚠️ Could not fetch companies from GitHub, using local: \(error)")
            // Hata durumunda local companies kullanılacak
        }
        
        // Şimdi firmayı bul ve deneme süresini uzat
        guard let index = companies.firstIndex(where: { $0.id == companyId }) else {
            throw CompanyError.companyNotFound
        }
        
        // Mevcut tarihi al, eğer geçmişteyse bugünden başlat, değilse mevcut tarihe ekle
        let currentExpiry = companies[index].trialExpiresAt
        let now = Date()
        
        let newExpiryDate: Date
        if currentExpiry < now {
            // Süresi dolmuşsa bugünden itibaren uzat
            newExpiryDate = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        } else {
            // Süresi dolmamışsa mevcut tarihe ekle
            newExpiryDate = Calendar.current.date(byAdding: .day, value: days, to: currentExpiry) ?? currentExpiry
        }
        
        await MainActor.run {
            companies[index].trialExpiresAt = newExpiryDate
        }
        
        // Merge edilmiş veriyi GitHub'a kaydet
        try await saveCompaniesToGitHub()
        
        print("✅ Extended trial period for company \(companies[index].name) by \(days) days. New expiry: \(newExpiryDate)")
    }
    
    // MARK: - Company Data Path
    
    /// Firma için data path'i döndür
    func getCompanyDataPath(file: String) -> String {
        guard let company = currentCompany else {
            return "data/\(file)"
        }
        return "companies/\(company.id)/\(file)"
    }
}

// MARK: - Errors

enum CompanyError: LocalizedError {
    case usernameExists
    case invalidCredentials
    case companyNotFound
    case githubConnectionFailed
    case trialExpired
    
    var errorDescription: String? {
        switch self {
        case .usernameExists:
            return "Bu kullanıcı adı zaten kullanılıyor."
        case .invalidCredentials:
            return "Kullanıcı adı veya parola hatalı."
        case .companyNotFound:
            return "Firma bulunamadı."
        case .githubConnectionFailed:
            return "GitHub bağlantısı kurulamadı. Lütfen token veya API URL ayarlarını kontrol edin."
        case .trialExpired:
            return "Deneme süreniz dolmuş. Firma bilgileri ve verileri silindi."
        }
    }
}
