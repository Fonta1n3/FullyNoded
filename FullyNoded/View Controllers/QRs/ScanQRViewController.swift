//
//  ScanQRViewController.swift
//  FullyNoded
//
//  Created by Fontaine on 12/31/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import URKit // For UR decoding
import Bbqr   // For BBQR decoding

@available(macCatalyst 14.0, *)
final class ScanQRViewController: UIViewController {
    
    // MARK: - Configuration
    var isQuickConnect = false
    var isScanningAddress = false
    var fromSignAndVerify = false
    var onCompletion: ((String) -> Void)?
    
    // MARK: - Private State
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var hasScanned = false
    
    // Animated QR state
    private var urDecoder = URDecoder()
    private var bbqrParts: [String] = []
    private var specterParts: [(index: Int, part: String)] = []
    
    // UI Elements
    private let closeButton = UIButton(type: .system)
    private let torchButton = UIButton(type: .system)
    private let libraryButton = UIButton(type: .system)
    private let progressContainer = UIView()
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let overlayView = UIView()
    
    private var isTorchOn = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
        requestCameraPermission()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        overlayView.frame = view.bounds
        
        updateOverlayMaskAndBrackets()  // Call this every layout (handles rotation/resizing on Mac)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScanning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
        toggleTorch(on: false)
    }
    
    private func updateOverlayMaskAndBrackets() {
        // Remove old brackets
        overlayView.layer.sublayers?.filter { $0 is CAShapeLayer }.forEach { $0.removeFromSuperlayer() }
        
        let bounds = view.bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        // Centered square scan area (70% of narrower dimension for better Mac compatibility)
        let side = min(bounds.width, bounds.height) * 0.7
        let scanRect = CGRect(
            x: (bounds.width - side) / 2,
            y: (bounds.height - side) / 2,
            width: side,
            height: side
        )
        
        // Mask for transparent cutout
        let path = UIBezierPath(rect: bounds)
        let clearPath = UIBezierPath(roundedRect: scanRect, cornerRadius: 20)
        path.append(clearPath)
        path.usesEvenOddFillRule = true
        
        let maskLayer = CAShapeLayer()
        maskLayer.path = path.cgPath
        maskLayer.fillRule = .evenOdd
        overlayView.layer.mask = maskLayer
        
        // Add corner brackets
        addCornerBrackets(to: overlayView, rect: scanRect)
    }
    
    // MARK: - Setup UI (Fully Programmatic)
    private func setupUI() {
        view.backgroundColor = .black
        
        // Preview container
        let previewContainer = UIView()
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewContainer)
        
        // Overlay with cutout
        setupOverlay()
        
        // Buttons
        setupButtons()
        
        // Progress UI
        setupProgressUI()
        
        // Constraints
        NSLayoutConstraint.activate([
            previewContainer.topAnchor.constraint(equalTo: view.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Add preview layer later
        previewLayer = AVCaptureVideoPreviewLayer()
        previewLayer.videoGravity = .resizeAspectFill
        previewContainer.layer.addSublayer(previewLayer)
    }
    
    private func setupOverlay() {
        // Initial empty setup (add overlayView to hierarchy)
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlayView)
        
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    
    
    private func addCornerBrackets(to view: UIView, rect: CGRect) {
        let cornerLength: CGFloat = 30
        let thickness: CGFloat = 4
        let color = UIColor.systemGreen
        
        let corners: [(CGPoint, CGPoint)] = [
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX + cornerLength, y: rect.minY)), // Top-left horizontal
            (CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.minX, y: rect.minY + cornerLength)), // Top-left vertical
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX - cornerLength, y: rect.minY)),
            (CGPoint(x: rect.maxX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY + cornerLength)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX + cornerLength, y: rect.maxY)),
            (CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.minX, y: rect.maxY - cornerLength)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX - cornerLength, y: rect.maxY)),
            (CGPoint(x: rect.maxX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        ]
        
        for (start, end) in corners {
            let line = CAShapeLayer()
            let path = UIBezierPath()
            path.move(to: start)
            path.addLine(to: end)
            line.path = path.cgPath
            line.strokeColor = color.cgColor
            line.lineWidth = thickness
            line.lineCap = .round
            view.layer.addSublayer(line)
        }
    }
    
    private func setupButtons() {
        let buttons: [(UIButton, String, Selector)] = [
            (closeButton, "xmark", #selector(closeTapped)),
            (torchButton, "flashlight.off.circle", #selector(torchButtonTapped)),
            (libraryButton, "photo.on.rectangle", #selector(openPhotoLibrary))
        ]
        
        for (button, icon, action) in buttons {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.setImage(UIImage(systemName: icon), for: .normal)
            button.tintColor = .white
            button.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            button.layer.cornerRadius = 30
            button.addTarget(self, action: action, for: .touchUpInside)
            view.addSubview(button)
            
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 60),
                button.heightAnchor.constraint(equalToConstant: 60)
            ])
        }
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            torchButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            torchButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            
            libraryButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            libraryButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }
    
    private func setupProgressUI() {
        progressContainer.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        progressContainer.layer.cornerRadius = 12
        progressContainer.alpha = 0
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressContainer)
        
        progressLabel.textColor = .white
        progressLabel.font = .systemFont(ofSize: 16, weight: .medium)
        progressLabel.textAlignment = .center
        progressLabel.translatesAutoresizingMaskIntoConstraints = false
        
        progressView.progressTintColor = .systemGreen
        progressView.trackTintColor = .darkGray
        progressView.translatesAutoresizingMaskIntoConstraints = false
        
        progressContainer.addSubview(progressLabel)
        progressContainer.addSubview(progressView)
        
        NSLayoutConstraint.activate([
            progressContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressContainer.bottomAnchor.constraint(equalTo: torchButton.topAnchor, constant: -20),
            progressContainer.widthAnchor.constraint(equalToConstant: 250),
            progressContainer.heightAnchor.constraint(equalToConstant: 80),
            
            progressLabel.topAnchor.constraint(equalTo: progressContainer.topAnchor, constant: 16),
            progressLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 16),
            progressLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -16),
            
            progressView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor, constant: 20),
            progressView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor, constant: -20),
            progressView.heightAnchor.constraint(equalToConstant: 8)
        ])
    }
    
    // MARK: - Actions
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func torchButtonTapped() {
        isTorchOn.toggle()
        toggleTorch(on: isTorchOn)
        torchButton.setImage(UIImage(systemName: isTorchOn ? "flashlight.on.circle.fill" : "flashlight.off.circle"), for: .normal)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    @objc private func openPhotoLibrary() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Scanning Logic
    private func startScanning() {
        guard captureSession?.isRunning == false else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    private func stopScanning(_ psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            captureSession.stopRunning()
            
            self.dismiss(animated: true) {
                self.onCompletion!(psbt)
            }
        }
    }
    
    private func finish(with result: String) {
        guard !hasScanned else { return }
        hasScanned = true
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            dismiss(animated: true) { [weak self] in
                self?.onCompletion?(result)
            }
        }
    }
    
    private func updateProgress(text: String, progress: Float) {
        DispatchQueue.main.async { [weak self] in
            self?.progressLabel.text = text
            self?.progressView.setProgress(progress, animated: true)
            UIView.animate(withDuration: 0.3) {
                self?.progressContainer.alpha = progress > 0 ? 1 : 0
            }
        }
    }
    
    // MARK: - QR Processing
    private func processQRCode(_ text: String) {
        guard !hasScanned else { return }
        
        let lower = text.lowercased()
        
        if text.hasPrefix("B$") {
            processBBQr(text: text)
        } else if lower.hasPrefix("ur:") {
            processUR(text)
        } else if text.hasPrefix("p") && fromSignAndVerify {
            processSpecter(text)
        } else if Keys.validPsbt(text) || Keys.validTx(text) || fromSignAndVerify {
            finish(with: text)
        } else {
            finish(with: text) // fallback for addresses, etc.
        }
    }
    
    private func processUR(_ part: String) {
        urDecoder.receivePart(part)
        
        if let result = try? urDecoder.result?.get() {
            finish(with: result.string)
        } else if let expected = urDecoder.expectedFragmentCount, expected > 0 {
            let progress = Float(urDecoder.processedPartsCount) / Float(expected)
            updateProgress(text: "\(Int(progress * 100))% complete", progress: progress)
        }
    }
    
    private func processBBQr(text: String) {
        let numberOfQrsBase36 = "\(text[4..<6])"
        //let qrNumberBase36 = "\(text[6..<8])"
        let numberOfQrs = strtoul(numberOfQrsBase36, nil, 36)
        //let qrNumber = strtoul(qrNumberBase36, nil, 36)
        
        if !bbqrParts.contains(text) {
            bbqrParts.append(text)
            
            DispatchQueue.main.async {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            
            let number = Float(bbqrParts.count) / Float(numberOfQrs)
            let percentageComplete = "\(Int(number * 100))% complete"
            updateProgress(text: percentageComplete, progress: number)
            
            if number == 1 {
                guard let result = try? continousJoiner(parts: bbqrParts) else { return }
            }
        }
        
        
        
        #if DEBUG
        //print("BBQr result: \(result)")
        #endif
    }
    
    func continousJoiner(parts: [String]) throws -> ((psbt: String?, descriptor: String?)) {
        let continousJoiner = ContinuousJoiner()
        
        for part in parts {
            switch try continousJoiner.addPart(part: part) {
            case .notStarted:
                #if DEBUG
                print("not started")
                #endif
                
            case .inProgress(let partsLeft):
                #if DEBUG
                print("added item, \(partsLeft) parts left")
                #endif
                hasScanned = false
                
            case .complete(let joined):
                hasScanned = true
                let s = String(decoding: joined.data(), as: UTF8.self)
                if s.hasPrefix("psbt") {
                    stopScanning(joined.data().base64EncodedString())
                } else {
                    stopScanning(s)
                }
            }
        }

        return ((nil, nil))
    }
    
    private func processSpecter(_ part: String) {
        // Simplified — implement full logic as needed
        // Parse "p1of10 ABC..." format
        // Collect and join parts
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate
extension ScanQRViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !hasScanned, let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              object.type == .qr, let string = object.stringValue else { return }
        
        AudioServicesPlaySystemSound(1103)
        processQRCode(string)
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ScanQRViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        guard let image = info[.originalImage] as? UIImage,
              let ciImage = CIImage(image: image),
              let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]),
              let features = detector.features(in: ciImage) as? [CIQRCodeFeature],
              let message = features.first?.messageString else {
            return
        }
        
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        processQRCode(message)
    }
}

// MARK: - Camera Setup & Permissions
extension ScanQRViewController {
    private func requestCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { DispatchQueue.main.async { self?.setupCaptureSession() } }
            }
        default:
            showAlert(title: "Camera Access Required", message: "Please enable camera access in Settings.")
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              captureSession.canAddInput(videoInput) else { return }
        
        captureSession.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "qr.queue"))
            metadataOutput.metadataObjectTypes = [.qr]
        }
        
        previewLayer.session = captureSession
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }
}
