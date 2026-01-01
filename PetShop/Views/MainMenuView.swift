//
//  MainMenuView.swift
//  PetShop
//
//  Main menu with product add and sales buttons
//

import SwiftUI

struct MainMenuView: View {
    @Binding var isLoggedIn: Bool
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var companyManager = CompanyManager.shared
    @State private var isUpdating = false
    @State private var showUpdateAlert = false
    @State private var updateMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 30) {
                Spacer()
                
                NavigationLink(destination: AddProductView()) {
                    MenuButton(title: "Ürün Ekleme", icon: "plus.circle.fill", color: .green)
                }
                
                NavigationLink(destination: ProductListView()) {
                    MenuButton(title: "Ürün Listesi", icon: "list.bullet", color: .orange)
                }
                
                NavigationLink(destination: SalesView()) {
                    MenuButton(title: "Satış", icon: "cart.fill", color: .blue)
                }
                
                NavigationLink(destination: SalesHistoryView()) {
                    MenuButton(title: "Satışlarım", icon: "chart.bar.doc.horizontal", color: .purple)
                }
                
                Button(action: {
                    updateSystem()
                }) {
                    HStack {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        
                        Text(isUpdating ? "Güncelleniyor..." : "Sistemi Güncelle")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.teal)
                    .cornerRadius(15)
                }
                .disabled(isUpdating)
                .padding(.horizontal, 40)
                
                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            VStack(spacing: 20) {
                Divider()
                    .padding(.vertical, 10)
                
                NavigationLink(destination: SettingsView()) {
                    MenuButton(title: "Ayarlar", icon: "gearshape.fill", color: .gray)
                }
                .padding(.horizontal, 40)
                
                Button(action: {
                    isLoggedIn = false
                }) {
                    Text("Çıkış Yap")
                        .foregroundColor(.red)
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("Güncelleme", isPresented: $showUpdateAlert) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(updateMessage)
        }
    }
    
    private func updateSystem() {
        guard !isUpdating else { return }
        
        isUpdating = true
        Task {
            // 1. Firmaları yeniden yükle
            await companyManager.refreshCompanies()
            
            // 2. Encryption key'i yükle
            await EncryptionService.shared.loadEncryptionKey(forceReload: true)
            
            // 3. Verileri GitHub'dan yükle
            await dataManager.loadDataFromGitHub()
            
            // 4. Verileri GitHub'a push et (senkronize et)
            await dataManager.syncToGitHub()
            
            // Hata kontrolü (lastError varsa göster)
            let errorMessage = dataManager.lastError ?? companyManager.lastError
            
            await MainActor.run {
                isUpdating = false
                if let error = errorMessage {
                    updateMessage = "Güncelleme sırasında hata oluştu: \(error)"
                } else {
                    updateMessage = "Sistem başarıyla güncellendi!"
                }
                showUpdateAlert = true
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(color)
        .cornerRadius(15)
    }
}

