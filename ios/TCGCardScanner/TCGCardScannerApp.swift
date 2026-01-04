//
//  TCGCardScannerApp.swift
//  TCGCardScanner
//
//  Trading Card Scanner App - Fully on-device, no server needed!
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
    
    init() {
        loadSavedCards()
    }
    
    func addScannedCard(_ card: ScannedCard) {
        scannedCards.insert(card, at: 0)
        saveCards()
    }
    
    func clearHistory() {
        scannedCards.removeAll()
        saveCards()
    }
    
    // MARK: - Persistence
    
    private func saveCards() {
        if let encoded = try? JSONEncoder().encode(scannedCards) {
            UserDefaults.standard.set(encoded, forKey: "scannedCards")
        }
    }
    
    private func loadSavedCards() {
        if let data = UserDefaults.standard.data(forKey: "scannedCards"),
           let decoded = try? JSONDecoder().decode([ScannedCard].self, from: data) {
            scannedCards = decoded
        }
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
    let detectedText: String?
    
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
        scannedAt: Date = Date(),
        detectedText: String? = nil
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
        self.detectedText = detectedText
    }
    
    // Create from TCGCard
    init(from tcgCard: TCGCard, imageData: Data? = nil, confidence: Double = 0.8, detectedText: String? = nil) {
        self.id = UUID()
        self.name = tcgCard.name
        self.setName = tcgCard.setName
        self.category = tcgCard.category
        self.marketPrice = tcgCard.marketPrice
        self.lowPrice = tcgCard.lowPrice
        self.midPrice = tcgCard.midPrice
        self.highPrice = tcgCard.highPrice
        self.tcgplayerURL = tcgCard.productURL
        self.imageData = imageData
        self.confidence = confidence
        self.scannedAt = Date()
        self.detectedText = detectedText
    }
}
