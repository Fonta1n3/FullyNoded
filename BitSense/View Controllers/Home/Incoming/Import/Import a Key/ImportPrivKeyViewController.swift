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
    
    var isTestnet = Bool()
    var reScan = Bool()
    var isWatchOnly = Bool()
    var desc = "wpkh"
    var importedKey = ""
    var addToKeypool = false
    var isInternal = false
    var range = "0 to 99"
    var convertedRange = [0,99]
    var fingerprint = ""
    var descriptor = ""
    var label = ""
    var bip44 = Bool()
    var bip84 = Bool()
    
    var keyArray = NSArray()
    
    var isAddress = false
    
    func convertRange() -> [Int] {
        
        var arrayToReturn = [Int]()
        let newrange = range.replacingOccurrences(of: " ", with: "")
        let rangeArray = newrange.components(separatedBy: "to")
        let zero = Int(rangeArray[0])!
        let one = Int(rangeArray[1])!
        arrayToReturn = [zero,one]
        return arrayToReturn
        
    }
    
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
        
        getSettings()
        
    }
    
    func getSettings() {
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "bip44") != nil {
            
            bip44 = userDefaults.bool(forKey: "bip44")
            
        } else {
            
            bip44 = false
            
        }
        
        if userDefaults.object(forKey: "bip84") != nil {
            
            bip84 = userDefaults.bool(forKey: "bip84")
            
        } else {
            
            bip84 = true
            
        }
        
        if bip44 {
            
            desc = "pkh"
            
        } else {
            
            desc = "wpkh"
            
        }
        
        if bip84 {
            
            desc = "wpkh"
            
        } else {
            
            desc = "pkh"
            
        }
        
        if userDefaults.object(forKey: "addToKeypool") != nil {
            
            addToKeypool = userDefaults.bool(forKey: "addToKeypool")
            
        }
        
        if userDefaults.object(forKey: "isInternal") != nil {
            
            isInternal = userDefaults.bool(forKey: "isInternal")
            
        }
        
        if userDefaults.object(forKey: "range") != nil {
            
            range = userDefaults.object(forKey: "range") as! String
            
        }
        
        convertedRange = convertRange()
        
        if userDefaults.object(forKey: "reScan") != nil {
            
            reScan = userDefaults.bool(forKey: "reScan")
            
        } else {
            
            reScan = false
            
        }
        
        if isPruned {
            
            reScan = false
            
        }
        
        if userDefaults.object(forKey: "fingerprint") != nil {
            
            fingerprint = userDefaults.object(forKey: "fingerprint") as! String
            
        }
        
        if reScan {
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Alert",
                                              message: "You have enabled rescanning of the blockchain in settings.\n\nWhen you import a key it will take up to an hour to rescan the entire blockchain.", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: "OK",
                                              style: UIAlertAction.Style.default,
                                              handler: nil))
                
                self.present(alert,
                             animated: true,
                             completion: nil)
                
            }
            
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

                label = "\"Fully Noded Hot Storage\""

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

                label = "\"Fully Noded Cold Storage\""
                
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
    
    func importPublicKey(pubKey: String) {
     
        func getDescriptor() {
         
            let result = makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
             
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
             
                let descriptor = "\"\(result["descriptor"] as! String)\""
                let label = "\"Imported PubKey\""
                
                var params = "[{ \"desc\": \(descriptor), \"timestamp\": \"now\", \"watchonly\": true, \"label\": \(label), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": \(reScan)}''"
                
                if isInternal {
                    
                    params = "[{ \"desc\": \(descriptor), \"timestamp\": \"now\", \"range\": \(convertedRange), \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": \(reScan)}''"
                    
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
                 _ where prefix.hasPrefix("c"):
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing Private Key")
                    
                }
                
                if self.ssh.session.isConnected {
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importprivkey,
                                               param: "\"\(key)\", \"Imported Private Key\", \(reScan)")
                    
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
                    
                    let label = "\"Imported Address\""
                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(key)\" }, \"label\": \(label), \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": \(reScan)}''"
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                               param: param)
                    
                } else {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Not connected")
                    
                }
                
            case _ where prefix.hasPrefix("xpub"),
                 _ where prefix.hasPrefix("tpub"),
                 _ where prefix.hasPrefix("zpub"),
                 _ where prefix.hasPrefix("vpub"):
                
                isWatchOnly = true
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Deriving addresses from index \(self.range) with your xpub. This can take a little while, stick around ✌🏼")
                    
                }
                
                importXpub(xpub: key)
                
            case _ where prefix.hasPrefix("xprv"),
                 _ where prefix.hasPrefix("tprv"),
                 _ where prefix.hasPrefix("zprv"),
                 _ where prefix.hasPrefix("vprv"):
                
                isWatchOnly = false
                
                DispatchQueue.main.async {
                    
                    self.connectingView.addConnectingView(vc: self,
                                                          description: "Importing 100 addresses (index \(self.range)) from your xprv. This can take a little while, stick around ✌🏼")
                    
                }
                
                importXprv(xprv: key)
                
            case _ where prefix.hasPrefix("0"):
                
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
                    
                case BTC_CLI_COMMAND.deriveaddresses:
                    
                    keyArray = makeSSHCall.arrayToReturn
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.removeConnectingView()
                        
                        self.performSegue(withIdentifier: "importExtendedKey", sender: self)
                        
                    }
                    
                case BTC_CLI_COMMAND.importprivkey:
                    
                    self.connectingView.removeConnectingView()
                    let result = makeSSHCall.stringToReturn
                    
                    if result == "Imported key success" {
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Successfully imported private key")
                        
                    }
                    
                case BTC_CLI_COMMAND.importmulti:
                    
                    let result = makeSSHCall.arrayToReturn
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Sucessfully imported the address")
                        
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
        
        if segue.identifier == "importExtendedKey" {
         
            if let vc = segue.destination as? ImportExtendedKeysViewController {
             
                vc.torClient = self.torClient
                vc.torRPC = self.torRPC
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                vc.isTestnet = self.isTestnet
                vc.reScan = self.reScan
                vc.isWatchOnly = self.isWatchOnly
                vc.desc = self.desc
                vc.importedKey = self.importedKey
                vc.addToKeypool = self.addToKeypool
                vc.isInternal = self.isInternal
                vc.range = self.range
                vc.convertedRange = self.convertedRange
                vc.fingerprint = self.fingerprint
                vc.keyArray = self.keyArray
                vc.descriptor = self.descriptor
                vc.label = self.label
                vc.bip44 = self.bip44
                vc.bip84 = self.bip84
                
            }
            
        }
        
    }

}
