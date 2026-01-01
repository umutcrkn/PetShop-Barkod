//
//  EncryptionService.swift
//  PetShop
//
//  Simple encryption service for company passwords
//

import Foundation
import CryptoKit

class EncryptionService {
    static let shared = EncryptionService()
    
    private let key: SymmetricKey
    
    private init() {
        // Key'i UserDefaults'tan al veya oluştur
        if let keyData = UserDefaults.standard.data(forKey: "EncryptionKey") {
            self.key = SymmetricKey(data: keyData)
        } else {
            // Yeni key oluştur
            let newKey = SymmetricKey(size: .bits256)
            UserDefaults.standard.set(newKey.withUnsafeBytes { Data($0) }, forKey: "EncryptionKey")
            self.key = newKey
        }
    }
    
    func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else {
            return text
        }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            if let encryptedData = sealedBox.combined {
                return encryptedData.base64EncodedString()
            }
        } catch {
            print("Encryption error: \(error)")
        }
        
        return text
    }
    
    func decrypt(_ encryptedText: String) -> String {
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            return encryptedText
        }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            return String(data: decryptedData, encoding: .utf8) ?? encryptedText
        } catch {
            print("Decryption error: \(error)")
            return encryptedText
        }
    }
}
