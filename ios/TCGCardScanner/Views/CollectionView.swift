//
//  CollectionView.swift
//  TCGCardScanner
//
//  Collection view grouped by card category
//

import SwiftUI

struct CollectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCategory: String? = nil
    @State private var expandedCategories: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
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
                
                if appState.scannedCards.isEmpty {
                    emptyStateView
                } else {
                    collectionListView
                }
            }
            .navigationTitle("My Collection")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "00d4ff").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: 8) {
                Text("No Cards in Collection")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Scan cards to build your collection")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Collection List
    
    private var collectionListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Collection stats
                collectionStatsView
                
                // Category sections
                ForEach(categories, id: \.self) { category in
                    if let categoryCards = cardsByCategory[category], !categoryCards.isEmpty {
                        CategorySection(
                            category: category,
                            cards: categoryCards,
                            isExpanded: expandedCategories.contains(category),
                            onToggle: {
                                if expandedCategories.contains(category) {
                                    expandedCategories.remove(category)
                                } else {
                                    expandedCategories.insert(category)
                                }
                            },
                            onCardTap: { card in
                                // Card tap handled by CategorySection
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Collection Stats
    
    private var collectionStatsView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                StatBox(
                    icon: "square.grid.2x2",
                    title: "Total Cards",
                    value: "\(appState.scannedCards.count)",
                    color: Color(hex: "00d4ff")
                )
                
                StatBox(
                    icon: "dollarsign.circle",
                    title: "Collection Value",
                    value: totalValue,
                    color: Color(hex: "00ff88")
                )
            }
            
            HStack(spacing: 16) {
                StatBox(
                    icon: "folder.fill",
                    title: "Categories",
                    value: "\(categories.count)",
                    color: Color(hex: "9d4edd")
                )
                
                StatBox(
                    icon: "star.fill",
                    title: "Most Valuable",
                    value: mostValuableCard,
                    color: Color(hex: "ffd700")
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var categories: [String] {
        let uniqueCategories = Set(appState.scannedCards.map { $0.category })
        return Array(uniqueCategories).sorted()
    }
    
    private var cardsByCategory: [String: [ScannedCard]] {
        Dictionary(grouping: appState.scannedCards) { $0.category }
    }
    
    private var totalValue: String {
        let total = appState.scannedCards.compactMap { $0.marketPrice }.reduce(0, +)
        if total >= 1000 {
            return String(format: "$%.1fK", total / 1000)
        }
        return String(format: "$%.2f", total)
    }
    
    private var mostValuableCard: String {
        if let mostExpensive = appState.scannedCards
            .compactMap({ card -> (name: String, price: Double)? in
                guard let price = card.marketPrice else { return nil }
                return (card.name, price)
            })
            .max(by: { $0.price < $1.price }) {
            return mostExpensive.name.components(separatedBy: " ").first ?? "N/A"
        }
        return "N/A"
    }
}

// MARK: - Category Section

struct CategorySection: View {
    let category: String
    let cards: [ScannedCard]
    let isExpanded: Bool
    let onToggle: () -> Void
    let onCardTap: (ScannedCard) -> Void
    
    @State private var selectedCard: ScannedCard? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            Button(action: onToggle) {
                HStack {
                    categoryIcon(for: category)
                        .font(.title2)
                        .foregroundColor(categoryColor(for: category))
                    
                    Text(categoryName(for: category))
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(cards.count) cards")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.6))
                        .animation(.easeInOut, value: isExpanded)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(categoryColor(for: category).opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Cards grid (if expanded)
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(cards) { card in
                        CollectionCardTile(card: card)
                            .onTapGesture {
                                selectedCard = card
                            }
                    }
                }
            }
        }
        .sheet(item: $selectedCard) { card in
            CardResultView(card: card)
        }
    }
    
    private func categoryIcon(for category: String) -> Image {
        switch category.lowercased() {
        case "pokemon": return Image(systemName: "flame.fill")
        case "magic: the gathering", "magic": return Image(systemName: "sparkles")
        case "yu-gi-oh!", "yugioh": return Image(systemName: "star.fill")
        case "sports": return Image(systemName: "sportscourt.fill")
        case "one piece": return Image(systemName: "sailboat.fill")
        case "disney lorcana", "lorcana": return Image(systemName: "wand.and.stars")
        default: return Image(systemName: "rectangle.fill")
        }
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "pokemon": return Color(hex: "ffd700")
        case "magic: the gathering", "magic": return Color(hex: "9d4edd")
        case "yu-gi-oh!", "yugioh": return Color(hex: "ff006e")
        case "sports": return Color(hex: "00ff88")
        case "one piece": return Color(hex: "ff6600")
        case "disney lorcana", "lorcana": return Color(hex: "00bfff")
        default: return Color(hex: "00d4ff")
        }
    }
    
    private func categoryName(for category: String) -> String {
        switch category.lowercased() {
        case "pokemon": return "Pokémon"
        case "magic: the gathering", "magic": return "Magic: The Gathering"
        case "yu-gi-oh!", "yugioh": return "Yu-Gi-Oh!"
        case "sports": return "Sports Cards"
        case "one piece": return "One Piece"
        case "disney lorcana", "lorcana": return "Disney Lorcana"
        default: return category.capitalized
        }
    }
}

// MARK: - Collection Card Tile

struct CollectionCardTile: View {
    let card: ScannedCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card image
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 140)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(.white.opacity(0.3))
                        .frame(height: 140)
                }
            }
            
            // Card info
            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                Text(card.setName)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                if let price = card.marketPrice {
                    Text(String(format: "$%.2f", price))
                        .font(.caption.bold())
                        .foregroundColor(Color(hex: "00ff88"))
                } else {
                    Text("N/A")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    CollectionView()
        .environmentObject({
            let state = AppState()
            state.scannedCards = [
                ScannedCard(
                    name: "Charizard VMAX",
                    setName: "Champion's Path",
                    category: "Pokemon",
                    marketPrice: 245.99,
                    confidence: 0.92
                ),
                ScannedCard(
                    name: "Black Lotus",
                    setName: "Alpha",
                    category: "Magic: The Gathering",
                    marketPrice: 25000,
                    confidence: 0.85
                ),
                ScannedCard(
                    name: "Blue-Eyes White Dragon",
                    setName: "LDB-001",
                    category: "Yu-Gi-Oh!",
                    marketPrice: 12.99,
                    confidence: 0.78
                )
            ]
            return state
        }())
}

