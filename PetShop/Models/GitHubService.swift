//
//  GitHubService.swift
//  PetShop
//
//  GitHub API service for data storage
//

import Foundation

class GitHubService {
    static let shared = GitHubService()
    
    // GitHub repository bilgileri
    private let owner = "umutcrkn"
    private let repo = "PetShop-Barkod"
    private let baseURL = "https://api.github.com"
    
    // Token UserDefaults'tan alınacak (güvenlik için)
    private var token: String? {
        get {
            return UserDefaults.standard.string(forKey: "GitHubToken")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "GitHubToken")
        }
    }
    
    private init() {}
    
    // MARK: - Token Management
    func setToken(_ token: String) {
        self.token = token
    }
    
    func hasToken() -> Bool {
        return token != nil && !token!.isEmpty
    }
    
    // MARK: - File Operations
    
    /// GitHub'dan dosya içeriğini okur
    func getFileContent(path: String) async throws -> Data {
        guard let token = token else {
            throw GitHubError.noToken
        }
        
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 404 {
                // Dosya yoksa boş data döndür
                return Data()
            }
            throw GitHubError.httpError(httpResponse.statusCode)
        }
        
        // GitHub API base64 encoded content döndürür
        let json = try JSONDecoder().decode(GitHubFileResponse.self, from: data)
        
        guard let contentData = Data(base64Encoded: json.content.replacingOccurrences(of: "\n", with: "")) else {
            throw GitHubError.decodingError
        }
        
        return contentData
    }
    
    /// GitHub'a dosya yazar veya günceller
    func putFileContent(path: String, content: Data, message: String) async throws {
        guard let token = token else {
            throw GitHubError.noToken
        }
        
        // Önce mevcut dosyayı kontrol et (sha için)
        var sha: String? = nil
        do {
            let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"
            guard let url = URL(string: urlString) else {
                throw GitHubError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let json = try JSONDecoder().decode(GitHubFileResponse.self, from: data)
                sha = json.sha
            }
        } catch {
            // Dosya yoksa sha nil kalır (yeni dosya oluşturulacak)
        }
        
        // Dosyayı yaz/güncelle
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"
        guard let url = URL(string: urlString) else {
            throw GitHubError.invalidURL
        }
        
        let base64Content = content.base64EncodedString()
        
        var body: [String: Any] = [
            "message": message,
            "content": base64Content
        ]
        
        if let sha = sha {
            body["sha"] = sha
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw GitHubError.httpError(httpResponse.statusCode)
        }
    }
    
    // MARK: - Convenience Methods
    
    /// Products dosyasını okur
    func getProducts() async throws -> [Product] {
        let data = try await getFileContent(path: "data/products.json")
        
        if data.isEmpty {
            return []
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([Product].self, from: data)
    }
    
    /// Products dosyasını yazar
    func saveProducts(_ products: [Product]) async throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(products)
        try await putFileContent(path: "data/products.json", content: data, message: "Update products")
    }
    
    /// Sales dosyasını okur
    func getSales() async throws -> [Sale] {
        let data = try await getFileContent(path: "data/sales.json")
        
        if data.isEmpty {
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Sale].self, from: data)
    }
    
    /// Sales dosyasını yazar
    func saveSales(_ sales: [Sale]) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(sales)
        try await putFileContent(path: "data/sales.json", content: data, message: "Update sales")
    }
}

// MARK: - GitHub API Response Models

struct GitHubFileResponse: Codable {
    let sha: String
    let content: String
    let encoding: String
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case noToken
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .noToken:
            return "GitHub token bulunamadı. Lütfen ayarlardan token girin."
        case .invalidURL:
            return "Geçersiz URL"
        case .invalidResponse:
            return "Geçersiz yanıt"
        case .httpError(let code):
            return "HTTP hatası: \(code)"
        case .decodingError:
            return "Veri çözümleme hatası"
        case .encodingError:
            return "Veri kodlama hatası"
        }
    }
}

