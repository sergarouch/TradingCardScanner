//
//  TCGPlayerService.swift
//  TCGCardScanner
//
//  Direct TCGPlayer integration - no backend server needed
//

import Foundation
import SwiftUI

// MARK: - Models

struct TCGCard: Identifiable, Codable {
    let id: String
    let name: String
    let setName: String
    let category: String
    let imageURL: String?
    let productURL: String
    let marketPrice: Double?
    let lowPrice: Double?
    let midPrice: Double?
    let highPrice: Double?
    
    init(id: String = UUID().uuidString,
         name: String,
         setName: String,
         category: String,
         imageURL: String? = nil,
         productURL: String,
         marketPrice: Double? = nil,
         lowPrice: Double? = nil,
         midPrice: Double? = nil,
         highPrice: Double? = nil) {
        self.id = id
        self.name = name
        self.setName = setName
        self.category = category
        self.imageURL = imageURL
        self.productURL = productURL
        self.marketPrice = marketPrice
        self.lowPrice = lowPrice
        self.midPrice = midPrice
        self.highPrice = highPrice
    }
}

// MARK: - TCGPlayer Service

class TCGPlayerService {
    static let shared = TCGPlayerService()
    
    private let session: URLSession
    private let baseURL = "https://www.tcgplayer.com"
    private let searchURL = "https://www.tcgplayer.com/search/product/all"
    
    // Cache for recent searches
    private var cache: [String: (results: [TCGCard], timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9"
        ]
        session = URLSession(configuration: config)
    }
    
    // MARK: - Search Cards
    
    func searchCards(query: String, category: String? = nil) async throws -> [TCGCard] {
        let cacheKey = "\(query)-\(category ?? "all")"
        
        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            return cached.results
        }
        
        // Build search URL
        var urlComponents = URLComponents(string: searchURL)!
        var queryItems = [URLQueryItem(name: "q", value: query)]
        
        if let category = category {
            let categoryId = getCategoryId(for: category)
            if let id = categoryId {
                queryItems.append(URLQueryItem(name: "productLineName", value: category))
            }
        }
        
        urlComponents.queryItems = queryItems
        
        guard let url = urlComponents.url else {
            throw TCGError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw TCGError.networkError
        }
        
        let html = String(data: data, encoding: .utf8) ?? ""
        let results = parseSearchResults(html: html)
        
        // Cache results
        cache[cacheKey] = (results, Date())
        
