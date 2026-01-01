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
    var trialExpiresAt: Date // Deneme süresi bitiş tarihi (10 gün)
    
    init(id: String = UUID().uuidString, name: String, username: String, password: String) {
        self.id = id
        self.name = name
        self.username = username
        // Parola şifrelenerek saklanacak
        self.encryptedPassword = EncryptionService.shared.encrypt(password)
        self.createdAt = Date()
        // 10 günlük deneme süresi
        self.trialExpiresAt = Calendar.current.date(byAdding: .day, value: 10, to: Date()) ?? Date()
    }
    
    // Deneme süresi bitmiş mi?
    var isTrialExpired: Bool {
        return Date() > trialExpiresAt
    }
    
    // Kalan deneme günü
    var remainingTrialDays: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: trialExpiresAt)
        return max(0, components.day ?? 0)
    }
    
    // Parolayı doğrula
    func verifyPassword(_ password: String) async -> Bool {
        let decrypted = await EncryptionService.shared.decryptAsync(encryptedPassword)
        let isValid = decrypted == password
        print("Password verification - Encrypted: \(encryptedPassword.prefix(20))..., Decrypted: \(decrypted), Expected: \(password), Match: \(isValid)")
        return isValid
    }
    
    // Parolayı güncelle
    mutating func updatePassword(_ newPassword: String) {
        self.encryptedPassword = EncryptionService.shared.encrypt(newPassword)
    }
}
