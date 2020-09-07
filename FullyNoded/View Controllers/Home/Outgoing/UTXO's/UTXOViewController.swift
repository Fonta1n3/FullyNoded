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
    var rawSigned = ""
    var psbt = ""
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
    var isUnsigned = false
    var utxo = NSDictionary()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let blurView2 = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView", owner: self, options: nil)?.first as! UIView?
    @IBOutlet weak var utxoTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        utxoTable.delegate = self
        utxoTable.dataSource = self
        configureAmountView()
        utxoTable.tableFooterView = UIView(frame: .zero)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(refresh), for: UIControl.Event.valueChanged)
        utxoTable.addSubview(refresher)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.blurView2.addGestureRecognizer(tapGesture)
        NotificationCenter.default.addObserver(self, selector: #selector(reloadUtxos), name: .refreshUtxos, object: nil)
        refresh()
    }
    
    @objc func reloadUtxos() {
        refresh()
    }
    
    @IBAction func lockAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "goToLocked", sender: self)
        }
    }
    
    @IBAction func getUtxoInfo(_ sender: Any) {
        if self.utxoToSpendArray.count == 1 {
            
            DispatchQueue.main.async {
                
                self.utxo = self.utxoToSpendArray.last as! NSDictionary
                
                self.performSegue(withIdentifier: "getUTXOinfo", sender: self)
                
            }
            
        } else {
         
            displayAlert(viewController: self, isError: true, message: "select one utxo to get info for")
            
        }
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
            self.creatingView.addConnectingView(vc: self, description: "Consolidating UTXO's")
            if self.nativeSegwit {
                self.executeNodeCommand(method: .getnewaddress, param: "\"\", \"bech32\"")
            } else if self.legacy {
                self.executeNodeCommand(method: .getnewaddress, param: "\"\", \"legacy\"")
            } else if self.p2shSegwit {
                self.executeNodeCommand(method: .getnewaddress, param: "")
            }
        } else {
            displayAlert(viewController: self, isError: true, message: "No UTXO's to consolidate")
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
        
        let string = amountAvailable.avoidNotation
        
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
            
            self.amountInput.text = amountToSweep.avoidNotation
            
        }
        
    }
    
    @objc func closeAmount() {
        
        if self.amountInput.text != "" {
                        
            self.amountToSend = self.amountInput.text!
            
            let amount = Double(self.amountToSend)!
            
            if amountAvailable(amount: amount).0 {
                
                self.amountInput.resignFirstResponder()
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.amountView.frame = CGRect(x: 0, y: -200, width: self.view.frame.width, height: -200)
                }) { _ in
                    self.amountView.removeFromSuperview()
                    self.amountInput.removeFromSuperview()
                    self.getAddress()
                }
                
            } else {
                                
                let available = amountAvailable(amount: amount).1
                displayAlert(viewController: self, isError: true, message: "That UTXO only has \(available) BTC")
                
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
        
        label.frame = CGRect(x: 0, y: 15, width: amountView.frame.width, height: 20)
        
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
//            DispatchQueue.main.async { [weak self] in
//                self?.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
//            }
//
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
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        self.amountInput.resignFirstResponder()
        UIView.animate(withDuration: 0.2, animations: {
            self.amountView.frame = CGRect(x: 0, y: -200, width: self.view.frame.width, height: -200)
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
        executeNodeCommand(method: .listunspent, param: "0")
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return utxoArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "utxoCell", for: indexPath)
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        
        if utxoArray.count > 0 {
            
            let dict = utxoArray[indexPath.section] as! NSDictionary
            let address = cell.viewWithTag(1) as! UILabel
            let txid = cell.viewWithTag(2) as! UILabel
            let amount = cell.viewWithTag(4) as! UILabel
            let vout = cell.viewWithTag(6) as! UILabel
            let solvable = cell.viewWithTag(7) as! UILabel
            let confs = cell.viewWithTag(8) as! UILabel
            let spendable = cell.viewWithTag(10) as! UILabel
            let checkMark = cell.viewWithTag(13) as! UIImageView
            let label = cell.viewWithTag(11) as! UILabel
            
            if !(selectedArray[indexPath.section]) {
                
                checkMark.alpha = 0
                cell.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
                
            } else {
                
                checkMark.alpha = 1
                cell.backgroundColor = UIColor.black
                
            }
            
            for (key, value) in dict {
                
                let keyString = key as! String
                
                switch keyString {
                    
                case "txid":
                    txid.text = "\(value)"
                    
                case "address":
                    
                    address.text = "\(value)"
                    
                case "amount":
                    
                    let dbl = rounded(number: value as! Double)
                    amount.text = dbl.avoidNotation
                    
                case "vout":
                    
                    vout.text = "vout #\(value)"
                    
                case "solvable":
                    
                    if (value as! Int) == 1 {
                        
                        solvable.text = "Solvable"
                        solvable.textColor = .systemGreen
                        
                    } else if (value as! Int) == 0 {
                        
                        solvable.text = "Not Solvable"
                        solvable.textColor = .systemBlue
                        
                    }
                    
                case "confirmations":
                    
                    if (value as! Int) == 0 {
                     
                        confs.textColor = .systemRed
                        
                    } else {
                        
                        confs.textColor = .systemGreen
                        
                    }
                    
                    confs.text = "\(value) confs"
                    
               case "spendable":
                    
                    if (value as! Int) == 1 {
                        
                        spendable.text = "Spendable"
                        spendable.textColor = .systemGreen
                        
                    } else if (value as! Int) == 0 {
                        
                        spendable.text = "COLD"
                        spendable.textColor = .systemBlue
                        
                    }
                    
                case "label":
                    
                    label.text = (value as! String)
                    
                default:
                    
                    break
                    
                }
                
            }
            
        }
        
        return cell
        
    }
    
    @objc func lockViaButton(_ sender: UIButton) {
        let utxo = utxoArray[sender.tag] as! [String:Any]
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        lockUTXO(txid: txid, vout: vout)
    }
    
    func lockUTXO(txid: String, vout: Int) {
        creatingView.addConnectingView(vc: self, description: "locking...")
        let param = "false, ''[{\"txid\":\"\(txid)\",\"vout\":\(vout)}]''"
        executeNodeCommand(method: .lockunspent, param: param)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let utxos = utxoArray as NSArray
        let utxo = utxos[indexPath.section] as! NSDictionary
        let txid = utxo["txid"] as! String
        let vout = utxo["vout"] as! Int
        let lock = UIContextualAction(style: .destructive, title: "Lock") {  (contextualAction, view, boolValue) in
            self.lockUTXO(txid: txid, vout: vout)
        }
        lock.backgroundColor = .systemRed
        let swipeActions = UISwipeActionsConfiguration(actions: [lock])
        return swipeActions
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = utxoTable.cellForRow(at: indexPath)
        let checkmark = cell?.viewWithTag(13) as! UIImageView
        cell?.isSelected = true
        
        self.selectedArray[indexPath.section] = true
        
        DispatchQueue.main.async {
            
            impact()
            
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
        
        utxoToSpendArray.append(utxoArray[indexPath.section] as! [String:Any])
        
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
            
            self.selectedArray[indexPath.section] = false
            
            let checkmark = cell.viewWithTag(13) as! UIImageView
            let cellTxid = (cell.viewWithTag(2) as! UILabel).text
            let cellVout = (cell.viewWithTag(6) as! UILabel).text
            impact()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    checkmark.alpha = 0
                    cell.alpha = 0
                    
                }) { _ in
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        cell.alpha = 1
                        cell.backgroundColor = #colorLiteral(red: 0.07831101865, green: 0.08237650245, blue: 0.08238270134, alpha: 1)
                        
                    }, completion: { _ in
                        
                        if self.utxoToSpendArray.count > 0 {
                            
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
                        
                    })
                    
                }
                
            }
            
        }
        
    }
    
    func parseUnspent(utxos: NSArray) {
        if utxos.count > 0 {
            utxoArray = (utxos as NSArray).sortedArray(using: [NSSortDescriptor(key: "confirmations", ascending: true)]) as! [[String:AnyObject]]
            for _ in utxoArray {
                self.selectedArray.append(false)
            }
            DispatchQueue.main.async {
                self.removeSpinner()
                self.utxoTable.reloadData()
                self.executeNodeCommand(method: .getnetworkinfo, param: "")
            }
        } else {
            self.removeSpinner()
            displayAlert(viewController: self, isError: true, message: "No UTXO's")
        }
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        Reducer.makeCommand(command: method, param: param) { [weak self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                    
                case .lockunspent:
                    if self != nil {
                        if let result = response as? Double {
                            self!.removeSpinner()
                            if result == 1 {
                                displayAlert(viewController: self, isError: false, message: "UTXO is locked and will not be selected for spends unless your node restarts, tap the lock button to unlock it")
                                self!.creatingView.removeConnectingView()
                                self!.refresh()
                            } else {
                                displayAlert(viewController: self, isError: true, message: "Unable to lock that UTXO")
                            }
                        }
                    }
                    
                case .getnewaddress:
                    if self != nil {
                        if let address = response as? String {
                            var total = Double()
                            var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
                            for utxoDict in self!.utxoToSpendArray {
                                let utxo = utxoDict as! NSDictionary
                                let amount = utxo["amount"] as! Double
                                miningFee += 0.00000100
                                total += amount
                            }
                            let roundedAmount = rounded(number: total - miningFee)
                            let rawTransaction = SendUTXO()
                            rawTransaction.addressToPay = address
                            rawTransaction.sweep = true
                            rawTransaction.amount = roundedAmount
                            rawTransaction.inputArray = self!.inputArray
                            rawTransaction.createRawTransaction { [weak self] (signedTx, psbt, errorMessage) in
                                if signedTx != nil {
                                    self!.rawSigned = signedTx!
                                    self!.displayRaw(raw: self!.rawSigned)
                                } else if psbt != nil {
                                    self!.psbt = psbt!
                                    self!.displayRaw(raw: self!.psbt)
                                } else {
                                    self!.creatingView.removeConnectingView()
                                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                                }
                            }
                        }
                    }
                    
                case .listunspent:
                    if let resultArray = response as? NSArray {
                        self?.parseUnspent(utxos: resultArray)
                    }
                    
                case .getrawchangeaddress:
                    if let changeAddress = response as? String {
                        self?.getRawTx(changeAddress: changeAddress)
                    }
                    
                default:
                    break
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.removeSpinner()
                    displayAlert(viewController: self, isError: true, message: errorMessage!)
                }
            }
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
            self.creatingView.addConnectingView(vc: self, description: "Getting UTXOs")
        }
    }
    
    func getAddress() {
        DispatchQueue.main.async { [weak self] in
            self?.blurView2.removeFromSuperview()
            self?.amountView.removeFromSuperview()
            self?.amountInput.removeFromSuperview()
            self?.performSegue(withIdentifier: "segueToGetAddressFromUtxos", sender: self)
        }
    }
    
    func getRawTx(changeAddress: String) {
        let dbl = Double(amountToSend)!
        let roundedAmount = rounded(number: dbl)
        var total = Double()
        var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
        for utxoDict in utxoToSpendArray {
            let utxo = utxoDict as! NSDictionary
            let amount = utxo["amount"] as! Double
            miningFee += 0.00000100
            total += amount
        }
        let changeAmount = (total - dbl) - miningFee
        let rawTransaction = SendUTXO()
        rawTransaction.addressToPay = self.address
        rawTransaction.changeAddress = changeAddress
        rawTransaction.amount = roundedAmount
        rawTransaction.changeAmount = rounded(number: changeAmount)
        rawTransaction.sweep = self.isSweeping
        rawTransaction.inputArray = self.inputArray
        rawTransaction.createRawTransaction { [weak self] (signedTx, psbt, errorMessage) in
            if self != nil {
                if signedTx != nil {
                    self!.rawSigned = signedTx!
                    self!.displayRaw(raw: self!.rawSigned)
                } else if psbt != nil {
                    self!.psbt = psbt!
                    self!.displayRaw(raw: self!.psbt)
                } else {
                    self!.creatingView.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                }
            }
        }
    }
    
   func createRawNow() {
        if !isSweeping {
            activeWallet { [weak self] (wallet) in
                if wallet != nil {
                    if wallet!.type == "Multi-Sig" {
                        let index = Int(wallet!.index) + 1
                        CoreDataService.update(id: wallet!.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { (success) in
                            if success {
                                Reducer.makeCommand(command: .deriveaddresses, param: "\"\(wallet!.changeDescriptor)\", [\(index),\(index)]") { (response, errorMessage) in
                                    if self != nil {
                                        if let result = response as? NSArray {
                                            if let changeAddress = result[0] as? String {
                                                self!.getRawTx(changeAddress: changeAddress)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        if self != nil {
                            self!.executeNodeCommand(method: .getrawchangeaddress, param: "")
                        }
                        
                    }
                } else {
                    if self != nil {
                        self!.executeNodeCommand(method: .getrawchangeaddress, param: "")
                    }
                    
                }
            }
            
        } else {
            var total = Double()
            var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
            for utxoDict in self.utxoToSpendArray {
                let utxo = utxoDict as! NSDictionary
                let amount = utxo["amount"] as! Double
                miningFee += 0.00000100
                total += amount
            }
            let roundedAmount = rounded(number: total - miningFee)
            let rawTransaction = SendUTXO()
            rawTransaction.addressToPay = self.address
            rawTransaction.sweep = true
            rawTransaction.amount = roundedAmount
            rawTransaction.inputArray = self.inputArray
            rawTransaction.createRawTransaction { [weak self] (signedTx, psbt, errorMessage) in
                if self != nil {
                    if signedTx != nil {
                        self!.rawSigned = signedTx!
                        self!.displayRaw(raw: self!.rawSigned)
                    } else if psbt != nil {
                        self!.psbt = psbt!
                        self!.displayRaw(raw: psbt!)
                    } else {
                        self!.creatingView.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                    }
                }
            }
        }
    }
    
    func displayRaw(raw: String) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToBroadcasterFromUtxo", sender: self)
        }
    }
    
    // MARK: TEXTFIELD METHODS
    
    func processBIP21(url: String) {
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        if !errorBool {
            self.address = addressParser.parseAddress(url: url).address
            DispatchQueue.main.async { [weak self] in
                if self != nil {
                    self!.blurView.removeFromSuperview()
                    self!.createRawNow()
                }
            }
        } else {
            displayAlert(viewController: self, isError: true, message: errorDescription)
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
                
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let lockButton = UIButton()
        let lockImage = UIImage(systemName: "lock")!
        lockButton.tag = section
        lockButton.tintColor = .systemTeal
        lockButton.setImage(lockImage, for: .normal)
        lockButton.addTarget(self, action: #selector(lockViaButton(_:)), for: .touchUpInside)
        lockButton.frame = CGRect(x: header.frame.maxX - 60, y: 0, width: 50, height: 50)
        lockButton.center.y = header.center.y
        header.addSubview(lockButton)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "segueToSendFromUtxos":
            if let vc = segue.destination as? CreateRawTxViewController {
                vc.inputArray = inputArray
            }
            
        case "getUTXOinfo":
            if let vc = segue.destination as? GetInfoViewController {
                vc.utxo = utxo
                vc.isUtxo = true
            }
            
        case "segueToGetAddressFromUtxos":
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { [unowned thisVc = self] address in
                    if address != nil {
                        thisVc.creatingView.addConnectingView(vc: thisVc, description: "building psbt...")
                        thisVc.processBIP21(url: address!)
                    }
                }
            }
            
        case "segueToBroadcasterFromUtxo":
            if let vc = segue.destination as? SignerViewController {
                creatingView.removeConnectingView()
                if rawSigned != "" {
                    vc.txn = rawSigned
                    vc.broadcast = true
                } else if psbt != "" {
                    vc.psbt = psbt
                    vc.export = true
                }
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



