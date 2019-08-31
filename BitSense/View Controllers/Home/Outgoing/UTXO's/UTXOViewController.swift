//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UTXOViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UINavigationControllerDelegate {
    
    var isSweeping = false
    var amountToSend = String()
    let amountInput = UITextField()
    let amountView = UIView()
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    var rawSigned = String()
    var amountTotal = 0.0
    let refresher = UIRefreshControl()
    
    var utxoArray = [Any]()
    var inputArray = [Any]()
    var inputs = ""
    var address = ""
    var utxoToSpendArray = [Any]()
    var creatingView = ConnectingView()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    var selectedArray = [Bool]()
    var scannerShowing = false
    var blurArray = [UIVisualEffectView]()
    var isFirstTime = Bool()
    var isUnsigned = false
    var lockedArray = NSArray()
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let blurView2 = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrGenerator = QRGenerator()
    var isTorchOn = Bool()
    let qrScanner = QRScanner()
    let rawDisplayer = RawDisplayer()
    
    let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView",
                                                   owner: self,
                                                   options: nil)?.first as! UIView?
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var utxoTable: UITableView!
    
    @IBAction func lockAction(_ sender: Any) {
        
        creatingView.addConnectingView(vc: self, description: "Getting Locked UTXO's")
        
        executeNodeCommandSSH(method: BTC_CLI_COMMAND.listlockunspent, param: "")
        
    }
    
    
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
    
    func configureAmountView() {
        
        amountView.backgroundColor = view.backgroundColor
        
        amountView.frame = CGRect(x: 0,
                                  y: -200,
                                  width: view.frame.width,
                                  height: -200)
        
        amountInput.backgroundColor = view.backgroundColor
        amountInput.textColor = UIColor.white
        amountInput.keyboardAppearance = .dark
        amountInput.textAlignment = .center
        
        amountInput.frame = CGRect(x: 0,
                                   y: amountView.frame.midY,
                                   width: amountView.frame.width,
                                   height: 90)
        
        amountInput.keyboardType = UIKeyboardType.decimalPad
        amountInput.font = UIFont.init(name: "HiraginoSans-W3", size: 40)
        amountInput.tintColor = UIColor.white
        amountInput.inputAccessoryView = sweepButtonView
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sweepButtonClicked),
                                               name: NSNotification.Name(rawValue: "buttonClickedNotification"),
                                               object: nil)
        
        
    }
    
    func amountAvailable(amount: Double) -> (Bool, String) {
        
        var amountAvailable = 0.0
        
        for utxoDict in utxoToSpendArray {
            
            let utxo = utxoDict as! NSDictionary
            let amnt = utxo["amount"] as! Double
            amountAvailable += amnt
            
        }
        
        let string = "\(amountAvailable)"
        
        if amountAvailable >= amount {
            
            return (true, string)
            
        } else {
            
            return (false, string)
            
        }
        
    }
    
    @objc func sweepButtonClicked() {
        
        var amountToSweep = 0.0
        isSweeping = true
        
        for utxoDict in utxoToSpendArray {
            
            let utxo = utxoDict as! NSDictionary
            let amount = utxo["amount"] as! Double
            amountToSweep += amount
            
        }
        
        DispatchQueue.main.async {
            
            self.amountInput.text = "\(amountToSweep)"
            
        }
        
    }
    
    @objc func closeAmount() {
        
        if self.amountInput.text != "" {
            
            self.creatingView.addConnectingView(vc: self, description: "")
            
            self.amountToSend = self.amountInput.text!
            
            let amount = Double(self.amountToSend)!
            
            if amountAvailable(amount: amount).0 {
                
                self.amountInput.resignFirstResponder()
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.amountView.frame = CGRect(x: 0,
                                                   y: -200,
                                                   width: self.view.frame.width,
                                                   height: -200)
                    
                }) { _ in
                    
                    self.amountView.removeFromSuperview()
                    self.amountInput.removeFromSuperview()
                    self.getAddress()
                    
                }
                
            } else {
                
                creatingView.removeConnectingView()
                
                let available = amountAvailable(amount: amount).1
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "That UTXO only has \(available) BTC")
                
            }
            
        } else {
            
            self.amountInput.resignFirstResponder()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.amountView.frame = CGRect(x: 0,
                                               y: -200,
                                               width: self.view.frame.width,
                                               height: -200)
                self.blurView2.alpha = 0
                
            }) { _ in
                
                self.blurView2.removeFromSuperview()
                self.amountView.removeFromSuperview()
                self.amountInput.removeFromSuperview()
                
            }
            
        }
        
    }
    
    func getAmount() {
        
        blurView2.removeFromSuperview()
        
        let label = UILabel()
        
        label.frame = CGRect(x: 0,
                             y: 15,
                             width: amountView.frame.width,
                             height: 20)
        
        label.font = UIFont.init(name: "HiraginoSans-W3", size: 20)
        label.textColor = UIColor.darkGray
        label.textAlignment = .center
        label.text = "Amount to send"
        
        let button = UIButton()
        button.setImage(UIImage(named: "Minus"), for: .normal)
        button.frame = CGRect(x: 0, y: 140, width: self.view.frame.width, height: 60)
        button.addTarget(self, action: #selector(closeAmount), for: .touchUpInside)
        
        blurView2.alpha = 0
        
        blurView2.frame = CGRect(x: 0,
                                 y: -20,
                                 width: self.view.frame.width,
                                 height: self.view.frame.height + 20)
        
        self.view.addSubview(self.blurView2)
        self.view.addSubview(self.amountView)
        self.amountView.addSubview(self.amountInput)
        self.amountInput.text = "0.0"
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.amountView.frame = CGRect(x: 0,
                                           y: 85,
                                           width: self.view.frame.width,
                                           height: 200)
            
            self.amountInput.frame = CGRect(x: 0,
                                            y: 40,
                                            width: self.amountView.frame.width,
                                            height: 90)
            
        }) { _ in
            
            self.amountView.addSubview(label)
            self.amountView.addSubview(button)
            self.amountInput.becomeFirstResponder()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.blurView2.alpha = 1
                
            })
            
        }
        
    }
    
    @IBAction func createRaw(_ sender: Any) {
        
        if self.utxoToSpendArray.count > 0 {
            
            updateInputs()
            
            if self.inputArray.count > 0 {
                
                DispatchQueue.main.async {
                    
                    self.getAmount()
                    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        
        utxoTable.delegate = self
        utxoTable.dataSource = self
        
        configureScanner()
        configureAmountView()

        utxoTable.tableFooterView = UIView(frame: .zero)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(refresh),
                            for: UIControl.Event.valueChanged)
        utxoTable.addSubview(refresher)
        
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.blurView2.addGestureRecognizer(tapGesture)
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        refresh()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("viewDidAppear")
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        utxoTable.reloadData()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
        print("view will dissapear")
        
        for (index, _) in selectedArray.enumerated() {
            
            selectedArray[index] = false
            
        }
        
    }
    
    @objc func dismissAddressKeyboard(_ sender: UITapGestureRecognizer) {
     
        DispatchQueue.main.async {
            
            self.qrScanner.textField.resignFirstResponder()
            
        }
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        self.amountInput.resignFirstResponder()
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.amountView.frame = CGRect(x: 0,
                                           y: -200,
                                           width: self.view.frame.width,
                                           height: -200)
            
            self.blurView2.alpha = 0
            
        }) { _ in
            
            self.blurView2.removeFromSuperview()
            self.amountView.removeFromSuperview()
            self.amountInput.removeFromSuperview()
            
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
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "utxoCell", for: indexPath)
        
        if utxoArray.count > 0 {
            
            let dict = utxoArray[indexPath.row] as! NSDictionary
            let address = cell.viewWithTag(1) as! UILabel
            let txId = cell.viewWithTag(2) as! UILabel
            let amount = cell.viewWithTag(4) as! UILabel
            let vout = cell.viewWithTag(6) as! UILabel
            let solvable = cell.viewWithTag(7) as! UILabel
            let confs = cell.viewWithTag(8) as! UILabel
            let safe = cell.viewWithTag(9) as! UILabel
            let spendable = cell.viewWithTag(10) as! UILabel
            let checkMark = cell.viewWithTag(13) as! UIImageView
            txId.adjustsFontSizeToFitWidth = true
            
            if !(selectedArray[indexPath.row]) {
                
                checkMark.alpha = 0
                cell.backgroundColor = view.backgroundColor
                
            } else {
                
                checkMark.alpha = 1
                cell.backgroundColor = UIColor.black
                
            }
            
            for (key, value) in dict {
                
                let keyString = key as! String
                
                switch keyString {
                    
                case "address":
                    
                    address.text = "\(value)"
                    
                case "txid":
                    
                    txId.text = "txid: \(value)"
                    
                case "amount":
                    
                    let dbl = rounded(number: value as! Double)
                    amount.text = "\(dbl)"
                    
                case "vout":
                    
                    vout.text = "vout #\(value)"
                    
                case "solvable":
                    
                    if (value as! Int) == 1 {
                        
                        solvable.text = "Solvable"
                        solvable.textColor = UIColor.green
                        
                    } else if (value as! Int) == 0 {
                        
                        solvable.text = "Not Solvable"
                        solvable.textColor = UIColor.blue
                        
                    }
                    
                case "confirmations":
                    
                    confs.text = "\(value) confs"
                    
                case "safe":
                    
                    if (value as! Int) == 1 {
                        
                        safe.text = "Safe"
                        safe.textColor = UIColor.green
                        
                    } else if (value as! Int) == 0 {
                        
                        safe.text = "Not Safe"
                        safe.textColor = UIColor.red
                        
                    }
                    
                case "spendable":
                    
                    if (value as! Int) == 1 {
                        
                        spendable.text = "Spendable"
                        spendable.textColor = UIColor.green
                        
                    } else if (value as! Int) == 0 {
                        
                        spendable.text = "COLD"
                        spendable.textColor = UIColor.blue
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            }
            
        }
        
        return cell
        
    }
    
    func lockUTXO(txid: String, vout: Int) {
        
        let param = "false, ''[{\"txid\":\"\(txid)\",\"vout\":\(vout)}]''"
        
        executeNodeCommandSSH(method: BTC_CLI_COMMAND.lockunspent,
                              param: param)
        
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt: IndexPath) -> [UITableViewRowAction]? {
        
        let utxos = utxoArray as NSArray
        let utxo = utxos[editActionsForRowAt.row] as! NSDictionary
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        
        let lock = UITableViewRowAction(style: .normal, title: "Lock") { action, index in
            
            self.lockUTXO(txid: txid, vout: vout)
            
        }
        
        lock.backgroundColor = .red
        
        return [lock]
        
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
                    cell?.backgroundColor = UIColor.black
                    
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
            amountTotal += amount
            let txid = dict["txid"] as! String
            let vout = dict["vout"] as! Int
            let spendable = dict["spendable"] as! Bool
            let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
            
            if !spendable {
                
                isUnsigned = true
                
            }
            
            inputArray.append(input)
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        
        if let cell = utxoTable.cellForRow(at: indexPath) {
            
            self.selectedArray[indexPath.row] = false
            
            let checkmark = cell.viewWithTag(13) as! UIImageView
            let cellTxid = (cell.viewWithTag(2) as! UILabel).text
            let cellVout = (cell.viewWithTag(6) as! UILabel).text
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    checkmark.alpha = 0
                    cell.alpha = 0
                    
                }) { _ in
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        cell.alpha = 1
                        cell.backgroundColor = self.view.backgroundColor
                        
                    })
                    
                }
                
            }
            
            if utxoToSpendArray.count > 0 {
                
                let txidProcessed = cellTxid?.replacingOccurrences(of: "txid: ", with: "")
                let voutProcessed = cellVout?.replacingOccurrences(of: "vout #", with: "")
                
                for (index, utxo) in (self.utxoToSpendArray as! [[String:Any]]).enumerated() {
                    
                    let txid = utxo["txid"] as! String
                    let vout = "\(utxo["vout"] as! Int)"
                    
                    if txid == txidProcessed && vout == voutProcessed {
                        
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
        
        if !isUsingSSH {
            
            executeNodeCommandTor(method: method,
                                  param: param)
            
        } else {
         
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.listlockunspent:
                        
                        lockedArray = makeSSHCall.arrayToReturn
                        
                        creatingView.removeConnectingView()
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToLocked", sender: self)
                            
                        }
                        
                    case BTC_CLI_COMMAND.lockunspent:
                        
                        let result = makeSSHCall.doubleToReturn
                        removeSpinner()
                        
                        if result == 1 {
                            
                            displayAlert(viewController: self.navigationController!,
                                         isError: false,
                                         message: "UTXO is locked and will not be selected for spends unless your node restarts, tap the lock button to unlock it")
                            
                            self.refresh()
                            
                        } else {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Unable to lock that UTXO")
                            
                        }
                        
                    case BTC_CLI_COMMAND.getnewaddress:
                        
                        let address = makeSSHCall.stringToReturn
                        let roundedAmount = rounded(number: self.amountTotal)
                        
                        let spendUtxo = SendUTXO()
                        spendUtxo.inputArray = self.inputArray
                        spendUtxo.ssh = self.ssh
                        spendUtxo.isUsingSSH = self.isUsingSSH
                        spendUtxo.sweep = true
                        spendUtxo.addressToPay = address
                        spendUtxo.amount = roundedAmount
                        spendUtxo.makeSSHCall = self.makeSSHCall
                        
                        func getResult() {
                            
                            if !spendUtxo.errorBool {
                                
                                let rawTx = spendUtxo.signedRawTx
                                
                                optimizeTheFee(raw: rawTx,
                                               amount: roundedAmount,
                                               addressToPay: address,
                                               sweep: true,
                                               inputArray: self.inputArray,
                                               changeAddress: "",
                                               changeAmount: 0.0)
                                
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
                        
                    case BTC_CLI_COMMAND.getrawchangeaddress:
                        
                        let changeAddress = makeSSHCall.stringToReturn
                        self.getRawTx(changeAddress: changeAddress)
                        
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
            
            if self.ssh != nil {
                
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
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        }
        
        
        
    }
    
    func executeNodeCommandTor(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !torRPC.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.listlockunspent:
                    
                    lockedArray = torRPC.arrayToReturn
                    
                    creatingView.removeConnectingView()
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToLocked", sender: self)
                        
                    }
                    
                case BTC_CLI_COMMAND.lockunspent:
                    
                    let result = torRPC.doubleToReturn
                    removeSpinner()
                    
                    if result == 1 {
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: false,
                                     message: "UTXO is locked and will not be selected for spends unless your node restarts, tap the lock button to unlock it")
                        
                        self.refresh()
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "Unable to lock that UTXO")
                        
                    }
                    
                case BTC_CLI_COMMAND.getnewaddress:
                    
                    let address = torRPC.stringToReturn
                    let roundedAmount = rounded(number: self.amountTotal)
                    
                    let spendUtxo = SendUTXO()
                    spendUtxo.inputArray = self.inputArray
                    spendUtxo.ssh = self.ssh
                    spendUtxo.isUsingSSH = self.isUsingSSH
                    spendUtxo.sweep = true
                    spendUtxo.addressToPay = address
                    spendUtxo.amount = roundedAmount
                    spendUtxo.torRPC = self.torRPC
                    spendUtxo.torClient = self.torClient
                    
                    func getResult() {
                        
                        if !spendUtxo.errorBool {
                            
                            let rawTx = spendUtxo.signedRawTx
                            
                            optimizeTheFee(raw: rawTx,
                                           amount: roundedAmount,
                                           addressToPay: address,
                                           sweep: true,
                                           inputArray: self.inputArray,
                                           changeAddress: "",
                                           changeAmount: 0.0)
                            
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
                    
                    let resultArray = torRPC.arrayToReturn
                    parseUnspent(utxos: resultArray)
                    
                case BTC_CLI_COMMAND.getrawchangeaddress:
                    
                    let changeAddress = torRPC.stringToReturn
                    self.getRawTx(changeAddress: changeAddress)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.removeSpinner()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: self.torRPC.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.torClient.isOperational {
            
            self.torRPC.executeRPCCommand(method: method,
                                          param: param,
                                          completion: getResult)
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Tor not connected")
            
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
    
    func configureScanner() {
        
        isFirstTime = true
        
        imageView.isUserInteractionEnabled = true
        blurView.isUserInteractionEnabled = true
        
        blurView.frame = CGRect(x: view.frame.minX + 10,
                                y: 100,
                                width: view.frame.width - 20,
                                height: 50)
        
        blurView.layer.cornerRadius = 10
        blurView.clipsToBounds = true
        
        imageView.alpha = 0
        imageView.frame = view.frame
        imageView.backgroundColor = UIColor.black
        
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.textField.delegate = self
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = imageView
        qrScanner.textFieldPlaceholder = "scan address QR or type/paste here"
        qrScanner.closeButton.alpha = 0
        
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        
        qrScanner.uploadButton.addTarget(self,
                                         action: #selector(self.chooseQRCodeFromLibrary),
                                         for: .touchUpInside)
        
        qrScanner.torchButton.addTarget(self,
                                        action: #selector(toggleTorch),
                                        for: .touchUpInside)
        
        isTorchOn = false
        
        let tapGesture2 = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissAddressKeyboard (_:)))
        
        tapGesture2.numberOfTapsRequired = 1
        self.imageView.addGestureRecognizer(tapGesture2)
        
    }
    
    func getAddress() {
        
        self.utxoTable.isUserInteractionEnabled = false
        scannerShowing = true
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.qrScanner.scanQRCode()
                self.addScannerButtons()
                self.imageView.addSubview(self.qrScanner.closeButton)
                self.isFirstTime = false
                self.imageView.alpha = 1
                self.blurView2.removeFromSuperview()
                self.creatingView.removeConnectingView()
                
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
    
    func getQRCode() {
        
        let stringURL = qrScanner.stringToReturn
        self.address = stringURL
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
    
    func getRawTx(changeAddress: String) {
        print("getRawTx")
        
        let dbl = Double(amountToSend)!
        let roundedAmount = rounded(number: dbl)
        
        var total = Double()
        
        for utxoDict in utxoToSpendArray {
            
            let utxo = utxoDict as! NSDictionary
            let amount = utxo["amount"] as! Double
            total += amount
            
        }
        // we set a dummy fee just to get a dummy raw transaction so we know what the size will be in order for fee estimation
        let changeAmount = total - (dbl + 0.00050000)
        
        let rawTransaction = SendUTXO()
        rawTransaction.addressToPay = self.address
        rawTransaction.changeAddress = changeAddress
        rawTransaction.amount = roundedAmount
        rawTransaction.changeAmount = rounded(number: changeAmount)
        rawTransaction.ssh = self.ssh
        rawTransaction.torClient = self.torClient
        rawTransaction.torRPC = self.torRPC
        rawTransaction.isUsingSSH = self.isUsingSSH
        rawTransaction.sweep = self.isSweeping
        rawTransaction.inputArray = self.inputArray
        rawTransaction.makeSSHCall = self.makeSSHCall
        
        func getResult() {
            
            if !rawTransaction.errorBool {
                
                let rawTxSigned = rawTransaction.signedRawTx
                //displayRaw(raw: rawTxSigned)
                
                optimizeTheFee(raw: rawTxSigned,
                               amount: roundedAmount,
                               addressToPay: self.address,
                               sweep: self.isSweeping,
                               inputArray: self.inputArray,
                               changeAddress: changeAddress,
                               changeAmount: rounded(number: changeAmount))
                
            } else {
                
                creatingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: rawTransaction.errorDescription)
                
            }
            
        }
        
        rawTransaction.createRawTransaction(completion: getResult)
        
    }
    
   func createRawNow() {
        
        if !isSweeping {
            
            //not sweeping so need to get change address
            self.executeNodeCommandSSH(method: BTC_CLI_COMMAND.getrawchangeaddress,
                                       param: "")
            
        } else {
            
            let dbl = Double(amountToSend)!
            let roundedAmount = rounded(number: dbl)
            
            let rawTransaction = SendUTXO()
            rawTransaction.addressToPay = self.address
            rawTransaction.amount = roundedAmount
            rawTransaction.ssh = self.ssh
            rawTransaction.makeSSHCall = self.makeSSHCall
            rawTransaction.torClient = self.torClient
            rawTransaction.torRPC = self.torRPC
            rawTransaction.isUsingSSH = self.isUsingSSH
            rawTransaction.sweep = self.isSweeping
            rawTransaction.inputArray = self.inputArray
            
            func getResult() {
                
                if !rawTransaction.errorBool {
                    
                    let rawTxSigned = rawTransaction.signedRawTx
                    
                    optimizeTheFee(raw: rawTxSigned,
                                   amount: roundedAmount,
                                   addressToPay: self.address,
                                   sweep: self.isSweeping,
                                   inputArray: self.inputArray,
                                   changeAddress: "",
                                   changeAmount: 0.0)
                    
                } else {
                    
                    creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: rawTransaction.errorDescription)
                    
                }
                
            }
            
            rawTransaction.createRawTransaction(completion: getResult)
            
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
            
            self.utxoTable.removeFromSuperview()
            
            self.rawDisplayer.rawString = raw
            self.rawDisplayer.vc = self
            
            if self.isUnsigned {
                
                self.navigationController?.navigationBar.topItem?.title = "Unsigned Tx"
                
            } else {
                
                self.navigationController?.navigationBar.topItem?.title = "Signed Tx"
                
            }
            
            self.tapQRGesture = UITapGestureRecognizer(target: self,
                                                  action: #selector(self.shareQRCode(_:)))
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                        action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            self.qrScanner.removeFromSuperview()
            self.imageView.removeFromSuperview()
            
            self.rawDisplayer.addRawDisplay()
            self.creatingView.removeConnectingView()
            
        }
        
    }
    
    func optimizeTheFee(raw: String, amount: Double, addressToPay: String, sweep: Bool, inputArray: [Any], changeAddress: String, changeAmount: Double) {
        
        let getSmartFee = GetSmartFee()
        getSmartFee.rawSigned = raw
        getSmartFee.ssh = self.ssh
        getSmartFee.makeSSHCall = self.makeSSHCall
        getSmartFee.vc = self
        getSmartFee.torRPC = self.torRPC
        getSmartFee.torClient = self.torClient
        getSmartFee.isUsingSSH = self.isUsingSSH
        
        func getFeeResult() {
            
            let optimalFee = rounded(number: getSmartFee.optimalFee)
            print("optimalFee = \(optimalFee)")
            
            let spendUtxo = SendUTXO()
            spendUtxo.ssh = self.ssh
            spendUtxo.isUsingSSH = self.isUsingSSH
            spendUtxo.makeSSHCall = self.makeSSHCall
            spendUtxo.torClient = self.torClient
            spendUtxo.torRPC = self.torRPC
            
            spendUtxo.sweep = sweep
            spendUtxo.addressToPay = addressToPay
            
            spendUtxo.inputArray = inputArray
            spendUtxo.changeAddress = changeAddress
            
            // sender always pays the fee
            if !sweep {
                
                // if not sweeping then nullify the fixed fee we added initially and then reduce the optimal fee from the change output, receiver gets what is intended
                let roundChange = rounded(number: (changeAmount + 0.00050000) - optimalFee)
                spendUtxo.changeAmount = roundChange
                let rnd = rounded(number: amount)
                spendUtxo.amount = rnd
                
            } else {
                
                // if sweeping just reduce the overall amount by the optimal fee
                let rnd = rounded(number: amount - optimalFee)
                spendUtxo.amount = rnd
                
            }
            
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
            
        }
        
        getSmartFee.getSmartFee(completion: getFeeResult)
        
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
        
        creatingView.addConnectingView(vc: self, description: "")
        
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        
        if textField != amountInput {
            
            if textField.text != "" {
                
                textField.becomeFirstResponder()
                
            } else {
                
                if let string = UIPasteboard.general.string {
                    
                    textField.resignFirstResponder()
                    textField.text = string
                    self.processBIP21(url: string)
                    
                } else {
                    
                    textField.becomeFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        
        if textField != amountInput {
            
            if textField.text != "" {
                
                self.processBIP21(url: textField.text!)
                
            }
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
        case "goToLocked":
            
            if let vc = segue.destination as? LockedTableViewController {
                
                vc.lockedArray = self.lockedArray
                
            }
            
        default:
            break
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



