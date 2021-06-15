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
    private var alertStyle = UIAlertController.Style.actionSheet
    var fxRate:Double?
    
    @IBOutlet weak private var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(loadUnlockedUtxos), for: UIControl.Event.valueChanged)
        tableView.addSubview(refresher)
        
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
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "goToLocked", sender: self)
        }
    }
    
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
            
            var param = ""
            
            if self.nativeSegwit {
                param = "\"\", \"bech32\""
            } else if self.legacy {
                param = "\"\", \"legacy\""
            }
            
            activeWallet { wallet in
                guard let wallet = wallet else { return }
                
                let descriptorParser = DescriptorParser()
                let descriptorStruct = descriptorParser.descriptor(wallet.receiveDescriptor)
                
                guard descriptorStruct.isMulti else {
                    self.executeNodeCommand(method: .getnewaddress, param: param)
                    return
                }
                
                let index = Int(wallet.index) + 1
                
                CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(index), entity: .wallets) { success in
                    if success {
                        Reducer.makeCommand(command: .deriveaddresses, param: "\"\(wallet.receiveDescriptor)\", [\(index),\(index)]") { (response, errorMessage) in
                            guard let result = response as? NSArray, let changeAddress = result[0] as? String else {
                                showAlert(vc: self, title: "Uhoh", message: "There was an issue getting an address to consolidate your multisig wallet to: \(errorMessage ?? "unknown")")
                                return
                            }
                            
                            self.consolidateToAddress(changeAddress)
                        }
                    }
                }
            }
        } else {
            displayAlert(viewController: self, isError: true, message: "No UTXO's to consolidate")
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
        guard let version = UserDefaults.standard.object(forKey: "version") as? String, version.contains("0.21.") else {
            showAlert(vc: self, title: "Bitcoin Core needs to be updated", message: "Manual utxo selection requires Bitcoin Core 0.21, please update and try again. If you already have 0.21 go to the home screen, refresh and load it completely then try again.")
            
            return
        }
        
        if self.selectedUTXOs.count > 0 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.updateInputs()
                self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
            }
            
        } else {
            showAlert(vc: self, title: "Select a UTXO first", message: "Just tap a utxo(s) to select it. Then tap the 🔗 to create a transaction with those utxos.")
        }
    }
    
    private func editLabel(_ utxo: UtxosStruct) {
        guard let address = utxo.address, let isHot = utxo.spendable else {
            showAlert(vc: self, title: "Ooops", message: "We not have an address or info on whether that utxo is watch-only or not.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit utxo label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                guard let textFields = alert.textFields, let label = textFields[0].text else {
                    showAlert(vc: self, title: "Ooops", message: "Something went wrong here, the textfield is not accessible...")
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "updating utxo label")
                
                let param = "[{ \"scriptPubKey\": { \"address\": \"\(address)\" }, \"label\": \"\(label)\", \"timestamp\": \"now\", \"watchonly\": \(!isHot), \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                
                Reducer.makeCommand(command: .importmulti, param: param) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard let result = response as? NSArray,
                        let dict = result[0] as? NSDictionary,
                        let success = dict["success"] as? Bool,
                        success else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Something went wrong...", message: "error: \(errorMessage ?? "unknown error")")
                        return
                    }
                    
                    showAlert(vc: self, title: "Label updated ✅", message: "")
                    
                    DispatchQueue.main.async { [weak self] in
                        self?.loadUnlockedUtxos()
                    }
                    
                    self.spinner.removeConnectingView()
                }
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = "Add a Label"
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
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
                let utxoStr = UtxosStruct(dictionary: utxoDict)
                self.unlockedUtxos.append(utxoStr)
                
                if i + 1 == utxos.count {
                    self.unlockedUtxos = self.unlockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                    self.finishedLoading()
                }
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
                    self.consolidateToAddress(address)
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
    
    private func consolidateToAddress(_ address: String) {
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
    
    private func getRawTx(changeAddress: String) {
        let dbl = amountToSend.doubleValue
        let roundedAmount = rounded(number: dbl)
        var total = Double()
        var miningFee = 0.00000100//No good way to do fee estimation when manually selecting utxos (for now), if the wallet knows about the utxo's we can set a low ball fee and always use rbf. For now we hardcode 100 sats per input as the fee.
        for utxo in selectedUTXOs {
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
            for utxo in selectedUTXOs {
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "goToLocked":
            guard let vc = segue.destination as? LockedViewController else { fallthrough }
            
            vc.fxRate = fxRate
            
        case "segueToSendFromUtxos":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            vc.inputArray = inputArray
            vc.utxoTotal = amountTotal
            
        case "segueToBroadcasterFromUtxo":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            spinner.removeConnectingView()
            if rawSigned != "" {
                vc.signedRawTx = rawSigned
            } else if psbt != "" {
                vc.unsignedPsbt = psbt
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
    
    func didTapToEditLabel(_ utxo: UtxosStruct) {
        editLabel(utxo)
    }
    
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: false, fxRate: fxRate, delegate: self)
        
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
