//
//  ProductListView.swift
//  PetShop
//
//  Product list view with edit and delete options
//

import SwiftUI

struct ProductListView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var searchText = ""
    @State private var selectedProduct: Product?
    @State private var showBackupSheet = false
    @State private var selectedProducts: Set<Product.ID> = []
    @State private var showDeleteConfirmation = false
    @State private var showBarcodeScanner = false
    @Environment(\.editMode) var editMode
    
    var filteredProducts: [Product] {
        if searchText.isEmpty {
            return dataManager.products.sorted { $0.name < $1.name }
        } else {
            return dataManager.products.filter { product in
                product.name.localizedCaseInsensitiveContains(searchText) ||
                product.barcode.localizedCaseInsensitiveContains(searchText) ||
                product.barcode.replacingOccurrences(of: " ", with: "").localizedCaseInsensitiveContains(searchText.replacingOccurrences(of: " ", with: "")) ||
                product.description.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.name < $1.name }
        }
    }
    
    var body: some View {
        listContent
            .navigationTitle("Ürün Listesi")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Ürün adı, barkod veya açıklama ara...")
            .sheet(item: $selectedProduct) { product in
                ProductEditView(product: product)
            }
            .sheet(isPresented: $showBackupSheet) {
                BackupExportView()
            }
            .sheet(isPresented: $showBarcodeScanner) {
                BarcodeScannerView(barcode: $searchText)
            }
            .toolbar {
                toolbarContent
            }
            .alert("Ürünleri Sil", isPresented: $showDeleteConfirmation) {
                Button("İptal", role: .cancel) { }
                Button("Sil", role: .destructive) {
                    deleteSelectedProducts()
                }
            } message: {
                Text("\(selectedProducts.count) ürünü silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
            }
            .onChange(of: editMode?.wrappedValue) { oldValue, newValue in
                if newValue == .inactive {
                    selectedProducts.removeAll()
                }
            }
            .onAppear {
                // View görünür olduğunda verileri GitHub'dan yeniden yükle
                Task {
                    await dataManager.loadDataFromGitHub()
                }
            }
            .onChange(of: selectedProduct) { oldValue, newValue in
                // Ürün düzenleme ekranı kapandığında verileri yeniden yükle
                if newValue == nil && oldValue != nil {
                    Task {
                        await dataManager.loadDataFromGitHub()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                backupButton
            }
    }
    
    @ViewBuilder
    private var listContent: some View {
        List(selection: $selectedProducts) {
            if filteredProducts.isEmpty {
                emptyStateView
            } else {
                productsList
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("Henüz ürün eklenmemiş")
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
    
    private var productsList: some View {
        ForEach(filteredProducts) { product in
            ProductRowView(product: product)
                .contentShape(Rectangle())
                .onTapGesture {
                    if editMode?.wrappedValue == .inactive {
                        selectedProduct = product
                    }
                }
                .tag(product.id)
        }
        .onDelete(perform: deleteProducts)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if editMode?.wrappedValue == .inactive {
                Button(action: {
                    showBarcodeScanner = true
                }) {
                    Image(systemName: "camera.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                if editMode?.wrappedValue == .active {
                    if selectedProducts.count == filteredProducts.count {
                        Button(action: {
                            selectedProducts.removeAll()
                        }) {
                            Text("Seçimi Kaldır")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Button(action: {
                            selectedProducts = Set(filteredProducts.map { $0.id })
                        }) {
                            Text("Hepsini Seç")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if !selectedProducts.isEmpty {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Sil (\(selectedProducts.count))")
                            }
                            .foregroundColor(.red)
                        }
                    }
                }
                EditButton()
            }
        }
    }
    
    @ViewBuilder
    private var backupButton: some View {
        if !dataManager.products.isEmpty {
            Button(action: {
                selectedProduct = nil
                showBackupSheet = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Yedekle ve Mail Gönder")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            dataManager.deleteProduct(product)
        }
    }
    
    private func deleteSelectedProducts() {
        for productId in selectedProducts {
            if let product = dataManager.products.first(where: { $0.id == productId }) {
                dataManager.deleteProduct(product)
            }
        }
        selectedProducts.removeAll()
        editMode?.wrappedValue = .inactive
    }
}

struct ProductRowView: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(String(format: "%.2f ₺", product.price))
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Label(product.barcode, systemImage: "barcode")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Label("\(product.stock) adet", systemImage: "cube.box")
                    .font(.subheadline)
                    .foregroundColor(product.stock > 0 ? .green : .red)
            }
            
            if !product.description.isEmpty {
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

