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
    private var isUnsigned = false
    private var wallet:Wallet?
    private var psbt:String?
    private var depositAddress:String?
    var fxRate:Double?
    var isBtc = false
    var isSats = false
    var isFiat = false
    
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
        
        activeWallet { wallet in
            guard let wallet = wallet else { return }
            
            self.wallet = wallet
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        loadUnlockedUtxos()
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
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                guard let textFields = alert.textFields, let label = textFields[0].text else {
                    showAlert(vc: self, title: "Ooops", message: "Something went wrong here, the textfield is not accessible...")
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "updating utxo label")
                
                // need to check if its a native descriptor wallet then add label
                guard let wallet = self.wallet else { return }
                
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
            
            if !(utxo.spendable ?? false) {
                isUnsigned = true
            }
            
            inputArray.append(input)
        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            JoinMarket.syncAddresses()
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
                
                if let wallet = self.wallet {
                    if wallet.type == WalletType.descriptor.stringValue {
                        let dStruct = Descriptor(wallet.receiveDescriptor)
                        utxoDict["spendable"] = dStruct.isHot
                    }
                }
                
                func finish() {
                    self.unlockedUtxos.append(utxo)
                    
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
                                                
                                                if wallet.type == WalletType.descriptor.stringValue {
                                                    guard let desc = unlockedUtxo.desc else { return }
                                                    
                                                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(savedUtxoStr.label ?? "")\"}]"
                                                    
                                                    Reducer.makeCommand(command: .importdescriptors, param: params) { (_, _) in }
                                                    
                                                } else {
                                                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(unlockedUtxo.address!)\" }, \"label\": \"\(savedUtxoStr.label ?? "")\", \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                                                    
                                                    Reducer.makeCommand(command: .importmulti, param: param) { (_, _) in }
                                                }
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
    
    private func mix(_ utxo: Utxo) {
//        JoinMarket.getDepositAddress { [weak self] address in
//            guard let self = self else { return }
//
//            guard let address = address else { return }
//
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//
//                self.inputArray.append(utxo.input)
//                self.depositAddress = address
//                self.amountTotal = 0.0
//
//                self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
//            }
//        }
        
        
        
        let jm = JoinMarketPit.sharedInstance
        let taker = Taker.shared
        print("jm.absOffers.count: \(jm.absOffers.count)")
        print("jm.relOffers.count: \(jm.relOffers.count)")
        
        guard jm.absOffers.count > 0 || jm.relOffers.count > 0 else {
            showAlert(vc: self, title: "", message: "No offers...")
            return
        }
        
        if jm.absOffers.count > 0 {
            jm.absOffers.sort { $0.cjFee ?? 0 < $1.cjFee ?? 0 }
            jm.absOffers.sort { $0.minSize ?? 0 < $1.minSize ?? 0 }
        }
        
        if jm.relOffers.count > 0 {
            jm.relOffers.sort { $0.cjFee ?? 0 < $1.cjFee ?? 0 }
            jm.relOffers.sort { $0.minSize ?? 0 < $1.minSize ?? 0 }
        }
                        
        guard let amount = utxo.amount else { print("failing here"); return }
        
        let satsToMix = Int(amount * 100000000.0)
        
        var idealAbsOffers = jm.absOffers
        
        for (i, absOffer) in jm.absOffers.enumerated() {
            if (satsToMix > absOffer.minSize ?? 0 && satsToMix < absOffer.maxSize ?? 0) {
                idealAbsOffers.append(absOffer)
            }
            
            if i + 1 == jm.absOffers.count {
                //print("ideal absoffer: \(idealAbsOffers[0].raw)")
                
                if idealAbsOffers.count > 4 {
                    for i in 0...4 {
                        let offer = idealAbsOffers[i]
                        print("maker: \(offer.maker)\nminAmount: \(offer.minSize!)\nmaxAmount: \(offer.maxSize!)")
                        
                        taker.handshake(offer, utxo) { _ in
                            //print("handshake response: \(response ?? "empty")")
                        }
                    }
                }
            }
        }
        
        var idealRelOffers = jm.relOffers
        
        for (i, relOffer) in jm.relOffers.enumerated() {
            if (satsToMix > relOffer.minSize ?? 0 && satsToMix < relOffer.maxSize ?? 0) {
                idealRelOffers.append(relOffer)
            }
            
            if i + 1 == jm.relOffers.count {
                print("ideal reloffer: \(idealRelOffers[0].raw)")
                
                if idealRelOffers.count > 4 {
                    for i in 0...4 {
                        let offer = idealRelOffers[i]
                        print("maker: \(offer.maker)\nminAmount: \(offer.minSize!)\nmaxAmount: \(offer.maxSize!)")
                        
                        taker.handshake(idealRelOffers[i], utxo) { response in
                            //print("handshake response: \(response ?? "empty")")
                        }
                    }
                }
            }
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
        mix(utxo)
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
