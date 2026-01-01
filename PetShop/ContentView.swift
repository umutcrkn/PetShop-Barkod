//
//  ContentView.swift
//  PetShop
//
//  Main entry point - shows login or main menu
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var companyManager = CompanyManager.shared
    @State private var isLoggedIn = false
    
    var body: some View {
        NavigationView {
            Group {
                if isLoggedIn {
                    MainMenuView(isLoggedIn: $isLoggedIn)
                } else {
                    LoginView(isLoggedIn: $isLoggedIn)
                }
            }
            .background(Color(.systemBackground))
        }
        .onAppear {
            // Uygulama açıldığında firmaları ve verileri yükle
            Task {
                // Önce firmaları yükle
                await companyManager.loadCompanies()
                // Eğer firma seçiliyse verileri yükle
                if companyManager.currentCompany != nil {
                    await dataManager.loadDataFromGitHub()
                }
            }
        }
        .onChange(of: companyManager.currentCompany?.id) { _ in
            // Firma değiştiğinde verileri yeniden yükle
            Task {
                await dataManager.loadDataFromGitHub()
            }
        }
    }
}

#Preview {
    ContentView()
}
