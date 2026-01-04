//
//  HistoryView.swift
//  TCGCardScanner
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedCard: ScannedCard?
    @State private var showingDeleteAlert = false
    
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
                    cardListView
                }
            }
            .navigationTitle("Scan History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !appState.scannedCards.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showingDeleteAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(Color(hex: "ff006e"))
                        }
                    }
                }
            }
            .alert("Clear History", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    withAnimation {
                        appState.clearHistory()
                    }
                }
            } message: {
                Text("Are you sure you want to delete all scanned cards?")
            }
            .sheet(item: $selectedCard) { card in
                CardResultView(card: card)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(hex: "00d4ff").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "clock.arrow.circlepath")
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
                Text("No Scans Yet")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Cards you scan will appear here")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
    
    // MARK: - Card List
    
    private var cardListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Summary header
                summaryHeader
                
                ForEach(appState.scannedCards) { card in
                    HistoryCardRow(card: card)
                        .onTapGesture {
                            selectedCard = card
                        }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        HStack(spacing: 16) {
            SummaryCard(
                icon: "camera.viewfinder",
                title: "Total Scans",
                value: "\(appState.scannedCards.count)",
                color: Color(hex: "00d4ff")
            )
            
            SummaryCard(
                icon: "dollarsign.circle",
                title: "Total Value",
                value: totalValue,
                color: Color(hex: "00ff88")
            )
        }
    }
    
    private var totalValue: String {
        let total = appState.scannedCards.compactMap { $0.marketPrice }.reduce(0, +)
        return String(format: "$%.2f", total)
    }
}

// MARK: - History Card Row

struct HistoryCardRow: View {
    let card: ScannedCard
    
    var body: some View {
        HStack(spacing: 16) {
            // Card thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
                
                if let imageData = card.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 84)
                        .cornerRadius(8)
                } else {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.3))
                }
            }
            .frame(width: 60, height: 84)
            
            // Card info
            VStack(alignment: .leading, spacing: 6) {
                Text(card.name)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(card.setName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    CategoryBadge(
                        text: card.category.capitalized,
                        color: categoryColor(for: card.category)
                    )
                    
                    Spacer()
                    
                    Text(formatDate(card.scannedAt))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            
            Spacer()
            
            // Price
            VStack(alignment: .trailing, spacing: 4) {
                if let price = card.marketPrice {
                    Text(String(format: "$%.2f", price))
                        .font(.headline.bold())
                        .foregroundColor(Color(hex: "00ff88"))
                } else {
                    Text("N/A")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.3))
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func categoryColor(for category: String) -> Color {
        switch category.lowercased() {
        case "pokemon": return Color(hex: "ffd700")
        case "magic_the_gathering": return Color(hex: "9d4edd")
        case "yugioh": return Color(hex: "ff006e")
        case "sports": return Color(hex: "00ff88")
        default: return Color(hex: "00d4ff")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Summary Card

struct SummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

#Preview {
    HistoryView()
        .environmentObject({
            let state = AppState()
            state.scannedCards = [
                ScannedCard(
                    name: "Charizard VMAX",
                    setName: "Champion's Path",
                    category: "pokemon",
                    marketPrice: 245.99,
                    confidence: 0.92
                ),
                ScannedCard(
                    name: "Black Lotus",
                    setName: "Alpha",
                    category: "magic_the_gathering",
                    marketPrice: 25000,
                    confidence: 0.85
                )
            ]
            return state
        }())
}

