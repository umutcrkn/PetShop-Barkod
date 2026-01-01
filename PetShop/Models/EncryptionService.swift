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
    
    private var key: SymmetricKey?
    private let githubService = GitHubService.shared
    private let encryptionKeyPath = "config/encryption_key.json"
    
    private init() {
        Task {
            await loadEncryptionKey()
        }
    }
    
    /// Encryption key'i GitHub'dan yükle veya oluştur
    func loadEncryptionKey() async {
        // Önce UserDefaults'tan kontrol et
        if let keyData = UserDefaults.standard.data(forKey: "EncryptionKey") {
            self.key = SymmetricKey(data: keyData)
            return
        }
        
        // GitHub'dan yükle
        guard githubService.hasAPIURL() || githubService.hasToken() else {
            // GitHub bağlantısı yoksa local key oluştur
            createLocalKey()
            return
        }
        
        do {
            let data = try await githubService.getFileContent(path: encryptionKeyPath)
            
            if !data.isEmpty {
                // GitHub'dan key'i yükle
                if let keyData = try? JSONDecoder().decode(EncryptionKeyData.self, from: data) {
                    if let keyBytes = Data(base64Encoded: keyData.key) {
                        self.key = SymmetricKey(data: keyBytes)
                        // Local'e de kaydet
                        UserDefaults.standard.set(keyBytes, forKey: "EncryptionKey")
                        return
                    }
                }
            }
            
            // GitHub'da key yoksa oluştur ve kaydet
            let newKey = SymmetricKey(size: .bits256)
            let keyBytes = newKey.withUnsafeBytes { Data($0) }
            let keyData = EncryptionKeyData(key: keyBytes.base64EncodedString())
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encodedData = try encoder.encode(keyData)
            
            try await githubService.putFileContent(
                path: encryptionKeyPath,
                content: encodedData,
                message: "Create encryption key"
            )
            
            self.key = newKey
            UserDefaults.standard.set(keyBytes, forKey: "EncryptionKey")
            
        } catch {
            print("Error loading encryption key from GitHub: \(error)")
            // Hata durumunda local key oluştur
            createLocalKey()
        }
    }
    
    /// Local key oluştur
    private func createLocalKey() {
        let newKey = SymmetricKey(size: .bits256)
        UserDefaults.standard.set(newKey.withUnsafeBytes { Data($0) }, forKey: "EncryptionKey")
        self.key = newKey
    }
    
    /// Key'in yüklendiğinden emin ol
    private func ensureKey() -> SymmetricKey {
        if let key = key {
            return key
        }
        // Key yüklenmemişse bekle (async yükleme için)
        // Geçici olarak local key oluştur
        if let keyData = UserDefaults.standard.data(forKey: "EncryptionKey") {
            return SymmetricKey(data: keyData)
        }
        let newKey = SymmetricKey(size: .bits256)
        UserDefaults.standard.set(newKey.withUnsafeBytes { Data($0) }, forKey: "EncryptionKey")
        return newKey
    }
    
    func encrypt(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else {
            return text
        }
        
        let encryptionKey = ensureKey()
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
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
        
        let encryptionKey = ensureKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8) ?? encryptedText
        } catch {
            print("Decryption error: \(error)")
            return encryptedText
        }
    }
}

// MARK: - Encryption Key Data Model

struct EncryptionKeyData: Codable {
    let key: String // Base64 encoded key
}
