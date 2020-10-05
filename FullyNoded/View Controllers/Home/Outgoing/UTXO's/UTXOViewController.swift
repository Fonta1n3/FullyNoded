//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UTXOViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    private var isSweeping = false
    private var amountToSend = String()
    private let amountInput = UITextField()
    private let amountView = UIView()
    private var rawSigned = ""
    private var psbt = ""
    private var amountTotal = 0.0
    private let refresher = UIRefreshControl()
    private var unlockedUtxos = [UtxosStruct]()
    private var inputArray = [Any]()
    private var address = ""
    private var selectedUTXOs = [UtxosStruct]()
    private var spinner = ConnectingView()
    private var nativeSegwit = Bool()
    private var p2shSegwit = Bool()
    private var legacy = Bool()
    private var isUnsigned = false
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private let blurView2 = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private let sweepButtonView = Bundle.main.loadNibNamed("KeyPadButtonView", owner: self, options: nil)?.first as! UIView?
    private var alertStyle = UIAlertController.Style.actionSheet
    
    @IBOutlet weak private var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        configureAmountView()
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(loadUnlockedUtxos), for: UIControl.Event.valueChanged)
        tableView.addSubview(refresher)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        blurView2.addGestureRecognizer(tapGesture)
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadUnlockedUtxos()
    }
    
    @IBAction private func lockAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "goToLocked", sender: self)
        }
    }
    
    // TODO: Go over this with Fontaine
    private func getAddressSettings() {
        
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
    
    @IBAction private func consolidate(_ sender: Any) {
        if unlockedUtxos.count > 0 {
            if selectedUTXOs.count > 0 {
                //consolidate selected utxos only
            } else {
                //consolidate them all
                for utxo in unlockedUtxos {
                    selectedUTXOs.append(utxo)
                }
            }
            getAddressSettings()
            updateInputs()
            self.spinner.addConnectingView(vc: self, description: "Consolidating UTXO's")
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
    
    private func configureAmountView() {
        
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
        amountInput.font = UIFont(name: "HiraginoSans-W3", size: 40)
        amountInput.tintColor = UIColor.white
        amountInput.inputAccessoryView = sweepButtonView
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sweepButtonClicked),
                                               name: NSNotification.Name(rawValue: "buttonClickedNotification"),
                                               object: nil)
        
        
    }
    // TODO: Talk to Fontaine
    private func amountAvailable(amount: Double) -> (Bool, String) {
        
        let amountAvailable = selectedUTXOs.map { $0.amount ?? 0.0 }.reduce(0, +)
        let string = amountAvailable.avoidNotation
        
        if amountAvailable >= amount {
            
            return (true, string)
            
        } else {
            
            return (false, string)
            
        }
        
    }
    
    @objc private func sweepButtonClicked() {
        
        isSweeping = true
        let amountToSweep = selectedUTXOs.map { $0.amount ?? 0.0 }.reduce(0, +)
        
        DispatchQueue.main.async {
            self.amountInput.text = amountToSweep.avoidNotation
        }
        
    }
    
    @objc private func closeAmount() {
        
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
    
    private func getAmount() {
        
        blurView2.removeFromSuperview()
        
        let label = UILabel()
        
        label.frame = CGRect(x: 0, y: 15, width: amountView.frame.width, height: 20)
        
        label.font = UIFont(name: "HiraginoSans-W3", size: 20)
        label.textColor = UIColor.darkGray
        label.textAlignment = .center
        label.text = "Amount to send"
        
        
        
        blurView2.alpha = 0
        
        blurView2.frame = CGRect(x: 0,
                                 y: -20,
                                 width: self.view.frame.width,
                                 height: self.view.frame.height + 20)
        
        self.view.addSubview(self.blurView2)
        self.view.addSubview(self.amountView)
        self.amountView.addSubview(self.amountInput)
        self.amountInput.text = "0.0"
        
        let button = UIButton()
        button.setImage(UIImage(systemName: "link"), for: .normal)
        button.frame = CGRect(x: 0, y: 140, width: self.amountView.frame.width, height: 60)
        button.addTarget(self, action: #selector(closeAmount), for: .touchUpInside)
        button.tintColor = .systemTeal
        
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
    
    private func updateSelectedUtxos() {
        selectedUTXOs.removeAll()
        
        for utxo in unlockedUtxos {
            if utxo.isSelected {
                selectedUTXOs.append(utxo)
            }
        }
    }
    
    @IBAction private func createRaw(_ sender: Any) {
        
        if selectedUTXOs.count > 0 {
            
            updateInputs()
//            DispatchQueue.main.async { [weak self] in
//                self?.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
//            }
//
            if inputArray.count > 0 {

                DispatchQueue.main.async {

                    self.getAmount()

                }

            } else {

                showAlert(vc: self, title: "Select a UTXO first", message: "The 🔗 button allows you to create a transaction using only the utxo's you select here, to select a utxo just tap it.")

            }
            
        } else {
            
            showAlert(vc: self, title: "Select a UTXO first", message: "")
            
        }
    }
    
    @objc private func dismissKeyboard(_ sender: UITapGestureRecognizer) {
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
    
    private func lock(_ utxo: UtxosStruct) {
        spinner.addConnectingView(vc: self, description: "locking...")
        
        let param = "false, [{\"txid\":\"\(utxo.txid)\",\"vout\":\(utxo.vout)}]"
        
        Reducer.makeCommand(command: .lockunspent, param: param) { (response, errorMessage) in
            guard let success = response as? Bool else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                }
                
                return
            }
            
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Only save UTXO's when they get locked, delete them from storage when they get unlocked.
                    self.saveUtxoLocally(utxo)
                    self.loadUnlockedUtxos()
                }
                
                showAlert(vc: self, title: "UTXO Locked 🔐", message: "You can tap the locked button to see your locked utxo's and unlock them. Be aware if your node reboots all utxo's will be unlocked by default!")
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: "utxo was not locked")
                }
                
            }
        }
    }
    
    private func updateInputs() {
        
        inputArray.removeAll()
        
        for utxo in selectedUTXOs {
            
            amountTotal += utxo.amount ?? 0.0
            let input = "{\"txid\":\"\(utxo.txid)\",\"vout\": \(utxo.vout),\"sequence\": 1}"
            
            if !(utxo.spendable ?? false) {
                
                isUnsigned = true
                
            }
            
            inputArray.append(input)
            
        }
        
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.updateSelectedUtxos()
            self.tableView.isUserInteractionEnabled = true
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: true)
            self.removeSpinner()
        }
    }
    
    @objc private func loadUnlockedUtxos() {
        unlockedUtxos.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.isUserInteractionEnabled = false
            self.addSpinner()
        }
        
        Reducer.makeCommand(command: .listunspent, param: "0") { (response, errorMessage) in
            guard let utxos = response as? NSArray else {
                self.finishedLoading()
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error fecthing your utxos")
                return
            }
            
            guard utxos.count > 0 else {
                self.finishedLoading()
                showAlert(vc: self, title: "No UTXO's", message: "")
                return
            }
            
            for (i, utxo) in utxos.enumerated() {
                guard let utxoDict = utxo as? [String:Any] else { return }
                self.unlockedUtxos.append(UtxosStruct(dictionary: utxoDict))
                
                if i + 1 == utxos.count {
                    self.unlockedUtxos = self.unlockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                    self.finishedLoading()
                }
            }
        }
    }
    
    private func saveUtxoLocally(_ utxo: UtxosStruct) {
        activeWallet { (wallet) in
            // Only save utxos for Fully Noded wallets
            guard let wallet = wallet else { return }
            
            var dict = [String:Any]()
            dict["txid"] = utxo.txid
            dict["vout"] = utxo.vout
            dict["label"] = utxo.label
            dict["id"] = UUID()
            dict["walletId"] = wallet.id
            dict["address"] = utxo.address
            dict["amount"] = utxo.amount
            dict["desc"] = utxo.desc
            dict["solvable"] = utxo.solvable
            dict["confirmations"] = utxo.confs
            dict["safe"] = utxo.safe
            dict["spendable"] = utxo.spendable
            
            CoreDataService.saveEntity(dict: dict, entityName: .utxos) { success in
                #if DEBUG
                print("saved utxo locally: \(success)")
                #endif
            }
        }
    }
    
    private func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        Reducer.makeCommand(command: method, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard errorMessage == nil else {
                DispatchQueue.main.async {
                    self.removeSpinner()
                    displayAlert(viewController: self, isError: true, message: errorMessage!)
                }
                return
            }
            
            switch method {
            case .getnewaddress:
                if let address = response as? String {
                    var total = Double()
                    var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
                    for utxo in self.selectedUTXOs { // TODO: Make method to adhere to DRY
                        miningFee += 0.00000100
                        total += utxo.amount ?? 0.0
                    }
                    let roundedAmount = rounded(number: total - miningFee)
                    let rawTransaction = SendUTXO()
                    rawTransaction.addressToPay = address
                    rawTransaction.sweep = true
                    rawTransaction.amount = roundedAmount
                    rawTransaction.inputArray = self.inputArray
                    rawTransaction.createRawTransaction { [weak self] (signedTx, psbt, errorMessage) in
                        if signedTx != nil {
                            self!.rawSigned = signedTx!
                            self!.displayRaw(raw: self!.rawSigned)
                        } else if psbt != nil {
                            self!.psbt = psbt!
                            self!.displayRaw(raw: self!.psbt)
                        } else {
                            self!.spinner.removeConnectingView()
                            displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                        }
                    }
                }
                
            case .getrawchangeaddress:
                if let changeAddress = response as? String {
                    self.getRawTx(changeAddress: changeAddress)
                }
                
            default:
                break
            }
            
        }
    }
    
    private func removeSpinner() {
        
        DispatchQueue.main.async {
            
            self.refresher.endRefreshing()
            self.spinner.removeConnectingView()
            
        }
        
    }
    
    private func addSpinner() {
        DispatchQueue.main.async {
            self.spinner.addConnectingView(vc: self, description: "Getting UTXOs")
        }
    }
    
    private func noAddressOnClipboard() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            
            let title = "You do not have a valid address copied on your clipboard"
            let message = "You can either copy a valid address or scan an address as a QR code to create a transaction using the selected utxo's. For the best experience copy the recipient address to your clipboard then select the utxo's you want to spend."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "scan an address", style: .default, handler: { action in
                self.performSegue(withIdentifier: "segueToGetAddressFromUtxos", sender: self)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getAddress() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.blurView2.removeFromSuperview()
            self.amountView.removeFromSuperview()
            self.amountInput.removeFromSuperview()
            
            guard let address = UIPasteboard.general.string, self.validAddress(address) else {
                self.noAddressOnClipboard()
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let title = "You have a valid address on your clipboard"
                let message = "Would you like to create a transaction that spends the selected utxo's to \(address)"
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: self.alertStyle)
                
                alert.addAction(UIAlertAction(title: "create transaction", style: .default, handler: { action in
                    self.spinner.addConnectingView(vc: self, description: "creating transaction...")
                    self.address = address
                    self.createRawNow()
                }))
                
                alert.addAction(UIAlertAction(title: "scan a different address", style: .default, handler: { action in
                    self.performSegue(withIdentifier: "segueToGetAddressFromUtxos", sender: self)
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func getRawTx(changeAddress: String) {
        let dbl = Double(amountToSend)! // TODO: Talk to Fontaine
        let roundedAmount = rounded(number: dbl)
        var total = Double()
        var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
        for utxo in selectedUTXOs { // TODO: Make method to adhere to DRY
            miningFee += 0.00000100
            total += utxo.amount ?? 0.0
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
                    self!.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                }
            }
        }
    }
    
   private func createRawNow() {
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
            var total = 0.0
            var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
            for utxo in selectedUTXOs { // TODO: Make method to adhere to DRY
                miningFee += 0.00000100
                total += utxo.amount ?? 0.0
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
                        self!.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                    }
                }
            }
        }
    }
    
    private func displayRaw(raw: String) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToBroadcasterFromUtxo", sender: self)
        }
    }
    
    // MARK: TEXTFIELD METHODS
    
    private func validAddress(_ string: String) -> Bool {
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: string).errorBool
        return !errorBool
    }
    
    private func processBIP21(url: String) {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "segueToSendFromUtxos":
            if let vc = segue.destination as? CreateRawTxViewController {
                vc.inputArray = inputArray
            }
            
//        case "getUTXOinfo":
//            if let vc = segue.destination as? GetInfoViewController, let utxo = sender as? UtxosStruct {
//                vc.configure(utxo: utxo)
//            }
            
        case "segueToGetAddressFromUtxos":
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { [weak self] address in
                    guard let address = address, let self = self else { return }
                    
                    self.spinner.addConnectingView(vc: self, description: "building psbt...")
                    self.processBIP21(url: address)
                }
            }
            
        case "segueToBroadcasterFromUtxo":
            if let vc = segue.destination as? VerifyTransactionViewController {
                spinner.removeConnectingView()
                if rawSigned != "" {
                    vc.signedRawTx = rawSigned
                } else if psbt != "" {
                    vc.unsignedPsbt = psbt
                }
            }
            
        default:
            break
        }
        
    }
    
}


// MARK: UTXOCellDelegate

extension UTXOViewController: UTXOCellDelegate {
    
    func didTapToLock(_ utxo: UtxosStruct) {
        lock(utxo)
    }
    
//    func didTapInfoFor(_ utxo: UtxosStruct) {
//        performSegue(withIdentifier: "getUTXOinfo", sender: utxo)
//    }
    
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: false, delegate: self)
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return unlockedUtxos.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
}


// MarK: UITableViewDelegate

extension UTXOViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 5 // Spacing between cells
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! UTXOCell
        let isSelected = unlockedUtxos[indexPath.section].isSelected
        
        if isSelected {
            cell.deselectedAnimation()
        } else {
            cell.selectedAnimation()
        }
        
        unlockedUtxos[indexPath.section].isSelected = !isSelected
        
        updateSelectedUtxos()
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
}
