//
//  DataManager.swift
//  PetShop
//
//  Data persistence manager
//

import Foundation
import Combine

class DataManager: ObservableObject {
    static let shared = DataManager()
    
    @Published var products: [Product] = []
    @Published var sales: [Sale] = []
    
    private let productsKey = "SavedProducts"
    private let salesKey = "SavedSales"
    private let passwordKey = "UserPassword"
    private let defaultPassword = "admin"
    
    private init() {
        loadProducts()
        loadSales()
        cleanupOldSales()
    }
    
    // MARK: - Products Management
    func addProduct(_ product: Product) {
        products.append(product)
        saveProducts()
    }
    
    func updateProduct(_ product: Product) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
            saveProducts()
        }
    }
    
    func deleteProduct(_ product: Product) {
        products.removeAll { $0.id == product.id }
        saveProducts()
    }
    
    func findProduct(byBarcode barcode: String) -> Product? {
        return products.first { $0.barcode == barcode }
    }
    
    private func saveProducts() {
        if let encoded = try? JSONEncoder().encode(products) {
            UserDefaults.standard.set(encoded, forKey: productsKey)
        }
    }
    
    private func loadProducts() {
        guard let data = UserDefaults.standard.data(forKey: productsKey) else {
            products = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Product].self, from: data)
            products = decoded
        } catch {
            print("Error loading products: \(error)")
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
        sales.append(sale)
        saveSales()
        cleanupOldSales()
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
        
        if sales.count != initialCount { // Only save if something changed
            saveSales()
        }
    }
    
    private func saveSales() {
        if let encoded = try? JSONEncoder().encode(sales) {
            UserDefaults.standard.set(encoded, forKey: salesKey)
        }
    }
    
    private func loadSales() {
        guard let data = UserDefaults.standard.data(forKey: salesKey) else {
            sales = []
            return
        }
        
        do {
            let decoded = try JSONDecoder().decode([Sale].self, from: data)
            sales = decoded
            cleanupOldSales()
        } catch {
            print("Error loading sales: \(error)")
            sales = []
        }
    }
}

