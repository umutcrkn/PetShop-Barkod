//
//  BulkProductImportView.swift
//  PetShop
//
//  Bulk product import from CSV
//

import SwiftUI
import UniformTypeIdentifiers

struct BulkProductImportView: View {
    @StateObject private var dataManager = DataManager.shared
    @Environment(\.dismiss) var dismiss
    
    @State private var csvContent: String = ""
    @State private var showDocumentPicker = false
    @State private var importedProducts: [ImportedProduct] = []
    @State private var showPreview = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var successCount = 0
    @State private var errorCount = 0
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Dosya Seçimi")) {
                    Button(action: {
                        showDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("CSV Dosyası Seç")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if !csvContent.isEmpty {
                        Text("Dosya yüklendi: \(importedProducts.count) ürün bulundu")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section(header: Text("CSV Formatı")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CSV dosyası şu formatta olmalıdır:")
                            .font(.subheadline)
                        
                        Text("Ürün Adı, Açıklama, Fiyat, Barkod, Stok")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(5)
                        
                        Text("Örnek:")
                            .font(.subheadline)
                            .padding(.top, 4)
                        
                        Text("Köpek Maması, Premium köpek maması, 150.50, 1234567890123, 50")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(5)
                        
                        Text("Not: İlk satır başlık olabilir, atlanacaktır.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if !importedProducts.isEmpty {
                    Section(header: Text("Önizleme (\(importedProducts.count) ürün)")) {
                        List {
                            ForEach(Array(importedProducts.enumerated()), id: \.offset) { index, product in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.name)
                                        .font(.headline)
                                    Text("Barkod: \(product.barcode) | Fiyat: \(String(format: "%.2f", product.price)) ₺ | Stok: \(product.stock)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 200)
                    }
                    
                    Section {
                        Button(action: importProducts) {
                            Text("Ürünleri Ekle (\(importedProducts.count))")
                                .foregroundColor(.green)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle("Toplu Ürün Ekleme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $showDocumentPicker,
                allowedContentTypes: [.commaSeparatedText, .text, .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        loadCSV(from: url)
                    }
                case .failure(let error):
                    errorMessage = "Dosya yüklenirken hata: \(error.localizedDescription)"
                    showError = true
                }
            }
            .alert("Başarılı", isPresented: $showSuccess) {
                Button("Tamam", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("\(successCount) ürün başarıyla eklendi!\n\(errorCount) ürün atlandı (hata veya tekrar).")
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func loadCSV(from url: URL) {
        do {
            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Dosyaya erişim izni verilmedi"
                showError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let content = try String(contentsOf: url, encoding: .utf8)
            parseCSV(content: content)
        } catch {
            errorMessage = "Dosya okunamadı: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func parseCSV(content: String) {
        let lines = content.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        var products: [ImportedProduct] = []
        
        for (index, line) in lines.enumerated() {
            // Skip header row if it looks like a header
            if index == 0 && (line.lowercased().contains("ürün") || line.lowercased().contains("product")) {
                continue
            }
            
            let columns = parseCSVLine(line)
            
            guard columns.count >= 5 else {
                continue
            }
            
            let name = columns[0].trimmingCharacters(in: .whitespaces)
            let description = columns[1].trimmingCharacters(in: .whitespaces)
            let priceString = columns[2].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
            let barcode = columns[3].trimmingCharacters(in: .whitespaces)
            let stockString = columns[4].trimmingCharacters(in: .whitespaces)
            
            guard !name.isEmpty, !barcode.isEmpty,
                  let price = Double(priceString), price > 0,
                  let stock = Int(stockString) else {
                continue
            }
            
            products.append(ImportedProduct(
                name: name,
                description: description,
                price: price,
                barcode: barcode,
                stock: stock
            ))
        }
        
        importedProducts = products
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        
        return result
    }
    
    private func importProducts() {
        guard !importedProducts.isEmpty else {
            errorMessage = "İçe aktarılacak ürün bulunamadı!"
            showError = true
            return
        }
        
        successCount = 0
        errorCount = 0
        
        for importedProduct in importedProducts {
            // Check if barcode already exists
            if dataManager.findProduct(byBarcode: importedProduct.barcode) != nil {
                errorCount += 1
                continue
            }
            
            let product = Product(
                name: importedProduct.name,
                description: importedProduct.description,
                price: importedProduct.price,
                barcode: importedProduct.barcode,
                stock: importedProduct.stock
            )
            
            dataManager.addProduct(product)
            successCount += 1
        }
        
        showSuccess = true
        importedProducts = []
        csvContent = ""
    }
}

struct ImportedProduct {
    let name: String
    let description: String
    let price: Double
    let barcode: String
    let stock: Int
}