        return results
    }
    
    // MARK: - Parse HTML Results
    
    private func parseSearchResults(html: String) -> [TCGCard] {
        var cards: [TCGCard] = []
        
        // Try simple approach first
        cards = parseWithSimpleApproach(html: html)
        
        // If that didn't work, try regex parsing
        if cards.isEmpty {
            cards = parseWithRegex(html: html)
        }
        
        return cards
    }
    
    private func parseWithRegex(html: String) -> [TCGCard] {
        var cards: [TCGCard] = []
        let pricePattern = #"\$(\d+(?:,\d{3})*(?:\.\d{2})?)"#
        
        // Split HTML into product sections
        let sections = html.components(separatedBy: "search-result__product")
        
        for section in sections.dropFirst() {
            // Extract product URL
            if let urlMatch = section.range(of: #"href="(/product/\d+/[^"]+)""#, options: .regularExpression) {
                let urlPath = String(section[urlMatch])
                    .replacingOccurrences(of: "href=\"", with: "")
                    .replacingOccurrences(of: "\"", with: "")
                
                let productURL = baseURL + urlPath
                
                // Extract product ID
                let productId = urlPath.components(separatedBy: "/").dropFirst(2).first ?? UUID().uuidString
                
                // Extract product name - look for title or product name
                var name = "Unknown Card"
                if let nameMatch = section.range(of: #"title="([^"]+)""#, options: .regularExpression) {
                    name = String(section[nameMatch])
                        .replacingOccurrences(of: "title=\"", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                } else if let altMatch = section.range(of: #"alt="([^"]+)""#, options: .regularExpression) {
                    name = String(section[altMatch])
                        .replacingOccurrences(of: "alt=\"", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Extract price
                var price: Double? = nil
                if let priceMatch = section.range(of: pricePattern, options: .regularExpression) {
                    let priceStr = String(section[priceMatch])
                        .replacingOccurrences(of: "$", with: "")
                        .replacingOccurrences(of: ",", with: "")
                    price = Double(priceStr)
                }
                
                // Extract image URL
                var imageURL: String? = nil
                if let imgMatch = section.range(of: #"src="(https://[^"]+(?:\.jpg|\.png|\.webp)[^"]*)""#, options: .regularExpression) {
                    imageURL = String(section[imgMatch])
                        .replacingOccurrences(of: "src=\"", with: "")
                        .replacingOccurrences(of: "\"", with: "")
                }
                
                // Extract set name
                var setName = "Unknown Set"
                if let setMatch = section.range(of: #"subtitle[^>]*>([^<]+)<"#, options: .regularExpression) {
                    setName = String(section[setMatch])
                        .replacingOccurrences(of: #"subtitle[^>]*>"#, with: "", options: .regularExpression)
                        .replacingOccurrences(of: "<", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                // Determine category from URL
                let category = detectCategory(from: productURL)
                
                let card = TCGCard(
                    id: productId,
                    name: name,
                    setName: setName,
                    category: category,
                    imageURL: imageURL,
                    productURL: productURL,
                    marketPrice: price
                )
                
                cards.append(card)
            }
        }
        
        return cards
    }
    
    private func parseWithSimpleApproach(html: String) -> [TCGCard] {
        var cards: [TCGCard] = []
        
        // Look for JSON data that TCGPlayer embeds in the page
        if let jsonStart = html.range(of: "\"products\":"),
           let jsonDataStart = html.range(of: "[", range: jsonStart.upperBound..<html.endIndex) {
            
            var bracketCount = 0
            var jsonEndIndex = jsonDataStart.lowerBound
            
            for i in html.index(jsonDataStart.lowerBound, offsetBy: 0)..<html.endIndex {
                let char = html[i]
                if char == "[" { bracketCount += 1 }
                if char == "]" { bracketCount -= 1 }
                if bracketCount == 0 {
                    jsonEndIndex = html.index(after: i)
                    break
                }
            }
            
            let jsonStr = String(html[jsonDataStart.lowerBound..<jsonEndIndex])
            
            if let jsonData = jsonStr.data(using: .utf8) {
                do {
                    if let products = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] {
                        for product in products.prefix(20) {
                            let name = product["productName"] as? String ?? "Unknown"
                            let setName = product["setName"] as? String ?? "Unknown Set"
                            let productId = product["productId"] as? Int ?? 0
                            let price = product["marketPrice"] as? Double
                            let imageURL = product["imageUrl"] as? String
                            
                            let card = TCGCard(
                                id: String(productId),
                                name: name,
                                setName: setName,
                                category: "Unknown",
                                imageURL: imageURL,
                                productURL: "\(baseURL)/product/\(productId)",
                                marketPrice: price
                            )
                            cards.append(card)
                        }
                    }
                } catch {
                    print("JSON parsing error: \(error)")
                }
            }
        }
        
        return cards
    }
    
    // MARK: - Helpers
    
    private func getCategoryId(for category: String) -> Int? {
        let categories: [String: Int] = [
            "pokemon": 3,
            "magic": 1,
            "magic the gathering": 1,
            "mtg": 1,
            "yugioh": 2,
            "yu-gi-oh": 2,
            "sports": 72,
            "one piece": 84,
            "lorcana": 87,
            "disney lorcana": 87
        ]
        return categories[category.lowercased()]
    }
    
    private func detectCategory(from url: String) -> String {
        let lowercased = url.lowercased()
        if lowercased.contains("pokemon") { return "Pokemon" }
        if lowercased.contains("magic") { return "Magic: The Gathering" }
        if lowercased.contains("yugioh") { return "Yu-Gi-Oh!" }
        if lowercased.contains("one-piece") { return "One Piece" }
        if lowercased.contains("lorcana") { return "Disney Lorcana" }
        if lowercased.contains("sports") || lowercased.contains("baseball") ||
           lowercased.contains("basketball") || lowercased.contains("football") {
            return "Sports"
        }
        return "Trading Card"
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        cache.removeAll()
    }
}

// MARK: - Errors

enum TCGError: LocalizedError {
    case invalidURL
    case networkError
    case parsingError
    case noResults
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid search URL"
        case .networkError: return "Network connection failed"
        case .parsingError: return "Failed to parse results"
        case .noResults: return "No cards found"
        }
    }
}

