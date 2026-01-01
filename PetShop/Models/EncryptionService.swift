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
    func loadEncryptionKey(forceReload: Bool = false) async {
        // Force reload isteniyorsa UserDefaults'ı temizle
        if forceReload {
            UserDefaults.standard.removeObject(forKey: "EncryptionKey")
            self.key = nil
        }
        
        // Önce UserDefaults'tan kontrol et (force reload değilse)
        if !forceReload, let keyData = UserDefaults.standard.data(forKey: "EncryptionKey") {
            self.key = SymmetricKey(data: keyData)
            // GitHub'dan da kontrol et (key güncel mi?)
            // Bu kontrolü arka planda yap, şimdilik local key'i kullan
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
            // Önce tekrar kontrol et (race condition için)
            let retryData = try? await githubService.getFileContent(path: encryptionKeyPath)
            if let retryData = retryData, !retryData.isEmpty,
               let keyData = try? JSONDecoder().decode(EncryptionKeyData.self, from: retryData),
               let keyBytes = Data(base64Encoded: keyData.key) {
                // Başka bir cihaz key'i oluşturmuş, onu kullan
                self.key = SymmetricKey(data: keyBytes)
                UserDefaults.standard.set(keyBytes, forKey: "EncryptionKey")
                return
            }
            
            // Hala yoksa oluştur
            let newKey = SymmetricKey(size: .bits256)
            let keyBytes = newKey.withUnsafeBytes { Data($0) }
            let keyData = EncryptionKeyData(key: keyBytes.base64EncodedString())
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let encodedData = try encoder.encode(keyData)
            
            // Dosya oluşturmayı dene, 409 hatası alırsak tekrar yükle
            do {
                try await githubService.putFileContent(
                    path: encryptionKeyPath,
                    content: encodedData,
                    message: "Create encryption key"
                )
                
                self.key = newKey
                UserDefaults.standard.set(keyBytes, forKey: "EncryptionKey")
            } catch let error as GitHubError {
                // 409 hatası alırsak (dosya başka bir cihaz tarafından oluşturulmuş)
                // Tekrar yükle
                if case .httpError(409) = error {
                    let finalData = try await githubService.getFileContent(path: encryptionKeyPath)
                    if !finalData.isEmpty,
                       let keyData = try? JSONDecoder().decode(EncryptionKeyData.self, from: finalData),
                       let keyBytes = Data(base64Encoded: keyData.key) {
                        self.key = SymmetricKey(data: keyBytes)
                        UserDefaults.standard.set(keyBytes, forKey: "EncryptionKey")
                        return
                    }
                }
                throw error
            }
            
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
        // Key yüklenmemişse local'den yükle
        if let keyData = UserDefaults.standard.data(forKey: "EncryptionKey") {
            let loadedKey = SymmetricKey(data: keyData)
            self.key = loadedKey
            return loadedKey
        }
        // Local'de de yoksa yeni key oluştur (bu durumda sorun var)
        print("Warning: Encryption key not found, creating new key. This may cause decryption failures.")
        let newKey = SymmetricKey(size: .bits256)
        UserDefaults.standard.set(newKey.withUnsafeBytes { Data($0) }, forKey: "EncryptionKey")
        self.key = newKey
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
            print("Decryption error: Invalid base64 data")
            return encryptedText
        }
        
        let encryptionKey = ensureKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8) ?? encryptedText
        } catch {
            print("Decryption error: \(error)")
            print("Encrypted text length: \(encryptedText.count)")
            print("Key loaded: \(key != nil)")
            
            // Authentication failure hatası alırsak, key yanlış olabilir
            // GitHub'dan key'i yeniden yüklemeyi dene (arka planda)
            if error.localizedDescription.contains("authenticationFailure") || 
               error.localizedDescription.contains("authentication") {
                print("Authentication failure detected, reloading key from GitHub...")
                // Arka planda key'i yeniden yükle (bir sonraki denemede kullanılacak)
                Task {
                    await loadEncryptionKey(forceReload: true)
                }
            }
            
            return encryptedText
        }
    }
    
    /// Async decrypt metodu (key reload ile)
    func decryptAsync(_ encryptedText: String) async -> String {
        guard let encryptedData = Data(base64Encoded: encryptedText) else {
            print("Decryption error: Invalid base64 data")
            return "" // Boş string döndür, parola eşleşmesin
        }
        
        // Önce mevcut key ile dene
        var encryptionKey = ensureKey()
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            let decrypted = String(data: decryptedData, encoding: .utf8) ?? ""
            print("Decryption successful with current key")
            return decrypted
        } catch {
            print("Decryption error: \(error)")
            print("Encrypted text length: \(encryptedText.count)")
            print("Key loaded: \(key != nil)")
            
            // Authentication failure hatası alırsak, key yanlış olabilir
            // GitHub'dan key'i yeniden yüklemeyi dene
            if error.localizedDescription.contains("authenticationFailure") || 
               error.localizedDescription.contains("authentication") ||
               String(describing: error).contains("authentication") {
                print("Authentication failure detected, reloading key from GitHub...")
                // UserDefaults'taki key'i temizle ve GitHub'dan yeniden yükle
                await loadEncryptionKey(forceReload: true)
                
                // Yeni key ile tekrar dene
                if let newKey = key {
                    do {
                        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
                        let decryptedData = try AES.GCM.open(sealedBox, using: newKey)
                        let decrypted = String(data: decryptedData, encoding: .utf8) ?? ""
                        print("Decryption successful after key reload: \(decrypted.prefix(10))...")
                        return decrypted
                    } catch let retryError {
                        print("Decryption still failed after key reload: \(retryError)")
                        print("Error details: \(String(describing: retryError))")
                    }
                } else {
                    print("Key is still nil after reload")
                }
            }
            
            // Decrypt başarısız oldu, boş string döndür (parola eşleşmesin)
            return ""
        }
    }
}

// MARK: - Encryption Key Data Model

struct EncryptionKeyData: Codable {
    let key: String // Base64 encoded key
}
