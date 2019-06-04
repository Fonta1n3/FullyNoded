//
//  ImportPrivKeyViewController.swift
//  BitSense
//
//  Created by Peter on 23/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportPrivKeyViewController: UIViewController, UITextFieldDelegate {
    
    var ssh:SSHService!
    var isPruned = Bool()
    var rescan = String()
    @IBOutlet var qrView: UIImageView!
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.dark))
    let connectingView = ConnectingView()
    @IBOutlet var backButtonImage: UIImageView!
    var makeSSHCall = SSHelper()
    var reScan = Bool()
    var isWatchOnly = Bool()
    
    @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        
        return UIInterfaceOrientationMask.portrait
        
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
        
        qrScanner.uploadButton.addTarget(self,
                               action: #selector(self.chooseQRCodeFromLibrary),
                               for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                              action: #selector(toggleTorch),
                              for: .touchUpInside)
        
        addShadow(view: backButtonImage)
        isTorchOn = false
        addScanner()
        
        reScan = true
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "reScan") != nil {
            
            reScan = userDefaults.bool(forKey: "reScan")
            
        }
        
        if isPruned {
            
            reScan = false
            
        }
        
        if reScan {
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Alert", message: "If the keys you are importing have transaction history your node will need to rescan the blockchain in order for those transactions to appear in Bitcoin Core, by default we enable rescanning, if your keys have never been used we recommend disabling \"Rescan\" in settings. Rescanning the blockchain can take up to an hour.", preferredStyle: UIAlertControllerStyle.alert)
                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
                
            }
            
        }
        
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
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        qrScanner.textField.removeFromSuperview()
        blurView.removeFromSuperview()
        view.addSubview(blurView)
        blurView.contentView.addSubview(qrScanner.textField)
        
        addBlurView(frame: CGRect(x: view.frame.maxX - 80,
                                  y: view.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.uploadButton)
        
        addBlurView(frame: CGRect(x: 10,
                                  y: view.frame.maxY - 80,
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
        
        qrScanner.keepRunning = true
        qrView.frame = view.frame
        qrScanner.imageView = qrView
        qrScanner.vc = self
        qrScanner.scanQRCode()
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
    }
    
    func importXprv(xprv: String) {
        
        func getDescriptor() {
            
            let result = self.makeSSHCall.dictToReturn
            let descriptor = "\"\(result["descriptor"] as! String)\""
            let params = "'[{ \"desc\": \(descriptor), \"timestamp\": \"now\", \"range\": 100, \"watchonly\": false, \"label\": \"Hot Storage\", \"keypool\": false, \"rescan\": \(reScan) }]'"
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                       param: params)
            
        }
        
        makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                      method: BTC_CLI_COMMAND.getdescriptorinfo,
                                      param: "\"wpkh(\(xprv)/*)\"", completion: getDescriptor)
        
    }
    
    func importXpub(xpub: String) {
        
        func getDescriptor() {
            
            let result = self.makeSSHCall.dictToReturn
            let descriptor = "\"\(result["descriptor"] as! String)\""
            let params = "'[{ \"desc\": \(descriptor), \"timestamp\": \"now\", \"range\": 100, \"watchonly\": true, \"label\": \"Cold Storage\", \"keypool\": true, \"rescan\": \(reScan) }]'"
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                       param: params)
            
        }
        
        makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                      method: BTC_CLI_COMMAND.getdescriptorinfo,
                                      param: "\"wpkh(\(xpub)/*)\"",
                                      completion: getDescriptor)
        
    }
    
    func parseKey(key: String) {
        
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
                 _ where prefix.hasPrefix("c"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Private Key")
                    
                }
                
                if self.ssh.session.isConnected {
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importprivkey,
                                               param: "\"\(key)\" \"Imported Private Key\" \(reScan)")
                    
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
                 _ where prefix.hasPrefix("m"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Address")
                    
                }
                
                if self.ssh.session.isConnected {
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importaddress,
                                               param: "\"\(key)\" \"Imported Address\" \(reScan)")
                    
                } else {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Not connected")
                    
                }
                
            case _ where prefix.hasPrefix("xpub"):
                
                isWatchOnly = true
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing first 100 XPUB addresses")
                    
                }
                
                importXpub(xpub: key)
                
            case _ where prefix.hasPrefix("xprv"):
                
                isWatchOnly = false
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing first 100 keys from xprv")
                    
                }
                
                importXprv(xprv: key)
                
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
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Success, your node will now rescan the blockchain.")
                    
                case BTC_CLI_COMMAND.importaddress:
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Success, your node will now rescan the blockchain.")
                    
                case BTC_CLI_COMMAND.importmulti:
                    
                    let result = makeSSHCall.arrayToReturn
                    print("result = \(result)")
                    
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        
                        if isWatchOnly {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "100 watch only addresses imported!")
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: false,
                                         message: "100 keys imported!")
                            
                        }
                        
                    } else {
                        
                        let error = ((result[0] as! NSDictionary)["error"] as! NSDictionary)["message"] as! String
                        
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: error)
                        
                    }
                    
                    let warnings = (result[0] as! NSDictionary)["warnings"] as! NSArray
                    
                    if warnings.count > 0 {
                        
                        for warning in warnings {
                            
                            let warn = warning as! String
                            
                            DispatchQueue.main.async {
                                
                                let alert = UIAlertController(title: "Warning", message: warn, preferredStyle: UIAlertControllerStyle.alert)
                                alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
                                self.present(alert, animated: true, completion: nil)
                                
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
        
    }

}
