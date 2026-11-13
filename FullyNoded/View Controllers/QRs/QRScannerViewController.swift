//
//  QRScannerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import AVFoundation
import UIKit

/// Camera QR scanner (with photo-library import and torch) used across the app: quick
/// connect, addresses, xpubs / descriptors, and animated PSBT / transaction QRs (UR, BBQr,
/// Specter) for signing and verifying.
///
/// The storyboard scene ("QRScanner") only supplies the class and outlets; the layout is
/// built in code in the app's cypherpunk theme: live preview, a dimmed surround with a
/// bracketed scan window and sweeping line, a hint, a progress card for animated QRs, and
/// torch / photo buttons.
@available(macCatalyst 14.0, *)
class QRScannerViewController: UIViewController {
    
    var isImporting = false
    private var hasScanned = false
    private let avCaptureSession = AVCaptureSession()
    private var stringToReturn = ""
    private let imagePicker = UIImagePickerController()
    private var qrString = ""
    private let uploadButton = UIButton(type: .system)
    private let torchButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let downSwipe = UISwipeGestureRecognizer()
    var isQuickConnect = Bool()
    var isScanningAddress = Bool()
    var onDoneBlock : ((String?) -> Void)?
    var fromSignAndVerify = Bool()
    var decoder:URDecoder!
    var bbqrParts: [String] = []
    private var isTorchOn = Bool()
    private var psbtParts = [[String:String]]()
    /// The last code that was rejected (so the same QR isn't reported every frame).
    private var lastRejected: String?
    
