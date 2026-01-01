//
//  CompanyRegistrationView.swift
//  PetShop
//
//  Company registration view
//

import SwiftUI

struct CompanyRegistrationView: View {
    @StateObject private var companyManager = CompanyManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var companyName: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var isRegistering = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Firma Bilgileri")) {
                    TextField("Firma Adı", text: $companyName)
                        .autocapitalization(.words)
                    
                    TextField("Kullanıcı Adı", text: $username)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    SecureField("Parola", text: $password)
                    
                    SecureField("Parola (Tekrar)", text: $confirmPassword)
                }
                
                Section {
                    Button(action: registerCompany) {
                        HStack {
                            if isRegistering {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text(isRegistering ? "Kaydediliyor..." : "Firma Kaydet")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(isRegistering || companyName.isEmpty || username.isEmpty || password.isEmpty || password != confirmPassword)
                    .buttonStyle(.borderedProminent)
                    
                    Text("⚠️ 10 günlük deneme süresi")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 5)
                }
                
                if !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
                    Section {
                        Text("Parolalar eşleşmiyor")
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Firma Kaydı")
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
                Button("Tamam") {
                    dismiss()
                }
            } message: {
                Text("Firma başarıyla kaydedildi!\n\n10 günlük deneme süreniz başladı. Deneme süresi bitince firma bilgileri ve verileri otomatik olarak silinecektir.")
            }
        }
    }
    
    private func registerCompany() {
        guard !companyName.isEmpty else {
            errorMessage = "Firma adı gereklidir."
            showError = true
            return
        }
        
        guard !username.isEmpty else {
            errorMessage = "Kullanıcı adı gereklidir."
            showError = true
            return
        }
        
        guard password.count >= 4 else {
            errorMessage = "Parola en az 4 karakter olmalıdır."
            showError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Parolalar eşleşmiyor."
            showError = true
            return
        }
        
        isRegistering = true
        
        Task {
            do {
                try await companyManager.registerCompany(
                    name: companyName,
                    username: username,
                    password: password
                )
                
                // Firma kaydedildikten sonra firmaları yeniden yükle
                await companyManager.refreshCompanies()
                
                await MainActor.run {
                    isRegistering = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isRegistering = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

#Preview {
    CompanyRegistrationView()
}
