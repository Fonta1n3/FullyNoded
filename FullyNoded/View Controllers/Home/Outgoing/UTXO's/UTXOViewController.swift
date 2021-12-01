//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UTXOViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    private var amountTotal = 0.0
    private let refresher = UIRefreshControl()
    private var unlockedUtxos = [Utxo]()
    private var inputArray = [String]()
    private var selectedUTXOs = [Utxo]()
    private var spinner = ConnectingView()
    private var wallet:Wallet?
    private var psbt:String?
    private var depositAddress:String?
    private var isJmarketWallet = false
    private var isJmarket = false
    var fxRate:Double?
    var isBtc = false
    var isSats = false
    var isFiat = false
    private var jmWallet:JMWallet?
    
    @IBOutlet weak private var jmMixOutlet: UIBarButtonItem!
    
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
        jmMixOutlet.tintColor = .clear
        
        activeWallet { wallet in
            guard let wallet = wallet else {
                return
            }
            
            self.wallet = wallet
            
            CoreDataService.retrieveEntity(entityName: .jmWallets) { jmwallets in
                guard let jmwallets = jmwallets, !jmwallets.isEmpty else {
                    return
                }
                
                for jmwallet in jmwallets {
                    let str = JMWallet(jmwallet)
                    if str.fnWallet == wallet.name {
                        self.jmMixOutlet.tintColor = .systemTeal
                        self.isJmarketWallet = true
                        self.jmWallet = str
                    }
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        unlockedUtxos.removeAll()
        selectedUTXOs.removeAll()
        inputArray.removeAll()
        loadUnlockedUtxos()
    }
    
    @IBAction func mixAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "checking JM session status...")
        
        JMUtils.session { (response, message) in
            self.spinner.removeConnectingView()
            
            guard let session = response else {
                showAlert(vc: self, title: "Unable to fetch sesssion...", message: message ?? "Unknown error.")
                return
            }
            
            guard !session.coinjoin_in_process else {
                showAlert(vc: self, title: "Coinjoin already in process...", message: "Only one coinjoin session can be active at a time.")
                return
            }
            
            if self.unlockedUtxos.count > 1 {
                self.warnAboutCoinControl()
            } else {
                self.joinNow()
            }
        }
    }
    
    private func warnAboutCoinControl() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Join Market"
            let mess = "Ensure you lock any utxos you do *not* want to be used in the Join market transaction! Currently utxo selection is not supported by Join Market."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Join now", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                
                self.isJmarket = true
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Lock utxos first", style: .default, handler: { _ in }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func joinNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Join?"
            let mess = "This action will create a coinjoin transaction to the address of your choice. Select a recipient and amount as normal. The fees will be determined as per your Join Market config."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                
                self.isJmarket = true
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func divideAction(_ sender: Any) {
        guard selectedUTXOs.count > 0 else {
            showAlert(vc: self, title: "Select some utxos first.", message: "")
            return
        }
        
        promptToDivide()
    }
    
    private func promptToDivide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Divide selected utxos?"
            let mess = "This action will divide the selected utxos into identical amounts. Choose an amount."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            let denomArray = [0.5, 0.05, 0.2, 0.02, 0.1, 0.01, 0.001]
            
            for denom in denomArray {
                alert.addAction(UIAlertAction(title: "\(denom) btc", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.divideNow(denom: denom)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func divideNow(denom: Double) {
        spinner.addConnectingView(vc: self, description: "dividing...")
        updateInputs()
        
        var totalAmount = 0.0
        
        for utxo in selectedUTXOs {
            if let amount = utxo.amount, amount > 0.00000200 {
                totalAmount += amount - 0.00000200
            }
        }
        
        let numberOfOutputs = Int(totalAmount / denom)
        
        let inputs = inputArray.processedInputs
        
        guard let wallet = self.wallet else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "This feature is only available for Fully Noded wallets.")
            return
        }
        
        let startIndex = Int(wallet.index + 1)
        let stopIndex = (startIndex - 1) + numberOfOutputs
        let descriptor = wallet.receiveDescriptor
        
        Reducer.makeCommand(command: .deriveaddresses, param: "\"\(descriptor)\", [\(startIndex),\(stopIndex)]") { (response, errorMessage) in
            guard let addresses = response as? [String] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "addresses not returned...", message: errorMessage ?? "unknown error.")
                return
            }
            
            var outputs = [[String:Any]]()
                        
            for addr in addresses {
                let output:[String:Any] = [addr:denom]
                outputs.append(output)
            }
            
            CreatePSBT.create(inputs: inputs, outputs: outputs.processedOutputs) { (psbt, rawTx, errorMessage) in
                guard let psbt = psbt else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "psbt not returned...", message: errorMessage ?? "unknown error.")
                    return
                }
                
                self.psbt = psbt
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    self.performSegue(withIdentifier: "segueToBroadcasterFromUtxo", sender: self)
                }
            }
        }
    }
    
    
    @IBAction private func lockAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "goToLocked", sender: self)
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
        guard let version = UserDefaults.standard.object(forKey: "version") as? Int, version >= 210000 else {
            showAlert(vc: self, title: "Bitcoin Core needs to be updated",
                      message: "Manual utxo selection requires Bitcoin Core 0.21, please update and try again. If you already have 0.21 go to the home screen, refresh and load it completely then try again.")
            
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
    
    private func editLabel(_ utxo: Utxo) {
        guard let wallet = self.wallet else { return }
        
        let descStruct = Descriptor(wallet.receiveDescriptor)
        
        guard let address = utxo.address else {
            showAlert(vc: self, title: "Ooops", message: "We do not have an address or info on whether that utxo is watch-only or not.")
            return
        }
        
        let isHot = descStruct.isHot
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit utxo label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                guard let textFields = alert.textFields, let label = textFields[0].text else {
                    showAlert(vc: self, title: "Ooops", message: "Something went wrong here, the textfield is not accessible...")
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "updating utxo label")
                
                // need to check if its a native descriptor wallet then add label
                
                if wallet.type == WalletType.descriptor.stringValue {
                    guard let desc = utxo.desc else { return }
                    
                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(label)\"}]"
                    self.importdesc(params: params, utxo: utxo, label: label)
                    
                } else {
                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(address)\" }, \"label\": \"\(label)\", \"timestamp\": \"now\", \"watchonly\": \(!isHot), \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                    self.importmulti(param: param, utxo: utxo, label: label)
                }
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = "add a label"
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func importdesc(params: String, utxo: Utxo, label: String) {
        Reducer.makeCommand(command: .importdescriptors, param: params) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            self.updateLocally(utxo: utxo, label: label)
        }
    }
    
    private func importmulti(param: String, utxo: Utxo, label: String) {
        OnchainUtils.importMulti(param) { (imported, message) in
            if imported {
                self.updateLocally(utxo: utxo, label: label)
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Something went wrong...", message: "error: \(message ?? "unknown error")")
            }
        }
    }
    
    private func updateLocally(utxo: Utxo, label: String) {
        func saved() {
            showAlert(vc: self, title: "Label updated ✅", message: "")
            
            DispatchQueue.main.async { [weak self] in
                self?.loadUnlockedUtxos()
            }
            
            self.spinner.removeConnectingView()
        }
        
        CoreDataService.retrieveEntity(entityName: .utxos) { savedUtxos in
            guard let savedUtxos = savedUtxos, savedUtxos.count > 0 else {
                saved()
                return
            }
            
            for savedUtxo in savedUtxos {
                let savedUtxoStr = Utxo(savedUtxo)
                
                if savedUtxoStr.txid == utxo.txid && savedUtxoStr.vout == utxo.vout {
                    CoreDataService.update(id: savedUtxoStr.id!, keyToUpdate: "label", newValue: label as Any, entity: .utxos) { _ in }
                }
            }
            
            saved()
        }
    }
    
    private func lock(_ utxo: Utxo) {
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
        
        OnchainUtils.listUnspent(param: "0") { [weak self] (utxos, message) in
            guard let self = self else { return }
            
            guard let utxos = utxos else {
                self.finishedLoading()
                showAlert(vc: self, title: "Error", message: message ?? "unknown error fecthing your utxos")
                return
            }
            
            guard utxos.count > 0 else {
                self.finishedLoading()
                showAlert(vc: self, title: "No UTXO's", message: "")
                return
            }
            
            for (i, utxo) in utxos.enumerated() {
                var dateToSave:Date?
                var txUUID:UUID?
                var capGain:String?
                var originValue:String?
                var amountFiat:String?
                
                var utxoDict = utxo.dict
                utxoDict["isJoinMarket"] = self.isJmarketWallet
                
                func finish() {
                    self.unlockedUtxos.append(Utxo(utxoDict))
                    
                    if i + 1 == utxos.count {
                        self.unlockedUtxos = self.unlockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                        
                        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] savedUtxos in
                            guard let self = self else { return }
                            
                            guard let savedUtxos = savedUtxos, savedUtxos.count > 0 else {
                                self.finishedLoading()
                                
                                return
                            }
                            
                            for (u, unlockedUtxo) in self.unlockedUtxos.enumerated() {
                                
                                func loopSavedUtxos() {
                                    for (s, savedUtxo) in savedUtxos.enumerated() {
                                        let savedUtxoStr = Utxo(savedUtxo)
                                        
                                        /// We always use the Bitcoin Core address label as the utxo label, when recovering with a new node the user will see the
                                        /// label the user added via Fully Noded. Fully Noded automatically saves the utxo labels.
                                        
                                        if let wallet = self.wallet {
                                            
                                            if savedUtxoStr.txid == unlockedUtxo.txid && savedUtxoStr.vout == unlockedUtxo.vout && wallet.label != savedUtxoStr.label {
                                                self.unlockedUtxos[i].label = savedUtxoStr.label
                                                
//                                                if wallet.type == WalletType.descriptor.stringValue {
//                                                    guard let desc = unlockedUtxo.desc else { return }
//
//                                                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(savedUtxoStr.label ?? "")\"}]"
//
//                                                    Reducer.makeCommand(command: .importdescriptors, param: params) { (_, _) in }
//
//                                                } else {
//                                                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(unlockedUtxo.address!)\" }, \"label\": \"\(savedUtxoStr.label ?? "")\", \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
//
//                                                    Reducer.makeCommand(command: .importmulti, param: param) { (_, _) in }
//                                                }
                                            }
                                        }
                                        
                                        if s + 1 == savedUtxos.count && u + 1 == self.unlockedUtxos.count {
                                            self.finishedLoading()
                                        }
                                    }
                                }
                                
                                if unlockedUtxo.label == "" || unlockedUtxo.label == self.wallet?.label {
                                    loopSavedUtxos()
                                } else if u + 1 == self.unlockedUtxos.count {
                                    self.finishedLoading()
                                }
                            }
                        }
                    }
                }
                
                let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
                let amountBtc = utxo.amount!
                utxoDict["amountSats"] = amountBtc.sats
                utxoDict["lifehash"] = LifeHash.image(utxo.address ?? "")
                
                CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                    if let txs = txs, txs.count > 0 {
                        
                        for (i, tx) in txs.enumerated() {
                            let txStruct = TransactionStruct(dictionary: tx)
                            
                            if txStruct.txid == utxo.txid {
                                dateToSave = txStruct.date
                                txUUID = txStruct.id
                                
                                if txStruct.fiatCurrency == currency, let currentFxRate = self.fxRate {
                                    let currentFiatValue = currentFxRate * amountBtc
                                    amountFiat = currentFiatValue.fiatString
                                    
                                    if let originRate = txStruct.fxRate {
                                        let originFiatValue = originRate * amountBtc
                                        var gain = currentFiatValue - originFiatValue
                                        
                                        if originFiatValue > 0 {
                                            originValue = originFiatValue.fiatString
                                            
                                            if gain > 1.0 {
                                                let ratio = gain / originFiatValue
                                                let percentage = Int(ratio * 100.0)
                                                
                                                if percentage > 1 {
                                                    capGain = "gain of \(gain.fiatString) / \(percentage)%"
                                                } else {
                                                    capGain = "gain of \(gain.fiatString)"
                                                }
                                                
                                            } else if gain < 0.0 {
                                                gain = gain * -1.0
                                                let ratio = gain / originFiatValue
                                                let percentage = Int(ratio * 100.0)
                                                
                                                if percentage > 1 {
                                                    capGain = "loss of \(gain.fiatString) / \(percentage)%"
                                                } else {
                                                    capGain = "loss of \(gain.fiatString)"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if i + 1 == txs.count {
                                utxoDict["capGain"] = capGain
                                utxoDict["originValue"] = originValue
                                utxoDict["date"] = dateToSave
                                utxoDict["txUUID"] = txUUID
                                utxoDict["amountFiat"] = amountFiat
                                finish()
                            }
                        }
                    } else {
                        finish()
                    }
                }
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
    
    private func fetchOriginRate(_ utxo: Utxo) {
        guard let date = utxo.date, let id = utxo.txUUID else {
            showAlert(vc: self, title: "", message: "Date or saved tx UUID missing.")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let today = dateFormatter.string(from: Date())
        
        if dateString == today {
            showAlert(vc: self, title: "", message: "You need to wait for the transaction to be at least one day old before fetching the historic rate.")
        } else {
            self.spinner.addConnectingView(vc: self, description: "")
            
            FiatConverter.sharedInstance.getOriginRate(date: dateString) { [weak self] originRate in
                guard let self = self else { return }
                
                guard let originRate = originRate else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "There was an issue fetching the historic exchange rate, please let us know about it.")
                    return
                }
                
                CoreDataService.update(id: id, keyToUpdate: "originFxRate", newValue: originRate, entity: .transactions) { [weak self] success in
                    guard let self = self else { return }
                    
                    guard success else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "", message: "There was an issue saving the historic exchange rate, please let us know about it.")
                        return
                    }
                    
                    self.loadUnlockedUtxos()
                }
            }
        }
    }
        
    private func depositNow(_ utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for (i, unlockedUtxo) in self.unlockedUtxos.enumerated() {
                if unlockedUtxo.id == utxo.id && unlockedUtxo.txid == utxo.txid && unlockedUtxo.vout == utxo.vout {
                    self.unlockedUtxos[i].isSelected = true
                    self.updateSelectedUtxos()
                    self.updateInputs()
                }
                
                if i + 1 == self.unlockedUtxos.count {
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }
        }
    }
    
    
    
//    private func mix(_ utxo: Utxo) {
//
////        Keys.privKey(descriptor.derivation, descriptor.pubkey) { (privKey, errorMessage) in
////            guard let privKey = privKey else {
////                let defaultError = "We were unable to derive a private key from any of your signers which can spend for this utxo."
////
////                showAlert(vc: self,
////                          title: "Something went wrong...",
////                          message: errorMessage ?? defaultError)
////
////                return
////            }
////
////            // MARK: RAJ TODO
////            // You will need to convert the privkey from data to a 256 bit integer and then supply it to your code for creating a commitment.
////            // BigInt is already added to the project, just import the module to use it.
////            // Once you have the commitment simply supply it as a string to the below line of code:
////
////            utxoToMix.commitment = "<insert commitment here>"
////
////            let jm = JoinMarketPit.sharedInstance
////            let taker = Taker.shared
////
////            guard jm.absOffers.count > 0 || jm.relOffers.count > 0 else {
////                showAlert(vc: self, title: "", message: "No offers...")
////                return
////            }
////
////            if jm.absOffers.count > 0 {
////                jm.absOffers.sort { $0.cjFee ?? 0 < $1.cjFee ?? 0 }
////                jm.absOffers.sort { $0.minSize ?? 0 < $1.minSize ?? 0 }
////            }
////
////            if jm.relOffers.count > 0 {
////                jm.relOffers.sort { $0.cjFee ?? 0 < $1.cjFee ?? 0 }
////                jm.relOffers.sort { $0.minSize ?? 0 < $1.minSize ?? 0 }
////            }
////
////            guard let amount = utxo.amount else { print("failing here"); return }
////
////            let satsToMix = Int(amount * 100000000.0)
////
////            var idealAbsOffers = jm.absOffers
////
////            for (i, absOffer) in jm.absOffers.enumerated() {
////                if (satsToMix > absOffer.minSize ?? 0 && satsToMix < absOffer.maxSize ?? 0) {
////                    idealAbsOffers.append(absOffer)
////                }
////
////                if i + 1 == jm.absOffers.count {
////                    if idealAbsOffers.count > 4 {
////                        for i in 0...4 {
////                            let offer = idealAbsOffers[i]
////                            print("maker: \(offer.maker)\nminAmount: \(offer.minSize!)\nmaxAmount: \(offer.maxSize!)")
////
////                            taker.handshake(offer, utxoToMix) { _ in
////                                //print("handshake response: \(response ?? "empty")")
////                            }
////                        }
////                    }
////                }
////            }
////
////            var idealRelOffers = jm.relOffers
////
////            for (i, relOffer) in jm.relOffers.enumerated() {
////                if (satsToMix > relOffer.minSize ?? 0 && satsToMix < relOffer.maxSize ?? 0) {
////                    idealRelOffers.append(relOffer)
////                }
////
////                if i + 1 == jm.relOffers.count {
////                    if idealRelOffers.count > 4 {
////                        for i in 0...4 {
////                            let offer = idealRelOffers[i]
////                            print("maker: \(offer.maker)\nminAmount: \(offer.minSize!)\nmaxAmount: \(offer.maxSize!)")
////
////                            taker.handshake(offer, utxoToMix) { response in
////                                //print("handshake response: \(response ?? "empty")")
////                            }
////                        }
////                    }
////                }
////            }
////        }
//    }
    
    private func promptToLockWallets() {
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
            guard let jmWallets = jmWallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "You have an existing Join Market wallet which is unlocked, you need to lock it before we can create a new one."
                
                let mess = ""
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                for jmWallet in jmWallets {
                    let str = JMWallet(jmWallet)
                    alert.addAction(UIAlertAction(title: str.name, style: .default, handler: { [weak self] action in
                        JMUtils.lockWallet(wallet: str) { (locked, message) in
                            if locked {
                                showAlert(vc: self, title: "Wallet locked ✓", message: "Try joining the utxo again.")
                            }
                        }
                    }))
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func promptToDepositToWallet(_ utxo: Utxo) {
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
            guard let jmWallets = jmWallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "Deposit to Join Market wallet?"
                let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal."
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                for jmWallet in jmWallets {
                    let str = JMWallet(jmWallet)
                    alert.addAction(UIAlertAction(title: str.name, style: .default, handler: { [weak self] action in
                        guard let self = self else { return }
                        
                        self.spinner.addConnectingView(vc: self, description: "fetching JM deposit address...")
                        
                        JMUtils.getAddress(wallet: str) { (address, message) in
                            guard let address = address else {
                                showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                                return
                            }
                            
                            self.depositAddress = address
                            self.depositNow(utxo)
                        }
                    }))
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func promptToCreateJmWallet(_ utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Create a Join Market wallet?"
            let mess = "In order to join your utxos you need to create a Join Market wallet. This will be like your other Fully Noded wallets with the added ability to instantly join and earn interest on your balance."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                let currentWallet = self.wallet?.name ?? ""
                
                JMUtils.createWallet { (response, message) in
                    guard let jmWallet = response else {
                        if let mess = message, mess.contains("Wallet already unlocked.") {
                            self.promptToLockWallets()
                        } else {
                            showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
                        }
                        
                        return
                    }
                    
                    UserDefaults.standard.setValue(currentWallet, forKey: "walletName")
                    self.walletCreatedSuccess(utxo, jmWallet)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func walletCreatedSuccess(_ utxo: Utxo, _ jmWallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Join Market wallet created successfully ✓"
            let mess = "You may now deposit funds to it."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Deposit funds", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.promptToDeposit(utxo, jmWallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDeposit(_ utxo: Utxo, _ jmWallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Deposit to Join Market wallet?"
            let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                JMUtils.getAddress(wallet: jmWallet) { (address, message) in
                    guard let address = address else {
                        showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                        return
                    }
                    
                    self.depositAddress = address
                    self.depositNow(utxo)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDonateChange(_ utxo: Utxo) {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "Donate toxic change?"
                let mess = "Toxic change is best used as a donation to the developer."
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Donate", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    guard let donationAddress = Keys.donationAddress() else {
                        return
                    }
                    
                    self.depositAddress = donationAddress
                    self.amountTotal = utxo.amount ?? 0.0
                    self.depositNow(utxo)                    
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
    }
                
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "goToLocked":
            guard let vc = segue.destination as? LockedViewController else { fallthrough }
            
            vc.fxRate = fxRate
            vc.isFiat = isFiat
            vc.isBtc = isBtc
            vc.isSats = isSats
            
        case "segueToSendFromUtxos":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            vc.isJmarket = isJmarket
            vc.jmWallet = jmWallet
            vc.inputArray = inputArray
            vc.utxoTotal = amountTotal
            vc.address = depositAddress ?? ""
            
        case "segueToBroadcasterFromUtxo":
            guard let vc = segue.destination as? VerifyTransactionViewController, let psbt = psbt else { fallthrough }
            
            vc.unsignedPsbt = psbt
            
        default:
            break
        }
    }
}


// MARK: UTXOCellDelegate

extension UTXOViewController: UTXOCellDelegate {
    
    func didTapToLock(_ utxo: Utxo) {
        lock(utxo)
    }
    
    func didTapToEditLabel(_ utxo: Utxo) {
        editLabel(utxo)
    }
    
    func didTapToFetchOrigin(_ utxo: Utxo) {
        fetchOriginRate(utxo)
    }
    
    func didTapToMix(_ utxo: Utxo) {
        spinner.addConnectingView(vc: self, description: "checking nodes, wallet and utxo...")
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, !nodes.isEmpty else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No nodes", message: "")
                return
            }
            
            var jmNodeActive = false
            var isAny = false
            
            for node in nodes {
                let str = NodeStruct(dictionary: node)
                if str.isJoinMarket {
                    isAny = true
                    if str.isActive {
                        jmNodeActive = true
                    }
                }
            }
            
            guard isAny else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Add a Join Market node first.", message: "")
                return
            }
            
            guard jmNodeActive else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Activate your Join Market node first.", message: "")
                return
            }
            
            CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
                guard let jmWallets = jmWallets, !jmWallets.isEmpty else {
                    self.spinner.removeConnectingView()
                    self.promptToCreateJmWallet(utxo)
                    return
                }
                
                var isAnyJMWallet = false
                
                for (i, jmWallet) in jmWallets.enumerated() {
                    let jmWalletStruct = JMWallet(jmWallet)
                    
                    if jmWalletStruct.fnWallet != "" {
                        isAnyJMWallet = true
                    }
                    
                    self.spinner.removeConnectingView()
                    
                    if i + 1 == jmWallets.count && isAnyJMWallet {
                        self.promptToDepositToWallet(utxo)
                    } else if i + 1 == jmWallets.count {
                        self.promptToCreateJmWallet(utxo)
                    }
                }
            }
        }
    }
    
    func didTapDonateChange(_ utxo: Utxo) {
        promptToDonateChange(utxo)
    }
    
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: false, fxRate: fxRate, isSats: isSats, isBtc: isBtc, isFiat: isFiat, delegate: self)
        
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
