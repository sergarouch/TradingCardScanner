//
//  ScannerView.swift
//  TCGCardScanner
//
//  Fully on-device card scanning - no server needed!
//

import SwiftUI
import AVFoundation

struct ScannerView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var cameraManager = CameraManager()
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var processingStatus = "Analyzing..."
    @State private var scanResult: ScannedCard?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var detectedCardName: String?
    
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
        .alert("Scan Result", isPresented: $showingError) {
            Button("Search Manually") {
                // Could navigate to search tab
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "Unknown error occurred")
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Trading Card Scanner")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "00d4ff"), Color(hex: "9d4edd")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Position card within frame")
                    .font(.caption)
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
            
            // Detected text preview
            if let cardName = detectedCardName {
                VStack {
                    Spacer()
                    Text("Detected: \(cardName)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "00d4ff").opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 8)
                }
                .frame(width: 280, height: 390)
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
            Color.black.opacity(0.8)
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
                    Text(processingStatus)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    
                    Text("Processing on-device...")
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
        processingStatus = "Reading card text..."
        
        Task {
            do {
                // Step 1: OCR - Read text from card
                let recognition = try await CardRecognitionService.shared.recognizeCard(from: image)
                
                guard let cardName = recognition.detectedName else {
                    await MainActor.run {
                        isProcessing = false
                        appState.isScanning = false
                        
                        let allText = recognition.allDetectedText.map { $0.text }.joined(separator: ", ")
                        errorMessage = "Could not identify card name.\n\nDetected text: \(allText.isEmpty ? "None" : allText)\n\nTry the Search tab to find your card manually."
                        showingError = true
                    }
                    return
                }
                
                await MainActor.run {
                    processingStatus = "Searching TCGPlayer..."
                    detectedCardName = cardName
                }
                
                // Step 2: Search TCGPlayer for the card
                    // Search TCGPlayer for the detected card name
                    let results = try await TCGPlayerService.shared.searchCards(
                        query: cardName,
                        category: mapCategoryToTCGPlayer(recognition.category)
                    )
                    
                    await MainActor.run {
                        isProcessing = false
                        appState.isScanning = false
                        detectedCardName = nil
                        
                        if let topResult = results.first {
                            let imageData = image.jpegData(compressionQuality: 0.5)
                            let scannedCard = ScannedCard(
                                from: topResult,
                                imageData: imageData,
                                confidence: recognition.confidence,
                                detectedText: cardName
                            )
                            scanResult = scannedCard
                            appState.addScannedCard(scannedCard)
                            showingResult = true
                        } else {
                            // If no exact match, try searching without category filter
                            Task {
                                do {
                                    let broaderResults = try await TCGPlayerService.shared.searchCards(
                                        query: cardName,
                                        category: nil
                                    )
                                    
                                    await MainActor.run {
                                        if let topResult = broaderResults.first {
                                            let imageData = image.jpegData(compressionQuality: 0.5)
                                            let scannedCard = ScannedCard(
                                                from: topResult,
                                                imageData: imageData,
                                                confidence: recognition.confidence * 0.8, // Lower confidence for broader search
                                                detectedText: cardName
                                            )
                                            scanResult = scannedCard
                                            appState.addScannedCard(scannedCard)
                                            showingResult = true
                                        } else {
                                            errorMessage = "Card '\(cardName)' not found on TCGPlayer.\n\nDetected text: \(cardName)\n\nTry searching manually in the Search tab or scan again with better lighting."
                                            showingError = true
                                        }
                                    }
                                } catch {
                                    await MainActor.run {
                                        errorMessage = "Could not find card '\(cardName)' on TCGPlayer.\n\nError: \(error.localizedDescription)\n\nTry searching manually in the Search tab."
                                        showingError = true
                                    }
                                }
                            }
                        }
                    }
                
            } catch {
                await MainActor.run {
                    isProcessing = false
                    appState.isScanning = false
                    detectedCardName = nil
                    errorMessage = "Error: \(error.localizedDescription)"
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

// MARK: - Helper Functions

func mapCategoryToTCGPlayer(_ category: String) -> String? {
    switch category.lowercased() {
    case "pokemon": return "pokemon"
    case "magic: the gathering", "trading card": return "magic"
    case "yu-gi-oh!", "yugioh": return "yugioh"
    case "sports": return "sports"
    case "one piece": return "one piece"
    case "disney lorcana", "lorcana": return "lorcana"
    default: return nil
    }
}

#Preview {
    ScannerView()
        .environmentObject(AppState())
}
