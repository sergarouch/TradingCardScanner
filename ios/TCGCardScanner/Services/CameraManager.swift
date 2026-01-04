//
//  CameraManager.swift
//  TCGCardScanner
//

import AVFoundation
import UIKit
import Vision

class CameraManager: NSObject, ObservableObject {
    @Published var isFlashOn = false
    @Published var permissionGranted = false
    
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Permissions
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted {
                        self?.startSession()
                    }
                }
            }
        default:
            permissionGranted = false
        }
    }
    
    // MARK: - Session Setup
    
    private func setupSession() {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Add video input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else {
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoInput)
        
        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
        }
        
        captureSession.commitConfiguration()
        
        // Setup preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
    }
    
    // MARK: - Session Control
    
    func startSession() {
        guard !captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func stopSession() {
        guard captureSession.isRunning else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }
    
    // MARK: - Flash
    
    func toggleFlash() {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }
        
        do {
            try device.lockForConfiguration()
            
            if isFlashOn {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 1.0)
            }
            
            isFlashOn.toggle()
            device.unlockForConfiguration()
        } catch {
            print("Flash error: \(error)")
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletion = completion
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletion?(nil)
            return
        }
        
        // Crop to card aspect ratio (standard trading card is ~2.5 x 3.5 inches)
        let croppedImage = cropToCardRatio(image)
        photoCaptureCompletion?(croppedImage)
    }
    
    private func cropToCardRatio(_ image: UIImage) -> UIImage {
        let cardAspectRatio: CGFloat = 2.5 / 3.5 // width / height
        
        let imageSize = image.size
        let imageAspectRatio = imageSize.width / imageSize.height
        
        var cropRect: CGRect
        
        if imageAspectRatio > cardAspectRatio {
            // Image is wider than card - crop sides
            let newWidth = imageSize.height * cardAspectRatio
            let xOffset = (imageSize.width - newWidth) / 2
            cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: imageSize.height)
        } else {
            // Image is taller than card - crop top/bottom
            let newHeight = imageSize.width / cardAspectRatio
            let yOffset = (imageSize.height - newHeight) / 2
            cropRect = CGRect(x: 0, y: yOffset, width: imageSize.width, height: newHeight)
        }
        
        // Center crop with padding for card frame
        let centerPadding: CGFloat = 0.15 // 15% padding on each side
        let paddingX = cropRect.width * centerPadding
        let paddingY = cropRect.height * centerPadding
        
        cropRect = cropRect.insetBy(dx: paddingX, dy: paddingY)
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    // MARK: - OCR Text Recognition
    
    func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard error == nil,
                  let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // Extract text from the top portion of the card (where the name usually is)
            let topTexts = observations
                .filter { $0.boundingBox.minY > 0.7 } // Top 30% of image
                .compactMap { $0.topCandidates(1).first?.string }
            
            // Get the most likely card name (usually the largest/most prominent text at top)
            let cardName = topTexts.first ?? observations.first?.topCandidates(1).first?.string
            
            completion(cardName)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("OCR Error: \(error)")
                completion(nil)
            }
        }
    }
}

