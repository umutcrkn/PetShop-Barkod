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
    @State private var selectedCompany: Company?
    @State private var showExtendTrialSheet = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isExtending = false
    
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
                            },
                            onTap: {
                                selectedCompany = company
                                showExtendTrialSheet = true
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
            .sheet(isPresented: $showExtendTrialSheet) {
                if let company = selectedCompany {
                    ExtendTrialView(
                        company: company,
                        onExtended: {
                            loadCompanyData()
                        }
                    )
                }
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
    let onTap: () -> Void
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct ExtendTrialView: View {
    let company: Company
    let onExtended: () -> Void
    @Environment(\.dismiss) var dismiss
    @StateObject private var companyManager = CompanyManager.shared
    
    @State private var isExtending = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Firma Bilgileri")) {
                    HStack {
                        Text("Firma Adı:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(company.name)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Kullanıcı Adı:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(company.username)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Mevcut Deneme Süresi:")
                            .foregroundColor(.secondary)
                        Spacer()
                        if company.isTrialExpired {
                            Text("Süresi Dolmuş")
                                .foregroundColor(.red)
                                .fontWeight(.medium)
                        } else {
                            Text("\(company.remainingTrialDays) gün kaldı")
                                .foregroundColor(company.remainingTrialDays <= 3 ? .orange : .primary)
                                .fontWeight(.medium)
                        }
                    }
                    
                    HStack {
                        Text("Bitiş Tarihi:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(company.trialExpiresAt, style: .date)
                            .fontWeight(.medium)
                    }
                }
                
                Section(header: Text("Deneme Süresini Uzat")) {
                    Button(action: { extendTrial(days: 7) }) {
                        HStack {
                            if isExtending {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("7 Gün Ekle")
                        }
                    }
                    .disabled(isExtending)
                    
                    Button(action: { extendTrial(days: 15) }) {
                        HStack {
                            if isExtending {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("15 Gün Ekle")
                        }
                    }
                    .disabled(isExtending)
                    
                    Button(action: { extendTrial(days: 30) }) {
                        HStack {
                            if isExtending {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("30 Gün Ekle")
                        }
                    }
                    .disabled(isExtending)
                    
                    Button(action: { extendTrial(days: 60) }) {
                        HStack {
                            if isExtending {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("60 Gün Ekle")
                        }
                    }
                    .disabled(isExtending)
                }
            }
            .navigationTitle("Deneme Süresi Uzat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam") {
                    onExtended()
                    dismiss()
                }
            } message: {
                Text("Deneme süresi başarıyla uzatıldı!")
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func extendTrial(days: Int) {
        isExtending = true
        Task {
            do {
                try await companyManager.extendTrialPeriod(for: company.id, days: days)
                await MainActor.run {
                    isExtending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isExtending = false
                    errorMessage = "Deneme süresi uzatılırken hata oluştu: \(error.localizedDescription)"
                    showError = true
                }
            }
        }
    }
}

