//
//  QRViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/30/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit
import URKit
import Bbqr

class QRViewController: UIViewController {
    
    // MARK: - Public Configuration
    var text: String = ""
    var psbt: String = ""
    var txn: String = ""
    var headerText: String = ""
    var descriptionText: String = ""
    var headerIcon: UIImage?
    
    // MARK: - Private Properties
    private let spinner = ConnectingView.shared
    private let qrGenerator = QRGenerator()
    private var isBbqr: Bool = false
    private var isUR: Bool = false
    
    private var encoder: UREncoder?
    private var timer: Timer?
    private var parts: [String] = []
    private var partIndex: Int = 0
    private var originalQrText: String = ""
    
    // MARK: - UI Elements
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 24
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.15
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let qrBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.separator.cgColor
        
        // Optional: subtle inner padding feel
        view.clipsToBounds = false
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.08
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 10
        
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let headerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        return stack
    }()
    
    private let headerIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .systemOrange
        iv.isHidden = true
        return iv
    }()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        button.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var copyButton = createActionButton(title: "Copy Text", systemImage: "doc.on.doc")
    private lazy var shareButton = createActionButton(title: "Share QR", systemImage: "square.and.arrow.up")
    
    private lazy var buttonsStackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [copyButton, shareButton])
        stack.axis = .horizontal
        stack.spacing = 20
        stack.distribution = .fillEqually
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    // MARK: - Init
    convenience init(
        text: String = "",
        psbt: String = "",
        txn: String = "",
        headerText: String = "",
        descriptionText: String = "",
        headerIcon: UIImage? = nil,
        isBbqr: Bool = false,
        isUR: Bool = false
    ) {
        self.init()
        self.text = text
        self.psbt = psbt
        self.txn = txn
        self.headerText = headerText
        self.descriptionText = descriptionText
        self.headerIcon = headerIcon
        self.isBbqr = isBbqr
        self.isUR = isUR
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        setupUI()
        configureContent()
        setupActions()
        startQRGeneration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cleanup()
    }
    
    private func cleanup() {
        text = ""
        psbt = ""
        txn = ""
        isBbqr = false
        isUR = false
        partIndex = 0
        parts.removeAll()
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.addSubview(containerView)
        view.addSubview(closeButton)
        
        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Create vertical stack for all content inside container
        let contentStack = UIStackView()
        contentStack.axis = .vertical
        contentStack.spacing = 32
        contentStack.alignment = .center
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(contentStack)
        
        // QR section
        qrBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        qrBackgroundView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Header section
        headerStackView.addArrangedSubview(headerIconView)
        headerStackView.addArrangedSubview(headerLabel)
        
        // Add to content stack in order
        contentStack.addArrangedSubview(headerStackView)
        contentStack.addArrangedSubview(qrBackgroundView)
        contentStack.addArrangedSubview(descriptionLabel)
        contentStack.addArrangedSubview(buttonsStackView) // buttons last
        
        // Constraints
        NSLayoutConstraint.activate([
            // Close button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Container card
            containerView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 20),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // Content stack fills container with padding
            contentStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 40),
            contentStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 40),
            contentStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
            contentStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -40),
            
            // QR background size
            qrBackgroundView.widthAnchor.constraint(equalTo: contentStack.widthAnchor, multiplier: 0.8),
            qrBackgroundView.heightAnchor.constraint(equalTo: qrBackgroundView.widthAnchor),
            
            // Image inset inside QR background
            imageView.topAnchor.constraint(equalTo: qrBackgroundView.topAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: qrBackgroundView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: qrBackgroundView.trailingAnchor, constant: -16),
            imageView.bottomAnchor.constraint(equalTo: qrBackgroundView.bottomAnchor, constant: -16),
            
            // Icon size
            headerIconView.widthAnchor.constraint(equalToConstant: 32),
            headerIconView.heightAnchor.constraint(equalToConstant: 32),
            
            // Buttons fixed height
            buttonsStackView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func createActionButton(title: String, systemImage: String) -> UIButton {
        let button = UIButton(type: .system)
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: systemImage)
        config.imagePadding = 8
        config.imagePlacement = .leading
        config.baseBackgroundColor = .systemBlue
        config.baseForegroundColor = .white
        config.cornerStyle = .large
        
        button.configuration = config
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        return button
    }
    
    private func configureContent() {
        headerLabel.text = headerText.isEmpty ? "Scan QR Code" : headerText
        descriptionLabel.text = descriptionText
        
        if let icon = headerIcon {
            headerIconView.image = icon.withRenderingMode(.alwaysTemplate)
            headerIconView.isHidden = false
        } else if let systemName = getSystemIconForContent() {
            headerIconView.image = UIImage(systemName: systemName)
            headerIconView.isHidden = false
        }
        
        originalQrText = txn.isEmpty ? (text.isEmpty ? psbt : text) : txn
    }
    
    private func getSystemIconForContent() -> String? {
        if !psbt.isEmpty { return "bitcoinsign.circle.fill" }
        if !txn.isEmpty { return "bitcoinsign.circle.fill" }
        if !text.isEmpty && text.lowercased().hasPrefix("bitcoin:") { return "bitcoinsign.circle.fill" }
        return "qrcode"
    }
    
    private func setupActions() {
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyQrTextToClipboard), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareQRCode), for: .touchUpInside)
    }
    
    private func split(string: String) throws -> [String] {
        var data: Data? = nil
        var fileType: FileType = .unicodeText
        
        if !psbt.isEmpty {
            data = Data(base64Encoded: psbt)
            fileType = .psbt
        }
        
        if !txn.isEmpty {
            if let hexData = Data(hexString: txn) {
                data = hexData
                fileType = .transaction
            }
        }
        
        if !text.isEmpty && data == nil {
            data = Data(text.utf8)
            fileType = .unicodeText
        }
        
        guard let data = data else {
            // Fallback: return single part if we can't determine type
            return [string.uppercased()]
        }
        
        let minSplitNumber = UInt16(max(1, ceil(Double(data.count) / 250.0)))
        
        let options = SplitOptions(
            encoding: .zlib,
            minSplitNumber: minSplitNumber,
            minVersion: .v01,
            maxVersion: .v40
        )
        
        do {
            let split = try Split.tryFromData(bytes: data, fileType: fileType, options: options)
            return split.parts()
        } catch {
            print("BBQR split failed: \(error)")
            // Fallback to single part
            return [string.uppercased()]
        }
    }
    
    private func showBbqrParts(bbQrparts: [String]) {
        parts = bbQrparts
        partIndex = 0
        spinner.dismiss()
        
        // Start animation timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.animate()
        }
        
        // Show first part immediately
        animate()
    }
    
    @objc private func animate() {
        guard !parts.isEmpty else { return }
        
        let currentPart = parts[partIndex]
        showQR(currentPart)
        
        partIndex = (partIndex + 1) % parts.count
    }

    private func showQR(_ string: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let qrImage = self?.qR(text: string)
            DispatchQueue.main.async {
                self?.imageView.image = qrImage
            }
        }
    }
    
    // MARK: - QR Generation & Actions (unchanged logic)
    private func startQRGeneration() {
        // ... your existing startQRGeneration(), showStaticQR(), animateUr(), showBbqrParts(), etc.
        // All logic remains exactly the same
        if isBbqr {
            spinner.show(vc: self, description: "")
            let input = txn.isEmpty ? (text.isEmpty ? psbt : text) : txn
            if let parts = try? split(string: input) {
                showBbqrParts(bbQrparts: parts)
            } else {
                spinner.dismiss()
                showStaticQR(from: input)
            }
        } else if isUR || psbt.lowercased().hasPrefix("ur:") || text.lowercased().hasPrefix("ur:") {
            spinner.show(vc: self, description: "loading...")
            let input = text.isEmpty ? psbt : text
            if let ur = URHelper.ur(input) {
                animateUr(ur: ur)
            } else {
                spinner.dismiss()
                showStaticQR(from: input)
            }
        } else {
            let content = txn.isEmpty ? (text.isEmpty ? psbt : text) : txn
            showStaticQR(from: content)
        }
    }
    
    private func animateUr(ur: UR) {
        encoder = UREncoder(ur, maxFragmentLen: 250)
        
        guard let encoder = encoder else {
            spinner.dismiss()
            showStaticQR(from: originalQrText)
            return
        }
        
        if encoder.isSinglePart {
            // Single part — show static QR
            spinner.dismiss()
            showQR(ur.qrString.uppercased())
        } else {
            // Multi-part — animate
            parts.removeAll()
            partIndex = 0
            
            // Start timer to cycle through parts
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let part = encoder.nextPart().uppercased()
                
                // First part: dismiss spinner and start animation
                if encoder.seqNum == 1 {
                    self.parts.append(part)
                    self.spinner.dismiss()
                    self.showQR(part)
                } else if encoder.seqNum <= encoder.seqLen {
                    self.parts.append(part)
                    self.showQR(part)
                }
                
                // Loop back to first part when done
                if encoder.seqNum == encoder.seqLen {
                    // Reset for seamless loop
                    self.encoder = UREncoder(ur, maxFragmentLen: 250)
                }
            }
        }
    }
    
    private func showStaticQR(from string: String) {
        DispatchQueue.global().async { [weak self] in
            let qrImage = self?.qR(text: string)
            DispatchQueue.main.async {
                self?.imageView.image = qrImage
            }
        }
    }
    
    private func qR(text: String) -> UIImage {
        qrGenerator.qrText = text
        return qrGenerator.getQRCode()
    }
    
    // Keep your existing animate(), animateUr(), showBbqrParts(), split(), etc.
    
    @objc private func closeAction() {
        dismiss(animated: true)
    }
    
    @objc private func copyQrTextToClipboard() {
        UIPasteboard.general.string = originalQrText
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
        
        // Optional: show subtle success
        let label = UILabel()
        label.text = "Copied!"
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .systemGreen
        label.alpha = 0
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: -20)
        ])
        
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.4, delay: 1.0, options: [], animations: {
                label.alpha = 0
            }) { _ in
                label.removeFromSuperview()
            }
        }
    }
    
    @objc private func shareQRCode() {
        let item: Any = parts.count == 1 ? (imageView.image ?? "") : originalQrText
        
        let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = shareButton
            activityVC.popoverPresentationController?.sourceRect = shareButton.bounds
        }
        
        present(activityVC, animated: true)
    }
}
