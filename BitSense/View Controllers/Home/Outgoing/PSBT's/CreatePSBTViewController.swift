//
//  CreatePSBTViewController.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class CreatePSBTViewController: UIViewController, UITextFieldDelegate {
    
    let addressParser = AddressParser()
    let qrScanner = QRScanner()
    let qrGenerator = QRGenerator()
    let rawDisplayer = RawDisplayer()
    let creatingView = ConnectingView()
    
    var activeNode = [String:Any]()
    var isFirstTime = Bool()
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var makeSSHCall:SSHelper!
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var scannerShowing = false
    var psbt = ""
    var amount = Double()
    var isSpendingFrom = Bool()
    var isReceiving = Bool()
    var isChange = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var receivingField: UITextField!
    @IBOutlet var amountField: UITextField!
    
    @IBAction func scanReceiving(_ sender: Any) {
        
        print("scanReceiving")
        isReceiving = true
        isSpendingFrom = false
        isChange = false
        scanNow()
        
    }
    
    @IBAction func goBack(_ sender: Any) {
        
        if !scannerShowing {
            
            DispatchQueue.main.async {
                
                self.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }
    
    @IBAction func createPSBT(_ sender: Any) {
        print("createPSBT")
        
        if receivingField.text != "" && amountField.text != "" {
            
            creatingView.addConnectingView(vc: self,
                                           description: "Creating PSBT")
            
            let output = "[{\"\(receivingField.text!)\":\(Double(amountField.text!)!)}]"
            let param = "[],\(output), 0, {\"includeWatching\": true}, true"
            
            executeNodeCommandSSH(method: BTC_CLI_COMMAND.walletcreatefundedpsbt,
                                  param: param)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Ooops, you need to fill out an amount and recipient address")
            
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        amountField.delegate = self
        receivingField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        
        configureScanner()
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.amountField.resignFirstResponder()
            self.receivingField.resignFirstResponder()
            
        }
        
    }
    
    func parseDecodedTx(decodedTx: NSDictionary) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = "\(decodedTx)"
            self.rawDisplayer.decodeButton.setTitle("Encode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.decode),
                                                        for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.encodeText),
                                                     for: .touchUpInside)
            
        }
        
    }
    
    @objc func encodeText() {
        print("encodeText")
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = self.psbt
            
            self.rawDisplayer.decodeButton.setTitle("Decode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.encodeText),
                                                        for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                     for: .touchUpInside)
            
        }
        
    }
    
    // MARK: SSH METHODS
    
    func executeNodeCommandSSH(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.decodepsbt:
                    
                    let decodedTx = makeSSHCall.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                case BTC_CLI_COMMAND.walletcreatefundedpsbt:
                    
                    self.creatingView.removeConnectingView()
                    let result = makeSSHCall.dictToReturn
                    let psbt = result["psbt"] as! String
                    self.displayRaw(raw: psbt)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh.session.isConnected {
            
            makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                          method: method,
                                          param: param,
                                          completion: getResult)
            
        } else {
            
            self.removeSpinner()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.creatingView.removeConnectingView()
            
        }
        
    }
    
    // MARK: QR SCANNER METHODS
    
    func scanNow() {
        print("scanNow")
        
        scannerShowing = true
        hideKeyboards()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.qrScanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textField.alpha = 0
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        
        qrScanner.closeButton.addTarget(self,
                                        action: #selector(back),
                                        for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.qrScanner.torchButton)
        
    }
    
    @objc func back() {
        print("back")
        
        DispatchQueue.main.async {
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        self.imageView.addSubview(blur)
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        parseAddress(address: stringURL)
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        parseAddress(address: qrString)
        
    }
    
    func parseAddress(address: String) {
        
        addressParser.url = address
        let address = addressParser.parseAddress(url: address).address
        let errorBool = addressParser.parseAddress(url: address).errorBool
        let errorDescription = addressParser.parseAddress(url: address).errorDescription
        
        if !errorBool {
            
            if isReceiving {
                
                DispatchQueue.main.async {
                    
                    self.back()
                    self.receivingField.text = address
                    print("update receiving")
                    
                }
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
        }
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @objc func decode() {
        
        self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.decodepsbt,
                                   param: "\"\(self.psbt)\"")
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.psbt]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.qrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.qrView.alpha = 1
                    
                })
                
            }
            
            self.qrGenerator.textInput = self.psbt
            self.qrGenerator.backColor = UIColor.white
            self.qrGenerator.foreColor = UIColor.black
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.completionWithItemsHandler = { (type,completed,items,error) in }
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    func displayRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.titleString = "PSBT"
            self.rawDisplayer.rawString = raw
            self.psbt = raw
            self.rawDisplayer.vc = self
            
            self.rawDisplayer.closeButton.addTarget(self, action: #selector(self.close), for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                     for: .touchUpInside)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                       action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                             action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.qrScanner.removeFromSuperview()
            self.imageView.removeFromSuperview()
            
            
            let backView = UIView()
            backView.frame = self.view.frame
            backView.backgroundColor = self.view.backgroundColor
            self.view.addSubview(backView)
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    // MARK: TEXTFIELD METHODS
    
    func hideKeyboards() {
        
        receivingField.resignFirstResponder()
        amountField.resignFirstResponder()
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        textField.endEditing(true)
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        print("textFieldDidEndEditing")
        
        if textField == receivingField && receivingField.text != "" && isReceiving {
            
            let address = receivingField.text!
            addressParser.url = address
            parseAddress(address: address)
            
        } else if textField == amountField && amountField.text != "" {
            
            if let amountCheck = Double(amountField.text!) {
                
                self.amount = amountCheck
                
            } else {
                
                amountField.text = ""
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Only valid numbers allowed")
                
            }
            
        } else {
            
            //shakeAlert(viewToShake: textField)
            
        }
        
    }


}
