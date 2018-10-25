//
//  ReceiveViewController.swift
//  BitSense
//
//  Created by Peter on 09/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import AES256CBC

class ReceiveViewController: UIViewController, UIGestureRecognizerDelegate {
    
    enum BTC_CLI_COMMAND: String {
        case getnewaddress = "getnewaddress"
    }
    
    var addressString = String()
    var qrCode = UIImage()
    let label = UILabel()
    let subview = UIView()
    let backButton = UIButton()
    let segwitButton = UIButton()
    let legacyButton = UIButton()
    let bech32Button = UIButton()
    var activityIndicator:UIActivityIndicatorView!
    var tapQRGesture = UITapGestureRecognizer()
    var tapAddressGesture = UITapGestureRecognizer()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("ReceiveViewController")
        view.backgroundColor = UIColor.black
        activityIndicator = UIActivityIndicatorView(frame: CGRect(x: self.view.center.x - 25, y: self.view.center.y - 25, width: 50, height: 50))
        activityIndicator.hidesWhenStopped = true
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.whiteLarge
        activityIndicator.isUserInteractionEnabled = true
        view.addSubview(self.activityIndicator)
        addButtons()
        
    }

    func addButtons() {
        
        DispatchQueue.main.async {
            
            self.backButton.removeFromSuperview()
            self.backButton.frame = CGRect(x: 20, y: 20, width: 30, height: 30)
            self.backButton.showsTouchWhenHighlighted = true
            self.backButton.setImage(#imageLiteral(resourceName: "back.png"), for: .normal)
            self.backButton.addTarget(self, action: #selector(self.goBack), for: .touchUpInside)
            self.view.addSubview(self.backButton)
            
            self.bech32Button.removeFromSuperview()
            self.bech32Button.frame = CGRect(x: 50, y: self.view.center.y, width: self.view.frame.width - 100, height: 35)
            self.bech32Button.showsTouchWhenHighlighted = true
            self.bech32Button.backgroundColor = UIColor.darkGray
            self.bech32Button.layer.cornerRadius = 10
            self.bech32Button.setTitleColor(UIColor.white, for: .normal)
            self.bech32Button.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Light", size: 20)
            self.bech32Button.titleLabel?.textAlignment = .center
            self.bech32Button.setTitle("Segwit Bech32 Address", for: .normal)
            self.bech32Button.addTarget(self, action: #selector(self.getBech32Address), for: .touchUpInside)
            self.view.addSubview(self.bech32Button)
            
            self.segwitButton.removeFromSuperview()
            self.segwitButton.frame = CGRect(x: 50, y: self.bech32Button.frame.minY - 105, width: self.view.frame.width - 100, height: 35)
            self.segwitButton.showsTouchWhenHighlighted = true
            self.segwitButton.backgroundColor = UIColor.darkGray
            self.segwitButton.layer.cornerRadius = 10
            self.segwitButton.setTitleColor(UIColor.white, for: .normal)
            self.segwitButton.setTitle("Segwit P2SH Address", for: .normal)
            self.segwitButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Light", size: 20)
            self.segwitButton.titleLabel?.textAlignment = .center
            self.segwitButton.addTarget(self, action: #selector(self.getSegwitAddress), for: .touchUpInside)
            self.view.addSubview(self.segwitButton)
            
            self.legacyButton.removeFromSuperview()
            self.legacyButton.frame = CGRect(x: 50, y: self.segwitButton.frame.minY - 105, width: self.view.frame.width - 100, height: 35)
            self.legacyButton.backgroundColor = UIColor.darkGray
            self.legacyButton.layer.cornerRadius = 10
            self.legacyButton.showsTouchWhenHighlighted = true
            self.legacyButton.setTitleColor(UIColor.white, for: .normal)
            self.legacyButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Light", size: 20)
            self.legacyButton.titleLabel?.textAlignment = .center
            self.legacyButton.setTitle("Legacy Address", for: .normal)
            self.legacyButton.addTarget(self, action: #selector(self.getLegacyAddress), for: .touchUpInside)
            self.view.addSubview(self.legacyButton)
            
        }
        
    }
    
    @objc func getBech32Address() {
        
        DispatchQueue.main.async {
            self.activityIndicator.startAnimating()
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress.rawValue, param: "\"\", \"bech32\"")
        }
        
    }
    
    @objc func getSegwitAddress() {
        
        activityIndicator.startAnimating()
        self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress.rawValue, param: "")
        
    }
    
    @objc func getLegacyAddress() {
        
        activityIndicator.startAnimating()
        self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress.rawValue, param: "\"\", \"legacy\"")
        
    }
    
    @objc func goBack() {
        
        self.dismiss(animated: true, completion: nil)
        
    }
    
    func executeNodeCommand(method: String, param: Any) {
        
        func decrypt(item: String) -> String {
            
            var decrypted = ""
            if let password = KeychainWrapper.standard.string(forKey: "AESPassword") {
                if let decryptedCheck = AES256CBC.decryptString(item, password: password) {
                    decrypted = decryptedCheck
                }
            }
            return decrypted
        }
        
        let nodeUsername = decrypt(item: KeychainWrapper.standard.string(forKey: "NodeUsername")!)
        let nodePassword = decrypt(item: KeychainWrapper.standard.string(forKey: "NodePassword")!)
        let ip = decrypt(item: KeychainWrapper.standard.string(forKey: "NodeIPAddress")!)
        let port = decrypt(item: KeychainWrapper.standard.string(forKey: "NodePort")!)
        let url = URL(string: "http://\(nodeUsername):\(nodePassword)@\(ip):\(port)")
        var request = URLRequest(url: url!)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "POST"
        request.httpBody = "{\"jsonrpc\":\"1.0\",\"id\":\"curltest\",\"method\":\"\(method)\",\"params\":[\(param)]}".data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) -> Void in
            
            do {
                
                if error != nil {
                    
                    print("error = \(String(describing: error))")
                    
                } else {
                    
                    print("response = \(String(describing: response))")
                    
                    if let urlContent = data {
                        
                        do {
                            
                            let jsonAddressResult = try JSONSerialization.jsonObject(with: urlContent, options: JSONSerialization.ReadingOptions.mutableLeaves) as! NSDictionary
                            print("jsonAddressResult = \(jsonAddressResult)")
                            
                            if let errorCheck = jsonAddressResult["error"] as? NSDictionary {
                                
                                print("json error = \(errorCheck)")
                                self.removeSpinner()
                                
                            } else {
                                
                                if let resultCheck = jsonAddressResult["result"] as? Any {
                                    
                                    switch method {
                                        
                                    case BTC_CLI_COMMAND.getnewaddress.rawValue:
                                        
                                        if let address = resultCheck as? String {
                                            
                                            print("address = \(address)")
                                            
                                            DispatchQueue.main.async {
                                                self.removeSpinner()
                                                self.addressString = address
                                                self.showAddress(address: address)
                                            }
                                            
                                        }
                                        
                                    default: break
                                        
                                    }
                                    
                                } else {
                                    
                                    print("no results")
                                    self.removeSpinner()
                                    
                                }
                                
                            }
                            
                        } catch {
                            
                            print("error processing json")
                            self.removeSpinner()
                            
                        }
                    }
                }
            }
        }
        
        task.resume()
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.activityIndicator.stopAnimating()
            
        }
    }
    
    func showAddress(address: String) {
        
        subview.frame = CGRect(x: 10, y: 20, width: self.view.frame.width - 20, height: self.view.frame.height - 40)
        subview.layer.cornerRadius = 20
        subview.backgroundColor = UIColor.white
        subview.alpha = 0
        view.addSubview(subview)
        
        let backButton = UIButton()
        backButton.frame = CGRect(x: 20, y: 20, width: 25, height: 25)
        backButton.showsTouchWhenHighlighted = true
        backButton.setImage(#imageLiteral(resourceName: "blackClose.jpg"), for: .normal)
        backButton.addTarget(self, action: #selector(self.closeAddress), for: .touchUpInside)
        self.subview.addSubview(backButton)
        
        let ciContext = CIContext()
        let data = address.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let upScaledImage = filter.outputImage?.transformed(by: transform)
            let cgImage = ciContext.createCGImage(upScaledImage!, from: upScaledImage!.extent)
            self.qrCode = UIImage(cgImage: cgImage!)
        }
        
        let qrView = UIImageView(image: self.qrCode)
        qrView.isUserInteractionEnabled = true
        qrView.frame = CGRect(x: 35, y: subview.frame.height / 6, width: subview.frame.width - 70, height: subview.frame.width - 70)
        qrView.alpha = 0
        self.subview.addSubview(qrView)
        
        let description = UILabel()
        description.frame = CGRect(x: self.subview.frame.minX - 10, y: self.subview.frame.maxY - 50, width: self.subview.frame.width - 20, height: 20)
        description.textAlignment = .center
        description.font = UIFont.init(name: "HelveticaNeue-Light", size: 15)
        description.textColor = UIColor.gray
        description.text = "Tap the QR Code or text to copy/save"
        description.alpha = 0
        self.subview.addSubview(description)
        
        label.removeFromSuperview()
        label.frame = CGRect(x: 10, y: qrView.frame.maxY + 50, width: subview.frame.width - 20, height: 50)
        label.textAlignment = .center
        label.font = UIFont.init(name: "HelveticaNeue-Bold", size: 18)
        label.textColor = UIColor.black
        label.alpha = 0
        label.text = address
        label.isUserInteractionEnabled = true
        label.adjustsFontSizeToFitWidth = true
        self.subview.addSubview(label)
        
        tapAddressGesture = UITapGestureRecognizer(target: self, action: #selector(shareAddressText(_:)))
        label.addGestureRecognizer(tapAddressGesture)
        
        tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(shareQRCode(_:)))
        qrView.addGestureRecognizer(tapQRGesture)
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.subview.alpha = 1
            qrView.alpha = 1
            self.label.alpha = 1
            description.alpha = 1
            
        }) { _ in
            
        }
        
    }
    
    @objc func closeAddress() {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.subview.alpha = 0
            
        }) { _ in
            
            self.label.text = ""
            self.subview.removeFromSuperview()
            
        }
        
    }
    
    @objc func shareAddressText(_ sender: UITapGestureRecognizer) {
        print("shareAddressText")
        
        DispatchQueue.main.async {
            let textToShare = [self.addressString]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            self.present(activityViewController, animated: true, completion: nil)
        }
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        if let data = UIImagePNGRepresentation(self.qrCode) {
            
            let fileName = getDocumentsDirectory().appendingPathComponent("bitcoinAddress.png")
            try? data.write(to: fileName)
            let objectsToShare = [fileName]
            
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                self.present(activityController, animated: true, completion: nil)
            }
            
        }
    }
    
    
}