    // Storyboard outlets (still connected; their views are replaced by the layout below).
    @IBOutlet weak private var scannerView: UIImageView!
    @IBOutlet weak private var progressDescriptionLabel: UILabel!
    @IBOutlet weak private var progressView: UIProgressView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    
    private let tint = WalletTheme.Tint.wallet
    private let previewView = UIView()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private let dimLayer = CAShapeLayer()
    private let bracketLayer = CAShapeLayer()
    private let scanLine = CAGradientLayer()
    private let titleLabel = UILabel()
    private let hintLabel = UILabel()
    private let progressCard = UIView()
    private let progressLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .bar)
    private let permissionCard = UIView()
    private var scanRect: CGRect = .zero
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Edge to edge camera (a sheet would leave the parent showing above it).
        modalPresentationStyle = .fullScreen
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        buildLayout()
        configureScanner()
        decoder = URDecoder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutOverlay()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scanNow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isTorchOn { toggleTorch(on: false); isTorchOn = false }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    private func scanNow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.startCamera() } else { self?.showPermissionCard() }
                }
            }
        default:
            showPermissionCard()
        }
    }
    
    private func startCamera() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.permissionCard.isHidden = true
            self.bracketLayer.isHidden = false
            self.scanQRCode()
            self.startScanLine()
        }
    }
    
    private func configureScanner() {
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        isTorchOn = false
        // No torch (simulator, iPad, Mac): hide the button and its caption.
        torchButton.superview?.isHidden = !(AVCaptureDevice.default(for: .video)?.hasTorch ?? false)
        configureImagePicker()
        configureDownSwipe()
    }
    
    // MARK: - Layout
    
    private func buildLayout() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black
        view.tintColor = tint.accent
        // The scene's own views are replaced by this layout.
        view.subviews.forEach { $0.removeFromSuperview() }
        
        previewView.backgroundColor = .black
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)
        view.addSubview(previewView)
        
        // Dimmed surround with a clear scan window, accent corner brackets, sweeping line.
        dimLayer.fillRule = .evenOdd
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.6).cgColor
        view.layer.addSublayer(dimLayer)
        bracketLayer.strokeColor = tint.accent.cgColor
        bracketLayer.fillColor = UIColor.clear.cgColor
        bracketLayer.lineWidth = 3
        bracketLayer.lineCap = .square
        bracketLayer.shadowColor = tint.accent.cgColor
        bracketLayer.shadowRadius = 6
        bracketLayer.shadowOpacity = 0.6
        bracketLayer.shadowOffset = .zero
        view.layer.addSublayer(bracketLayer)
        scanLine.colors = [tint.accent.withAlphaComponent(0).cgColor, tint.accent.withAlphaComponent(0.85).cgColor, tint.accent.withAlphaComponent(0).cgColor]
        scanLine.startPoint = CGPoint(x: 0, y: 0.5)
        scanLine.endPoint = CGPoint(x: 1, y: 0.5)
        scanLine.opacity = 0
        view.layer.addSublayer(scanLine)
        
        // Top: close, title, hint.
        styleRoundButton(closeButton, systemName: "xmark", label: "Close")
        titleLabel.text = "SCAN QR"
        titleLabel.font = WalletTheme.mono(15, weight: .bold)
        titleLabel.textColor = tint.accent
        titleLabel.textAlignment = .center
        hintLabel.text = defaultHint
        hintLabel.font = WalletTheme.mono(12)
        hintLabel.textColor = WalletTheme.text
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        
        // Bottom: torch, photo library.
        styleRoundButton(torchButton, systemName: "flashlight.off.fill", label: "Torch")
        styleRoundButton(uploadButton, systemName: "photo.on.rectangle", label: "Choose a QR image")
        let torchCaption = caption("torch")
        let photoCaption = caption("photos")
        let torchColumn = column(torchButton, torchCaption)
        let photoColumn = column(uploadButton, photoCaption)
        
        // Animated QR progress card.
        progressCard.backgroundColor = WalletTheme.bg.withAlphaComponent(0.92)
        progressCard.layer.borderWidth = 1
        progressCard.layer.borderColor = tint.line.cgColor
        progressCard.alpha = 0
        progressLabel.font = WalletTheme.mono(12, weight: .semibold)
        progressLabel.textColor = WalletTheme.text
        progressLabel.textAlignment = .center
        progressBar.progressTintColor = tint.accent
        progressBar.trackTintColor = tint.line.withAlphaComponent(0.25)
        let progressStack = UIStackView(arrangedSubviews: [progressLabel, progressBar])
        progressStack.axis = .vertical
        progressStack.spacing = 8
        progressStack.translatesAutoresizingMaskIntoConstraints = false
        progressCard.addSubview(progressStack)
        
        buildPermissionCard()
        
        [closeButton, titleLabel, hintLabel, torchColumn, photoColumn, progressCard, permissionCard].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            closeButton.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            closeButton.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hintLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 18),
            hintLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            hintLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32),
            
            torchColumn.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 36),
            torchColumn.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            photoColumn.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -36),
            photoColumn.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            
            progressCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressCard.bottomAnchor.constraint(equalTo: photoColumn.topAnchor, constant: -24),
            progressCard.widthAnchor.constraint(equalToConstant: 260),
            progressStack.topAnchor.constraint(equalTo: progressCard.topAnchor, constant: 12),
            progressStack.leadingAnchor.constraint(equalTo: progressCard.leadingAnchor, constant: 14),
            progressStack.trailingAnchor.constraint(equalTo: progressCard.trailingAnchor, constant: -14),
            progressStack.bottomAnchor.constraint(equalTo: progressCard.bottomAnchor, constant: -12),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            permissionCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            permissionCard.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            permissionCard.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32)
        ])
    }
    
    private var defaultHint: String {
        if fromSignAndVerify { return "Point the camera at a PSBT or transaction QR.\nAnimated QRs: hold steady until it completes." }
        if isQuickConnect { return "Point the camera at your node's quick connect QR." }
        if isScanningAddress { return "Point the camera at an address QR." }
        return "Point the camera at a QR code."
    }
    
    private func styleRoundButton(_ button: UIButton, systemName: String, label: String) {
        button.setImage(UIImage(systemName: systemName, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        button.tintColor = tint.accent
        button.backgroundColor = WalletTheme.bg.withAlphaComponent(0.75)
        button.layer.borderWidth = 1
        button.layer.borderColor = tint.line.cgColor
        button.accessibilityLabel = label
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 48),
            button.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func caption(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(10, weight: .semibold)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        return label
    }
    
    private func column(_ button: UIButton, _ caption: UILabel) -> UIStackView {
        let stack = UIStackView(arrangedSubviews: [button, caption])
        stack.axis = .vertical
        stack.spacing = 6
        stack.alignment = .center
        return stack
    }
    
    private func buildPermissionCard() {
        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor = tint.accent
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let title = UILabel()
        title.text = "Camera access is off"
        title.font = WalletTheme.mono(15, weight: .semibold)
        title.textColor = WalletTheme.text
        title.textAlignment = .center
        let body = UILabel()
        body.text = "Allow camera access for Fully Noded in Settings, or choose a QR image from your photos."
        body.font = WalletTheme.mono(12)
        body.textColor = WalletTheme.dim
        body.textAlignment = .center
        body.numberOfLines = 0
        let settings = UIButton(type: .system)
        settings.configuration = WalletTheme.buttonConfiguration(title: "Open Settings", systemImage: "gearshape", filled: true, tint: tint)
        settings.addTarget(self, action: #selector(openSettings), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [icon, title, body, settings])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        permissionCard.addSubview(stack)
        permissionCard.backgroundColor = WalletTheme.card
        permissionCard.layer.borderWidth = 1
        permissionCard.layer.borderColor = tint.line.cgColor
        permissionCard.isHidden = true
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: permissionCard.topAnchor, constant: 20),
            stack.leadingAnchor.constraint(equalTo: permissionCard.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: permissionCard.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: permissionCard.bottomAnchor, constant: -20)
        ])
    }
    
    private func showPermissionCard() {
        permissionCard.isHidden = false
        hintLabel.text = ""
        bracketLayer.isHidden = true
        scanLine.removeAllAnimations()
        scanLine.opacity = 0
    }
    
    @objc private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
    
    /// Square scan window (68% of the narrower side, capped), slightly above centre.
    private func layoutOverlay() {
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        previewLayer.frame = previewView.bounds
        
        let side = min(min(bounds.width, bounds.height) * 0.68, 360)
        scanRect = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2 - 20, width: side, height: side)
        
        let dim = UIBezierPath(rect: bounds)
        dim.append(UIBezierPath(rect: scanRect))
        dimLayer.frame = bounds
        dimLayer.path = dim.cgPath
        
        let length: CGFloat = 26
        let r = scanRect
        let brackets = UIBezierPath()
        for (corner, dx, dy) in [(CGPoint(x: r.minX, y: r.minY), 1.0, 1.0), (CGPoint(x: r.maxX, y: r.minY), -1.0, 1.0),
                                 (CGPoint(x: r.minX, y: r.maxY), 1.0, -1.0), (CGPoint(x: r.maxX, y: r.maxY), -1.0, -1.0)] {
            brackets.move(to: CGPoint(x: corner.x + CGFloat(dx) * length, y: corner.y))
            brackets.addLine(to: corner)
            brackets.addLine(to: CGPoint(x: corner.x, y: corner.y + CGFloat(dy) * length))
        }
        bracketLayer.frame = bounds
        bracketLayer.path = brackets.cgPath
        
        scanLine.frame = CGRect(x: r.minX + 8, y: r.minY, width: r.width - 16, height: 2)
        if scanLine.opacity > 0 { startScanLine() }
    }
    
    private func startScanLine() {
        guard scanRect != .zero, !UIAccessibility.isReduceMotionEnabled else { return }
        scanLine.removeAllAnimations()
        scanLine.opacity = 1
        let sweep = CABasicAnimation(keyPath: "position.y")
        sweep.fromValue = scanRect.minY + 6
        sweep.toValue = scanRect.maxY - 6
        sweep.duration = 1.8
        sweep.autoreverses = true
        sweep.repeatCount = .infinity
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        scanLine.add(sweep, forKey: "sweep")
    }
    
    /// Brief accent flash of the brackets when a code is read.
    private func flashBrackets() {
        let pulse = CABasicAnimation(keyPath: "lineWidth")
        pulse.fromValue = 6
        pulse.toValue = 3
        pulse.duration = 0.35
        bracketLayer.add(pulse, forKey: "pulse")
    }
    
    /// Shows a problem in the hint (instead of an alert) and lets scanning carry on.
    private func reject(_ text: String, message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.lastRejected = text
            self.hintLabel.text = message
            self.hintLabel.textColor = WalletTheme.pending
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self = self else { return }
                self.hintLabel.text = self.defaultHint
                self.hintLabel.textColor = WalletTheme.text
                self.lastRejected = nil
            }
            self.hasScanned = false
        }
    }
    
    private func didPickImage() {
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func toggleTorchNow() {
        if isTorchOn {
            toggleTorch(on: false)
            isTorchOn = false
        } else {
            toggleTorch(on: true)
            isTorchOn = true
        }
        torchButton.setImage(UIImage(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)), for: .normal)
        torchButton.backgroundColor = isTorchOn ? tint.accent.withAlphaComponent(0.25) : WalletTheme.bg.withAlphaComponent(0.75)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    private func stopScanning(_ psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            
            self.dismiss(animated: true) {
                self.onDoneBlock!(psbt)
            }
        }
    }
    
    private func processUrQr(text: String) {
        guard decoder.result == nil else {
            guard let result = try? decoder.result?.get() else { return }
            
            hasScanned = true
            stopScanning(result.string)
            return
        }

        decoder.receivePart(text.lowercased())
        
        let expectedParts = decoder.expectedFragmentCount ?? 0
        
        guard expectedParts != 0 else {
            guard let result = try? decoder.result?.get() else { return }
            hasScanned = true
            stopScanning(result.string)
            return
        }
        
        let percentageCompletion = "\(Int(decoder.estimatedPercentComplete * 100))% complete"
        updateProgress(percentageCompletion, self.decoder.estimatedPercentComplete)
        hasScanned = false
    }
    
    private func updateProgress(_ progressText: String, _ progressDoub: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.progressBar.setProgress(Float(min(progressDoub, 1)), animated: true)
            self.progressLabel.text = "ANIMATED QR · " + progressText.uppercased()
            self.hintLabel.text = "Hold steady, reading every part…"
            if self.progressCard.alpha == 0 {
                UIView.animate(withDuration: 0.25) { self.progressCard.alpha = 1 }
            }
        }
    }
    
    private func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    
    private func parseSpecterAnimatedQr(_ part: String) {
        var partArray = [String]()
        let arr = part.split(separator: " ")
        
        if arr.count > 0 {
            var prefix =  "\(arr[0])"
            let part = "\(arr[1])"
            
            prefix = prefix.replacingOccurrences(of: "p", with: "")
            prefix = prefix.replacingOccurrences(of: "of", with: "*")
            
            let arr1 = prefix.split(separator: "*")
            
            if arr1.count > 0 {
                if let index = Int(arr1[0]), let count = Int(arr1[1]) {
                    
                    var alreadyAdded = false
                    for (i, item) in psbtParts.enumerated() {
                        if let existingIndex = item["index"] {
                            if existingIndex == "\(index)" {
                                alreadyAdded = true
                            }
                        }
                        
                        if i + 1 == psbtParts.count {
                            if !alreadyAdded {
                                let number = Double(psbtParts.count) / Double(count)
                                let percentageComplete = "\(Int(number * 100))% complete"
                                if number < 1.1 {
                                    self.updateProgress(percentageComplete, number)
                                }
                            }
                        }
                    }
                    
                    if !alreadyAdded {
                        psbtParts.append(["part":part, "index":"\(index)"])
                        
                        if psbtParts.count >= count {
                            psbtParts.sort(by: {($0["index"]!) < $1["index"]!})
                            
                            for (i, item) in psbtParts.enumerated() {
                                guard let part = item["part"] else { return }
                                
                                partArray.append(part)
                                
                                if i + 1 == psbtParts.count {
                                    let unique = uniq(source: partArray)
                                    let psbtString = unique.joined()
                                                                    
                                    if Keys.validPsbt(psbtString) {
                                        hasScanned = true
                                        stopScanning(psbtString)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func continousJoiner(parts: [String]) throws -> ((psbt: String?, descriptor: String?)) {
        let joiner = BBQR.Joiner()
        
        for part in parts {
            switch try joiner.add(part) {
            case .inProgress(let received, let total):
                #if DEBUG
                print("added item, \(total - received) parts left")
                #endif
                hasScanned = false
                
            case .complete(let type, let data):
                hasScanned = true
                switch type {
                case .psbt:
                    stopScanning(data.base64EncodedString())
                case .transaction:
                    stopScanning(data.hexString)
                default:
                    let s = String(decoding: data, as: UTF8.self)
                    // A psbt sent with another type letter.
                    stopScanning(s.hasPrefix("psbt") ? data.base64EncodedString() : s)
                }
            }
        }

        return ((nil, nil))
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
            
            let number = Double(bbqrParts.count) / Double(numberOfQrs)
            let percentageComplete = "\(Int(number * 100))% complete"
            updateProgress(percentageComplete, number)
        }
        
        guard let result = try? continousJoiner(parts: bbqrParts) else { return }
        
        #if DEBUG
        print("BBQr result: \(result)")
        #endif
    }
    
    private func process(text: String) {
        let lowercased = text.lowercased()
        
        #if DEBUG
        print("text: \(text)")
        #endif
        
        if text.hasPrefix("B$") {
            processBBQr(text: text)
            
        } else if fromSignAndVerify {
            if lowercased.hasPrefix("ur:crypto-psbt") || lowercased.hasPrefix("ur:bytes") {
                processUrQr(text: text)
                
            } else if Keys.validTx(text) {
                // its a raw transaction
                hasScanned = true
                stopScanning(text)
            } else if Keys.validPsbt(text) {
                // its a plain text base64 psbt
                hasScanned = true
                stopScanning(text)
            } else if text.hasPrefix("p") {
                // could be a specter animated psbt
                hasScanned = false
                parseSpecterAnimatedQr(text)
            } else {
                reject(text, message: "That QR isn't a PSBT or transaction this app recognises. Let us know so we can add it.")
            }
            
        } else if isImporting {
            if lowercased.hasPrefix("ur:") {
                processUrQr(text: lowercased)
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.dismiss(animated: true) {
                        vc.stopScanner()
                        vc.onDoneBlock!(text)
                    }
                }
            }
                        
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.stopScanner()
                    vc.onDoneBlock!(text)
                }
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        closeAction(sender)
    }
    
    private func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    private func configureDownSwipe() {
        downSwipe.direction = .down
        downSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        view.addGestureRecognizer(downSwipe)
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
            
        } else {
            print("Torch is not available")
        }
    }
    
    private func scanQRCode() {
        let queue = DispatchQueue(label: "codes", qos: .userInteractive)
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: queue)
        
        if let inputs = self.avCaptureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.avCaptureSession.removeInput(input)
            }
        }
        
        if let outputs = self.avCaptureSession.outputs as? [AVCaptureMetadataOutput] {
            for output in outputs {
                self.avCaptureSession.removeOutput(output)
            }
        }
        
        self.avCaptureSession.addInput(avCaptureInput)
        self.avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        previewLayer.session = avCaptureSession
        previewLayer.frame = previewView.bounds
        self.startScanner()
    }
    
    private func removeScanner() {
        stopScanner()
        
        DispatchQueue.main.async { [weak self] in
            self?.scanLine.removeAllAnimations()
        }
    }
    
    private func stopScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.stopRunning()
        })
    }
    
    private func startScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.startRunning()
        })
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !hasScanned {
            guard metadataObjects.count > 0, let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject, machineReadableCode.type == AVMetadataObject.ObjectType.qr, let stringURL = machineReadableCode.stringValue else {
                
                return
            }
            
            guard stringURL != lastRejected else { return }
            
            hasScanned = true
            DispatchQueue.main.async { [weak self] in
                self?.flashBrackets()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
                        
            process(text: stringURL)
        }
    }
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        guard let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage,
            let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh]),
            let ciImage:CIImage = CIImage(image:pickedImage),
            let features = detector.features(in: ciImage) as? [CIQRCodeFeature],
            !features.isEmpty else {
            
            picker.dismiss(animated: true) { [weak self] in
                self?.reject("", message: "No QR code found in that image.")
            }
            return
        }
        
        var qrCodeLink = ""
        
        for feature in features {
            qrCodeLink += feature.messageString!
        }
        
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            AudioServicesPlaySystemSound(1103)
        }
        
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            
            self.process(text: qrCodeLink)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        // Back to the camera rather than closing the scanner.
        picker.dismiss(animated: true)
    }
    
}

extension DispatchQueue {

    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                    completion()
            }
        }
    }
}

extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: UINavigationControllerDelegate {}
