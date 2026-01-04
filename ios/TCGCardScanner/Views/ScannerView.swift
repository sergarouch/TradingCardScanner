//
//  ScannerView.swift
//  TCGCardScanner
//

import SwiftUI
import AVFoundation

struct ScannerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var scanResult: ScannedCard?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(cameraManager: cameraManager)
                .ignoresSafeArea()
            
            // Overlay UI
            VStack {
                // Header
                headerView
                
                Spacer()
                
                // Scan guide frame
                scanGuideView
                
                Spacer()
                
                // Capture button
                captureButtonView
            }
            
            // Processing overlay
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            cameraManager.checkPermissions()
        }
        .sheet(isPresented: $showingResult) {
            if let card = scanResult {
                CardResultView(card: card)
            }
        }
        .alert("Scan Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("TCG Scanner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Position card within frame")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Flash toggle
            Button(action: {
                cameraManager.toggleFlash()
            }) {
                Image(systemName: cameraManager.isFlashOn ? "bolt.fill" : "bolt.slash")
                    .font(.title2)
                    .foregroundColor(cameraManager.isFlashOn ? Color(hex: "ffd700") : .white.opacity(0.7))
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 60)
    }
    
    // MARK: - Scan Guide
    
    private var scanGuideView: some View {
        ZStack {
            // Card frame with animated border
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd"), Color(hex: "ff006e")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: 280, height: 390)
                .shadow(color: Color(hex: "00d4ff").opacity(0.5), radius: 10)
            
            // Corner markers
            VStack {
                HStack {
                    cornerMarker(rotation: 0)
                    Spacer()
                    cornerMarker(rotation: 90)
                }
                Spacer()
                HStack {
                    cornerMarker(rotation: 270)
                    Spacer()
                    cornerMarker(rotation: 180)
                }
            }
            .frame(width: 280, height: 390)
            
            // Scanning animation
            if appState.isScanning {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, Color(hex: "00d4ff").opacity(0.3), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 60)
                    .offset(y: -150)
                    .animation(
                        Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: appState.isScanning
                    )
            }
        }
    }
    
    private func cornerMarker(rotation: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color(hex: "00d4ff"), lineWidth: 4)
        .frame(width: 20, height: 20)
        .rotationEffect(.degrees(rotation))
    }
    
    // MARK: - Capture Button
    
    private var captureButtonView: some View {
        VStack(spacing: 20) {
            // Capture button
            Button(action: capturePhoto) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(hex: "00d4ff").opacity(0.5), radius: 15)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 70, height: 70)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
            }
            .disabled(isProcessing)
            
            Text("Tap to scan card")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Processing Overlay
    
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Animated logo
                ZStack {
                    Circle()
                        .stroke(Color(hex: "00d4ff").opacity(0.3), lineWidth: 4)
                        .frame(width: 100, height: 100)
                    
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(isProcessing ? 360 : 0))
                        .animation(
                            Animation.linear(duration: 1).repeatForever(autoreverses: false),
                            value: isProcessing
                        )
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "00d4ff"))
                }
                
                VStack(spacing: 8) {
                    Text("Analyzing Card")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Identifying and fetching price...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func capturePhoto() {
        cameraManager.capturePhoto { image in
            guard let image = image else {
                errorMessage = "Failed to capture photo"
                showingError = true
                return
            }
            
            capturedImage = image
            processImage(image)
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        appState.isScanning = true
        
        Task {
            do {
                let result = try await APIService.shared.identifyCard(
                    image: image,
                    serverURL: appState.serverURL
                )
                
                await MainActor.run {
                    isProcessing = false
                    appState.isScanning = false
                    
                    if let card = result {
                        scanResult = card
                        appState.addScannedCard(card)
                        showingResult = true
                    } else {
                        errorMessage = "Could not identify the card. Try adjusting the angle or lighting."
                        showingError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    appState.isScanning = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = cameraManager.previewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

#Preview {
    ScannerView()
        .environmentObject(AppState())
}

