//
//  Company.swift
//  PetShop
//
//  Company model for multi-tenant support
//

import Foundation

struct Company: Codable, Identifiable {
    var id: String // Unique company ID
    var name: String
    var username: String
    var encryptedPassword: String // Şifreli parola
    var createdAt: Date
    
    init(id: String = UUID().uuidString, name: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.username = username
        // Parola şifrelenerek saklanacak
        self.encryptedPassword = EncryptionService.shared.encrypt(password)
        self.createdAt = Date()
    }
    
    // Parolayı doğrula
    func verifyPassword(_ password: String) -> Bool {
        let decrypted = EncryptionService.shared.decrypt(encryptedPassword)
        return decrypted == password
    }
}
