//
//  SalesHistoryView.swift
//  PetShop
//
//  Sales history view grouped by date
//

import SwiftUI

struct SalesHistoryView: View {
    @StateObject private var dataManager = DataManager.shared
    @State private var expandedDates: Set<Date> = []
    
    var groupedSales: [(date: Date, sales: [Sale])] {
        let grouped = dataManager.getSalesGroupedByDate()
        return grouped.sorted { $0.key > $1.key }.map { (date: $0.key, sales: $0.value) }
    }
    
    var totalSalesAmount: Double {
        dataManager.sales.reduce(0) { $0 + $1.totalAmount }
    }
    
    
    var body: some View {
        List {
            if groupedSales.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text("Henüz satış yapılmamış")
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
            } else {
                // Summary Section
                Section(header: Text("Özet")) {
                    HStack {
                        Text("Toplam Satış")
                            .font(.headline)
                        Spacer()
                        Text(String(format: "%.2f ₺", totalSalesAmount))
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Toplam Satış Sayısı")
                            .font(.headline)
                        Spacer()
                        Text("\(dataManager.sales.count)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
                
                // Sales by Date
                ForEach(groupedSales, id: \.date) { dateGroup in
                    Section {
                        DisclosureGroup(
                            isExpanded: .init(
                                get: { expandedDates.contains(dateGroup.date) },
                                set: { newValue in
                                    if newValue {
                                        expandedDates.insert(dateGroup.date)
                                    } else {
                                        expandedDates.remove(dateGroup.date)
                                    }
                                }
                            )
                        ) {
                            ForEach(dateGroup.sales) { sale in
                                NavigationLink(destination: SaleDetailView(sale: sale)) {
                                    SaleRowView(sale: sale)
                                }
                            }
                        } label: {
                            HStack {
                                Text(formatDate(dateGroup.date))
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(dateGroup.sales.count) satış")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text(String(format: "%.2f ₺", dateGroup.sales.reduce(0) { $0 + $1.totalAmount }))
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Satışlarım")
        .navigationBarTitleDisplayMode(.large)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "EEEE, d MMMM yyyy"
        return formatter.string(from: date)
    }
}

struct SaleRowView: View {
    let sale: Sale
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(formatTime(sale.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(String(format: "%.2f ₺", sale.totalAmount))
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            
            Text("\(sale.items.count) ürün")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Show first few items
            if !sale.items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sale.items.prefix(2)) { item in
                        Text("• \(item.productName) x\(item.quantity)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if sale.items.count > 2 {
                        Text("... ve \(sale.items.count - 2) ürün daha")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct SaleDetailView: View {
    let sale: Sale
    
    var body: some View {
        List {
            Section(header: Text("Satış Bilgileri")) {
                HStack {
                    Text("Tarih")
                    Spacer()
                    Text(formatDateTime(sale.date))
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Toplam Tutar")
                    Spacer()
                    Text(String(format: "%.2f ₺", sale.totalAmount))
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            
            Section(header: Text("Ürünler (\(sale.items.count))")) {
                ForEach(sale.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.productName)
                                .font(.headline)
                            Text("Barkod: \(item.productBarcode)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(item.quantity) adet")
                                .font(.subheadline)
                            Text(String(format: "%.2f ₺", item.unitPrice))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.2f ₺", item.totalPrice))
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Satış Detayı")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

