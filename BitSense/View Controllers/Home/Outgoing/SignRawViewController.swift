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
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    
    let qrGenerator = QRGenerator()
    let scanner = QRScanner()
    let creatingView = ConnectingView()
    let rawDisplayer = RawDisplayer()
    
    var scanningKey = Bool()
    var keyToSignWith = ""
    
    var isTestnet = Bool()
    
    @IBOutlet var imageView: UIImageView!
    
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @IBOutlet var keyButton: UIBarButtonItem!
    
    @IBAction func getKey(_ sender: Any) {
        
        let impact = UIImpactFeedbackGenerator()
        
        if !scanningKey {
            
            if UserDefaults.standard.object(forKey: "rpcuser") == nil {
                
                DispatchQueue.main.async {
                    
                    let alert = UIAlertController(title: "Alert", message: "You have not set an RPC password yet in settings, in order to sign your raw tx with a private key outside of the node you need to input your rpcuser and rpcpassword in Fully Noded settings.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                    self.present(alert, animated: true, completion: nil)
                    
                }
                
            } else {
                
                scanningKey = true
                
                DispatchQueue.main.async {
                    
                    impact.impactOccurred()
                    
                    self.keyButton.image = UIImage(named: "MinusKey")
                    
                    self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a key to sign with",
                                                                                      attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
            }
            
        } else {
            
            scanningKey = false
            
            DispatchQueue.main.async {
                
                impact.impactOccurred()
                
                self.keyButton.image = UIImage(named: "Key")
                
                self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a raw tx to sign",
                                                                                  attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
        }
        
   }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        scanningKey = false
        
        scanner.textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)

        scanner.uploadButton.addTarget(self,
                                       action: #selector(chooseQRCodeFromLibrary),
                                       for: .touchUpInside)
        
        scanner.torchButton.addTarget(self,
                                      action: #selector(toggleTorch),
                                      for: .touchUpInside)
        
        scanner.imageView = imageView
        scanner.keepRunning = true
        scanner.vc = self
        scanner.textFieldPlaceholder = "scan or paste an unsigned tx"
        scanner.completion = { self.getQRCode() }
        scanner.didChooseImage = { self.didPickImage() }
        
        imageView.isUserInteractionEnabled = true
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 20,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        scan()
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        scanner.textField.resignFirstResponder()
        
    }
    
    func scan() {
        
        DispatchQueue.main.async {
            
            self.scanner.scanQRCode()
            self.addScannerButtons()
            self.imageView.addSubview(self.blurView)
            self.blurView.contentView.addSubview(self.scanner.textField)
            
        }
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView()
        blur.effect = UIBlurEffect(style: UIBlurEffectStyle.dark)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        
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
    
    func signWithKey(key: String, tx: String) {
        
        let userDefaults = UserDefaults.standard
        var rpcuser = "bitcoin"
        var rpcpassword = "password"
        var port = "8332"
        
        if isTestnet {
            
            port = "18332"
            
        }
        
        //delete!!!!
        //port = "18443"
        
        if userDefaults.string(forKey: "rpcuser") != nil {
            
            rpcuser = userDefaults.string(forKey: "rpcuser")!
            
        }
        
        if userDefaults.string(forKey: "rpcpassword") != nil {
            
            rpcpassword = userDefaults.string(forKey: "rpcpassword")!
            
        }
        
        if userDefaults.string(forKey: "rpcport") != nil {
            
            port = userDefaults.string(forKey: "rpcport")!
            
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
                                
                                DispatchQueue.main.async {
                                    
                                    self.keyToSignWith = ""
                                    
                                    self.keyButton.image = UIImage(named: "MinusKey")
                                    
                                    self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a key to sign with",
                                                                                                      attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                                    
                                }
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Error")
                            
                        }
                        
                    } else {
                        
                        self.keyToSignWith = ""
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
        
        if !scanningKey {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransaction,
                                  param: "\'\(stringURL)\'")
            
        } else {
            
            if keyToSignWith == "" {
                
                self.scanningKey = false
                
                keyToSignWith = stringURL
                
                DispatchQueue.main.async {
                    
                    self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a raw tx to sign",
                                                                                      attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
            } else {
                
                signWithKey(key: keyToSignWith, tx: stringURL)
                
            }
            
        }
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        scanner.chooseQRCodeFromLibrary()
        
    }
    
    func didPickImage() {
        
        let qrString = scanner.qrString
        
        if !scanningKey {
            
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransaction,
                                  param: "\'\(qrString)\'")
            
        } else {
            
            if keyToSignWith == "" {
                
                self.scanningKey = false
                
                keyToSignWith = qrString
                
                DispatchQueue.main.async {
                    
                    self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a raw tx to sign",
                                                                                      attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
            } else {
                
                signWithKey(key: keyToSignWith, tx: qrString)
                
            }
            
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
        
        textField.endEditing(true)
        
        return true
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        let txt = textField.text
        
        if txt != "" {
            
            if !scanningKey {
                
                executeNodeCommandSsh(method: BTC_CLI_COMMAND.signrawtransaction,
                                      param: "\'\(txt!)\'")
                
            } else {
                
                if keyToSignWith == "" {
                   
                    keyToSignWith = txt!
                    
                    DispatchQueue.main.async {
                        
                        self.scanningKey = false
                        
                        self.scanner.textField.attributedPlaceholder = NSAttributedString(string: "scan a raw tx to sign",
                                                                                          attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                        
                    }
                    
                }
                
            }
            
        } else {
            
            shakeAlert(viewToShake: textField)
            
        }
        
    }

}
