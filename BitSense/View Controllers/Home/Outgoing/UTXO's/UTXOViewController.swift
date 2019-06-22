//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UTXOViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var rawSigned = String()
    var amountTotal = 0.0
    let refresher = UIRefreshControl()
    var ssh:SSHService!
    var utxoArray = [Any]()
    var inputArray = [Any]()
    var inputs = ""
    var address = ""
    var miningFee = Double()
    var utxoToSpendArray = [Any]()
    var creatingView = ConnectingView()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    var selectedArray = [Bool]()
    var scannerShowing = false
    var blurArray = [UIVisualEffectView]()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrGenerator = QRGenerator()
    var isTorchOn = Bool()
    let qrScanner = QRScanner()
    let rawDisplayer = RawDisplayer()
    
    @IBOutlet var imageView: UIImageView!
    
    @IBOutlet var utxoTable: UITableView!
    
    func getAddressSettings() {
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "nativeSegwit") != nil {
            
            nativeSegwit = userDefaults.bool(forKey: "nativeSegwit")
            
        } else {
            
            nativeSegwit = true
            
        }
        
        if userDefaults.object(forKey: "p2shSegwit") != nil {
            
            p2shSegwit = userDefaults.bool(forKey: "p2shSegwit")
            
        } else {
            
            p2shSegwit = false
            
        }
        
        if userDefaults.object(forKey: "legacy") != nil {
            
            legacy = userDefaults.bool(forKey: "legacy")
            
        } else {
            
            legacy = false
            
        }
        
    }
    
    @IBAction func consolidate(_ sender: Any) {
        
        if utxoArray.count > 0 {
            
            if utxoToSpendArray.count > 0 {
                
                //consolidate selected utxos only
                
            } else {
                
                //consolidate them all
                
                for utxo in utxoArray {
                    
                    utxoToSpendArray.append(utxo as! [String:Any])
                    
                }
                
            }
            
            
            
            getAddressSettings()
            
            updateInputs()
            
            self.creatingView.addConnectingView(vc: self,
                                                description: "Consolidating UTXO's")
            
            if self.nativeSegwit {
             
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "\"\", \"bech32\"")
             
             } else if self.legacy {
             
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "\"\", \"legacy\"")
             
             } else if self.p2shSegwit {
             
                self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getnewaddress,
                                           param: "")
             
             }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "No UTXO's to consolidate")
            
        }
        
    }
    
    @IBAction func createRaw(_ sender: Any) {
        
        if self.utxoToSpendArray.count > 0 {
            
            updateInputs()
            
            if self.inputArray.count > 0 {
                
                DispatchQueue.main.async {
                    
                    self.getAddress()
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Select a UTXO first")
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Select a UTXO first")
            
        }
        
    }
    
    func rounded(number: Double) -> Double {
        
        return Double(round(100000000*number)/100000000)
        
    }
    
    @IBAction func back(_ sender: Any) {
        
        if !scannerShowing {
            
            DispatchQueue.main.async {
                
                self.dismiss(animated: true, completion: nil)
                
            }
            
        }
        
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        utxoTable.delegate = self
        utxoTable.dataSource = self
        
        qrScanner.textField.delegate = self
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black

        utxoTable.tableFooterView = UIView(frame: .zero)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(refresh),
                            for: UIControl.Event.valueChanged)
        utxoTable.addSubview(refresher)
        refresh()
        
        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
        var miningFeeString = ""
        miningFeeString = miningFeeCheck
        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
        let fee = (Double(miningFeeString)!) / 100000000
        miningFee = fee
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("viewDidAppear")
        
        utxoTable.reloadData()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        for (index, _) in selectedArray.enumerated() {
            
            selectedArray[index] = false
            
        }
        
    }
    
    @objc func refresh() {
        
        addSpinner()
        utxoArray.removeAll()
        
        executeNodeCommandSSH(method: BTC_CLI_COMMAND.listunspent,
                              param: "")
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return utxoArray.count
        
    }
    
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        if utxoArray.count > 0 {
            
            let dict = utxoArray[indexPath.row] as! NSDictionary
            let address = cell.viewWithTag(1) as! UILabel
            let txId = cell.viewWithTag(2) as! UILabel
            let redScript = cell.viewWithTag(3) as! UILabel
            let amount = cell.viewWithTag(4) as! UILabel
            let scriptPubKey = cell.viewWithTag(5) as! UILabel
            let vout = cell.viewWithTag(6) as! UILabel
            let solvable = cell.viewWithTag(7) as! UILabel
            let confs = cell.viewWithTag(8) as! UILabel
            let safe = cell.viewWithTag(9) as! UILabel
            let spendable = cell.viewWithTag(10) as! UILabel
            let checkMark = cell.viewWithTag(13) as! UIImageView
            
            if !(selectedArray[indexPath.row]) {
                
                checkMark.alpha = 0
                
            } else {
                
                checkMark.alpha = 1
                
            }
            
            for (key, value) in dict {
                
                let keyString = key as! String
                
                switch keyString {
                    
                case "address":
                    
                    address.text = "\(value)"
                    
                case "txid":
                    
                    txId.text = "\(value)"
                    
                case "redeemScript":
                    
                    redScript.text = "\(value)"
                    
                case "amount":
                    
                    amount.text = "\(value)"
                    
                case "scriptPubKey":
                    
                    scriptPubKey.text = "\(value)"
                    
                case "vout":
                    
                    vout.text = "\(value)"
                    
                case "solvable":
                    
                    if (value as! Int) == 1 {
                        
                        solvable.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        solvable.text = "False"
                        
                    }
                    
                case "confirmations":
                    
                    confs.text = "\(value)"
                    
                case "safe":
                    
                    if (value as! Int) == 1 {
                        
                        safe.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        safe.text = "False"
                        
                    }
                    
                case "spendable":
                    
                    if (value as! Int) == 1 {
                        
                        spendable.text = "True"
                        
                    } else if (value as! Int) == 0 {
                        
                        spendable.text = "False"
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            }
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = utxoTable.cellForRow(at: indexPath)
        let checkmark = cell?.viewWithTag(13) as! UIImageView
        cell?.isSelected = true
        
        self.selectedArray[indexPath.row] = true
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell?.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell?.alpha = 1
                    checkmark.alpha = 1
                    
                })
                
            }
            
        }
        
        utxoToSpendArray.append(utxoArray[indexPath.row] as! [String:Any])
        
    }
    
    func updateInputs() {
        
        inputArray.removeAll()
        
        for utxo in self.utxoToSpendArray {
            
            let dict = utxo as! [String:Any]
            let amount = dict["amount"] as! Double
            amountTotal = amountTotal + amount
            let txid = dict["txid"] as! String
            let vout = dict["vout"] as! Int
            let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
            inputArray.append(input)
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        if let cell = utxoTable.cellForRow(at: indexPath) {
            
            self.selectedArray[indexPath.row] = false
            
            let checkmark = cell.viewWithTag(13) as! UIImageView
            let cellTxid = (cell.viewWithTag(2) as! UILabel).text
            let cellAddress = (cell.viewWithTag(1) as! UILabel).text
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    checkmark.alpha = 0
                    cell.alpha = 0
                    
                }) { _ in
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        cell.alpha = 1
                        
                    })
                    
                }
                
            }
            
            if utxoToSpendArray.count > 0 {
                
                for (index, utxo) in (self.utxoToSpendArray as! [[String:Any]]).enumerated() {
                    
                    let txid = utxo["txid"] as! String
                    let address = utxo["address"] as! String
                    
                    if txid == cellTxid && address == cellAddress {
                        
                        self.utxoToSpendArray.remove(at: index)
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func parseUnspent(utxos: NSArray) {
        
        if utxos.count > 0 {
            
            self.utxoArray = utxos as! Array
            
            for _ in utxoArray {
                
                self.selectedArray.append(false)
                
            }
            
            DispatchQueue.main.async {
                
                self.removeSpinner()
                
                self.utxoTable.reloadData()
                
            }
            
        } else {
            
            self.removeSpinner()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "No UTXO's")
            
        }
        
    }
    
    func executeNodeCommandSSH(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.getnewaddress:
                    
                    let address = makeSSHCall.stringToReturn
                    
                    let roundedAmount = rounded(number: self.amountTotal - miningFee)
                    
                    let spendUtxo = SendUTXO()
                    spendUtxo.inputArray = self.inputArray
                    spendUtxo.inputs = self.inputs
                    spendUtxo.ssh = self.ssh
                    spendUtxo.address = address
                    spendUtxo.amount = roundedAmount
                    spendUtxo.makeSSHCall = self.makeSSHCall
                    
                    func getResult() {
                        
                        if !spendUtxo.errorBool {
                            
                            let rawTx = spendUtxo.signedRawTx
                            
                            DispatchQueue.main.async {
                                
                                self.rawSigned = rawTx
                                self.displayRaw(raw: self.rawSigned)
                                
                            }
                            
                        } else {
                            
                            DispatchQueue.main.async {
                                
                                self.removeSpinner()
                                
                                displayAlert(viewController: self,
                                             isError: true,
                                             message: spendUtxo.errorDescription)
                                
                            }
                            
                        }
                        
                    }
                    
                    spendUtxo.createRawTransaction(completion: getResult)
                    
                case BTC_CLI_COMMAND.listunspent:
                    
                    let resultArray = makeSSHCall.arrayToReturn
                    parseUnspent(utxos: resultArray)
                    
                case BTC_CLI_COMMAND.decoderawtransaction:
                    
                    let decodedTx = makeSSHCall.dictToReturn
                    parseDecodedTx(decodedTx: decodedTx)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    
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
            
            self.removeSpinner()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }
    
    func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.refresher.endRefreshing()
            self.creatingView.removeConnectingView()
            
        }
        
    }
    
    func addSpinner() {
        
        DispatchQueue.main.async {
            
            self.creatingView.addConnectingView(vc: self,
                                                description: "Getting UTXOs")
            
        }
        
    }
    
    // MARK: QR SCANNER METHODS
    
    func getAddress() {
        
        scannerShowing = true
        
        imageView.frame = view.frame
        imageView.isUserInteractionEnabled = true
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textFieldPlaceholder = "scan address QR or type/paste here"
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 80,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        
        qrScanner.closeButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        
        qrScanner.scanQRCode()
        
        DispatchQueue.main.async {
            
            self.imageView.alpha = 1
            self.imageView.addSubview(self.blurView)
            self.blurView.contentView.addSubview(self.qrScanner.textField)
            self.imageView.addSubview(self.qrScanner.closeButton)
            
            self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                           y: self.imageView.frame.maxY - 80,
                                           width: 70,
                                           height: 70), button: self.qrScanner.uploadButton)
            
            self.addBlurView(frame: CGRect(x: 10,
                                           y: self.imageView.frame.maxY - 80,
                                           width: 70,
                                           height: 70), button: self.qrScanner.torchButton)
        }
        
    }
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        self.address = stringURL
        //self.createRawNow()
        processBIP21(url: stringURL)
        
    }
    
    @objc func goBack() {
        print("goBack")
        
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
    
    func didPickImage() {
        
        let qrString = qrScanner.qrString
        self.address = qrString
        processBIP21(url: qrString)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        qrScanner.chooseQRCodeFromLibrary()
        
    }
    
    func createRawNow() {
        
        DispatchQueue.main.async {
         
            self.creatingView.addConnectingView(vc: self,
                                                description: "Creating Raw")
            
        }
        
        let roundedAmount = rounded(number: self.amountTotal - miningFee)
        
        let spendUtxo = SendUTXO()
        spendUtxo.makeSSHCall = self.makeSSHCall
        spendUtxo.inputArray = self.inputArray
        spendUtxo.inputs = self.inputs
        spendUtxo.ssh = self.ssh
        spendUtxo.address = self.address
        spendUtxo.amount = roundedAmount
        
        func getResult() {
            
            if !spendUtxo.errorBool {
                
                let rawTx = spendUtxo.signedRawTx
                self.rawSigned = rawTx
                self.displayRaw(raw: rawTx)
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: spendUtxo.errorDescription)
                    
                }
                
            }
            
        }
        
        spendUtxo.createRawTransaction(completion: getResult)
        
    }
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    @objc func decode() {
        
        self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.decoderawtransaction,
                                   param: "\"\(self.rawSigned)\"")
        
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
            
            let textToShare = [self.rawSigned]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
        }
        
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
            
            self.qrGenerator.textInput = self.rawSigned
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
    
    func displayRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.rawString = raw
            self.rawDisplayer.vc = self
            
            self.rawDisplayer.closeButton.addTarget(self, action: #selector(self.close), for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                for: .touchUpInside)
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                  action: #selector(self.shareQRCode(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.qrScanner.removeFromSuperview()
            self.imageView.removeFromSuperview()
            
            
            let backView = UIView()
            backView.frame = self.view.frame
            backView.backgroundColor = self.view.backgroundColor
            self.view.addSubview(backView)
            self.creatingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
            let getSmartFee = GetSmartFee()
            getSmartFee.rawSigned = self.rawSigned
            getSmartFee.ssh = self.ssh
            getSmartFee.makeSSHCall = self.makeSSHCall
            getSmartFee.vc = self
            getSmartFee.getSmartFee()
            
        }
        
    }
    
    // MARK: TEXTFIELD METHODS
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if textField == qrScanner.textField && qrScanner.textField.text != "" {
            
            processBIP21(url: qrScanner.textField.text!)
            
        } else if textField == self.qrScanner.textField && self.qrScanner.textField.text == "" {
            
            shakeAlert(viewToShake: self.qrScanner.textField)
            
        }
        
        return true
    }
    
    func processBIP21(url: String) {
        
        let addressParser = AddressParser()
        
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        
        if !errorBool {
            
            self.address = addressParser.parseAddress(url: url).address
            
            DispatchQueue.main.async {
                
                self.qrScanner.textField.resignFirstResponder()
                
                for blur in self.blurArray {
                    
                    blur.removeFromSuperview()
                    
                }
                
                self.blurView.removeFromSuperview()
                self.qrScanner.removeScanner()
                self.createRawNow()
                
            }
            
            
            if isTorchOn {
                
                toggleTorch()
                
            }
            
            DispatchQueue.main.async {
                
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                
            }
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: errorDescription)
            
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
    
    @objc func encodeText() {
        print("encodeText")
        
        DispatchQueue.main.async {
            
            self.rawDisplayer.textView.text = self.rawSigned
            self.rawDisplayer.decodeButton.setTitle("Decode", for: .normal)
            
            self.rawDisplayer.decodeButton.removeTarget(self, action: #selector(self.encodeText),
                                                        for: .touchUpInside)
            
            self.rawDisplayer.decodeButton.addTarget(self, action: #selector(self.decode),
                                                     for: .touchUpInside)
            
        }
        
    }
    
}

extension Int {
    
    var avoidNotation: String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(for: self) ?? ""
        
    }
}



