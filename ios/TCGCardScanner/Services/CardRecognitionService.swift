//
//  CardRecognitionService.swift
//  TCGCardScanner
//
//  On-device card recognition using Vision framework
//

import Vision
import UIKit
import CoreImage

class CardRecognitionService {
    static let shared = CardRecognitionService()
    
    private init() {}
    
    // MARK: - Main Recognition Function
    
    func recognizeCard(from image: UIImage) async throws -> CardRecognitionResult {
        // Run OCR and image analysis in parallel
        async let textResult = performOCR(on: image)
        async let categoryResult = detectCardCategory(from: image)
        
        let (texts, category) = try await (textResult, categoryResult)
        
        // Extract card name from detected texts
        let cardName = extractCardName(from: texts)
        let setInfo = extractSetInfo(from: texts)
        
        return CardRecognitionResult(
            detectedName: cardName,
            setInfo: setInfo,
            category: category,
            allDetectedText: texts,
            confidence: cardName != nil ? 0.8 : 0.3
        )
    }
    
    // MARK: - OCR
    
    private func performOCR(on image: UIImage) async throws -> [DetectedText] {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let detectedTexts = observations.compactMap { observation -> DetectedText? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    
                    return DetectedText(
                        text: candidate.string,
                        confidence: candidate.confidence,
                        boundingBox: observation.boundingBox
                    )
                }
                
                continuation.resume(returning: detectedTexts)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Card Category Detection
    
    private func detectCardCategory(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            return "Unknown"
        }
        
        // Analyze dominant colors and patterns
        let colors = extractDominantColors(from: cgImage)
        
        // Use color analysis to guess category
        // Pokemon cards often have yellow borders, MTG has black borders, etc.
        if colors.contains(where: { isYellowish($0) }) {
            return "Pokemon"
        } else if colors.contains(where: { isBlackish($0) }) && colors.count > 2 {
            return "Magic: The Gathering"
        }
        
        return "Trading Card"
    }
    
    // MARK: - Text Analysis
    
    private func extractCardName(from texts: [DetectedText]) -> String? {
        // Card names are typically:
        // 1. In the top portion of the card (high Y value in Vision coordinates)
        // 2. Larger/more prominent text
        // 3. Not numbers or game stats
        
        // Sort by Y position (top of card = higher Y in Vision coordinates)
        let topTexts = texts
            .filter { $0.boundingBox.minY > 0.65 } // Top 35% of image
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
        
        // Filter out common non-name text
        let filteredTexts = topTexts.filter { text in
            let str = text.text.lowercased()
            
            // Skip if it's just numbers
            if str.allSatisfy({ $0.isNumber || $0 == "/" || $0 == " " }) {
                return false
            }
            
            // Skip common card keywords that aren't names
            let skipWords = ["basic", "stage", "hp", "trainer", "supporter", "item",
                           "pokemon", "energy", "weakness", "resistance", "retreat",
                           "illustrator", "©", "®", "™"]
            for word in skipWords {
                if str.contains(word) { return false }
            }
            
            // Must have at least 2 characters
            if str.count < 2 { return false }
            
            return true
        }
        
        // Return the most likely card name
        // Prefer longer text that's not too long (card names are typically 2-30 chars)
        let candidates = filteredTexts.filter { $0.text.count >= 2 && $0.text.count <= 40 }
        
        // Return the first (topmost) valid candidate
        return candidates.first?.text
    }
    
    private func extractSetInfo(from texts: [DetectedText]) -> String? {
        // Set info is typically at the bottom of the card
        let bottomTexts = texts
            .filter { $0.boundingBox.maxY < 0.2 } // Bottom 20%
        
        // Look for set numbers like "123/456" or set names
        for text in bottomTexts {
            let str = text.text
            
            // Check for set number pattern
            if str.range(of: #"\d+/\d+"#, options: .regularExpression) != nil {
                return str
            }
        }
        
        return nil
    }
    
    // MARK: - Color Analysis
    
    private func extractDominantColors(from cgImage: CGImage) -> [UIColor] {
        let width = min(cgImage.width, 50)
        let height = min(cgImage.height, 50)
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return [] }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let data = context.data else { return [] }
        
        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)
        
        var colors: [UIColor] = []
        
        // Sample border colors (edges of card)
        let samplePoints = [
            (5, height/2),           // Left edge
            (width-5, height/2),     // Right edge
            (width/2, 5),            // Top edge
            (width/2, height-5)      // Bottom edge
        ]
        
        for (x, y) in samplePoints {
            let offset = (y * width + x) * 4
            let r = CGFloat(pointer[offset]) / 255.0
            let g = CGFloat(pointer[offset + 1]) / 255.0
            let b = CGFloat(pointer[offset + 2]) / 255.0
            colors.append(UIColor(red: r, green: g, blue: b, alpha: 1.0))
        }
        
        return colors
    }
    
    private func isYellowish(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return r > 0.7 && g > 0.6 && b < 0.4
    }
    
    private func isBlackish(_ color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: nil)
        return r < 0.2 && g < 0.2 && b < 0.2
    }
}

// MARK: - Models

struct CardRecognitionResult {
    let detectedName: String?
    let setInfo: String?
    let category: String
    let allDetectedText: [DetectedText]
    let confidence: Double
}

struct DetectedText {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
}

enum RecognitionError: LocalizedError {
    case invalidImage
    case ocrFailed
    case noTextFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image"
        case .ocrFailed: return "Text recognition failed"
        case .noTextFound: return "No text found on card"
        }
    }
}

