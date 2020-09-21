//
//  GetInfoViewController.swift
//  BitSense
//
//  Created by Peter on 27/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class GetInfoViewController: UIViewController, UITextFieldDelegate {
    
    var command = ""
    var helpText = ""
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
    var getUtxos = Bool()
    var getTxoutset = Bool()
    
    let creatingView = ConnectingView()
    let qrScanner = QRScanner()
    
    var isTorchOn = Bool()
    var blurArray = [UIVisualEffectView]()
    var scannerShowing = false
    var isFirstTime = Bool()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var textView: UITextView!
    @IBOutlet weak var label: UILabel!
    
    var labelToSearch = ""
    
    var indexToParse = 0
    var addressArray = NSArray()
    var infoArray = [NSDictionary]()
    var alertMessage = ""
    
    var address = ""
    var utxo: UTXO!
    var isUtxo = Bool()
    
    @IBAction func getHelp(_ sender: Any) {
        getInfoHelpText()
    }
    
    private func showHelp() {
        DispatchQueue.main.async { [unowned vc = self] in
                   vc.performSegue(withIdentifier: "segueToShowHelp", sender: vc)
               }
    }
    
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
        
        setupTextField()
        configureScanner()
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        getInfo()
        
    }
    
    private func setupTextField() {
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.lightGray.cgColor
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
        var placeholder = ""
        
        if getUtxos {
            
            titleString = "UTXO's"
            placeholder = "address"
            command = "listunspent"
            scan()
            
        }
        
        if getblock {
            
            titleString = "Block Info"
            placeholder = "block hash"
            command = "getblock"
            scan()
            
        }
        
        if getbestblockhash {
            
            command = "getbestblockhash"
            titleString = "Latest Block"
            executeNodeCommand(method: .getbestblockhash,
                               param: "")
            
        }
        
        if getTransaction {
            
            command = "gettransaction"
            titleString = "Transaction"
            placeholder = "transaction ID"
            scan()
            
        }
        
        if getaddressesbylabel {
            
            command = "getaddressesbylabel"
            titleString = "Address By Label"
            placeholder = "label"
            
            if labelToSearch != "" {
                
                titleString = "Imported key info"
                
            }
            
            if labelToSearch != "" {
                
                executeNodeCommand(method: .getaddressesbylabel,
                                   param: "\"\(labelToSearch)\"")
                
            } else {
                
                scan()
                
            }
            
        }
        
        if listLabels {
            
            command = "listlabels"
            titleString = "Labels"
            self.executeNodeCommand(method: .listlabels,
                                    param: "")
            
        }
        
        if getMempoolInfo {
            
            command = "getmempoolinfo"
            titleString = "Mempool Info"
            self.executeNodeCommand(method: .getmempoolinfo,
                                    param: "")
        }
        
        if getPeerInfo {
            
            command = "getpeerinfo"
            titleString = "Peer Info"
            self.executeNodeCommand(method: .getpeerinfo,
                                    param: "")
            
        }
        
        if decodeScript {
            
            command = "decodescript"
            placeholder = "script"
            titleString = "Decoded Script"
            scan()
            
        }
        
        if getMiningInfo {
            
            command = "getmininginfo"
            titleString = "Mining Info"
            self.executeNodeCommand(method: .getmininginfo,
                                    param: "")
        }
        
        if getNetworkInfo {
            
            command = "getnetworkinfo"
            titleString = "Network Info"
            self.executeNodeCommand(method: .getnetworkinfo,
                                    param: "")
            
        }
        
        if getBlockchainInfo {
            
            command = "getblockchaininfo"
            titleString = "Blockchain Info"
            self.executeNodeCommand(method: .getblockchaininfo,
                                    param: "")
            
        }
        
        if getAddressInfo {
            
            command = "getaddressinfo"
            titleString = "Address Info"
            placeholder = "address"
            
            if address == "" {
                
                scan()
                
            } else {
                
                getAddressInfo(address: address)
                
            }
            
        }
        
        if listAddressGroups {
            
            command = "listaddressgroupings"
            titleString = "Address Groups"
            self.executeNodeCommand(method: .listaddressgroupings,
                                    param: "")
            
        }
        
        if getWalletInfo {
            
            command = "getwalletinfo"
            titleString = "Wallet Info"
            self.executeNodeCommand(method: .getwalletinfo,
                                    param: "")
            
        }
        
        if isUtxo {
            
            command = "listunspent"
            titleString = "UTXO"
            
            DispatchQueue.main.async {
                
                self.textView.text = self.format(self.utxo)
                self.creatingView.removeConnectingView()
                
            }
            
        }
        
        if getTxoutset {
            
            command = "gettxoutsetinfo"
            DispatchQueue.main.async {
                self.creatingView.label.text = "this can take awhile..."
            }
            
            titleString = "UTXO Set Info"
            self.executeNodeCommand(method: .gettxoutsetinfo,
                                    param: "")
            
        }
        
        DispatchQueue.main.async {
            
            if placeholder != "" {
                
                self.qrScanner.textField.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
            }
            
            self.label.text = titleString
            
        }
        
    }
    // TODO: As Fontane about "safe" property
    private func format(_ utxo: UTXO) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let json: String
        if let data = try? encoder.encode(utxo), let jsonString = String(data: data, encoding: .utf8) {
            json = jsonString
        } else {
            json = ""
        }
        return json
    }
    
    private func setTextView(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textView.text = text
            vc.creatingView.removeConnectingView()
        }
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .listunspent:
                    if let result = response as? NSArray {
                        vc.setTextView(text: "\(result)")
                    }
                    
                case .getaddressesbylabel:
                    if let result = response as? NSDictionary {
                        if vc.labelToSearch != "" {
                            vc.addressArray = result.allKeys as NSArray
                            vc.parseAddresses(addresses: vc.addressArray, index: 0)
                        } else {
                            vc.setTextView(text: "\(result)")
                        }
                    }
                    
                case .getaddressinfo:
                    if let result = response as? NSDictionary {
                        if vc.address != "" {
                            vc.setTextView(text: "\(result)")
                        } else {
                            vc.infoArray.append(result)
                            if vc.addressArray.count > 0 {
                                if vc.indexToParse < vc.addressArray.count {
                                    vc.indexToParse += 1
                                    vc.parseAddresses(addresses: vc.addressArray, index: vc.indexToParse)
                                }
                                if vc.indexToParse == vc.addressArray.count {
                                    vc.setTextView(text: "\(vc.infoArray)")
                                    if vc.alertMessage != "" {
                                        displayAlert(viewController: vc, isError: false, message: vc.alertMessage)
                                    }
                                }
                            } else {
                                DispatchQueue.main.async { [unowned vc = self] in
                                    vc.textView.text = "\(result)"
                                    vc.creatingView.removeConnectingView()
                                }
                            }
                        }
                    }
                    
                case .listaddressgroupings, .getpeerinfo, .listlabels:
                    if let result = response as? NSArray {
                        vc.setTextView(text: "\(result)")
                    }
                    
                case .getbestblockhash:
                    if let result = response as? String {
                        vc.setTextView(text: result)
                    }
                    
                default:
                    if let result = response as? NSDictionary {
                        vc.setTextView(text: "\(result)")
                    }
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.creatingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    func parseAddresses(addresses: NSArray, index: Int) {
        print("parseAddresses")
        
        for (i, address) in addresses.enumerated() {
            
            if i == index {
                
                let addr = address as! String
                
                executeNodeCommand(method: .getaddressinfo,
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
        qrScanner.textFieldPlaceholder = "scan QR or paste here"
        
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
        
        if getUtxos {
            
            let param = "0, 9999999, [\"\(address)\"]"
            
            self.executeNodeCommand(method: .listunspent,
                                    param: param)
            
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
                                               description: "")
                
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
    
    private func getInfoHelpText() {
        let connectingView = ConnectingView()
        connectingView.addConnectingView(vc: self, description: "help \(command)...")
        Reducer.makeCommand(command: .help, param: "\"\(command)\"") { [unowned vc = self] (response, errorMessage) in
            connectingView.removeConnectingView()
            if let text = response as? String {
                vc.helpText = text
                vc.showHelp()
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToShowHelp" {
            if let vc = segue.destination as? HelpViewController {
                vc.labelText = command
                vc.textViewText = helpText
            }
        }
    }
    
}
