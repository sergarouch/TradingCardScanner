//
//  SettingsView.swift
//  TCGCardScanner
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var serverURL: String = ""
    @State private var isCheckingServer = false
    @State private var serverStatus: ServerStatus = .unknown
    @State private var showingURLEditor = false
    
    enum ServerStatus {
        case unknown, checking, online, offline
    }
    
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
                        // Server settings
                        serverSection
                        
                        // App info
                        appInfoSection
                        
                        // About
                        aboutSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                serverURL = appState.serverURL
                checkServerStatus()
            }
            .alert("Edit Server URL", isPresented: $showingURLEditor) {
                TextField("Server URL", text: $serverURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                
                Button("Cancel", role: .cancel) {
                    serverURL = appState.serverURL
                }
                
                Button("Save") {
                    appState.serverURL = serverURL
                    checkServerStatus()
                }
            } message: {
                Text("Enter the URL of your TCG Scanner backend server")
            }
        }
    }
    
    // MARK: - Server Section
    
    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Server Connection", icon: "server.rack")
            
            VStack(spacing: 16) {
                // Server URL
                Button(action: { showingURLEditor = true }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Server URL")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text(appState.serverURL)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "pencil")
                            .foregroundColor(Color(hex: "00d4ff"))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                }
                
                // Server status
                HStack {
                    serverStatusIndicator
                    
                    Spacer()
                    
                    Button(action: checkServerStatus) {
                        HStack(spacing: 6) {
                            if isCheckingServer {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "00d4ff")))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                            
                            Text("Check")
                        }
                        .font(.subheadline)
                        .foregroundColor(Color(hex: "00d4ff"))
                    }
                    .disabled(isCheckingServer)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }
    
    private var serverStatusIndicator: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(serverStatusColor)
                .frame(width: 10, height: 10)
            
            Text(serverStatusText)
                .font(.subheadline)
                .foregroundColor(.white)
        }
    }
    
    private var serverStatusColor: Color {
        switch serverStatus {
        case .unknown: return .gray
        case .checking: return .yellow
        case .online: return Color(hex: "00ff88")
        case .offline: return Color(hex: "ff006e")
        }
    }
    
    private var serverStatusText: String {
        switch serverStatus {
        case .unknown: return "Not checked"
        case .checking: return "Checking..."
        case .online: return "Connected"
        case .offline: return "Offline"
        }
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
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "About", icon: "info.circle")
            
            VStack(spacing: 12) {
                AboutRow(title: "Version", value: "1.0.0")
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                AboutRow(title: "Build", value: "2024.1")
                
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
                    TechBadge(text: "PyTorch", color: Color(hex: "ee4c2c"))
                    TechBadge(text: "ResNet50", color: Color(hex: "9d4edd"))
                    TechBadge(text: "SwiftUI", color: Color(hex: "00d4ff"))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func checkServerStatus() {
        isCheckingServer = true
        serverStatus = .checking
        
        Task {
            let isOnline = await APIService.shared.checkHealth(serverURL: appState.serverURL)
            
            await MainActor.run {
                serverStatus = isOnline ? .online : .offline
                isCheckingServer = false
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

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

