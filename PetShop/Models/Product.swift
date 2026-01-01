//
//  Product.swift
//  PetShop
//
//  Product model
//

import Foundation

struct Product: Codable, Identifiable {
    var id: UUID
    var name: String
    var description: String
    var price: Double
    var barcode: String
    var stock: Int
    
    init(id: UUID = UUID(), name: String, description: String, price: Double, barcode: String, stock: Int) {
        self.id = id
        self.name = name
        self.description = description
        self.price = price
        self.barcode = barcode
        self.stock = stock
    }
}

