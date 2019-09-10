//
//  GetInfoViewController.swift
//  BitSense
//
//  Created by Peter on 27/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class GetInfoViewController: UIViewController, UITextFieldDelegate {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    let connectingView = ConnectingView()
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var getBlockchainInfo = Bool()
    var getAddressInfo = Bool()
    var listAddressGroups = Bool()
    var getNetworkInfo = Bool()
    var getWalletInfo = Bool()
    var getMiningInfo = Bool()
    var decodeScript = Bool()
    var getPeerInfo = Bool()
    var getMempoolInfo = Bool()
    var listLabels = Bool()
    var getaddressesbylabel = Bool()
    var getTransaction = Bool()
    var getbestblockhash = Bool()
    var getblock = Bool()
    
    let creatingView = ConnectingView()
    let qrScanner = QRScanner()
    
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    var scannerShowing = false
    var isFirstTime = Bool()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var textView: UITextView!
    @IBOutlet var navBar: UINavigationBar!
    
    var labelToSearch = ""
    
    var indexToParse = 0
    var addressArray = NSArray()
    var infoArray = [NSDictionary]()
    var alertMessage = ""
    
    var address = ""
    
    var utxo = NSDictionary()
    var isUtxo = Bool()
    
    func scan() {
    
        scannerShowing = true
        textView.resignFirstResponder()
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                }, completion: { _ in
                    
                    self.connectingView.removeConnectingView()
                    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        configureScanner()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        getInfo()
        
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
        
    }
    
   @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.textView.resignFirstResponder()
            
        }
        
    }
    
    func getInfo() {
        
        connectingView.addConnectingView(vc: self,
                                         description: "")
        
        var titleString = ""
        
        if getblock {
            
            titleString = "Block Info"
            scan()
            
        }
        
        if getbestblockhash {
            
            titleString = "Latest Block"
            executeNodeCommandSsh(method: BTC_CLI_COMMAND.getbestblockhash,
                                  param: "")
            
        }
        
        if getTransaction {
            
            titleString = "Transaction"
            scan()
            
        }
        
        if getaddressesbylabel {
            
            titleString = "Address By Label"
            
            if labelToSearch != "" {
                
                titleString = "Imported key info"
                
            }
            
            if labelToSearch != "" {
                
                executeNodeCommandSsh(method: BTC_CLI_COMMAND.getaddressesbylabel,
                                      param: "\"\(labelToSearch)\"")
                
            } else {
                
                scan()
                
            }
            
        }
        
        if listLabels {
            
            titleString = "Labels"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.listlabels,
                                       param: "")
            
        }
        
        if getMempoolInfo {
            
            titleString = "Mempool Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getmempoolinfo,
                                       param: "")
        }
        
        if getPeerInfo {
            
            titleString = "Peer Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getpeerinfo,
                                       param: "")
            
        }
        
        if decodeScript {
            
//            connectingView.addConnectingView(vc: self,
//                                             description: "")
            
            titleString = "Decoded Script"
            scan()
            
        }
        
        if getMiningInfo {
            
            titleString = "Mining Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getmininginfo,
                                       param: "")
        }
        
        if getNetworkInfo {
            
            titleString = "Network Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getnetworkinfo,
                                       param: "")
            
        }
        
        if getBlockchainInfo {
            
            titleString = "Blockchain Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getblockchaininfo,
                                       param: "")
            
        }
        
        if getAddressInfo {
            
            titleString = "Address Info"
            
            if address == "" {
                
                scan()
                
            } else {
                
                getAddressInfo(address: address)
                
            }
            
        }
        
        if listAddressGroups {
            
            titleString = "Address Groups"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.listaddressgroupings,
                                       param: "")
            
        }
        
        if getWalletInfo {
            
            titleString = "Wallet Info"
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getwalletinfo,
                                       param: "")
            
        }
        
        if isUtxo {
            
            titleString = "UTXO"
            
            DispatchQueue.main.async {
                
                self.textView.text = "\(self.utxo)"
                self.connectingView.removeConnectingView()
                
            }

        }
        
        DispatchQueue.main.async {
            
            self.navigationController?.navigationBar.topItem?.title = titleString
            
        }
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.getaddressesbylabel:
                    
                    if labelToSearch != "" {
                        
                        addressArray = makeSSHCall.dictToReturn.allKeys as NSArray
                        parseAddresses(addresses: addressArray, index: 0)
                        
                    }
                    
                case BTC_CLI_COMMAND.getaddressinfo:
                    
                    let result = makeSSHCall.dictToReturn
                    
                    if address != "" {
                        
                        DispatchQueue.main.async {
                            
                            self.textView.text = "\(result)"
                            self.connectingView.removeConnectingView()
                            
                        }
                        
                    } else {
                        
                        infoArray.append(result)
                        
                        if addressArray.count > 0 {
                            
                            if indexToParse < addressArray.count {
                                
                                indexToParse += 1
                                parseAddresses(addresses: addressArray, index: indexToParse)
                                
                            }
                            
                            if indexToParse == addressArray.count {
                                
                                DispatchQueue.main.async {
                                    
                                    self.textView.text = "\(self.infoArray)"
                                    self.connectingView.removeConnectingView()
                                    
                                    if self.alertMessage != "" {
                                        
                                        displayAlert(viewController: self,
                                                     isError: false,
                                                     message: self.alertMessage)
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        } else {
                            
                            DispatchQueue.main.async {
                                
                                self.textView.text = "\(result)"
                                self.connectingView.removeConnectingView()
                                
                            }
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.listaddressgroupings,
                     BTC_CLI_COMMAND.getpeerinfo,
                     BTC_CLI_COMMAND.listlabels:
                    
                    DispatchQueue.main.async {
                        
                        let result = self.makeSSHCall.arrayToReturn
                        self.textView.text = "\(result)"
                        self.connectingView.removeConnectingView()
                        
                    }
                    
                case BTC_CLI_COMMAND.getbestblockhash:
                    
                    DispatchQueue.main.async {
                        
                        let result = self.makeSSHCall.stringToReturn
                        self.textView.text = result
                        self.connectingView.removeConnectingView()
                        
                    }
                    
                default:
                    
                    DispatchQueue.main.async {
                        
                        let result = self.makeSSHCall.dictToReturn
                        self.textView.text = "\(result)"
                        self.connectingView.removeConnectingView()
                        
                    }
                    
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
                
                self.makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                   method: method,
                                                   param: param,
                                                   completion: getResult)
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "SSH not connected")
                
            }
            
        } else {
            
            displayAlert(viewController: self.navigationController!,
                         isError: true,
                         message: "Not connected to a node")
            
        }
        
    }
    
    func parseAddresses(addresses: NSArray, index: Int) {
        print("parseAddresses")
        
        for (i, address) in addresses.enumerated() {
            
            if i == index {
                
                let addr = address as! String
                
                executeNodeCommandSsh(method: BTC_CLI_COMMAND.getaddressinfo,
                                      param: "\"\(addr)\"")
                
            }
            
        }
        
    }
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        blurView.isUserInteractionEnabled = true
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 100,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.textField.delegate = self
        qrScanner.closeButton.alpha = 0
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textFieldPlaceholder = "scan address QR or type/paste here"
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func addScannerButtons() {
        
        imageView.addSubview(blurView)
        blurView.contentView.addSubview(qrScanner.textField)
        
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
        
        back()
        let stringURL = qrScanner.stringToReturn
        getAddressInfo(address: stringURL)
        
    }
    
    func didPickImage() {
        
        back()
        let qrString = qrScanner.qrString
        getAddressInfo(address: qrString)
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.resignFirstResponder()
                textView.text = string
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func getAddressInfo(address: String) {
        
        DispatchQueue.main.async {
            
            self.qrScanner.textField.resignFirstResponder()
            
            for blur in self.blurArray {
                
                blur.removeFromSuperview()
                
            }
            
            self.blurView.removeFromSuperview()
            self.qrScanner.removeScanner()
            
        }
        
        if isTorchOn {
            
            toggleTorch()
            
        }
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
        }
        
        if getAddressInfo {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getaddressinfo,
                                       param: "\"\(address)\"")
            
        }
        
        if decodeScript {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.decodescript,
                                       param: "\"\(address)\"")
            
        }
        
        if getaddressesbylabel {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getaddressesbylabel,
                                       param: "\"\(address)\"")
            
        }
        
        if getTransaction {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getrawtransaction,
                                       param: "\"\(address)\", true")
            
        }
        
        if getblock {
            
            self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.getblock,
                                       param: "\"\(address)\"")
            
        }
        
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField.text != "" {
            
            textField.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textField.resignFirstResponder()
                textField.text = string
                getAddressInfo(address: string)
                
                connectingView.addConnectingView(vc: self,
                                                 description: "getting info")
                
            } else {
                
                textField.becomeFirstResponder()
                
            }
            
        }
            
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField.text != "" {
            
            getAddressInfo(address: textField.text!)
            
            connectingView.addConnectingView(vc: self,
                                             description: "getting info")
            
        }
        
    }

}
