//
//  SalesView.swift
//  PetShop
//
//  Sales screen with barcode scanning and total calculation
//

import SwiftUI

struct SalesView: View {
    @StateObject private var dataManager = DataManager.shared
    
    @State private var barcodeInput: String = ""
    @State private var showBarcodeScanner = false
    @State private var selectedProduct: Product?
    @State private var quantity: Int = 1
    @State private var cartItems: [CartItem] = []
    @State private var showError = false
    @State private var showSuccess = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var totalAmount: Double {
        cartItems.reduce(0) { $0 + ($1.product.price * Double($1.quantity)) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Barcode Input Section
            VStack(spacing: 15) {
                HStack {
                    TextField("Barkod Numarası", text: $barcodeInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .onSubmit {
                            searchProduct()
                        }
                    
                    Button(action: {
                        showBarcodeScanner = true
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                if let product = selectedProduct {
                    ProductInfoCard(product: product, quantity: $quantity, onAdd: addToCart)
                }
            }
            .padding(.vertical)
            .background(Color(.systemGray6))
            
            // Cart Items List
            if !cartItems.isEmpty {
                List {
                    ForEach(cartItems) { item in
                        CartItemRow(item: item, onDelete: {
                            removeFromCart(item)
                        })
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
                .listStyle(PlainListStyle())
            } else {
                Spacer()
                Text("Sepet boş")
                    .foregroundColor(.gray)
                Spacer()
            }
            
            // Total and Actions
            VStack(spacing: 15) {
                Divider()
                
                HStack {
                    Text("Toplam Tutar:")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Text(String(format: "%.2f ₺", totalAmount))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                .padding(.horizontal)
                
                HStack(spacing: 15) {
                    Button(action: clearCart) {
                        Text("Sepeti Temizle")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .cornerRadius(10)
                    }
                    
                    Button(action: completeSale) {
                        Text("Satışı Tamamla")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .background(Color(.systemBackground))
        }
        .navigationTitle("Satış")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(barcode: $barcodeInput)
        }
        .onChange(of: barcodeInput) { oldValue, newValue in
            if !newValue.isEmpty {
                searchProduct()
            }
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Başarılı", isPresented: $showSuccess) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
    }
    
    private func searchProduct() {
        guard !barcodeInput.isEmpty else { return }
        
        if let product = dataManager.findProduct(byBarcode: barcodeInput) {
            selectedProduct = product
            quantity = 1
        } else {
            errorMessage = "Ürün bulunamadı! Lütfen barkod numarasını kontrol edin."
            showError = true
            selectedProduct = nil
        }
    }
    
    private func addToCart() {
        guard let product = selectedProduct else { return }
        
        if let existingIndex = cartItems.firstIndex(where: { $0.product.id == product.id }) {
            cartItems[existingIndex].quantity += quantity
        } else {
            cartItems.append(CartItem(product: product, quantity: quantity))
        }
        
        // Update stock
        var updatedProduct = product
        updatedProduct.stock = max(0, product.stock - quantity)
        dataManager.updateProduct(updatedProduct)
        
        selectedProduct = nil
        barcodeInput = ""
        quantity = 1
    }
    
    private func removeFromCart(_ item: CartItem) {
        // Restore stock
        var product = item.product
        product.stock += item.quantity
        dataManager.updateProduct(product)
        
        cartItems.removeAll { $0.id == item.id }
    }
    
    private func clearCart() {
        // Restore all stock
        for item in cartItems {
            var product = item.product
            product.stock += item.quantity
            dataManager.updateProduct(product)
        }
        
        cartItems.removeAll()
        selectedProduct = nil
        barcodeInput = ""
    }
    
    private func completeSale() {
        guard !cartItems.isEmpty else {
            errorMessage = "Sepet boş!"
            showError = true
            return
        }
        
        // Save total amount before clearing cart
        let finalTotal = totalAmount
        
        // Create sale items
        let saleItems = cartItems.map { item in
            SaleItem(
                productName: item.product.name,
                productBarcode: item.product.barcode,
                quantity: item.quantity,
                unitPrice: item.product.price
            )
        }
        
        // Create and save sale
        let sale = Sale(items: saleItems)
        dataManager.addSale(sale)
        
        // Sale completed - stock already updated
        cartItems.removeAll()
        selectedProduct = nil
        barcodeInput = ""
        
        // Show success message with correct total
        successMessage = "Satış başarıyla tamamlandı!\n\nToplam: \(String(format: "%.2f ₺", finalTotal))"
        showSuccess = true
    }
}

struct CartItem: Identifiable {
    let id = UUID()
    var product: Product
    var quantity: Int
}

struct CartItemRow: View {
    let item: CartItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.product.name)
                    .font(.headline)
                Text("\(item.quantity) adet × \(String(format: "%.2f ₺", item.product.price))")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Text(String(format: "%.2f ₺", item.product.price * Double(item.quantity)))
                .font(.headline)
                .foregroundColor(.blue)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 5)
    }
}

struct ProductInfoCard: View {
    let product: Product
    @Binding var quantity: Int
    let onAdd: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(product.name)
                .font(.headline)
            
            if !product.description.isEmpty {
                Text(product.description)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            HStack {
                Text("Fiyat: \(String(format: "%.2f ₺", product.price))")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Spacer()
                
                Text("Stok: \(product.stock)")
                    .font(.subheadline)
                    .foregroundColor(product.stock > 0 ? .green : .red)
            }
            
            HStack {
                Stepper("Adet: \(quantity)", value: $quantity, in: 1...max(1, product.stock))
                
                Button(action: onAdd) {
                    Text("Sepete Ekle")
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(product.stock > 0 ? Color.green : Color.gray)
                        .cornerRadius(8)
                }
                .disabled(product.stock == 0)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

