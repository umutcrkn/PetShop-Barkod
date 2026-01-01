//
//  ProductEditView.swift
//  PetShop
//
//  Product edit view
//

import SwiftUI

struct ProductEditView: View {
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) var dismiss
    
    let product: Product
    
    @State private var productName: String = ""
    @State private var productDescription: String = ""
    @State private var productPrice: String = ""
    @State private var productBarcode: String = ""
    @State private var stockValue: Int = 0
    @State private var showBarcodeScanner = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ürün Bilgileri")) {
                    TextField("Ürün Adı", text: $productName)
                    
                    TextField("Açıklama", text: $productDescription)
                    
                    TextField("Fiyat", text: $productPrice)
                        .keyboardType(.decimalPad)
                    
                    HStack {
                        TextField("Barkod", text: $productBarcode)
                            .keyboardType(.numberPad)
                        
                        Button(action: {
                            showBarcodeScanner = true
                        }) {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    HStack {
                        Text("Stok Miktarı")
                        
                        Spacer()
                        
                        HStack(spacing: 15) {
                            Button(action: {
                                if stockValue > 0 {
                                    stockValue -= 1
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            
                            TextField("0", text: Binding(
                                get: { String(stockValue) },
                                set: { newValue in
                                    if let value = Int(newValue) {
                                        stockValue = max(0, min(9999, value))
                                    } else if newValue.isEmpty {
                                        stockValue = 0
                                    }
                                }
                            ))
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                            .multilineTextAlignment(.center)
                            
                            Button(action: {
                                if stockValue < 9999 {
                                    stockValue += 1
                                }
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: saveProduct) {
                        Text("Değişiklikleri Kaydet")
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                    }
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Text("Ürünü Sil")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Ürün Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(barcode: $productBarcode)
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("Ürün başarıyla güncellendi!")
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Ürünü Sil", isPresented: $showDeleteConfirmation) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    dataManager.deleteProduct(product)
                    dismiss()
                }
            } message: {
                Text("Bu ürünü silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
            }
        }
        .onAppear {
            loadProductData()
        }
    }
    
    private func loadProductData() {
        productName = product.name
        productDescription = product.description
        productPrice = String(format: "%.2f", product.price)
        productBarcode = product.barcode
        stockValue = product.stock
    }
    
    private func saveProduct() {
        guard !productName.isEmpty else {
            errorMessage = "Ürün adı boş olamaz!"
            showError = true
            return
        }
        
        guard let price = Double(productPrice), price > 0 else {
            errorMessage = "Geçerli bir fiyat giriniz!"
            showError = true
            return
        }
        
        guard !productBarcode.isEmpty else {
            errorMessage = "Barkod numarası boş olamaz!"
            showError = true
            return
        }
        
        // Check if barcode is already used by another product
        if let existingProduct = dataManager.findProduct(byBarcode: productBarcode),
           existingProduct.id != product.id {
            errorMessage = "Bu barkod numarası başka bir ürün tarafından kullanılıyor!"
            showError = true
            return
        }
        
        let stock = stockValue
        
        var updatedProduct = product
        updatedProduct.name = productName
        updatedProduct.description = productDescription
        updatedProduct.price = price
        updatedProduct.barcode = productBarcode
        updatedProduct.stock = stock
        
        dataManager.updateProduct(updatedProduct)
        showSuccess = true
    }
    
}

