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
    
    // MARK: - Public Configuration Properties
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
    
    // MARK: - UI Elements (programmatic)
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.isUserInteractionEnabled = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.font = .systemFont(ofSize: 14)
        tv.textColor = .secondaryLabel
        tv.backgroundColor = .clear
        tv.textAlignment = .center
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .boldSystemFont(ofSize: 17)
        label.textAlignment = .center
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .label
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var buttonsStackView: UIStackView!
    
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
        view.backgroundColor = .systemBackground
        setupUI()
        configureContent()
        setupButtons()
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
        // Add subviews
        view.addSubview(headerLabel)
        view.addSubview(imageView)
        view.addSubview(textView)
        view.addSubview(closeButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 35),
            closeButton.heightAnchor.constraint(equalToConstant: 35),
            
            headerLabel.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            headerLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            imageView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            
            textView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 20),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
        
        closeButton.addTarget(self, action: #selector(closeAction), for: .touchUpInside)
    }
    
    private func configureContent() {
        headerLabel.text = headerText
        textView.text = descriptionText
        originalQrText = txn.isEmpty ? (text.isEmpty ? psbt : text) : txn
    }
    
    private func setupButtons() {
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy Text", for: .normal)
        copyButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        copyButton.backgroundColor = .systemBlue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 10
        copyButton.addTarget(self, action: #selector(copyQrTextToClipboard), for: .touchUpInside)
        
        let shareButton = UIButton(type: .system)
        shareButton.setTitle("Share QR", for: .normal)
        shareButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        shareButton.backgroundColor = .systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 10
        shareButton.addTarget(self, action: #selector(shareQRCode), for: .touchUpInside)
        
        buttonsStackView = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 20
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(buttonsStackView)
        
        NSLayoutConstraint.activate([
            buttonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            buttonsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    // MARK: - QR Generation Logic
    private func startQRGeneration() {
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
            
        } else if !txn.isEmpty {
            showStaticQR(from: txn)
        } else if !text.isEmpty {
            showStaticQR(from: text)
        } else if !psbt.isEmpty {
            showStaticQR(from: psbt)
        }
    }
    
    private func showStaticQR(from string: String) {
        imageView.image = qR(text: string)
    }
    
    // MARK: - Actions
    @objc private func closeAction() {
        dismiss(animated: true, completion: nil)
    }
    
    @objc private func copyQrTextToClipboard() {
        UIPasteboard.general.string = originalQrText
        
        let alert = UIAlertController(title: "Copied!", message: "QR text copied to clipboard.", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    @objc private func shareQRCode() {
        guard let qrImage = imageView.image else { return }
        
        let activityVC = UIActivityViewController(activityItems: [qrImage], applicationActivities: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityVC.popoverPresentationController?.sourceView = buttonsStackView.arrangedSubviews.last
            activityVC.popoverPresentationController?.sourceRect = (buttonsStackView.arrangedSubviews.last?.bounds ?? .zero)
        }
        
        present(activityVC, animated: true)
    }
    
    // MARK: - QR Helpers (unchanged logic)
    private func qR(text: String) -> UIImage {
        qrGenerator.qrText = text
        return qrGenerator.getQRCode()
    }
    
    private func showQR(_ string: String) {
        qrGenerator.qrText = string
        imageView.image = qrGenerator.getQRCode()
    }
    
    @objc private func animate() {
        guard !parts.isEmpty else { return }
        showQR(parts[partIndex])
        partIndex = (partIndex + 1) % parts.count
    }
    
    private func animateUr(ur: UR) {
        encoder = UREncoder(ur, maxFragmentLen: 250)
        guard let encoder = encoder else { return }
        
        if encoder.isSinglePart {
            spinner.dismiss()
            showQR(ur.qrString)
        } else {
            parts.removeAll()
            partIndex = 0
            
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let part = encoder.nextPart().uppercased()
                if encoder.seqNum == 1 { // first part
                    self.parts.append(part)
                    self.spinner.dismiss()
                    self.animate()
                } else if encoder.seqNum <= encoder.seqLen {
                    self.parts.append(part)
                }
            }
        }
    }
    
    private func showBbqrParts(bbQrparts: [String]) {
        parts = bbQrparts
        partIndex = 0
        spinner.dismiss()
//        timer = Timer.scheduledTimer(timeInterval: 0.3, invocation: true) { [weak self] _ in
//            self?.animate()
//        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true, block: { [weak self] _ in
            self?.animate()
        })
    }
    
    // MARK: - Bbqr Split (unchanged)
    private func split(string: String) throws -> [String] {
        // ... (your existing split logic unchanged)
        // Just keep it as-is
        var data: Data? = nil
        var fileType: FileType = .unicodeText
        
        if !psbt.isEmpty {
            data = Data(base64Encoded: string)
            fileType = .psbt
        }
        
        if !txn.isEmpty {
            guard let hexData = hex_decode(string) else {
                spinner.dismiss()
                return [string]
            }
            data = Data(hexData)
            fileType = .transaction
        }
        
        if !text.isEmpty {
            data = Data(string.utf8)
        }
        
        let minSplitNumber = UInt16(max(1, ceil(Double(string.count) / 250.0)))
        
        let options = SplitOptions(
            encoding: .zlib,
            minSplitNumber: minSplitNumber,
            minVersion: .v01,
            maxVersion: .v40
        )
        
        guard let data = data else {
            spinner.dismiss()
            return [string]
        }
        
        do {
            let split = try Split.tryFromData(bytes: data, fileType: fileType, options: options)
            return split.parts()
        } catch {
            spinner.dismiss()
            return [string]
        }
    }
}
