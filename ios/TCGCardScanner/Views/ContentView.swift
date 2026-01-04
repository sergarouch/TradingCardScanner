//
//  ContentView.swift
//  TCGCardScanner
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Tab = .scan
    
    enum Tab {
        case scan, history, search, settings
    }
    
    var body: some View {
        ZStack {
            // Gradient background
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
            
            TabView(selection: $selectedTab) {
                ScannerView()
                    .tabItem {
                        Label("Scan", systemImage: "camera.viewfinder")
                    }
                    .tag(Tab.scan)
                
                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(Tab.history)
                
                SearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(Tab.search)
                
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .tag(Tab.settings)
            }
            .tint(Color(hex: "00d4ff"))
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}

