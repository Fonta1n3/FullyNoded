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
    var isBbqr = false
    var isUR = false
    
    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts: [String] = []
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
        
        #if DEBUG
        print("psbt: \(psbt)")
        print("text: \(text)")
        print("txn: \(txn)")
        #endif
        
        
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
            
        } else if isUR {
            spinner.addConnectingView(vc: self, description: "loading...")
            
            if psbt != "" {
                guard let data = Data(base64Encoded: psbt) else {
                    spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "Unable to convert base64 text to data.")
                    return
                }
                
                guard let psbtUr = URHelper.psbtUr(data) else {
                    spinner.removeConnectingView()
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
            spinner.addConnectingView(vc: self, description: "loading...")
            
            guard let ur = URHelper.ur(text == "" ? psbt : text) else { return }
                
            animateUr(ur: ur)
            
        } else if txn != "" {
            imageView.image = qR(text: txn)
            
        } else if text != "" {
            imageView.image = qR(text: text)
        }
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
    
    
    func split(string: String) throws -> [String] {
        var data: Data? = nil
        var fileType: FileType = .unicodeText
        
        if psbt != "" {
            data = Data(base64Encoded: string)!
            fileType = .psbt
        }
        
        if txn != "" {
            guard let hexData = hex_decode(string) else { return []}
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
        
        guard let data = data else { return [] }

        let split = try Split.tryFromData(bytes: data, fileType: fileType, options: options)
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
        if encoder.isSinglePart {
            spinner.removeConnectingView()
            showQR(ur.qrString)
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                
                let part = encoder.nextPart()
                let index = encoder.seqNum
                
                if index <= encoder.seqLen {
                    self.parts.append(part.uppercased())
                } else {
                    self.spinner.removeConnectingView()
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
