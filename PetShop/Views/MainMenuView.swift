//
//  MainMenuView.swift
//  PetShop
//
//  Main menu with product add and sales buttons
//

import SwiftUI

struct MainMenuView: View {
    @Binding var isLoggedIn: Bool
    
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

