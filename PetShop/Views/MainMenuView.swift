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
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 30) {
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
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                isLoggedIn = false
            }) {
                Text("Çıkış Yap")
                    .foregroundColor(.red)
                    .padding()
            }
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
                .font(.title)
                .foregroundColor(.white)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .background(color)
        .cornerRadius(15)
    }
}

