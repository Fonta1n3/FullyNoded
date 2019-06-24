//
//  SignRawViewController.swift
//  BitSense
//
//  Created by Peter on 05/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SignRawViewController: UIViewController, UITextFieldDelegate {
    
    var isTorchOn = Bool()
    var rawTxSigned = ""
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var activeNode = [String:Any]()
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var scannerShowing = false
    var isFirstTime = Bool()
    var blurArray = [UIVisualEffectView]()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    let qrGenerator = QRGenerator()
    let scanner = QRScanner()
    let creatingView = ConnectingView()
    let rawDisplayer = RawDisplayer()
    
    var isTestnet = Bool()
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var unsignedTextView: UITextView!
    @IBOutlet var privateKeyField: UITextField!
    
    @IBAction func signNow(_ sender: Any) {
        
        print("signNow")
        
        if privateKeyField.text != "" && unsignedTextView.text != "" {
            
            signWithKey(key: privateKeyField.text!,
                        tx: unsignedTextView.text!)
            
        } else if privateKeyField.text == "" && unsignedTextView.text != "" {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransaction,
                                  param: unsignedTextView.text!)
            
        } else if unsignedTextView.text == "" {
            
            shakeAlert(viewToShake: unsignedTextView)
            
        }
        
    }
    
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @IBAction func scanNow(_ sender: Any) {
        
        print("scan now")
        scan()
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        imageView.isUserInteractionEnabled = true
        imageView.alpha = 0
        
        configureScanner()
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        scanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        scanner.keepRunning = true
        scanner.vc = self
        scanner.imageView = imageView
        scanner.textField.alpha = 0
        
        scanner.completion = { self.getQRCode() }
        scanner.didChooseImage = { self.didPickImage() }
        
        scanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        scanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        scanner.closeButton.addTarget(self,
                                        action: #selector(closeScanner),
                                        for: .touchUpInside)
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.torchButton)
        
    }
    
    @objc func closeScanner() {
        print("back")
        
        DispatchQueue.main.async {
            
            for blur in self.blurArray{
                
                blur.removeFromSuperview()
                
            }
            
            self.imageView.alpha = 0
            self.scannerShowing = false
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        unsignedTextView.resignFirstResponder()
        privateKeyField.resignFirstResponder()
        
    }
    
    func scan() {
        
        scannerShowing = true
        privateKeyField.resignFirstResponder()
        unsignedTextView.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.scanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.scanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        } else {
            
            self.scanner.startScanner()
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        blurArray.append(blur)
        
    }
    
    func signWithKey(key: String, tx: String) {
        
        let aes = AESService()
        var rpcuser = "bitcoin"
        var rpcpassword = "password"
        var port = "8332"
        
        if isTestnet {
            
            port = "18332"
            
        }
        
        //delete!!!!
        //port = "18443"
        
        if activeNode["rpcuser"] != nil {
            
            let enc = activeNode["rpcuser"] as! String
            rpcuser = aes.decryptKey(keyToDecrypt: enc)
            
        }
        
        if activeNode["rpcpassword"] != nil {
            
            let enc = activeNode["rpcpassword"] as! String
            rpcpassword = aes.decryptKey(keyToDecrypt: enc)
            
        }
        
        if activeNode["rpcport"] != nil {
            
            let enc = activeNode["rpcport"] as! String
            port = aes.decryptKey(keyToDecrypt: enc)
            
        }
        
        let command = "curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"signrawtransactionwithkey\", \"params\":[\"\(tx)\", [\"\(key)\"]] }' -H 'content-type: text/plain;' http://\(rpcuser):\(rpcpassword)@127.0.0.1:\(port)/"
        
        var error: NSError?
        
        let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
        queue.async {
            
            if let responseString = self.ssh.session?.channel.execute(command, error: &error) {
                
                guard let responseData = responseString.data(using: .utf8) else { return }
                
                do {
                    
                    let json = try JSONSerialization.jsonObject(with: responseData, options: [.allowFragments]) as! NSDictionary
                    
                    if let result = json["result"] as? NSDictionary {
                        
                        print("result = \(result)")
                        
                        let completion = result["complete"] as! Bool
                        
                        if !completion {
                            
                            if let errors = result["errors"] as? NSArray {
                                
                                var errorArray = [String]()
                                
                                if errors.count > 0 {
                                    
                                    for err in errors {
                                        
                                        let er = err as! NSDictionary
                                        let descriptor = er["error"] as! String
                                        errorArray.append(descriptor)
                                        
                                    }
                                    
                                    displayAlert(viewController: self,
                                                 isError: true,
                                                 message: errorArray.description)
                                    
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: self,
                                             isError: true,
                                             message: "Error")
                                
                            }
                            
                        } else {
                            
                            let hex = result["hex"] as! String
                            self.showRaw(raw: hex)
                            
                        }
                        
                    }
                    
                } catch {
                    
                    
                }
                
            }
            
        }
        
    }
    
    func getQRCode() {
        
        let stringURL = scanner.stringToReturn
        parseText(text: stringURL)
        closeScanner()
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        scanner.chooseQRCodeFromLibrary()
        
    }
    
    func didPickImage() {
        
        let qrString = scanner.qrString
        parseText(text: qrString)
        closeScanner()
        
    }
    
    func parseText(text: String) {
        
        switch text {
            
        case _ where text.hasPrefix("l"),
             _ where text.hasPrefix("5"),
             _ where text.hasPrefix("9"),
             _ where text.hasPrefix("c"):
            
            DispatchQueue.main.async {
                
                self.privateKeyField.text = text
                
            }
            
        case _ where text.hasPrefix(""):
            
            DispatchQueue.main.async {
                
                self.unsignedTextView.text = text
                
            }
            
        default:
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "That is not an unsigned transaction or a private key")
            
        }
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            scanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            scanner.toggleTorch(on: true)
            isTorchOn = true
            
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
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let decodedTx = makeSSHCall.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                case BTC_CLI_COMMAND.signrawtransaction:
                    
                    let dict = makeSSHCall.dictToReturn
                    let complete = dict["complete"] as! Bool
                    
                    if complete {
                        
                        let hex = dict["hex"] as! String
                        self.showRaw(raw: hex)
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "Error")
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.creatingView.removeConnectingView()
                    
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
            
            creatingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    
    func getSmartFee() {
        
        let getSmartFee = GetSmartFee()
        getSmartFee.rawSigned = rawTxSigned
        getSmartFee.ssh = ssh
        getSmartFee.makeSSHCall = makeSSHCall
        getSmartFee.vc = self
        getSmartFee.getSmartFee()
        
    }
    
    @objc func close() {
        print("close")
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    func showRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.rawString = raw
            self.rawTxSigned = raw
            self.rawDisplayer.vc = self
            
            self.rawDisplayer.decodeButton.addTarget(self,
                                                     action: #selector(self.decode),
                                                     for: .touchUpInside)
            
            self.rawDisplayer.closeButton.addTarget(self,
                                                    action: #selector(self.close),
                                                    for: .touchUpInside)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                       action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                             action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            let newView = UIView()
            newView.backgroundColor = self.view.backgroundColor
            newView.frame = self.view.frame
            self.view.addSubview(newView)
            self.scanner.removeFromSuperview()
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    @objc func decode() {
        
        print("decode")
        
        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.decoderawtransaction,
                                   param: "\"\(self.rawTxSigned)\"")
        
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
            
            self.qrGenerator.textInput = self.rawDisplayer.rawString
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
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.rawDisplayer.rawString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func encodeText() {
        print("encodeText")
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = self.rawTxSigned
            self.rawDisplayer.decodeButton.setTitle("Decode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.encodeText),
                                                        for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                     for: .touchUpInside)
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        textField.endEditing(true)
        return true
        
    }

}
