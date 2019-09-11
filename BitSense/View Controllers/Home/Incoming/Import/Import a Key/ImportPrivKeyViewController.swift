//
//  ImportPrivKeyViewController.swift
//  BitSense
//
//  Created by Peter on 23/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportPrivKeyViewController: UIViewController, UITextFieldDelegate {
    
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var isPruned = Bool()
    @IBOutlet var qrView: UIImageView!
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let connectingView = ConnectingView()
    var isAddress = false
    
    var addToKeypool = Bool()
    var isInternal = Bool()
    var reScan = Bool()
    var importedKey = ""
    var label = ""
    var timestamp = Int()
    
    var dict = [String:Any]()
    
    var alertMessage = ""
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        return UIInterfaceOrientationMask.portrait
        
    }
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView()
        blur.effect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        qrScanner.textField.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 80,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        qrScanner.textFieldPlaceholder = "scan QR or type/paste here"
        qrScanner.keepRunning = false
        
        qrScanner.uploadButton.addTarget(self,
                               action: #selector(self.chooseQRCodeFromLibrary),
                               for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                              action: #selector(toggleTorch),
                              for: .touchUpInside)
        
        isTorchOn = false
        addScanner()
        getValues()
        
    }
    
    func getValues() {
     
        addToKeypool = dict["addToKeypool"] as? Bool ?? false
        isInternal = dict["addAsChange"] as? Bool ?? false
        timestamp = dict["rescanDate"] as? Int ?? 0
        label = dict["label"] as! String
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func addShadow(view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        
        view.layer.shadowOffset = CGSize(width: 1.5,
                                         height: 1.5)
        
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        if isTorchOn {
            
            toggleTorch()
            qrScanner.removeScanner()
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        qrScanner.textField.removeFromSuperview()
        blurView.removeFromSuperview()
        view.addSubview(blurView)
        blurView.contentView.addSubview(qrScanner.textField)
        
        addBlurView(frame: CGRect(x: view.frame.maxX - 80,
                                  y: qrView.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.uploadButton)
        
        addBlurView(frame: CGRect(x: 10,
                                  y: qrView.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.torchButton)
        
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
    
    func addScanner() {
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.keepRunning = false
        qrView.frame = view.frame
        qrScanner.imageView = qrView
        qrScanner.vc = self
        qrScanner.scanQRCode()
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
    }
    
    func importPublicKey(pubKey: String) {
        
        isAddress = false
     
        func getDescriptor() {
         
            let result = makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
             
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
             
                let descriptor = "\"\(result["descriptor"] as! String)\""
                
                var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
                
                if isInternal {
                    
                    params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": true }], ''{\"rescan\": true}''"
                    
                }
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                           param: params)
                
            }
            
        }
        
        makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                      method: BTC_CLI_COMMAND.getdescriptorinfo,
                                      param: "\"combo(\(pubKey))\"", completion: getDescriptor)
        
    }
    
    func parseKey(key: String) {
        
        importedKey = key
        
        qrScanner.textField.resignFirstResponder()
        
        func showError() {
            
            DispatchQueue.main.async {
                
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Invalid key!")
                
            }
            
        }
        
        if key != "" {
            
            var prefix = key.lowercased()
            
            prefix = prefix.replacingOccurrences(of: "bitcoin:",
                                                 with: "")
            
            switch prefix {
                
            case _ where prefix.hasPrefix("l"),
                 _ where prefix.hasPrefix("5"),
                 _ where prefix.hasPrefix("9"),
                 _ where prefix.hasPrefix("c"),
                 _ where prefix.hasPrefix("k"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Private Key")
                    
                }
                
                if self.ssh.session.isConnected {
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importprivkey,
                                               param: "\"\(key)\", \"\(label)\", false")
                    
                } else {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Not connected")
                    
                }
                
            case _ where prefix.hasPrefix("1"),
                 _ where prefix.hasPrefix("3"),
                 _ where prefix.hasPrefix("tb1"),
                 _ where prefix.hasPrefix("bc1"),
                 _ where prefix.hasPrefix("2"),
                 _ where prefix.hasPrefix("n"),
                 _ where prefix.hasPrefix("bcr"),
                 _ where prefix.hasPrefix("m"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Address")
                    
                }
                
                if self.ssh.session.isConnected {
                    
                    isAddress = true
                    
                    var param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"label\": \"\(label)\", \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
                    
                    if isInternal {
                        
                        param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"timestamp\": \(timestamp), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
                        
                    }
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                               param: param)
                    
                } else {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Not connected")
                    
                }
                
            case _ where prefix.hasPrefix("0"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Public Key")
                    
                }
                
                importPublicKey(pubKey: prefix)
                
                
            default:
                
                showError()
                
            }
            
        } else {
            
            showError()
            
        }
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        parseKey(key: stringURL)
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if qrScanner.textField.text != "" {
            
            parseKey(key: qrScanner.textField.text!)
            
        }
        
        return true
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        qrScanner.textField.resignFirstResponder()
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        parseKey(key: qrString)
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.qrScanner.removeFromSuperview()
                    
                }
                
                switch method {
                    
                case BTC_CLI_COMMAND.importprivkey:
                    
                    self.connectingView.removeConnectingView()
                    let result = makeSSHCall.stringToReturn
                    
                    if result == "Imported key success" {

                        alertMessage = "Successfully imported private key"
                        
                    }
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "showKeyDetails", sender: self)
                        
                    }
                    
                case BTC_CLI_COMMAND.importmulti:
                    
                    let result = makeSSHCall.arrayToReturn
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        
                        var messageString = "Sucessfully imported the address"
                        
                        if !isAddress {
                            
                            messageString = "Sucessfully imported the public key and its three address types"
                            
                        }
                        
                        alertMessage = messageString
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "showKeyDetails", sender: self)
                            
                        }
                        
                    } else {
                        
                        let error = ((result[0] as! NSDictionary)["error"] as! NSDictionary)["message"] as! String
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: error)
                        
                    }
                    
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        
                        if warnings.count > 0 {
                            
                            for warning in warnings {
                                
                                let warn = warning as! String
                                
                                DispatchQueue.main.async {
                                    
                                    let alert = UIAlertController(title: "Warning", message: warn, preferredStyle: UIAlertController.Style.alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                     isError: true,
                                     message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh != nil {
         
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
         
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if segue.identifier == "showKeyDetails" {

            if let vc = segue.destination as? GetInfoViewController {

                vc.labelToSearch = label
                vc.getaddressesbylabel = true
                vc.alertMessage = alertMessage

            }

        }

    }

}
