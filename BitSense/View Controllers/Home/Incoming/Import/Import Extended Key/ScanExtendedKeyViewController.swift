//
//  ScanExtendedKeyViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ScanExtendedKeyViewController: UIViewController, UITextFieldDelegate {
    
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var dict = [String:Any]()
    
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let connectingView = ConnectingView()
    
    @IBOutlet var imageView: UIImageView!
    var descriptor = ""
    var label = ""
    var range = "0 to 199"
    var convertedRange = [0,199]
    var desc = "wpkh"
    var fingerprint = ""
    var isTestnet = Bool()
    
    var keyArray = NSArray()
    
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
                                  y: imageView.frame.maxY - 80,
                                  width: 70,
                                  height: 70), button: qrScanner.uploadButton)
        
        addBlurView(frame: CGRect(x: 10,
                                  y: imageView.frame.maxY - 80,
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
        imageView.frame = view.frame
        qrScanner.imageView = imageView
        qrScanner.vc = self
        qrScanner.scanQRCode()
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
    }
    
    func setValues(key: String) {
        
        connectingView.addConnectingView(vc: self.navigationController!, description: "deriving keys for confirmation")
        
        dict["key"] = key
        fingerprint = dict["fingerprint"] as! String
        range = dict["range"] as! String
        convertedRange = convertRange()
        
        if key.hasPrefix("t") {
            
            isTestnet = true
            
        } else {
            
            isTestnet = false
            
        }
        
        let derivation = dict["derivation"] as! String
        
        if derivation == "BIP44" {
            
            desc = "pkh"
            
        }
        
        label = dict["label"] as! String
        
        if key.hasPrefix("xprv") || key.hasPrefix("tprv") {
            
            importXprv(xprv: key)
            
        } else {
            
            importXpub(xpub: key)
            
        }
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        setValues(key: stringURL)
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        let txt = qrScanner.textField.text
        
        if txt != "" {
            
            setValues(key: txt!)
            
        }
        
        return true
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        qrScanner.textField.resignFirstResponder()
        
    }
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        setValues(key: qrString)
        
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
    
    func importXprv(xprv: String) {
        
        func getDescriptor() {
            
            let result = self.makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
                
                descriptor = "\"\(result["descriptor"] as! String)\""
                
                descriptor = descriptor.replacingOccurrences(of: "4'", with: "4'\"'\"'")
                descriptor = descriptor.replacingOccurrences(of: "1'", with: "1'\"'\"'")
                descriptor = descriptor.replacingOccurrences(of: "0'", with: "0'\"'\"'")
                dict["descriptor"] = descriptor
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.deriveaddresses,
                                           param: "\(descriptor), ''\(convertedRange)''")
                
            }
            
        }
        
        if fingerprint != "" {
            
            //compatible with coldcard
            
            if desc == "pkh" {
                
                //BIP44
                
                if isTestnet {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/44h/1h/0h]\(xprv)/0/*)\"", completion: getDescriptor)
                    
                } else {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/44h/0h/0h]\(xprv)/0/*)\"", completion: getDescriptor)
                    
                }
                
            } else {
                
                //BIP84
                
                if isTestnet {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/84h/1h/0h]\(xprv)/0/*)\"", completion: getDescriptor)
                    
                } else {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/84h/0h/0h]\(xprv)/0/*)\"", completion: getDescriptor)
                    
                }
                
            }
            
        } else {
            
            //treat the xpub as a BIP32 extended key
            
            makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                          method: BTC_CLI_COMMAND.getdescriptorinfo,
                                          param: "\"\(desc)(\(xprv)/*)\"", completion: getDescriptor)
            
        }
        
    }
    
    func importXpub(xpub: String) {
        
        func getDescriptor() {
            
            let result = self.makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
                
                descriptor = "\"\(result["descriptor"] as! String)\""
                descriptor = descriptor.replacingOccurrences(of: "4'", with: "4'\"'\"'")
                descriptor = descriptor.replacingOccurrences(of: "1'", with: "1'\"'\"'")
                descriptor = descriptor.replacingOccurrences(of: "0'", with: "0'\"'\"'")
                dict["descriptor"] = descriptor
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.deriveaddresses,
                                           param: "\(descriptor), ''\(convertedRange)''")
                
            }
            
        }
        
        if fingerprint != "" {
            
            //compatible with coldcard
            
            if desc == "pkh" {
                
                //BIP44
                
                if isTestnet {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/44h/1h/0h]\(xpub)/0/*)\"", completion: getDescriptor)
                    
                } else {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/44h/0h/0h]\(xpub)/0/*)\"", completion: getDescriptor)
                    
                }
                
            } else {
                
                //BIP84
                
                if isTestnet {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/84h/1h/0h]\(xpub)/0/*)\"", completion: getDescriptor)
                    
                } else {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: BTC_CLI_COMMAND.getdescriptorinfo,
                                                  param: "\"\(desc)([\(fingerprint)/84h/0h/0h]\(xpub)/0/*)\"", completion: getDescriptor)
                    
                }
                
            }
            
        } else {
            
            //treat the xpub as a BIP32 extended key
            
            makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                          method: BTC_CLI_COMMAND.getdescriptorinfo,
                                          param: "\"\(desc)(\(xpub)/*)\"", completion: getDescriptor)
            
        }
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.qrScanner.removeFromSuperview()
                    
                }
                
                switch method {
                    
                case BTC_CLI_COMMAND.deriveaddresses:
                    
                    keyArray = makeSSHCall.arrayToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        
                        self.performSegue(withIdentifier: "goDisplayKeys", sender: self)
                        
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
    
    func convertRange() -> [Int] {
        
        var arrayToReturn = [Int]()
        let newrange = range.replacingOccurrences(of: " ", with: "")
        let rangeArray = newrange.components(separatedBy: "to")
        let zero = Int(rangeArray[0])!
        let one = Int(rangeArray[1])!
        arrayToReturn = [zero,one]
        dict["convertedRange"] = arrayToReturn
        return arrayToReturn
        
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goDisplayKeys":
            
            if let vc = segue.destination as? ImportExtendedKeysViewController  {
                
                vc.keyArray = keyArray
                vc.dict = dict
                
            }
            
        default:
            
            break
            
        }
    }

}
