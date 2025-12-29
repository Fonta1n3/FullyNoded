//
//  QRDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import URKit
import Bbqr

class QRDisplayerViewController: UIViewController {
    
    var text = ""
    var psbt = ""
    var txn = ""
    var headerText = ""
    var descriptionText = ""
    var headerIcon: UIImage!
    let spinner = ConnectingView.shared
    let qrGenerator = QRGenerator()
    var isBbqr = false
    var isUR = false
    
    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts: [String] = []
    private var ur: UR!
    private var partIndex = 0
    
    private var originalQrText = ""
    
    private var copyButton: UIButton!
    private var shareButton: UIButton!
    private var buttonsStackView: UIStackView!
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerImage: UIImageView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        headerLabel.text = headerText
        headerImage.image = headerIcon
        imageView.isUserInteractionEnabled = true
        textView.text = descriptionText
        originalQrText = txn != "" ? txn : (text != "" ? text : psbt)
        
        
        #if DEBUG
        print("psbt: \(psbt)")
        print("text: \(text)")
        print("txn: \(txn)")
        #endif
        
        
        if isBbqr {
            spinner.show(vc: self, description: "")
            
            var parts: [String]? = []
            
            if psbt != "" {
                parts = try? split(string: psbt)
            }
            
            if txn != "" {
                parts = try? split(string: txn)
            }
            
            if text != "" {
                parts = try? split(string: text)
            }
            
            if let parts = parts {
                showBbqrParts(bbQrparts: parts)
            }
            
        } else if isUR {
            spinner.show(vc: self, description: "loading...")
            
            if psbt != "" {
                guard let data = Data(base64Encoded: psbt) else {
                    spinner.dismiss()
                    showAlert(vc: self, title: "", message: "Unable to convert base64 text to data.")
                    return
                }
                
                guard let psbtUr = URHelper.psbtUr(data) else {
                    spinner.dismiss()
                    showAlert(vc: self, title: "", message: "Unable to convert to ur:crypto-psbt QR.")
                    return
                }
                
                animateUr(ur: psbtUr)
                                                   
            } else {
                if text.lowercased().hasPrefix("ur:") {
                    guard let ur = URHelper.ur(text) else { return }
                    
                    animateUr(ur: ur)
                }
            }
        } else if psbt.lowercased().hasPrefix("ur:") || text.lowercased().hasPrefix("ur:") {
            spinner.show(vc: self, description: "loading...")
            
            guard let ur = URHelper.ur(text == "" ? psbt : text) else { return }
                
            animateUr(ur: ur)
            
        } else if txn != "" {
            imageView.image = qR(text: txn)
            
        } else if text != "" {
            imageView.image = qR(text: text)
        }
        
        createButtonsStackView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        text = ""
        psbt = ""
        txn = ""
        isBbqr = false
        isUR = false
        partIndex = 0
        parts.removeAll()
        headerText = ""
        descriptionText = ""
        timer?.invalidate()
    }
    
    private func createButtonsStackView() {
        // Create the two buttons
        copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy Text", for: .normal)
        copyButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        copyButton.backgroundColor = UIColor.systemBlue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 10
        copyButton.addTarget(self, action: #selector(copyQrTextToClipboard), for: .touchUpInside)
        
        shareButton = UIButton(type: .system)
        shareButton.setTitle("Share QR", for: .normal)
        shareButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        shareButton.backgroundColor = UIColor.systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 10
        shareButton.addTarget(self, action: #selector(shareQRCode), for: .touchUpInside)
        
        // Create the stack view
        buttonsStackView = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 20
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add to view hierarchy
        view.addSubview(buttonsStackView)
        
        // Constraints: place it below the QR image with safe margins
        NSLayoutConstraint.activate([
            buttonsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            buttonsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            buttonsStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    @objc private func copyQrTextToClipboard() {
        UIPasteboard.general.string = originalQrText
        
        // Feedback
        let alert = UIAlertController(title: "Copied!", message: "QR text copied to clipboard.", preferredStyle: .alert)
        present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            alert.dismiss(animated: true)
        }
    }
    
    @objc private func shareQRCode() {
        guard let qrImage = imageView.image else { return }
        
        let activityController = UIActivityViewController(activityItems: [qrImage], applicationActivities: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityController.popoverPresentationController?.sourceView = shareButton
            activityController.popoverPresentationController?.sourceRect = shareButton.bounds
        }
        
        present(activityController, animated: true)
    }
    
    func split(string: String) throws -> [String] {
        var data: Data? = nil
        var fileType: FileType = .unicodeText
        
        if psbt != "" {
            data = Data(base64Encoded: string)
            fileType = .psbt
        }
        
        if txn != "" {
            guard let hexData = hex_decode(string) else {
                spinner.dismiss()
                return [string]
            }
            data = Data(hexData)
            fileType = .transaction
        }
        
        if text != "" {
            data = Data(string.utf8)
        }
        
        var minSplitNumber: UInt16 = 1
        minSplitNumber = UInt16((Double(string.count) / 250.0))
        
        let options = SplitOptions(
            encoding: Encoding.zlib,
            minSplitNumber: minSplitNumber,
            minVersion: Version.v01,
            maxVersion: Version.v40
        )
        
        guard let data = data else {
            spinner.dismiss()
            return [string]
        }
        
        do {
            let split = try Split.tryFromData(bytes: data, fileType: fileType, options: options)
            spinner.dismiss()
            return split.parts()
        } catch {
            spinner.dismiss()
            return [string]
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func qR(text: String) -> UIImage {
        qrGenerator.qrText = text
        return qrGenerator.getQRCode()
    }
    
    @objc func animate() {
        showQR(parts[partIndex])
        
        if partIndex < parts.count - 1 {
            partIndex += 1
        } else {
            partIndex = 0
        }
    }
    
    private func showQR(_ string: String) {
        qrGenerator.qrText = string
        imageView.image = qrGenerator.getQRCode()
    }
    
    private func animateUr(ur: UR) {
        let encoder = UREncoder(ur, maxFragmentLen: 250)
        if encoder.isSinglePart {
            spinner.dismiss()
            showQR(ur.qrString)
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let part = encoder.nextPart()
                let index = encoder.seqNum
                
                if index <= encoder.seqLen {
                    self.parts.append(part.uppercased())
                } else {
                    self.spinner.dismiss()
                    self.animate()
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.animate), userInfo: nil, repeats: true)
                }
            }
        }        
    }
    
    private func showBbqrParts(bbQrparts: [String]) {
        #if DEBUG
        print("showBbqrParts: \(bbQrparts)")
        #endif
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if partIndex < bbQrparts.count {
                showQR(bbQrparts[partIndex])
                partIndex += 1
            } else {
                partIndex = 0
            }
        }
    }

}
