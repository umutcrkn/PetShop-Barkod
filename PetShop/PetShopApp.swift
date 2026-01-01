//
//  PetShopApp.swift
//  PetShop
//
//  Created by Umut on 30.12.2025.
//

import SwiftUI

@main
struct PetShopApp: App {
    init() {
        // Uygulama başlangıcında GitHub token'ını otomatik ayarla
        setupGitHubConnection()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func setupGitHubConnection() {
        // Config.swift'ten token'ı oku ve ayarla
        if let token = AppConfig.githubToken, !token.isEmpty {
            GitHubService.shared.setToken(token)
        }
        
        // API URL'i de ayarla (varsa)
        if let apiURL = AppConfig.apiBaseURL, !apiURL.isEmpty {
            GitHubService.shared.setAPIURL(apiURL)
        }
    }
}
