//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import SwiftKeychainWrapper
import AES256CBC
import EFQRCode

class InvoiceViewController: UIViewController, UITextFieldDelegate {
    
    var makeRPCCall:MakeRPCCall!
    var ssh:SSHService!
    var textToShareViaQRCode = String()
    let blurActivityIndicator = UIActivityIndicatorView()
    var isUsingSSH = Bool()
    var addressString = String()
    let label = UILabel()
    var qrCode = UIImage()
    let descriptionLabel = UILabel()
    var tapQRGesture = UITapGestureRecognizer()
    var tapAddressGesture = UITapGestureRecognizer()
    @IBOutlet var amountField: UITextField!
    @IBOutlet var labelField: UITextField!
    @IBOutlet var qrView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        labelField.delegate = self
        amountField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        labelField.addTarget(self, action: #selector(textFieldDidChange(_:)), for: .editingChanged)
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        showAddress()
        addDoneButtonOnKeyboard()
    }
    

   @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    func showAddress() {
        
        DispatchQueue.main.async {
            
            self.blurActivityIndicator.frame = CGRect(x: self.view.center.x - 25, y: self.view.center.y - 25, width: 50, height: 50)
            self.blurActivityIndicator.hidesWhenStopped = true
            self.blurActivityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.whiteLarge
            self.view.addSubview(self.blurActivityIndicator)
            
            let alert = UIAlertController(title: "Which Address Format?", message: "Create a new address", preferredStyle: UIAlertControllerStyle.actionSheet)
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Legacy", comment: ""), style: .default, handler: { (action) in
                
                self.blurActivityIndicator.startAnimating()
                
                if !self.isUsingSSH {
                    
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress, param: "\"\", \"legacy\"")
                    
                } else {
                    
                   self.getLegacyAddress(ssh: self.ssh)
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Segwit P2SH", comment: ""), style: .default, handler: { (action) in
                
                self.blurActivityIndicator.startAnimating()
                
                if !self.isUsingSSH {
                    
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress, param: "")
                    
                } else {
                    
                    self.getSegwitAddress(ssh: self.ssh)
                    
                }
                
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Segwit Bech32", comment: ""), style: .default, handler: { (action) in
                
                self.blurActivityIndicator.startAnimating()
                
                if !self.isUsingSSH {
                    
                    self.executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress, param: "\"\", \"bech32\"")
                    
                } else {
                    
                    self.getBech32Address(ssh: self.ssh)
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.15, animations: {
                        
                        
                    }) { _ in
                        
                        self.qrView.image = nil
                        self.qrView.removeFromSuperview()
                        self.label.text = ""
                        
                    }
                    
                }
                
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
            
        }
    }
    
    func getBech32Address(ssh: SSHService) {
        print("getBech32Address")
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
                
            ssh.executeStringResponse(command: BTC_CLI_COMMAND.getnewaddress, params: "\"\", \"bech32\"", response: { (result, error) in
                    
                if error != nil {
                        
                    print("error getbalance = \(String(describing: error))")
                        
                } else {
                        
                    if result != "" {
                            
                        DispatchQueue.main.async {
                                
                            self.blurActivityIndicator.stopAnimating()
                            self.addressString = result!
                            self.showAddress(address: result!)
                                
                        }
                            
                    }
                        
                }
                    
            })
                
        }
        
    }
    
    func getSegwitAddress(ssh: SSHService) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
                
            ssh.executeStringResponse(command: BTC_CLI_COMMAND.getnewaddress, params: "", response: { (result, error) in
                    
                if error != nil {
                        
                    print("error getbalance = \(String(describing: error))")
                        
                } else {
                        
                    if result != "" {
                            
                        DispatchQueue.main.async {
                                
                            self.blurActivityIndicator.stopAnimating()
                            self.addressString = result!
                            self.showAddress(address: result!)
                                
                        }
                            
                    }
                        
                }
                    
            })
                
        }
        
    }
    
    func getLegacyAddress(ssh:SSHService) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
                
            ssh.executeStringResponse(command: BTC_CLI_COMMAND.getnewaddress, params: "\"\", \"legacy\"", response: { (result, error) in
                    
                if error != nil {
                        
                    print("error getbalance = \(String(describing: error))")
                        
                } else {
                        
                    if result != "" {
                        
                        DispatchQueue.main.async {
                                
                            self.blurActivityIndicator.stopAnimating()
                            self.addressString = result!
                            self.showAddress(address: result!)
                                
                        }
                            
                    }
                        
                }
                    
            })
                
        }
        
    }
    
    func showAddress(address: String) {
        
        self.qrCode = generateQrCode(key: address)
        
        qrView.image = self.qrCode
        qrView.isUserInteractionEnabled = true
        qrView.alpha = 0
        self.view.addSubview(qrView)
        
        descriptionLabel.frame = CGRect(x: 10, y: view.frame.maxY - 30, width: view.frame.width - 20, height: 20)
        descriptionLabel.textAlignment = .center
        descriptionLabel.font = UIFont.init(name: "HelveticaNeue-Light", size: 12)
        descriptionLabel.textColor = UIColor.white
        descriptionLabel.text = "Tap the QR Code or text to copy/save/share"
        descriptionLabel.adjustsFontSizeToFitWidth = true
        descriptionLabel.alpha = 0
        view.addSubview(self.descriptionLabel)
        
        label.removeFromSuperview()
        label.frame = CGRect(x: 10, y: qrView.frame.maxY + 50, width: view.frame.width - 20, height: 20)
        label.textAlignment = .center
        label.font = UIFont.init(name: "HelveticaNeue", size: 18)
        label.textColor = UIColor.white
        label.alpha = 0
        label.text = address
        label.isUserInteractionEnabled = true
        label.adjustsFontSizeToFitWidth = true
        view.addSubview(self.label)
        
        tapAddressGesture = UITapGestureRecognizer(target: self, action: #selector(shareAddressText(_:)))
        label.addGestureRecognizer(tapAddressGesture)
        
        tapQRGesture = UITapGestureRecognizer(target: self, action: #selector(shareQRCode(_:)))
        qrView.addGestureRecognizer(tapQRGesture)
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.descriptionLabel.alpha = 1
            self.qrView.alpha = 1
            self.label.alpha = 1
            
        }) { _ in
            
        }
        
    }
    
    @objc func shareAddressText(_ sender: UITapGestureRecognizer) {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.label.alpha = 0
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.label.alpha = 1
                
            })
            
        }
        
        DispatchQueue.main.async {
            
            let textToShare = [self.addressString]
            let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.qrView.alpha = 0
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.qrView.alpha = 1
                
            })
            
        }
        
        if self.textToShareViaQRCode == "" {
            
            self.textToShareViaQRCode = self.addressString
            
        }
        
        let cgImage = EFQRCode.generate(content: self.textToShareViaQRCode,
                                        size: EFIntSize.init(width: 256, height: 256),
                                        backgroundColor: UIColor.white.cgColor,
                                        foregroundColor: UIColor.black.cgColor,
                                        watermark: nil,
                                        watermarkMode: EFWatermarkMode.scaleAspectFit,
                                        inputCorrectionLevel: EFInputCorrectionLevel.h,
                                        icon: nil,
                                        iconSize: nil,
                                        allowTransparent: true,
                                        pointShape: EFPointShape.circle,
                                        mode: EFQRCodeMode.none,
                                        binarizationThreshold: 0,
                                        magnification: EFIntSize.init(width: 50, height: 50),
                                        foregroundPointOffset: 0)
        
        let qrImage = UIImage(cgImage: cgImage!)
        
        if let data = UIImagePNGRepresentation(qrImage) {
            
            let fileName = getDocumentsDirectory().appendingPathComponent("btc.png")
            try? data.write(to: fileName)
            let objectsToShare = [fileName]
            
            DispatchQueue.main.async {
                let activityController = UIActivityViewController(activityItems: objectsToShare, applicationActivities: nil)
                activityController.popoverPresentationController?.sourceView = self.view
                activityController.popoverPresentationController?.sourceView = self.view
                
                self.present(activityController, animated: true) {}
                
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        print("executeNodeCommand")
        
        func getResult() {
            
            if !makeRPCCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.getnewaddress:
                    
                    let address = makeRPCCall.stringToReturn
                        
                    DispatchQueue.main.async {
                            
                        self.blurActivityIndicator.stopAnimating()
                        self.addressString = address
                        self.showAddress(address: address)
                            
                    }
                        
                default:
                    
                    break
                    
                }
                
            } else {
                
                displayAlert(viewController: self, title: "Error", message: makeRPCCall.errorDescription)
                
            }
            
        }
        
        makeRPCCall.executeRPCCommand(method: method, param: param, completion: getResult)
        
    }
    
    @objc func textFieldDidChange(_ textField: UITextField) {
        print("textFieldDidChange")
        
        createBIP21Invoice()
        
    }
    
    func createBIP21Invoice() {
        print("createBIP21Invoice")
        
        updateQRImage()
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        let pic = UIImage(named: "bWhite.png")!
        let filter = CIFilter(name: "CISepiaTone")!
        filter.setValue(CIImage(image: pic), forKey: kCIInputImageKey)
        filter.setValue(1.0, forKey: kCIInputIntensityKey)
        let cgImage = EFQRCode.generate(content: key,
                                        size: EFIntSize.init(width: 256, height: 256),
                                        backgroundColor: UIColor.clear.cgColor,
                                        foregroundColor: UIColor.white.cgColor,
                                        watermark: nil,
                                        watermarkMode: EFWatermarkMode.scaleAspectFit,
                                        inputCorrectionLevel: EFInputCorrectionLevel.h,
                                        icon: nil,
                                        iconSize: nil,
                                        allowTransparent: true,
                                        pointShape: EFPointShape.circle,
                                        mode: EFQRCodeMode.none,
                                        binarizationThreshold: 0,
                                        magnification: EFIntSize.init(width: 50, height: 50),
                                        foregroundPointOffset: 0)
        
        let qrImage = UIImage(cgImage: cgImage!)
        
        return qrImage
        
    }
    
    func updateQRImage() {
        
        var newImage = UIImage()
        
        if self.amountField.text == "" && self.labelField.text == "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)"
            
        } else if self.amountField.text != "" && self.labelField.text != "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?amount=\(self.amountField.text!)?label=\(self.labelField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?amount=\(self.amountField.text!)?label=\(self.labelField.text!)"
            
        } else if self.amountField.text != "" && self.labelField.text == "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?amount=\(self.amountField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?amount=\(self.amountField.text!)"
            
        } else if self.amountField.text == "" && self.labelField.text != "" {
            
            newImage = self.generateQrCode(key:"bitcoin:\(self.addressString)?label=\(self.labelField.text!)")
            textToShareViaQRCode = "bitcoin:\(self.addressString)?label=\(self.labelField.text!)"
            
        }
        
        DispatchQueue.main.async {
            
            UIView.transition(with: self.qrView,
                              duration: 0.75,
                              options: .transitionCrossDissolve,
                              animations: { self.qrView.image = newImage },
                              completion: nil)
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
        }
        
    }
    
    @objc func doneButtonAction() {
        
        self.amountField.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        view.endEditing(true)
        return false
        
    }
    
    func addDoneButtonOnKeyboard() {
        
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 50))
        doneToolbar.barStyle = UIBarStyle.default
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(doneButtonAction))
        
        let items = NSMutableArray()
        items.add(flexSpace)
        items.add(done)
        
        doneToolbar.items = (items as! [UIBarButtonItem])
        doneToolbar.sizeToFit()
        
        self.amountField.inputAccessoryView = doneToolbar
        
    }
    
    @objc func dismissKeyboard() {
        
        view.endEditing(true)
        
    }

}
