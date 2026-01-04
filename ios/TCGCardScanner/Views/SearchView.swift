//
//  SearchView.swift
//  TCGCardScanner
//

import SwiftUI

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var selectedCategory: String?
    @State private var searchResults: [SearchResult] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    
    let categories = [
        ("All", nil as String?),
        ("Pokémon", "pokemon"),
        ("MTG", "magic_the_gathering"),
        ("Yu-Gi-Oh!", "yugioh"),
        ("Sports", "sports"),
        ("One Piece", "one_piece"),
        ("Lorcana", "disney_lorcana")
    ]
    
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
                
                VStack(spacing: 0) {
                    // Search bar
                    searchBarView
                    
                    // Category filter
                    categoryFilterView
                    
                    // Results
                    if isSearching {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(message: error)
                    } else if searchResults.isEmpty && hasSearched {
                        emptyResultsView
                    } else if searchResults.isEmpty {
                        searchPromptView
                    } else {
                        resultsListView
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBarView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                
                TextField("Search cards...", text: $searchText)
                    .foregroundColor(.white)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .onSubmit {
                        performSearch()
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
            
            Button(action: performSearch) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .disabled(searchText.isEmpty || isSearching)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
    
    // MARK: - Category Filter
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.0) { name, value in
                    Button(action: {
                        selectedCategory = value
                        if hasSearched {
                            performSearch()
                        }
                    }) {
                        Text(name)
                            .font(.subheadline.bold())
                            .foregroundColor(selectedCategory == value ? .white : .white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedCategory == value ? Color(hex: "00d4ff").opacity(0.3) : Color.white.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(
                                                selectedCategory == value ? Color(hex: "00d4ff") : Color.clear,
                                                lineWidth: 1
                                            )
                                    )
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
    }
    
    // MARK: - Results List
    
    private var resultsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(searchResults) { result in
                    SearchResultRow(result: result)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00d4ff")))
                .scaleEffect(1.5)
            
            Text("Searching TCGPlayer...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
        }
    }
    
    // MARK: - Empty Results
    
    private var emptyResultsView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Try a different search term or category")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Search Prompt
    
    private var searchPromptView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(hex: "00d4ff").opacity(0.1))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "sparkle.magnifyingglass")
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
                Text("Search TCGPlayer")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text("Find any trading card and check its value")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            // Quick search suggestions
            VStack(spacing: 8) {
                Text("Popular Searches")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.4))
                
                HStack(spacing: 10) {
                    QuickSearchChip(text: "Charizard") {
                        searchText = "Charizard"
                        selectedCategory = "pokemon"
                        performSearch()
                    }
                    
                    QuickSearchChip(text: "Black Lotus") {
                        searchText = "Black Lotus"
                        selectedCategory = "magic_the_gathering"
                        performSearch()
                    }
                    
                    QuickSearchChip(text: "Blue-Eyes") {
                        searchText = "Blue-Eyes White Dragon"
                        selectedCategory = "yugioh"
                        performSearch()
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "ff006e"))
            
            VStack(spacing: 8) {
                Text("Search Error")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: performSearch) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "00d4ff"))
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Search Action
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        errorMessage = nil
        hasSearched = true
        
        Task {
            do {
                let results = try await APIService.shared.searchCards(
                    query: searchText,
                    category: selectedCategory,
                    serverURL: appState.serverURL
                )
                
                await MainActor.run {
                    searchResults = results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSearching = false
                }
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: SearchResult
    @State private var showingDetail = false
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            HStack(spacing: 16) {
                // Card image
                AsyncImage(url: URL(string: result.imageUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .foregroundColor(.white.opacity(0.3))
                    case .empty:
                        ProgressView()
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 60, height: 84)
                .background(Color.white.opacity(0.05))
                .cornerRadius(8)
                
                // Card info
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.name)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    Text(result.setName)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                    
                    CategoryBadge(
                        text: result.category.capitalized,
                        color: Color(hex: "00d4ff")
                    )
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 4) {
                    if let price = result.marketPrice {
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
        .sheet(isPresented: $showingDetail) {
            if let url = URL(string: result.tcgplayerUrl) {
                SafariView(url: url)
            }
        }
    }
}

// MARK: - Quick Search Chip

struct QuickSearchChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption.bold())
                .foregroundColor(Color(hex: "00d4ff"))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(hex: "00d4ff").opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color(hex: "00d4ff").opacity(0.3), lineWidth: 1)
                        )
                )
        }
    }
}

#Preview {
    SearchView()
        .environmentObject(AppState())
}

