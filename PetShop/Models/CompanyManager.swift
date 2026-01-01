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
    }
    
    /// Firma girişi
    func loginCompany(username: String, password: String) -> Bool {
        guard let company = companies.first(where: { $0.username.lowercased() == username.lowercased() }) else {
            return false
        }
        
        if company.verifyPassword(password) {
            selectCompany(company)
            return true
        }
        
        return false
    }
    
    // MARK: - GitHub Operations
    
    /// Firmaları GitHub'dan yükle
    func loadCompanies() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            loadCompaniesFromLocal()
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
                }
            } else {
                loadCompaniesFromLocal()
            }
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                loadCompaniesFromLocal()
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Firmaları GitHub'a kaydet
    func saveCompaniesToGitHub() async throws {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            saveCompaniesToLocal()
            return
        }
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(companies)
        try await githubService.putFileContent(path: "companies/companies.json", content: data, message: "Update companies")
        
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
    
    var errorDescription: String? {
        switch self {
        case .usernameExists:
            return "Bu kullanıcı adı zaten kullanılıyor."
        case .invalidCredentials:
            return "Kullanıcı adı veya parola hatalı."
        case .companyNotFound:
            return "Firma bulunamadı."
        }
    }
}
