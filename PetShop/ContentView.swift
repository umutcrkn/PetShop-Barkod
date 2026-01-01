//
//  ContentView.swift
//  PetShop
//
//  Main entry point - shows login or main menu
//

import SwiftUI

struct ContentView: View {
    @StateObject private var dataManager = DataManager.shared
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
            // Uygulama açıldığında GitHub'dan veri yükle
            Task {
                await dataManager.loadDataFromGitHub()
            }
        }
    }
}

#Preview {
    ContentView()
}
