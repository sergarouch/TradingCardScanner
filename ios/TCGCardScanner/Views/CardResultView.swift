//
//  CardResultView.swift
//  TCGCardScanner
//

import SwiftUI
import SafariServices

struct CardResultView: View {
    let card: ScannedCard
    @Environment(\.dismiss) private var dismiss
    @State private var showingTCGPlayer = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Card Image
                    cardImageView
                    
                    // Card Info
                    cardInfoSection
                    
                    // Pricing Section
                    pricingSection
                    
                    // Actions
                    actionsSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "0f0c29"),
                        Color(hex: "302b63"),
                        Color(hex: "24243e")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Card Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "00d4ff"))
                }
            }
            .sheet(isPresented: $showingTCGPlayer) {
                if let urlString = card.tcgplayerURL,
                   let url = URL(string: urlString) {
                    SafariView(url: url)
                }
            }
        }
    }
    
    // MARK: - Card Image
    
    private var cardImageView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
            
            if let imageData = card.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "00d4ff").opacity(0.5))
                    
                    Text("No Preview")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .frame(height: 300)
        .shadow(color: Color(hex: "00d4ff").opacity(0.2), radius: 20)
    }
    
    // MARK: - Card Info
    
    private var cardInfoSection: some View {
        VStack(spacing: 16) {
            // Card name
            Text(card.name)
                .font(.title2.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            // Set and category
            HStack(spacing: 12) {
                CategoryBadge(text: card.setName, color: Color(hex: "9d4edd"))
                CategoryBadge(text: card.category.capitalized, color: Color(hex: "00d4ff"))
            }
            
            // Confidence
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(confidenceColor)
                
                Text("Match Confidence: \(Int(card.confidence * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // Detected text (if available)
            if let detectedText = card.detectedText {
                HStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .foregroundColor(Color(hex: "00d4ff"))
                    
                    Text("Detected: \(detectedText)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
    
    private var confidenceColor: Color {
        switch card.confidence {
        case 0.8...: return .green
        case 0.6..<0.8: return .yellow
        default: return .orange
        }
    }
    
    // MARK: - Pricing
    
    private var pricingSection: some View {
        VStack(spacing: 16) {
            Text("Pricing")
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if let marketPrice = card.marketPrice {
                // Main price card
                VStack(spacing: 8) {
                    Text("Market Price")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(formatPrice(marketPrice))
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "00d4ff"), Color(hex: "00ff88")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "00ff88").opacity(0.3), lineWidth: 1)
                        )
                )
                
                // Price range
                HStack(spacing: 12) {
                    PriceBox(
                        title: "Low",
                        price: card.lowPrice,
                        color: Color(hex: "ff006e")
                    )
                    
                    PriceBox(
                        title: "Mid",
                        price: card.midPrice,
                        color: Color(hex: "ffd700")
                    )
                    
                    PriceBox(
                        title: "High",
                        price: card.highPrice,
                        color: Color(hex: "00ff88")
                    )
                }
            } else {
                // No pricing available
                VStack(spacing: 12) {
                    Image(systemName: "dollarsign.circle")
                        .font(.system(size: 36))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("Pricing not available")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Try searching on TCGPlayer")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.vertical, 30)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
    
    // MARK: - Actions
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if card.tcgplayerURL != nil {
                Button(action: { showingTCGPlayer = true }) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("View on TCGPlayer")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
            }
            
            Button(action: shareCard) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.headline)
                .foregroundColor(Color(hex: "00d4ff"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(hex: "00d4ff"), lineWidth: 2)
                )
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatPrice(_ price: Double) -> String {
        return String(format: "$%.2f", price)
    }
    
    private func shareCard() {
        var shareText = "Check out this card: \(card.name)"
        
        if let price = card.marketPrice {
            shareText += "\nMarket Price: \(formatPrice(price))"
        }
        
        if let url = card.tcgplayerURL {
            shareText += "\n\(url)"
        }
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct PriceBox: View {
    let title: String
    let price: Double?
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            
            if let price = price {
                Text(String(format: "$%.2f", price))
                    .font(.headline.bold())
                    .foregroundColor(color)
            } else {
                Text("N/A")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
    }
}


#Preview {
    CardResultView(card: ScannedCard(
        name: "Charizard VMAX",
        setName: "Champion's Path",
        category: "pokemon",
        marketPrice: 245.99,
        lowPrice: 199.99,
        midPrice: 239.99,
        highPrice: 299.99,
        tcgplayerURL: "https://www.tcgplayer.com/product/123456",
        confidence: 0.92
    ))
}

