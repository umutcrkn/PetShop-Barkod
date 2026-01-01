//
//  DataManager.swift
//  PetShop
//
//  Data persistence manager - GitHub API integration
//

import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var products: [Product] = []
    @Published var sales: [Sale] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let githubService = GitHubService.shared
    private let companyManager = CompanyManager.shared
    private let passwordKey = "UserPassword"
    private let defaultPassword = "201812055"
    
    // Local cache keys (fallback) - firma bazlı
    private var productsKey: String {
        if let company = companyManager.currentCompany {
            return "SavedProducts_\(company.id)"
        }
        return "SavedProducts"
    }
    
    private var salesKey: String {
        if let company = companyManager.currentCompany {
            return "SavedSales_\(company.id)"
        }
        return "SavedSales"
    }
    
    private init() {
        // Firma seçildiğinde veriler yüklenecek
    }
    
    /// Firma değiştiğinde verileri temizle ve yeniden yükle
    func clearAndReloadForNewCompany() async {
        await MainActor.run {
            products = []
            sales = []
        }
        await loadDataFromGitHub()
    }
    
    // MARK: - GitHub Data Loading
    
    /// GitHub'dan tüm verileri yükler (firma bazlı)
    func loadDataFromGitHub() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            // Token yoksa local'den yükle
            loadProductsFromLocal()
            loadSalesFromLocal()
            return
        }
        
        // Firma seçili değilse yükleme
        guard companyManager.currentCompany != nil else {
            await MainActor.run {
                products = []
                sales = []
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        do {
            // Firma bazlı path al
            let productsPath = companyManager.getCompanyDataPath(file: "products.json")
            let salesPath = companyManager.getCompanyDataPath(file: "sales.json")
            
            // Products yükle
            let loadedProducts = try await githubService.getProducts(path: productsPath)
            await MainActor.run {
                products = loadedProducts
            }
            
            // Sales yükle
            let loadedSales = try await githubService.getSales(path: salesPath)
            await MainActor.run {
                sales = loadedSales
                cleanupOldSales()
            }
            
            // Local cache'e de kaydet
            saveProductsToLocal()
            saveSalesToLocal()
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
                // Hata durumunda local'den yükle
                loadProductsFromLocal()
                loadSalesFromLocal()
            }
            print("Error loading from GitHub: \(error)")
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    /// Verileri GitHub'a kaydeder (firma bazlı)
    func syncToGitHub() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            await MainActor.run {
                lastError = "GitHub bağlantısı bulunamadı"
            }
            return
        }
        
        // Firma seçili değilse kaydetme
        guard companyManager.currentCompany != nil else {
            return
        }
        
        await MainActor.run {
            isLoading = true
            lastError = nil
        }
        
        // Firma bazlı path al
        let productsPath = companyManager.getCompanyDataPath(file: "products.json")
        let salesPath = companyManager.getCompanyDataPath(file: "sales.json")
        
        var errors: [String] = []
        
        // Products'ı kaydet
        do {
            try await githubService.saveProducts(products, path: productsPath)
            print("✅ Products synced successfully")
        } catch {
            let errorMsg = "Ürünler kaydedilemedi: \(error.localizedDescription)"
            errors.append(errorMsg)
            print("❌ Error syncing products: \(error)")
        }
        
        // Sales'ı kaydet
        do {
            try await githubService.saveSales(sales, path: salesPath)
            print("✅ Sales synced successfully")
        } catch {
            let errorMsg = "Satışlar kaydedilemedi: \(error.localizedDescription)"
            errors.append(errorMsg)
            print("❌ Error syncing sales: \(error)")
        }
        
        // Hata varsa göster
        if !errors.isEmpty {
            await MainActor.run {
                lastError = errors.joined(separator: "\n")
            }
        } else {
            // Her iki dosya da başarılı, local cache'e de kaydet
            saveProductsToLocal()
            saveSalesToLocal()
            await MainActor.run {
                lastError = nil
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Products Management
    func addProduct(_ product: Product) {
        // Ürünü hemen ekle (MainActor'da @Published değişkeni güncelle)
        // Senkron olarak main thread'de çalıştır ki UI anında güncellensin
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.products.append(product)
            self.saveProductsToLocal()
            print("✅ Product added to list: \(product.name) (Total: \(self.products.count))")
        }
        // GitHub'a push et (sadece products, sales ayrı kaydedilecek)
        Task {
            await syncProductsToGitHub()
        }
    }
    
    func updateProduct(_ product: Product) {
        // Ürünü hemen güncelle (MainActor'da @Published değişkeni güncelle)
        // Senkron olarak main thread'de çalıştır ki UI anında güncellensin
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            if let index = self.products.firstIndex(where: { $0.id == product.id }) {
                self.products[index] = product
                self.saveProductsToLocal()
                print("✅ Product updated in list: \(product.name)")
            }
        }
        // GitHub'a push et (sadece products, sales ayrı kaydedilecek)
        Task {
            await syncProductsToGitHub()
        }
    }
    
    /// Sadece products'ı GitHub'a kaydeder (sales'i kaydetmez)
    private func syncProductsToGitHub() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            await MainActor.run {
                lastError = "GitHub bağlantısı bulunamadı"
            }
            return
        }
        
        // Firma seçili değilse kaydetme
        guard companyManager.currentCompany != nil else {
            return
        }
        
        let productsPath = companyManager.getCompanyDataPath(file: "products.json")
        
        do {
            try await githubService.saveProducts(products, path: productsPath)
            print("✅ Products synced successfully")
            await MainActor.run {
                lastError = nil
            }
        } catch {
            let errorMsg = "Ürünler kaydedilemedi: \(error.localizedDescription)"
            await MainActor.run {
                lastError = errorMsg
            }
            print("❌ Error syncing products: \(error)")
        }
    }
    
    func deleteProduct(_ product: Product) async {
        await MainActor.run {
            products.removeAll { $0.id == product.id }
            saveProductsToLocal()
        }
        // GitHub'a kaydet (yeniden yükleme yapma, silme işlemi zaten yapıldı)
        await syncToGitHub()
    }
    
    func findProduct(byBarcode barcode: String) -> Product? {
        return products.first { $0.barcode == barcode }
    }
    
    // MARK: - Local Cache (Fallback)
    private func saveProductsToLocal() {
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: productsKey)
        }
    }
    
    private func loadProductsFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: productsKey) else {
            products = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Product].self, from: data)
            products = decoded
        } catch {
            print("Error loading products from local: \(error)")
            products = []
        }
    }
    
    // MARK: - Password Management
    func getPassword() -> String {
        return UserDefaults.standard.string(forKey: passwordKey) ?? defaultPassword
    }
    
    func setPassword(_ password: String) {
        UserDefaults.standard.set(password, forKey: passwordKey)
    }
    
    func verifyPassword(_ password: String) -> Bool {
        return password == getPassword()
    }
    
    // MARK: - Sales Management
    func addSale(_ sale: Sale) {
        // Satışı hemen ekle (MainActor'da @Published değişkeni güncelle)
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.sales.append(sale)
            self.saveSalesToLocal()
            self.cleanupOldSales()
            print("✅ Sale added to list: \(sale.items.count) items, Total: \(sale.totalAmount) (Total sales: \(self.sales.count))")
        }
        
        // GitHub'a push et (sadece sales, products ayrı kaydedilecek)
        Task {
            await syncSalesToGitHub()
        }
    }
    
    /// Sadece sales'i GitHub'a kaydeder (products'ı kaydetmez)
    private func syncSalesToGitHub() async {
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            await MainActor.run {
                lastError = "GitHub bağlantısı bulunamadı"
            }
            return
        }
        
        // Firma seçili değilse kaydetme
        guard companyManager.currentCompany != nil else {
            return
        }
        
        let salesPath = companyManager.getCompanyDataPath(file: "sales.json")
        
        do {
            try await githubService.saveSales(sales, path: salesPath)
            print("✅ Sales synced successfully")
            await MainActor.run {
                lastError = nil
            }
        } catch {
            let errorMsg = "Satışlar kaydedilemedi: \(error.localizedDescription)"
            await MainActor.run {
                lastError = errorMsg
            }
            print("❌ Error syncing sales: \(error)")
        }
    }
    
    func getSalesForDate(_ date: Date) -> [Sale] {
        let calendar = Calendar.current
        return sales.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func getSalesGroupedByDate() -> [Date: [Sale]] {
        let calendar = Calendar.current
        var grouped: [Date: [Sale]] = [:]
        
        for sale in sales {
            let dateKey = calendar.startOfDay(for: sale.date)
            if grouped[dateKey] == nil {
                grouped[dateKey] = []
            }
            grouped[dateKey]?.append(sale)
        }
        
        return grouped
    }
    
    private func cleanupOldSales() {
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        let initialCount = sales.count
        
        sales.removeAll { sale in
            sale.date < threeDaysAgo
        }
        
        // Eğer satış silindi ise kaydet
        if sales.count != initialCount {
            saveSalesToLocal()
            // GitHub sync'i arka planda yap (non-blocking)
            Task {
                await syncToGitHub()
            }
        }
    }
    
    // MARK: - Local Cache (Fallback)
    private func saveSalesToLocal() {
        if let encoded = try? JSONEncoder().encode(sales) {
            UserDefaults.standard.set(encoded, forKey: salesKey)
        }
    }
    
    private func loadSalesFromLocal() {
        guard let data = UserDefaults.standard.data(forKey: salesKey) else {
            sales = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Sale].self, from: data)
            sales = decoded
            cleanupOldSales()
        } catch {
            print("Error loading sales from local: \(error)")
            sales = []
        }
    }
}

