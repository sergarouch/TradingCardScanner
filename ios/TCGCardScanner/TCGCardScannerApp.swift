//
//  TCGCardScannerApp.swift
//  TCGCardScanner
//
//  Trading Card Scanner App - Scan cards and get prices from TCGPlayer
//

import SwiftUI

@main
struct TCGCardScannerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var scannedCards: [ScannedCard] = []
    @Published var isScanning: Bool = false
    @Published var serverURL: String = "http://localhost:5000"
    
    func addScannedCard(_ card: ScannedCard) {
        scannedCards.insert(card, at: 0)
    }
    
    func clearHistory() {
        scannedCards.removeAll()
    }
}

// MARK: - Data Models

struct ScannedCard: Identifiable, Codable {
    let id: UUID
    let name: String
    let setName: String
    let category: String
    let marketPrice: Double?
    let lowPrice: Double?
    let midPrice: Double?
    let highPrice: Double?
    let tcgplayerURL: String?
    let imageData: Data?
    let confidence: Double
    let scannedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        setName: String,
        category: String,
        marketPrice: Double? = nil,
        lowPrice: Double? = nil,
        midPrice: Double? = nil,
        highPrice: Double? = nil,
        tcgplayerURL: String? = nil,
        imageData: Data? = nil,
        confidence: Double = 0.0,
        scannedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.setName = setName
        self.category = category
        self.marketPrice = marketPrice
        self.lowPrice = lowPrice
        self.midPrice = midPrice
        self.highPrice = highPrice
        self.tcgplayerURL = tcgplayerURL
        self.imageData = imageData
        self.confidence = confidence
        self.scannedAt = scannedAt
    }
}

// MARK: - API Response Models

struct RecognizeResponse: Codable {
    let success: Bool
    let classification: Classification?
    let perceptualHash: String?
    let similarCards: [SimilarCard]?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case classification
        case perceptualHash = "perceptual_hash"
        case similarCards = "similar_cards"
        case error
    }
}

struct Classification: Codable {
    let category: String
    let confidence: Double
    let predictions: [Prediction]?
}

struct Prediction: Codable {
    let category: String
    let confidence: Double
}

struct SimilarCard: Codable {
    let cardId: String
    let name: String
    let setName: String
    let category: String
    let tcgplayerId: String?
    let similarity: Double
    
    enum CodingKeys: String, CodingKey {
        case cardId = "card_id"
        case name
        case setName = "set_name"
        case category
        case tcgplayerId = "tcgplayer_id"
        case similarity
    }
}

struct IdentifyResponse: Codable {
    let success: Bool
    let classification: Classification?
    let cardInfo: CardInfo?
    let pricing: Pricing?
    let error: String?
    
    enum CodingKeys: String, CodingKey {
        case success
        case classification
        case cardInfo = "card_info"
        case pricing
        case error
    }
}

struct CardInfo: Codable {
    let name: String
    let setName: String
    let category: String
    let matchConfidence: Double
    
    enum CodingKeys: String, CodingKey {
        case name
        case setName = "set_name"
        case category
        case matchConfidence = "match_confidence"
    }
}

struct Pricing: Codable {
    let marketPrice: Double?
    let lowPrice: Double?
    let midPrice: Double?
    let highPrice: Double?
    let condition: String?
    let tcgplayerUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case marketPrice = "market_price"
        case lowPrice = "low_price"
        case midPrice = "mid_price"
        case highPrice = "high_price"
        case condition
        case tcgplayerUrl = "tcgplayer_url"
    }
}

struct SearchResponse: Codable {
    let success: Bool
    let query: String?
    let results: [SearchResult]?
    let error: String?
}

struct SearchResult: Codable, Identifiable {
    var id: String { productId }
    let productId: String
    let name: String
    let setName: String
    let category: String
    let imageUrl: String?
    let marketPrice: Double?
    let tcgplayerUrl: String
    
    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case name
        case setName = "set_name"
        case category
        case imageUrl = "image_url"
        case marketPrice = "market_price"
        case tcgplayerUrl = "tcgplayer_url"
    }
}

