//
//  GetInfoViewController.swift
//  BitSense
//
//  Created by Peter on 27/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class GetInfoViewController: UIViewController, UITextFieldDelegate {
    
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
                    
                    self.creatingView.removeConnectingView()
                    
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
        
        getInfo()
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.textView.resignFirstResponder()
            
        }
        
    }
    
    func getInfo() {
        
        creatingView.addConnectingView(vc: self,
                                       description: "")
        
        var titleString = ""
        
        if getblock {
            
            titleString = "Block Info"
            scan()
            
        }
        
        if getbestblockhash {
            
            titleString = "Latest Block"
            executeNodeCommand(method: BTC_CLI_COMMAND.getbestblockhash,
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
                
                executeNodeCommand(method: BTC_CLI_COMMAND.getaddressesbylabel,
                                   param: "\"\(labelToSearch)\"")
                
            } else {
                
                scan()
                
            }
            
        }
        
        if listLabels {
            
            titleString = "Labels"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.listlabels,
                                    param: "")
            
        }
        
        if getMempoolInfo {
            
            titleString = "Mempool Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getmempoolinfo,
                                    param: "")
        }
        
        if getPeerInfo {
            
            titleString = "Peer Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getpeerinfo,
                                    param: "")
            
        }
        
        if decodeScript {
            
            titleString = "Decoded Script"
            scan()
            
        }
        
        if getMiningInfo {
            
            titleString = "Mining Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getmininginfo,
                                    param: "")
        }
        
        if getNetworkInfo {
            
            titleString = "Network Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getnetworkinfo,
                                    param: "")
            
        }
        
        if getBlockchainInfo {
            
            titleString = "Blockchain Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getblockchaininfo,
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
            self.executeNodeCommand(method: BTC_CLI_COMMAND.listaddressgroupings,
                                    param: "")
            
        }
        
        if getWalletInfo {
            
            titleString = "Wallet Info"
            self.executeNodeCommand(method: BTC_CLI_COMMAND.getwalletinfo,
                                    param: "")
            
        }
        
        if isUtxo {
            
            titleString = "UTXO"
            
            DispatchQueue.main.async {
                
                self.textView.text = "\(self.utxo)"
                self.creatingView.removeConnectingView()
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.navigationController?.navigationBar.topItem?.title = titleString
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .getaddressesbylabel:
                    
                    let result = reducer.dictToReturn
                    
                    if labelToSearch != "" {
                        
                        addressArray = result.allKeys as NSArray
                        parseAddresses(addresses: addressArray, index: 0)
                        
                    } else {
                        
                        creatingView.removeConnectingView()
                        
                        DispatchQueue.main.async {
                            
                            self.textView.text = "\(result)"
                            
                        }
                        
                    }
                    
                case .getaddressinfo:
                    
                    let result = reducer.dictToReturn
                    
                    if address != "" {
                        
                        DispatchQueue.main.async {
                            
                            self.textView.text = "\(result)"
                            self.creatingView.removeConnectingView()
                            
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
                                    self.creatingView.removeConnectingView()
                                    
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
                                self.creatingView.removeConnectingView()
                                
                            }
                            
                        }
                        
                    }
                    
                case .listaddressgroupings,
                     .getpeerinfo,
                     .listlabels:
                    
                    DispatchQueue.main.async {
                        
                        let result = reducer.arrayToReturn
                        self.textView.text = "\(result)"
                        self.creatingView.removeConnectingView()
                        
                    }
                    
                case .getbestblockhash:
                    
                    DispatchQueue.main.async {
                        
                        let result = reducer.stringToReturn
                        self.textView.text = result
                        self.creatingView.removeConnectingView()
                        
                    }
                    
                default:
                    
                    DispatchQueue.main.async {
                        
                        let result = reducer.dictToReturn
                        self.textView.text = "\(result)"
                        self.creatingView.removeConnectingView()
                        
                    }
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    func parseAddresses(addresses: NSArray, index: Int) {
        print("parseAddresses")
        
        for (i, address) in addresses.enumerated() {
            
            if i == index {
                
                let addr = address as! String
                
                executeNodeCommand(method: BTC_CLI_COMMAND.getaddressinfo,
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
            
            self.executeNodeCommand(method: .getaddressinfo,
                                    param: "\"\(address)\"")
            
        }
        
        if decodeScript {
            
            self.executeNodeCommand(method: .decodescript,
                                    param: "\"\(address)\"")
            
        }
        
        if getaddressesbylabel {
            
            self.executeNodeCommand(method: .getaddressesbylabel,
                                    param: "\"\(address)\"")
            
        }
        
        if getTransaction {
            
            self.executeNodeCommand(method: .getrawtransaction,
                                    param: "\"\(address)\", true")
            
        }
        
        if getblock {
            
            self.executeNodeCommand(method: .getblock,
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
                
                creatingView.addConnectingView(vc: self,
                                               description: "getting info")
                
            } else {
                
                textField.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField.text != "" {
            
            getAddressInfo(address: textField.text!)
            
            creatingView.addConnectingView(vc: self,
                                           description: "getting info")
            
        }
        
    }
    
}
