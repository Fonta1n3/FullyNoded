//
//  QRDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import URKit

class QRDisplayerViewController: UIViewController {
    
    var text = ""
    var psbt = ""
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var headerText = ""
    var descriptionText = ""
    var headerIcon: UIImage!
    var spinner = ConnectingView()
    let qrGenerator = QRGenerator()
    var isPaying = false
    
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
        
        if psbt != "" {
            spinner.addConnectingView(vc: self, description: "loading QR parts...")
            imageView.isUserInteractionEnabled = false
            
            if psbt.hasPrefix("UR:BYTES") {
                convertBlindedPsbtToUrParts()
            } else {
                convertPsbtToUrParts()
            }
            
        } else if !isPaying {
            imageView.image = qR()
        }
        
        if isPaying {
            getPaymentAddress()
        }
    }
    
    private func getPaymentAddress() {
        guard let data = KeyChain.getData("paymentAddress") else {
            
            guard let paymentAddress = Keys.donationAddress() else { return }
            
            guard KeyChain.set(paymentAddress.dataUsingUTF8StringEncoding, forKey: "paymentAddress") else {
                return
            }
            
            getPaid(paymentAddress)
            
            return
        }
        
        let paymentAddress = data.utf8String ?? ""
        getPaid(paymentAddress)
    }
    
    private func getPaid(_ address: String) {
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self, let fxRate = fxRate else { return }
            
            let btcAmount = 1.0 / (fxRate / 20.0)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                                
                self.text = "bitcoin:\(address)?amount=\(btcAmount.avoidNotation)&label=FullyNoded-Payment"
                
                self.imageView.image = self.qR()
                
                self.spinner.removeConnectingView()
                
                showAlert(vc: self, title: "Thank you for supporting Fully Noded", message: "In order to use Fully Noded via direct download a donation of $20 in btc is suggested. You can scan this QR with any wallet to automatically pay the suggested amount, this address is unique to you and will not change, that way you can pay whenever you want.\n\nThe app has taken years of hard work, your support will help make Fully Noded even better ensuring its long term survival and evolution to be the best it can possibly be.\n\nOnce the payment is made you will have full lifetime access to the app.")
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                guard let self = self else { return }
                
                self.checkIfPaymentReceived(address)
            }
        }
    }
    
    private func checkIfPaymentReceived(_ address: String) {
        let blockstreamUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/address/" + address
        
        guard let url = URL(string: blockstreamUrl) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        let task = TorClient.sharedInstance.session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            guard let urlContent = data else {
                showAlert(vc: self, title: "Ooops", message: "There was an issue checking on payment status")
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as? NSDictionary else {
                showAlert(vc: self, title: "Ooops", message: "There was an issue decoding the response when fetching payment status")
                return
            }
            
            var txCount = 0
            
            if let chain_stats = json["chain_stats"] as? NSDictionary {
                guard let count = chain_stats["tx_count"] as? Int else { return }
                
                txCount += count
            }
            
            if let mempool_stats = json["mempool_stats"] as? NSDictionary {
                guard let count = mempool_stats["tx_count"] as? Int else { return }
                
                txCount += count
            }
            
            if txCount == 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self] in
                    guard let self = self else { return }
                    
                    self.checkIfPaymentReceived(address)
                }
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    let _ = KeyChain.set("hasPaid".dataUsingUTF8StringEncoding, forKey: "hasPaid")
                    
                    self.dismiss(animated: true) {
                        
                        showAlert(vc: self, title: "Thank you!", message: "Your support is greatly appreciated and will directly help making Fully Noded even better 💪")
                    }
                }
            }
        }
        
        task.resume()
    }
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }
    
    private func qR() -> UIImage {
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
    
    private func convertPsbtToUrParts() {
        guard let b64 = Data(base64Encoded: psbt), let ur = URHelper.psbtUr(b64) else { return }
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
    
    private func convertBlindedPsbtToUrParts() {
        guard let ur = try? UR(urString: psbt) else { return }
        
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
    
    

}
