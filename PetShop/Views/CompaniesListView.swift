//
//  CompaniesListView.swift
//  PetShop
//
//  View to display all registered companies (admin only)
//

import SwiftUI

struct CompaniesListView: View {
    @StateObject private var companyManager = CompanyManager.shared
    private let githubService = GitHubService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var companyProductCounts: [String: Int] = [:]
    @State private var isLoading = false
    @State private var decryptedPasswords: [String: String] = [:]
    
    var body: some View {
        NavigationView {
            List {
                if isLoading {
                    ProgressView("Yükleniyor...")
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else if companyManager.companies.isEmpty {
                    Text("Henüz kayıtlı firma yok")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(companyManager.companies) { company in
                        CompanyRowView(
                            company: company,
                            productCount: companyProductCounts[company.id] ?? 0,
                            decryptedPassword: decryptedPasswords[company.id] ?? "***"
                        )
                    }
                }
            }
            .navigationTitle("Kayıtlı Firmalar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCompanyData()
            }
        }
    }
    
    private func loadCompanyData() {
        isLoading = true
        Task {
            // Firmaları yeniden yükle
            await companyManager.refreshCompanies()
            
            // Her firma için ürün sayısını ve parolayı yükle
            var counts: [String: Int] = [:]
            var passwords: [String: String] = [:]
            
            for company in companyManager.companies {
                // Ürün sayısını GitHub'dan çek
                let productsPath = "companies/\(company.id)/products.json"
                do {
                    let products = try await githubService.getProducts(path: productsPath)
                    counts[company.id] = products.count
                } catch {
                    counts[company.id] = 0
                }
                
                // Parolayı decrypt et
                let decrypted = await EncryptionService.shared.decryptAsync(company.encryptedPassword)
                passwords[company.id] = decrypted.isEmpty ? "***" : decrypted
            }
            
            await MainActor.run {
                companyProductCounts = counts
                decryptedPasswords = passwords
                isLoading = false
            }
        }
    }
}

struct CompanyRowView: View {
    let company: Company
    let productCount: Int
    let decryptedPassword: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(company.name)
                    .font(.headline)
                Spacer()
                Text("\(productCount) ürün")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label("Kullanıcı Adı:", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(company.username)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Label("Parola:", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(decryptedPassword)
                    .font(.caption)
                    .fontWeight(.medium)
                    .textSelection(.enabled)
            }
            
            HStack {
                Label("Kayıt Tarihi:", systemImage: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(company.createdAt, style: .date)
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

