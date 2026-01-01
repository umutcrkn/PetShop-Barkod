//
//  LoginView.swift
//  PetShop
//
//  Login screen with password change option
//

import SwiftUI

struct LoginView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var companyManager = CompanyManager.shared
    @Binding var isLoggedIn: Bool
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showCompanyRegistration = false
    @State private var showPasswordChange = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo or Title
            Text("Pet Malzeme Satış")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            
            // Login Form
            VStack(spacing: 20) {
                if companyManager.isLoading {
                    ProgressView("Firmalar yükleniyor...")
                        .padding()
                }
                
                if !companyManager.companies.isEmpty {
                    Text("Kayıtlı Firmalar: \(companyManager.companies.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 5)
                }
                
                if let error = companyManager.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 40)
                        .multilineTextAlignment(.center)
                }
                
                TextField("Kullanıcı Adı", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal, 40)
                
                SecureField("Parola", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 40)
                    .onSubmit {
                        login()
                    }
                
                Button(action: login) {
                    Text("Giriş Yap")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                
                HStack(spacing: 20) {
                    Button(action: {
                        showCompanyRegistration = true
                    }) {
                        Text("Yeni Firma Kaydet")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        Task {
                            await companyManager.refreshCompanies()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Yenile")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 10)
                
                // Parola değiştirme butonu (kullanıcı adı girildiyse görünür)
                if !username.isEmpty {
                    Button(action: {
                        // Firmayı kontrol et ve seç
                        if let company = companyManager.companies.first(where: { $0.username.lowercased() == username.lowercased() }) {
                            companyManager.selectCompany(company)
                            showPasswordChange = true
                        } else {
                            errorMessage = "Bu kullanıcı adına sahip bir firma bulunamadı."
                            showError = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "lock.rotation")
                            Text("Parola Değiştir")
                        }
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    }
                    .padding(.top, 10)
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Giriş")
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showCompanyRegistration) {
            CompanyRegistrationView()
        }
        .sheet(isPresented: $showPasswordChange) {
            CompanyPasswordChangeView()
        }
        .onAppear {
            Task {
                // Önce encryption key'i GitHub'dan zorla yükle (local key'i atla)
                await EncryptionService.shared.loadEncryptionKey(forceReload: true)
                // Sonra firmaları yükle
                await companyManager.loadCompanies()
            }
        }
        .onChange(of: showCompanyRegistration) { oldValue, newValue in
            // Firma kaydı kapandığında firmaları yeniden yükle
            if !newValue {
                Task {
                    await companyManager.refreshCompanies()
                }
            }
        }
    }
    
    private func login() {
        Task {
            // Önce encryption key'i GitHub'dan zorla yükle (local key'i atla)
            await EncryptionService.shared.loadEncryptionKey(forceReload: true)
            
            // Firmaları da yeniden yükle (güncel olmalı)
            await companyManager.refreshCompanies()
            
            // Firma girişi dene
            do {
                if try await companyManager.loginCompany(username: username, password: password) {
                    await MainActor.run {
                        isLoggedIn = true
                        username = ""
                        password = ""
                    }
                    return
                }
            } catch let error as CompanyError {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                }
                return
            } catch {
                await MainActor.run {
                    errorMessage = "Giriş yapılırken bir hata oluştu: \(error.localizedDescription)"
                    showError = true
                }
                return
            }
            
            // Eski admin girişi (backward compatibility)
            if username.lowercased() == "admin" && dataManager.verifyPassword(password) {
                await MainActor.run {
                    isLoggedIn = true
                    username = ""
                    password = ""
                }
                return
            }
            
            await MainActor.run {
                errorMessage = "Kullanıcı adı veya parola hatalı!"
                showError = true
            }
        }
    }
}

struct PasswordChangeView: View {
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var currentPassword: String = ""
    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
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
                
                Button(action: changePassword) {
                    Text("Parolayı Değiştir")
                        .foregroundColor(.blue)
                }
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
        guard dataManager.verifyPassword(currentPassword) else {
            errorMessage = "Mevcut parola hatalı!"
            showError = true
            return
        }
        
        guard !newPassword.isEmpty else {
            errorMessage = "Yeni parola boş olamaz!"
            showError = true
            return
        }
        
        guard newPassword == confirmPassword else {
            errorMessage = "Yeni parolalar eşleşmiyor!"
            showError = true
            return
        }
        
        dataManager.setPassword(newPassword)
        showSuccess = true
    }
}

