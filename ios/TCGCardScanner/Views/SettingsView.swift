//
//  SettingsView.swift
//  TCGCardScanner
//
//  App settings - fully on-device, no server config needed!
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingClearAlert = false
    
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
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Status banner
                        statusBanner
                        
                        // App info
                        appInfoSection
                        
                        // Data management
                        dataSection
                        
                        // About
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Clear History", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    appState.clearHistory()
                }
            } message: {
                Text("Are you sure you want to delete all scanned cards? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Status Banner
    
    private var statusBanner: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: "00ff88").opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "checkmark.icloud.fill")
                    .font(.title2)
                    .foregroundColor(Color(hex: "00ff88"))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("100% On-Device")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("No server required • Works offline for scanning")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "00ff88").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "00ff88").opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - App Info Section
    
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Statistics", icon: "chart.bar")
            
            HStack(spacing: 16) {
                StatCard(
                    title: "Total Scans",
                    value: "\(appState.scannedCards.count)",
                    icon: "camera.viewfinder",
                    color: Color(hex: "00d4ff")
                )
                
                StatCard(
                    title: "Collection Value",
                    value: totalCollectionValue,
                    icon: "dollarsign.circle",
                    color: Color(hex: "00ff88")
                )
            }
        }
    }
    
    private var totalCollectionValue: String {
        let total = appState.scannedCards.compactMap { $0.marketPrice }.reduce(0, +)
        if total >= 1000 {
            return String(format: "$%.1fK", total / 1000)
        }
        return String(format: "$%.2f", total)
    }
    
    // MARK: - Data Section
    
    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Data", icon: "externaldrive")
            
            VStack(spacing: 12) {
                Button(action: { TCGPlayerService.shared.clearCache() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(Color(hex: "00d4ff"))
                        
                        Text("Clear Search Cache")
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                Button(action: { showingClearAlert = true }) {
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(Color(hex: "ff006e"))
                        
                        Text("Clear Scan History")
                            .foregroundColor(Color(hex: "ff006e"))
                        
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "About", icon: "info.circle")
            
            VStack(spacing: 12) {
                AboutRow(title: "Version", value: "2.0.0")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                AboutRow(title: "Build", value: "On-Device Edition")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                Link(destination: URL(string: "https://www.tcgplayer.com")!) {
                    HStack {
                        Text("Prices from TCGPlayer")
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(Color(hex: "00d4ff"))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
            )
            
            // Tech stack info
            VStack(alignment: .leading, spacing: 12) {
                Text("Powered by")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                HStack(spacing: 12) {
                    TechBadge(text: "Vision OCR", color: Color(hex: "00d4ff"))
                    TechBadge(text: "SwiftUI", color: Color(hex: "9d4edd"))
                    TechBadge(text: "On-Device", color: Color(hex: "00ff88"))
                }
            }
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                Text("Features")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 8)
                
                FeatureRow(icon: "camera.viewfinder", text: "Scan cards with your camera")
                FeatureRow(icon: "text.viewfinder", text: "Automatic card name detection")
                FeatureRow(icon: "dollarsign.circle", text: "Real-time prices from TCGPlayer")
                FeatureRow(icon: "iphone", text: "100% on-device processing")
                FeatureRow(icon: "wifi.slash", text: "Works offline for scanning")
            }
        }
    }
}

// MARK: - Supporting Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color(hex: "00d4ff"))
            
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text(value)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
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

struct AboutRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
        }
    }
}

struct TechBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption.bold())
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(color.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(Color(hex: "00d4ff"))
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}
