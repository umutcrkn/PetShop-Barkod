//
//  Sale.swift
//  PetShop
//
//  Sale model for sales history
//

import Foundation

struct SaleItem: Codable, Identifiable {
    var id: UUID
    var productName: String
    var productBarcode: String
    var quantity: Int
    var unitPrice: Double
    var totalPrice: Double
    
    init(id: UUID = UUID(), productName: String, productBarcode: String, quantity: Int, unitPrice: Double) {
        self.id = id
        self.productName = productName
        self.productBarcode = productBarcode
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.totalPrice = unitPrice * Double(quantity)
    }
}

struct Sale: Codable, Identifiable {
    var id: UUID
    var date: Date
    var items: [SaleItem]
    var totalAmount: Double
    
    init(id: UUID = UUID(), date: Date = Date(), items: [SaleItem]) {
        self.id = id
        self.date = date
        self.items = items
        self.totalAmount = items.reduce(0) { $0 + $1.totalPrice }
    }
}

