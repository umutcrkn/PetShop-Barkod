//
//  CompaniesListView.swift
//  PetShop
//
//  View to display all registered companies (admin only) with delete functionality
//

import SwiftUI

struct CompaniesListView: View {
    @StateObject private var companyManager = CompanyManager.shared
    private let githubService = GitHubService.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var companyProductCounts: [String: Int] = [:]
    @State private var isLoading = false
    @State private var decryptedPasswords: [String: String] = [:]
    @State private var companyToDelete: Company?
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""
    
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
                            decryptedPassword: decryptedPasswords[company.id] ?? "***",
                            onDelete: {
                                companyToDelete = company
                                showDeleteConfirmation = true
                            }
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
            .alert("Firmayı Sil", isPresented: $showDeleteConfirmation) {
                Button("İptal", role: .cancel) {
                    companyToDelete = nil
                }
                Button("Sil", role: .destructive) {
                    if let company = companyToDelete {
                        deleteCompany(company)
                    }
                }
            } message: {
                if let company = companyToDelete {
                    Text("'\(company.name)' firmasını silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
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
    
    private func deleteCompany(_ company: Company) {
        Task {
            do {
                try await companyManager.deleteCompany(company)
                // Firmaları yeniden yükle
                await loadCompanyData()
            } catch {
                await MainActor.run {
                    errorMessage = "Firma silinirken hata oluştu: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

struct CompanyRowView: View {
    let company: Company
    let productCount: Int
    let decryptedPassword: String
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(company.name)
                    .font(.headline)
                Spacer()
                Text("\(productCount) ürün")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
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
            
            HStack {
                if company.isTrialExpired {
                    Label("Deneme Süresi:", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("Süresi Dolmuş")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                } else {
                    Label("Deneme Süresi:", systemImage: "clock.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(company.remainingTrialDays) gün kaldı")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(company.remainingTrialDays <= 3 ? .orange : .primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

