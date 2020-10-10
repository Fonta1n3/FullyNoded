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
    var deriveAddresses = Bool()
    let spinner = ConnectingView()
            
    @IBOutlet weak var goButtonOutlet: UIButton!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet var textView: UITextView!
    @IBOutlet weak var label: UILabel!
    
    var labelToSearch = ""
    
    var indexToParse = 0
    var addressArray = NSArray()
    var infoArray = [NSDictionary]()
    var alertMessage = ""
    var address = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        getInfo()
        setupTextField()
    }
    
    private func setupTextField() {
        textView.textContainer.lineBreakMode = .byCharWrapping
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.lightGray.cgColor
    }
    
    @IBAction func scanQr(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToGoGetInfoScan", sender: self)
        }
    }
    
    @IBAction func getHelp(_ sender: Any) {
        getInfoHelpText()
    }
    
    private func showHelp() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToShowHelp", sender: self)
        }
    }
    
    @IBAction func goAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "")
        makeCommand(param: textField.text ?? "")
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async {
            self.textView.resignFirstResponder()
            self.textField.resignFirstResponder()
        }
    }
    
    func getInfo() {
                
        var titleString = ""
        var placeholder = ""
        
        if deriveAddresses {
            titleString = "Derive Addresses"
            command = "deriveaddresses"
        }
        
        if getUtxos {
            titleString = "UTXO's"
            placeholder = "address"
            command = "listunspent"
        }
        
        if getblock {
            titleString = "Block Info"
            placeholder = "block hash"
            command = "getblock"
        }
        
        if getbestblockhash {
            command = "getbestblockhash"
            titleString = "Latest Block"
            hideParam()
            executeNodeCommand(method: .getbestblockhash, param: "")
        }
        
        if getTransaction {
            command = "gettransaction"
            titleString = "Transaction"
            placeholder = "transaction ID"
        }
        
        if getaddressesbylabel {
            command = "getaddressesbylabel"
            titleString = "Address By Label"
            placeholder = "label"
            
            if labelToSearch != "" {
                titleString = "Imported key info"
                hideParam()
                executeNodeCommand(method: .getaddressesbylabel, param: "\"\(labelToSearch)\"")
            }
        }
        
        if listLabels {
            command = "listlabels"
            titleString = "Labels"
            hideParam()
            self.executeNodeCommand(method: .listlabels, param: "")
        }
        
        if getMempoolInfo {
            command = "getmempoolinfo"
            titleString = "Mempool Info"
            hideParam()
            self.executeNodeCommand(method: .getmempoolinfo, param: "")
        }
        
        if getPeerInfo {
            command = "getpeerinfo"
            titleString = "Peer Info"
            hideParam()
            self.executeNodeCommand(method: .getpeerinfo, param: "")
        }
        
        if decodeScript {
            command = "decodescript"
            placeholder = "script"
            titleString = "Decoded Script"
        }
        
        if getMiningInfo {
            command = "getmininginfo"
            titleString = "Mining Info"
            hideParam()
            self.executeNodeCommand(method: .getmininginfo, param: "")
        }
        
        if getNetworkInfo {
            command = "getnetworkinfo"
            titleString = "Network Info"
            hideParam()
            self.executeNodeCommand(method: .getnetworkinfo, param: "")
        }
        
        if getBlockchainInfo {
            command = "getblockchaininfo"
            titleString = "Blockchain Info"
            hideParam()
            self.executeNodeCommand(method: .getblockchaininfo, param: "")
        }
        
        if getAddressInfo {
            command = "getaddressinfo"
            titleString = "Address Info"
            placeholder = "address"
            
            if address != "" {
                hideParam()
                makeCommand(param: address)
            }
        }
        
        if listAddressGroups {
            command = "listaddressgroupings"
            titleString = "Address Groups"
            hideParam()
            self.executeNodeCommand(method: .listaddressgroupings, param: "")
        }
        
        if getWalletInfo {
            command = "getwalletinfo"
            titleString = "Wallet Info"
            hideParam()
            self.executeNodeCommand(method: .getwalletinfo, param: "")
        }
        
        if getTxoutset {
            command = "gettxoutsetinfo"
            DispatchQueue.main.async {
                self.spinner.label.text = "this can take awhile..."
            }
            titleString = "UTXO Set Info"
            hideParam()
            self.executeNodeCommand(method: .gettxoutsetinfo, param: "")
        }
        
        DispatchQueue.main.async {
            self.label.text = titleString
        }
        
    }
    
    private func hideParam() {
        goButtonOutlet.isEnabled = false
        goButtonOutlet.alpha = 0
        textField.alpha = 0
    }
    
    private func setTextView(text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.textView.text = text
            self.spinner.removeConnectingView()
        }
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        spinner.addConnectingView(vc: self, description: "")
        
        Reducer.makeCommand(command: method, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            if errorMessage == nil {
                switch method {
                case .deriveaddresses:
                    if let addresses = response as? NSArray {
                        self.setTextView(text: "\(addresses)")
                    }
                
                case .listunspent:
                    if let result = response as? NSArray {
                        self.setTextView(text: "\(result)")
                    }
                    
                case .getaddressesbylabel:
                    if let result = response as? NSDictionary {
                        if self.labelToSearch != "" {
                            self.addressArray = result.allKeys as NSArray
                            self.parseAddresses(addresses: self.addressArray, index: 0)
                        } else {
                            self.setTextView(text: "\(result)")
                        }
                    }
                    
                case .getaddressinfo:
                    if let result = response as? NSDictionary {
                        if self.address != "" {
                            self.setTextView(text: "\(result)")
                        } else {
                            self.infoArray.append(result)
                            if self.addressArray.count > 0 {
                                if self.indexToParse < self.addressArray.count {
                                    self.indexToParse += 1
                                    self.parseAddresses(addresses: self.addressArray, index: self.indexToParse)
                                }
                                if self.indexToParse == self.addressArray.count {
                                    self.setTextView(text: "\(self.infoArray)")
                                    if self.alertMessage != "" {
                                        displayAlert(viewController: self, isError: false, message: self.alertMessage)
                                    }
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.textView.text = "\(result)"
                                    self.spinner.removeConnectingView()
                                }
                            }
                        }
                    }
                    
                case .listaddressgroupings, .getpeerinfo, .listlabels:
                    if let result = response as? NSArray {
                        self.setTextView(text: "\(result)")
                    }
                    
                case .getbestblockhash:
                    if let result = response as? String {
                        self.setTextView(text: result)
                    }
                    
                default:
                    if let result = response as? NSDictionary {
                        self.setTextView(text: "\(result)")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    func parseAddresses(addresses: NSArray, index: Int) {
        for (i, address) in addresses.enumerated() {
            if i == index {
                let addr = address as! String
                executeNodeCommand(method: .getaddressinfo, param: "\"\(addr)\"")
            }
        }
    }
    
    func makeCommand(param: String) {
        
        if deriveAddresses {
            let params = "\"\(param)\", [0,2500]"
            self.executeNodeCommand(method: .deriveaddresses, param: params)
        }
        
        if getUtxos {
            let params = "0, 9999999, [\"\(param)\"]"
            self.executeNodeCommand(method: .listunspent, param: params)
        }
        
        if getAddressInfo {
            self.executeNodeCommand(method: .getaddressinfo, param: "\"\(param)\"")
        }
        
        if decodeScript {
            self.executeNodeCommand(method: .decodescript, param: "\"\(param)\"")
        }
        
        if getaddressesbylabel {
            self.executeNodeCommand(method: .getaddressesbylabel, param: "\"\(param)\"")
        }
        
        if getTransaction {
            self.executeNodeCommand(method: .getrawtransaction, param: "\"\(param)\", true")
        }
        
        if getblock {
            self.executeNodeCommand(method: .getblock, param: "\"\(param)\"")
        }
        
    }
    
    private func getInfoHelpText() {
        let connectingView = ConnectingView()
        connectingView.addConnectingView(vc: self, description: "help \(command)...")
        Reducer.makeCommand(command: .help, param: "\"\(command)\"") { [weak self] (response, errorMessage) in
            connectingView.removeConnectingView()
            if let text = response as? String {
                guard let self = self else { return }
                
                self.helpText = text
                self.showHelp()
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
        if segue.identifier == "segueToGoGetInfoScan" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { [weak self] item in
                    if item != nil {
                        DispatchQueue.main.async {
                            self?.textField.text = item
                        }
                    }
                }
            }
        }
    }
    
}
