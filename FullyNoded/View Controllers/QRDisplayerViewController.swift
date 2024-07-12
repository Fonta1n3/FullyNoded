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
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var headerText = ""
    var descriptionText = ""
    var headerIcon: UIImage!
    var spinner = ConnectingView()
    let qrGenerator = QRGenerator()
    var isPaying = false
    var isBbqr = false
    
    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts = [String]()
    private var ur: UR!
    private var partIndex = 0
    
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
        tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(shareQRCode(_:)))
        imageView.addGestureRecognizer(tapQRGesture)
        
        
        if isBbqr {
            spinner.addConnectingView(vc: self, description: "loading...")
            
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
            
        } else if psbt.lowercased().hasPrefix("ur:") || text.lowercased().hasPrefix("ur:") {
            spinner.addConnectingView(vc: self, description: "loading...")
            
            guard let ur = URHelper.ur(text == "" ? psbt : text) else { return }
                
            animateUr(ur: ur)
            spinner.removeConnectingView()
            
        } else if txn != "" {
            imageView.image = qR(text: txn)
            
        } else if text != "" {
            imageView.image = qR(text: text)
        }
    }
    
    
    func split(string: String) throws -> [String] {
        let large = Data(string.utf8)
        var minSplitNumber: UInt16 = 1
        minSplitNumber = UInt16((Double(string.count) / 250.0))
        
        let options = SplitOptions(
            encoding: Encoding.zlib,
            minSplitNumber: minSplitNumber,
            minVersion: Version.v01,
            maxVersion: Version.v40
        )
        
        var fileType: FileType = .unicodeText
        
        if psbt != "" {
            fileType = .psbt
        }
        
        if txn != "" {
            fileType = .transaction
        }

        let split = try Split.tryFromData(bytes: large, fileType: fileType, options: options)
        spinner.removeConnectingView()

        return split.parts()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func qR(text: String) -> UIImage {
        qrGenerator.textInput = text
        return qrGenerator.getQRCode()
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        let objectsToShare = [imageView.image]
        let activityController = UIActivityViewController(activityItems: objectsToShare as [Any], applicationActivities: nil)
        if UIDevice.current.userInterfaceIdiom == .pad {
            activityController.popoverPresentationController?.sourceView = self.view
            activityController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
        }
        self.present(activityController, animated: true) {}
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
        qrGenerator.textInput = string
        imageView.image = qrGenerator.getQRCode()
    }
    
    private func animateUr(ur: UR) {
        let encoder = UREncoder(ur, maxFragmentLen: 250)
        weak var timer: Timer?
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let part = encoder.nextPart()
            let index = encoder.seqNum
            
            if index <= encoder.seqLen {
                self.parts.append(part.uppercased())
            } else {
                self.spinner.removeConnectingView()
                timer?.invalidate()
                timer = Timer.scheduledTimer(timeInterval: 0.4, target: self, selector: #selector(self.animate), userInfo: nil, repeats: true)
            }
        }
    }
    
    private func showBbqrParts(bbQrparts: [String]) {
        let _ = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
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
