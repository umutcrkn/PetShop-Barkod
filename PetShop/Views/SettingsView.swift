//
//  SettingsView.swift
//  PetShop
//
//  Settings view for GitHub configuration
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var companyManager = CompanyManager.shared
    @State private var githubToken: String = ""
    @State private var showToken = false
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSyncing = false
    @State private var showPasswordChange = false
    
    var body: some View {
        Form {
            Section(header: Text("GitHub Ayarları")) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("GitHub Personal Access Token")
                        .font(.headline)
                    
                    Text("Verilerinizi GitHub'da saklamak için bir Personal Access Token gereklidir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if GitHubService.shared.hasToken() {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Token kayıtlı")
                                .foregroundColor(.green)
                            Spacer()
                            Button("Değiştir") {
                                githubToken = ""
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    
                    HStack {
                        if showToken {
                            TextField("ghp_...", text: $githubToken, prompt: Text("GitHub token'ınızı buraya yapıştırın"))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        } else {
                            SecureField("ghp_...", text: $githubToken, prompt: Text("GitHub token'ınızı buraya yapıştırın"))
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        Button(action: {
                            showToken.toggle()
                        }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: {
                        saveToken()
                    }) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isSaving ? "Kaydediliyor..." : GitHubService.shared.hasToken() ? "Token Güncelle" : "Token Kaydet")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isSaving || githubToken.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.vertical, 4)
            }
            
            Section(header: Text("Veri Yönetimi")) {
                Button(action: {
                    syncData()
                }) {
                    HStack {
                        if isSyncing {
                            ProgressView()
                        }
                        Text(isSyncing ? "Senkronize ediliyor..." : "GitHub'dan Veri Çek")
                    }
                }
                .disabled(isSyncing || !GitHubService.shared.hasToken())
                
                Button(action: {
                    pushData()
                }) {
                    HStack {
                        if isSaving {
                            ProgressView()
                        }
                        Text(isSaving ? "Yükleniyor..." : "GitHub'a Veri Gönder")
                    }
                }
                .disabled(isSaving || !GitHubService.shared.hasToken())
            }
            
            Section(header: Text("Durum")) {
                HStack {
                    Text("Bağlantı Durumu:")
                    Spacer()
                    if GitHubService.shared.hasToken() {
                        Label("Bağlı", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Bağlı Değil", systemImage: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                
                if dataManager.isLoading {
                    HStack {
                        Text("Yükleniyor...")
                        Spacer()
                        ProgressView()
                    }
                }
                
                if let error = dataManager.lastError {
                    Text("Hata: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            
            if companyManager.currentCompany != nil {
                Section(header: Text("Firma Ayarları")) {
                    Button(action: {
                        showPasswordChange = true
                    }) {
                        HStack {
                            Image(systemName: "lock.rotation")
                            Text("Parola Değiştir")
                        }
                    }
                }
            }
            
            Section(header: Text("Bilgi")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GitHub Personal Access Token Nasıl Oluşturulur?")
                        .font(.headline)
                    
                    Text("1. GitHub.com'a giriş yapın\n2. Settings > Developer settings > Personal access tokens > Tokens (classic)\n3. 'Generate new token' butonuna tıklayın\n4. 'repo' yetkisini seçin\n5. Token'ı kopyalayıp buraya yapıştırın")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Ayarlar")
        .onAppear {
            // Mevcut token varsa, kullanıcıya bilgi ver (güvenlik için tam token gösterilmez)
            if GitHubService.shared.hasToken() {
                // Token var ama gösterilmiyor (güvenlik)
                githubToken = ""
            }
        }
        .alert("Bilgi", isPresented: $showAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showPasswordChange) {
            CompanyPasswordChangeView()
        }
    }
    
    private func saveToken() {
        guard !githubToken.isEmpty else {
            showAlert = true
            alertMessage = "Lütfen bir token girin."
            return
        }
        
        isSaving = true
        GitHubService.shared.setToken(githubToken)
        
        // Test için GitHub'dan veri çekmeyi dene
        Task {
            do {
                _ = try await GitHubService.shared.getProducts()
                await MainActor.run {
                    isSaving = false
                    showAlert = true
                    alertMessage = "Token başarıyla kaydedildi ve doğrulandı!"
                    
                    // Token'ı temizle (güvenlik)
                    githubToken = ""
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    showAlert = true
                    alertMessage = "Token kaydedildi ancak doğrulama başarısız: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func syncData() {
        isSyncing = true
        Task {
            await dataManager.loadDataFromGitHub()
            await MainActor.run {
                isSyncing = false
                showAlert = true
                alertMessage = dataManager.lastError ?? "Veriler başarıyla yüklendi."
            }
        }
    }
    
    private func pushData() {
        isSaving = true
        Task {
            await dataManager.syncToGitHub()
            await MainActor.run {
                isSaving = false
                showAlert = true
                alertMessage = dataManager.lastError ?? "Veriler başarıyla GitHub'a gönderildi."
            }
        }
    }
}

// MARK: - Company Password Change View

struct CompanyPasswordChangeView: View {
    @StateObject private var companyManager = CompanyManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var isChanging = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Mevcut Parola")) {
                    SecureField("Mevcut Parola", text: $currentPassword)
                }
                
                Section(header: Text("Yeni Parola")) {
                    SecureField("Yeni Parola", text: $newPassword)
                    SecureField("Yeni Parola (Tekrar)", text: $confirmPassword)
                }
                
                if !newPassword.isEmpty && !confirmPassword.isEmpty && newPassword != confirmPassword {
                    Section {
                        Text("Parolalar eşleşmiyor")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                Button(action: changePassword) {
                    HStack {
                        if isChanging {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isChanging ? "Değiştiriliyor..." : "Parolayı Değiştir")
                    }
                }
                .disabled(isChanging || currentPassword.isEmpty || newPassword.isEmpty || newPassword != confirmPassword)
            }
            .navigationTitle("Şifre Değiştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Parola başarıyla değiştirildi!")
            }
        }
    }
    
    private func changePassword() {
        guard !newPassword.isEmpty else {
            errorMessage = "Yeni parola boş olamaz!"
            showError = true
            return
        }
        
        guard newPassword.count >= 4 else {
            errorMessage = "Parola en az 4 karakter olmalıdır."
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Yeni parolalar eşleşmiyor!"
            showError = true
            return
        }
        
        isChanging = true
        Task {
            do {
                try await companyManager.changePassword(currentPassword: currentPassword, newPassword: newPassword)
                await MainActor.run {
                    isChanging = false
                    showSuccess = true
                    currentPassword = ""
                    newPassword = ""
                    confirmPassword = ""
                }
            } catch {
                await MainActor.run {
                    isChanging = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        SettingsView()
    }
}

