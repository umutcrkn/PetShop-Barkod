//
//  AddProductView.swift
//  PetShop
//
//  Add product screen with barcode scanning
//

import SwiftUI

struct AddProductView: View {
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var companyManager = CompanyManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var productName: String = ""
    @State private var productDescription: String = ""
    @State private var productPrice: String = ""
    @State private var productBarcode: String = ""
    @State private var productStock: String = ""
    @State private var showBarcodeScanner = false
    @State private var showBulkImport = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showCompaniesList = false
    
    // Admin kontrolü: currentCompany nil ise admin kullanıcısıdır
    private var isAdmin: Bool {
        companyManager.currentCompany == nil
    }
    
    var body: some View {
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
                
                TextField("Stok Miktarı", text: $productStock)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Button(action: saveProduct) {
                    Text("Ürünü Kaydet")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                }
                
                Button(action: {
                    showBulkImport = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Excel/CSV'den Toplu Ürün Ekle")
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Ürün Ekleme")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCompaniesList = true
                    }) {
                        HStack {
                            Image(systemName: "building.2.fill")
                            Text("Kayıtlı Firmalar")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showBarcodeScanner) {
            BarcodeScannerView(barcode: $productBarcode)
        }
        .sheet(isPresented: $showBulkImport) {
            BulkProductImportView()
        }
        .sheet(isPresented: $showCompaniesList) {
            CompaniesListView()
        }
        .alert("Başarılı", isPresented: $showSuccess) {
            Button("Tamam", role: .cancel) {
                clearForm()
            }
        } message: {
            Text("Ürün başarıyla eklendi!")
        }
        .alert("Hata", isPresented: $showError) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
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
        
        // Check if barcode already exists
        if dataManager.findProduct(byBarcode: productBarcode) != nil {
            errorMessage = "Bu barkod numarası zaten kullanılıyor!"
            showError = true
            return
        }
        
        let stock = Int(productStock) ?? 0
        
        let product = Product(
            name: productName,
            description: productDescription,
            price: price,
            barcode: productBarcode,
            stock: stock
        )
        
        dataManager.addProduct(product)
        showSuccess = true
    }
    
    private func clearForm() {
        productName = ""
        productDescription = ""
        productPrice = ""
        productBarcode = ""
        productStock = ""
    }
}

