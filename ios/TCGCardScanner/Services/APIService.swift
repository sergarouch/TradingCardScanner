//
//  APIService.swift
//  TCGCardScanner
//

import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case serverError(String)
    case encodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return "Server error: \(message)"
        case .encodingError:
            return "Failed to encode image"
        }
    }
}

class APIService {
    static let shared = APIService()
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        session = URLSession(configuration: config)
    }
    
    // MARK: - Image to Base64
    
    private func imageToBase64(_ image: UIImage, quality: CGFloat = 0.8) -> String? {
        // Resize image for faster upload
        let maxDimension: CGFloat = 1024
        let resizedImage = resizeImage(image, maxDimension: maxDimension)
        
        guard let imageData = resizedImage.jpegData(compressionQuality: quality) else {
            return nil
        }
        
        return imageData.base64EncodedString()
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        guard max(size.width, size.height) > maxDimension else {
            return image
        }
        
        let ratio = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
    
    // MARK: - API Calls
    
    /// Identify a card and get pricing information
    func identifyCard(image: UIImage, serverURL: String, cardNameHint: String? = nil) async throws -> ScannedCard? {
        guard let url = URL(string: "\(serverURL)/api/identify") else {
            throw APIError.invalidURL
        }
        
        guard let base64Image = imageToBase64(image) else {
            throw APIError.encodingError
        }
        
        var requestBody: [String: Any] = [
            "image": "data:image/jpeg;base64,\(base64Image)"
        ]
        
        if let hint = cardNameHint {
            requestBody["card_name_hint"] = hint
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let result = try decoder.decode(IdentifyResponse.self, from: data)
            
            if !result.success {
                throw APIError.serverError(result.error ?? "Unknown error")
            }
            
            // Convert to ScannedCard
            let imageData = image.jpegData(compressionQuality: 0.5)
            
            return ScannedCard(
                name: result.cardInfo?.name ?? "Unknown Card",
                setName: result.cardInfo?.setName ?? "Unknown Set",
                category: result.classification?.category ?? "Unknown",
                marketPrice: result.pricing?.marketPrice,
                lowPrice: result.pricing?.lowPrice,
                midPrice: result.pricing?.midPrice,
                highPrice: result.pricing?.highPrice,
                tcgplayerURL: result.pricing?.tcgplayerUrl,
                imageData: imageData,
                confidence: result.cardInfo?.matchConfidence ?? result.classification?.confidence ?? 0.0
            )
            
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    /// Recognize a card (classification only, no pricing)
    func recognizeCard(image: UIImage, serverURL: String) async throws -> RecognizeResponse {
        guard let url = URL(string: "\(serverURL)/api/recognize") else {
            throw APIError.invalidURL
        }
        
        guard let base64Image = imageToBase64(image) else {
            throw APIError.encodingError
        }
        
        let requestBody: [String: Any] = [
            "image": "data:image/jpeg;base64,\(base64Image)"
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        return try JSONDecoder().decode(RecognizeResponse.self, from: data)
    }
    
    /// Search for cards by name
    func searchCards(query: String, category: String? = nil, serverURL: String) async throws -> [SearchResult] {
        var urlComponents = URLComponents(string: "\(serverURL)/api/search")
        urlComponents?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        
        if let category = category {
            urlComponents?.queryItems?.append(URLQueryItem(name: "category", value: category))
        }
        
        guard let url = urlComponents?.url else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        let result = try JSONDecoder().decode(SearchResponse.self, from: data)
        
        if !result.success {
            throw APIError.serverError(result.error ?? "Search failed")
        }
        
        return result.results ?? []
    }
    
    /// Get detailed price for a specific product
    func getCardPrice(productId: String, serverURL: String) async throws -> Pricing? {
        guard let url = URL(string: "\(serverURL)/api/price/\(productId)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw APIError.invalidResponse
        }
        
        struct PriceResponse: Codable {
            let success: Bool
            let pricing: Pricing?
        }
        
        let result = try JSONDecoder().decode(PriceResponse.self, from: data)
        return result.pricing
    }
    
    /// Check server health
    func checkHealth(serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/health") else {
            return false
        }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

