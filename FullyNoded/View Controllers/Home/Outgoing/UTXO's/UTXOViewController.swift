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
    private var unlockedUtxos = [UtxosStruct]()
    private var inputArray = [Any]()
    private var selectedUTXOs = [UtxosStruct]()
    private var spinner = ConnectingView()
    private var isUnsigned = false
    private var alertStyle = UIAlertController.Style.actionSheet
    private var wallet:Wallet?
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
        
        activeWallet { wallet in
            guard let wallet = wallet else { return }
            
            self.wallet = wallet
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
            
    private func updateSelectedUtxos() {
        selectedUTXOs.removeAll()
        
        for utxo in unlockedUtxos {
            if utxo.isSelected {
                selectedUTXOs.append(utxo)
            }
        }
    }
    
    @IBAction private func createRaw(_ sender: Any) {
        guard let version = UserDefaults.standard.object(forKey: "version") as? String, version.bitcoinVersion >= 21 else {
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
    
    private func importdesc(params: String, utxo: UtxosStruct, label: String) {
        Reducer.makeCommand(command: .importdescriptors, param: params) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            self.updateLocally(utxo: utxo, label: label)
        }
    }
    
    private func importmulti(param: String, utxo: UtxosStruct, label: String) {
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
            
            self.updateLocally(utxo: utxo, label: label)
        }
    }
    
    private func updateLocally(utxo: UtxosStruct, label: String) {
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
                let savedUtxoStr = UtxosStruct(dictionary: savedUtxo)
                
                if savedUtxoStr.txid == utxo.txid && savedUtxoStr.vout == utxo.vout {
                    CoreDataService.update(id: savedUtxoStr.id!, keyToUpdate: "label", newValue: label as Any, entity: .utxos) { _ in }
                }
            }
            
            saved()
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
        
        Reducer.makeCommand(command: .listunspent, param: "0") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
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
                var dateToSave:Date?
                var txUUID:UUID?
                var capGain:String?
                var originValue:String?
                
                guard var utxoDict = utxo as? [String:Any] else { return }
                
//                utxoDict["capGain"] = ""
//                utxoDict["originValue"] = "missing origin rate"
//                utxoDict["date"] = nil
//                utxoDict["txUUID"] = nil
                
                if let wallet = self.wallet {
                    if wallet.type == WalletType.descriptor.stringValue {
                        let dp = DescriptorParser()
                        let dStruct = dp.descriptor(wallet.receiveDescriptor)
                        utxoDict["spendable"] = dStruct.isHot
                    }
                }
                
                func finish() {
                    let utxoStr = UtxosStruct(dictionary: utxoDict)
                    self.unlockedUtxos.append(utxoStr)
                    
                    if i + 1 == utxos.count {
                        self.unlockedUtxos = self.unlockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                        
                        if let wallet = self.wallet {
                            CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] savedUtxos in
                                guard let self = self else { return }
                                
                                guard let savedUtxos = savedUtxos, savedUtxos.count > 0 else {
                                    self.finishedLoading()
                                    
                                    return
                                }
                                
                                for (u, unlockedUtxo) in self.unlockedUtxos.enumerated() {
                                    
                                    func loopSavedUtxos() {
                                        for (s, savedUtxo) in savedUtxos.enumerated() {
                                            let savedUtxoStr = UtxosStruct(dictionary: savedUtxo)
                                            
                                            /// We always use the Bitcoin Core address label as the utxo label, when recovering with a new node the user will see the
                                            /// label the user added via Fully Noded. Fully Noded automatically saves the utxo labels.
                                            
                                            if savedUtxoStr.txid == unlockedUtxo.txid && savedUtxoStr.vout == unlockedUtxo.vout && wallet.label != savedUtxoStr.label {
                                                self.unlockedUtxos[i].label = savedUtxoStr.label
                                                
                                                if wallet.type == WalletType.descriptor.stringValue {
                                                    guard let desc = unlockedUtxo.desc else { return }
                                                    
                                                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(savedUtxoStr.label!)\"}]"
                                                    
                                                    Reducer.makeCommand(command: .importdescriptors, param: params) { (_, _) in }
                                                    
                                                } else {
                                                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(unlockedUtxo.address!)\" }, \"label\": \"\(savedUtxoStr.label!)\", \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                                                    
                                                    Reducer.makeCommand(command: .importmulti, param: param) { (_, _) in }
                                                }
                                            }
                                            
                                            if s + 1 == savedUtxos.count && u + 1 == self.unlockedUtxos.count {
                                                self.finishedLoading()
                                            }
                                        }
                                    }
                                    
                                    if unlockedUtxo.label == "" || unlockedUtxo.label == wallet.label {
                                        loopSavedUtxos()
                                    } else if u + 1 == self.unlockedUtxos.count {
                                        self.finishedLoading()
                                    }
                                }
                            }
                        }
                    }
                }
                
                let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
                let amountBtc = utxoDict["amount"] as! Double
                
                CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                    if let txs = txs, txs.count > 0 {
                        
                        
                        for (i, tx) in txs.enumerated() {
                            let txStruct = TransactionStruct(dictionary: tx)
                            
                            if txStruct.txid == utxoDict["txid"] as! String {
                                dateToSave = txStruct.date
                                txUUID = txStruct.id
                                
                                if txStruct.fiatCurrency == currency, let currentFxRate = self.fxRate, let originRate = txStruct.fxRate {
                                    let originFiatValue = originRate * amountBtc
                                    let currentFiatValue = currentFxRate * amountBtc
                                    var gain = currentFiatValue - originFiatValue
                              
                                    if originFiatValue > 0 {
                                        originValue = originFiatValue.fiatString
                                        let ratio = round(gain / originFiatValue)
                                        let percentage = Int(ratio * 100.0)
                                        
                                        if gain > 1.0 {
                                            if percentage > 1 {
                                                capGain = "gain of \(gain.fiatString) / \(percentage)%"
                                            } else {
                                                capGain = "gain of \(gain.fiatString)"
                                            }
                                            
                                        } else if gain < -1.0 {
                                            gain = gain * -1.0
                                            if percentage > 1 {
                                                capGain = "loss of \(gain.fiatString) / \(percentage)%"
                                            } else {
                                                capGain = "loss of \(gain.fiatString)"
                                            }
                                            
                                        } else {
                                            capGain = ""
                                        }
                                    }
                                }
                            }
                            
                            if i + 1 == txs.count {
                                utxoDict["capGain"] = capGain
                                utxoDict["originValue"] = originValue
                                utxoDict["date"] = dateToSave
                                utxoDict["txUUID"] = txUUID
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
    
    private func fetchOriginRate(_ utxo: UtxosStruct) {
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
                    
//                    DispatchQueue.main.async { [weak self] in
//                        guard let self = self else { return }
//
//                        self.tableView.reloadData()
//                        self.spinner.removeConnectingView()
//                    }
                    self.loadUnlockedUtxos()
                }
            }
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
    
    func didTapToFetchOrigin(_ utxo: UtxosStruct) {
        fetchOriginRate(utxo)
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
