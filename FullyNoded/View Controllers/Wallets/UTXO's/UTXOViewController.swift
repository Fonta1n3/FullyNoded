//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import BitcoinDevKit

// To do: add a nodeless button to each utxo, then reuse already existing signing logic.
class UTXOViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    private var utxoToSweep: UTXO?
    private var dataRefresher = UIBarButtonItem()
    private var amountTotal: Double = 0.0
    private let refresher = UIRefreshControl()
    var unlockedUtxos: [UTXO] = []
    private var inputArray: [[String:Any]] = []
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var refreshButton = UIBarButtonItem()
    var wallet: Wallet?
    private var psbt: String?
    private var depositAddress: String?
    var fxRate: Double?
    private var allCachedUtxos: [[String: Any]] = []
    private var initialLoad = true
    var signedRawTx: String?
    
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var lastSavedDateLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(loadUnlockedUtxos), for: UIControl.Event.valueChanged)
        tableView.addSubview(refresher)
        
        if let displayedDate = displaySavedDate() {
            lastSavedDateLabel.text = "Last updated: " + displayedDate
        }
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        amountTotal = 0.0
        inputArray.removeAll()
        
        if initialLoad {
            loadCachedUtxos()
        } else {
            initialLoad = false
        }
    }
    
    private func loadCachedUtxos() {
        addNavBarSpinner()
        unlockedUtxos.removeAll()
        allCachedUtxos.removeAll()
        
        guard let _ = wallet else {
            loadUtxos()
            return
        }
        
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
                        
            guard let utxos = utxos, utxos.count > 0 else {
                loadUtxos()
                return
            }
                        
            allCachedUtxos = utxos
            
            for (i, utxo) in utxos.enumerated() {
                let utxoStr = UTXO(from: utxo)
                if let id = utxoStr.walletId, let walletId = wallet?.id {
                    if id == walletId {
                        // TODO: wallet IDs can change, lets use the descriptors instead.
                        unlockedUtxos.append(utxoStr)
                    }
                }
                
                if i + 1 == utxos.count {
                    unlockedUtxos.sort { ($0.confirmations ?? 0) < ($1.confirmations ?? 0) }
                    reload()
                    loadUtxos()
                }
            }
        }
    }
    
    private func reload() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            tableView.reloadData()
        }
    }
    
    private func deleteThisWalletsCachedUtxos(completion: @escaping ((Bool) -> (Void))) {
        guard allCachedUtxos.count > 0 else {
            completion((true))
            return
        }
        
        for (i, cachedUtxo) in allCachedUtxos.enumerated() {
            let cachedUtxoStruct = UTXO(from: cachedUtxo)
            
            guard let cachedUtxoWalletId = cachedUtxoStruct.walletId, let walletId = wallet?.id, cachedUtxoWalletId == walletId else {
                if i + 1 == allCachedUtxos.count {
                    completion((true))
                    return
                } else {
                    continue
                }
            }
            
            guard let id = cachedUtxoStruct.id else {
                if i + 1 == allCachedUtxos.count {
                    completion((true))
                    return
                } else {
                    continue
                }
            }
            
            CoreDataService.deleteEntity(id: id, entityName: .utxos) { [weak self] cachedUtxoDeleted in
                guard let self = self else { return }
                guard cachedUtxoDeleted else {
                    showAlert(vc: self, title: "", message: "There was an error deleting a cached utxo.")
                    if i + 1 == allCachedUtxos.count {
                        completion((true))
                    }
                    return
                }
                if i + 1 == allCachedUtxos.count {
                    completion((true))
                }
            }
        }
    }
    
    private func loadUtxos() {
        let param: List_Unspent = .init(["minconf": 0])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listunspent(param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let utxos = response as? [[String: Any]] else {
                removeSpinner()
                
                showAlert(vc: self, title: "", message: errorDesc ?? "Unable to fetch utxos from your node.")
                return
            }
            
            if utxos.count == 0 {
                showAlert(vc: self, title: "", message: "No unlocked utxo's.")
            }
            
            saveLastSavedUtxosDate()
            unlockedUtxos.removeAll()
            
            for utxo in utxos {
                var utxoStr = UTXO(from: utxo)
                utxoStr.id = UUID()
                unlockedUtxos.append(utxoStr)
            }
            
            unlockedUtxos.sort { ($0.confirmations ?? 0) < ($1.confirmations ?? 0) }
            reload()
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                
                // Easier and lighter to simply overwrite all cached utxos for this wallet than it is to update existing utxos and delete spent utxos.
                deleteThisWalletsCachedUtxos { [weak self] deleted in
                    guard let self = self else { return }
                    guard deleted else {
                        removeSpinner()
                        return
                    }
                    cacheUtxos()
                }
            }
        }
    }
    
    func cacheUtxos() {
        guard let walletId = wallet?.id else {
            removeSpinner()
            return
        }
        
        for (i, unlockedUtxo) in unlockedUtxos.enumerated() {
            var dict: [String: Any] = [:]
            dict["walletId"] = walletId
            dict["amount"] = unlockedUtxo.amount
            dict["address"] = unlockedUtxo.address ?? ""
            dict["txid"] = unlockedUtxo.txid
            dict["vout"] = unlockedUtxo.vout
            dict["label"] = unlockedUtxo.label ?? ""
            dict["desc"] = unlockedUtxo.desc ?? ""
            dict["confirmations"] = unlockedUtxo.confirmations
            dict["solvable"] = unlockedUtxo.solvable
            dict["spendable"] = unlockedUtxo.spendable
            dict["lastUpdated"] = Date()
            dict["id"] = unlockedUtxo.id
            dict["reused"] = unlockedUtxo.reused
            
            // Sync cached utxo ID, so we can delete it from the cache if user locks the utxo.
            CoreDataService.saveEntity(dict: dict, entityName: .utxos) { [weak self] utxosSaved in
                guard let self = self else { return }
                
                guard utxosSaved else {
                    if i + 1 == unlockedUtxos.count {
                        removeSpinner()
                    }
                    return
                }
                #if DEBUG
                print("saved utxo: \(dict)")
                #endif
                
                if i + 1 == unlockedUtxos.count {
                    removeSpinner()
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
    
    private func lock(_ utxo: UTXO) {
        addNavBarSpinner()
        
        let param = Lock_Unspent(["unlock": false, "transactions": [["txid": utxo.txid,"vout": utxo.vout]]])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .lockunspent(param)) { (response, errorDesc) in
            guard let success = response as? Bool else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: errorDesc ?? "unknown error")
                }
                
                return
            }
            
            if success {
                guard let id = utxo.id else {
                    print("no id")
                    return
                }
                
                CoreDataService.deleteEntity(id: id, entityName: .utxos) { deleted in
                    guard deleted else { return }
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.loadUnlockedUtxos()
                    }
                    
                    showAlert(vc: self, title: "UTXO Locked 🔐", message: "You can tap the locked button to see your locked utxo's and unlock them. Be aware if your node reboots all utxo's will be unlocked by default!")
                }
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: "utxo was not locked")
                }
            }
        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: true)
            self.removeSpinner()
        }
    }
    
    @objc private func loadUnlockedUtxos() {
        unlockedUtxos.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addNavBarSpinner()
        }
        
        loadCachedUtxos()
    }
    
    private func removeSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            ConnectingView.shared.dismiss()
            self.refresher.endRefreshing()
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.loadUnlockedUtxos))
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    
//    private func fetchOriginRate(_ utxo: Utxo) {
//        guard let date = utxo.date, let id = utxo.txUUID else {
//            showAlert(vc: self, title: "", message: "Date or saved tx UUID missing.")
//            return
//        }
//        
//        let dateFormatter = DateFormatter()
//        dateFormatter.dateFormat = "yyyy-MM-dd"
//        let dateString = dateFormatter.string(from: date)
//        
//        let today = dateFormatter.string(from: Date())
//        
//        if dateString == today {
//            showAlert(vc: self, title: "", message: "You need to wait for the transaction to be at least one day old before fetching the historic rate.")
//        } else {
//            addNavBarSpinner()
//            
//            FiatConverter.sharedInstance.getOriginRate(date: dateString) { [weak self] originRate in
//                guard let self = self else { return }
//                
//                guard let originRate = originRate else {
//                    removeSpinner()
//                    showAlert(vc: self, title: "", message: "There was an issue fetching the historic exchange rate, please let us know about it.")
//                    return
//                }
//                
//                CoreDataService.update(id: id, keyToUpdate: "originFxRate", newValue: originRate, entity: .transactions) { [weak self] success in
//                    guard let self = self else { return }
//                    
//                    guard success else {
//                        removeSpinner()
//                        showAlert(vc: self, title: "", message: "There was an issue saving the historic exchange rate, please let us know about it.")
//                        return
//                    }
//                    
//                    self.loadUnlockedUtxos()
//                }
//            }
//        }
//    }
    
    func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.spinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.spinner.startAnimating()
            self.spinner.alpha = 1
        }
    }
    
    private func updateLabelNow(label: String, address: String) {
        addNavBarSpinner()
        let param: Set_Label_Param = .init(["label":label, "address": address])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .setlabel(param: param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard errorDesc == nil else {
                showAlert(vc: self, title: "Error", message: errorDesc!)
                return
            }
            
            loadUnlockedUtxos()
        }
    }
        
    private func promptToEditLabel(_ utxo: UTXO) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Edit label?"
            let mess = "Labels are address based and stored by Bitcoin Core. If you reuse addresses this label will apply to multiple utxos."
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                guard let label = (alert.textFields![0] as UITextField).text else { return }
                
                updateLabelNow(label: label, address: utxo.address!)
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = utxo.label ?? ""
            }
            alert.addAction(save)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        let modalVC = TextModalViewController(data: data, viewTitle: title)
        
        let nav = UINavigationController(rootViewController: modalVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        
        present(nav, animated: true)
    }
    
    func saveLastSavedUtxosDate() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "lastSavedUtxosDate")
        
        if let lastSaved = displaySavedDate() {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                lastSavedDateLabel.text = "Last updated: " + lastSaved
            }
        }
    }

    func displaySavedDate() -> String? {
        guard let savedDate = UserDefaults.standard.object(forKey: "lastSavedUtxosDate") as? Date else {
            return nil
        }
        
        return savedDate.formattedDate
    }
                
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "segueToSendFromUtxos":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }

            vc.inputs = inputArray
            vc.utxoTotal = amountTotal
            vc.address = depositAddress ?? ""
            vc.fxRate = fxRate
            
        case "segueToBroadcasterFromUtxo":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            if let signedRawTx = signedRawTx {
                vc.signedRawTx = signedRawTx
            } else if let psbt = psbt {
                vc.unsignedPsbt = psbt
            }
            
            
        default:
            break
        }
    }
        
    private func sweepUtxo(utxo: UTXO) {
        guard let wallet = wallet else { return }
        
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let self = self else { return }
            
            guard let signers = signers, signers.count > 0 else {
                showAlert(title: "", message: "No signers present.")
                ConnectingView.shared.dismiss()
                return
            }
            
            var signerToUse: SignerStruct? = nil
            
            for (i, signer) in signers.enumerated() {
                let signerStruct = SignerStruct(dictionary: signer)
                
                if let encryptedXfp = signerStruct.xfp, let decryptedXfp = Crypto.decrypt(encryptedXfp), let utf8Xfp = decryptedXfp.utf8String, let parentDescs = utxo.parentDescs, !parentDescs.isEmpty {
                    let desc = parentDescs[0]
                    let fnDesc = Descriptor(desc)
                    if fnDesc.fingerprint.contains(utf8Xfp), let _ = utxo.address, let _ = signerStruct.words {
                        signerToUse = signerStruct
                    }
                }
                
                if i + 1 == signers.count, let inputAddress = utxo.address {
                    let esploraUtxo = Esplora_Utxo(
                        txid: utxo.txid,
                        vout: utxo.vout,
                        value: Int64(utxo.amount * 100000000),
                        status: .init(confirmed: true, blockHeight: nil, blockHash: nil, blockTime: nil),
                        address: inputAddress
                    )
                    
                    guard let network = WalletLogic.shared.bdkNetwork() else {
                        return
                    }
                    
                    do {
                        let wallet = try WalletLogic.shared.bdkWalletFromDescriptors(recDesc: wallet.receiveDescriptor, changeDesc: wallet.changeDescriptor)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            let vc = SweepViewController(utxos: [esploraUtxo], watchOnlyBdkWallet: wallet, signer: signerToUse, network: network)
                            navigationController?.pushViewController(vc, animated: true)
                        }
                        
                    } catch {
                        showAlert(title: "Failed converting to bdkMnemonic", message: error.localizedDescription)
                        ConnectingView.shared.dismiss()
                    }
                }
            }
        }
    }
    
}



// MARK: UTXOCellDelegate

extension UTXOViewController: UTXOCellDelegate {
    
    private func getDescriptorInfo(descriptor: String) {
        let p: Get_Descriptor_Info = .init(["descriptor": descriptor])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getdescriptorinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Parent Descriptor Info")
            }
        }
    }
    
    func copyParentDesc(_ utxo: UTXO) {
        if let parentDescs = utxo.parentDescs {
            UIPasteboard.general.string = "\(parentDescs)"
            showAlert(vc: self, title: "", message: "Parent descriptor copied ✓")
        }
    }
    
    func didTapParentDescInfoButton(_ utxo: UTXO) {
        addNavBarSpinner()
        guard let parentDescs = utxo.parentDescs else {
            showAlert(vc: self, title: "", message: "No descriptor associated with this UTXO.")
            return
        }
        let descriptor = "\(parentDescs[0])"
        let p: Get_Descriptor_Info = .init(["descriptor": descriptor])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getdescriptorinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Parent Descriptor Info")
            }
        }
    }
    
    func showUtxoRawData(_ utxo: UTXO) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            showModal(data: utxo.rawData, title: "Utxo Info")
        }
    }
    
    func getAddressInfo(_ utxo: UTXO) {
        addNavBarSpinner()
        guard let address = utxo.address else {
            showAlert(vc: self, title: "", message: "No address associated with that UTXO.")
            return
        }
        removeSpinner()
        let p: Get_Address_Info = .init(["address": address])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard let addressInfo = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: addressInfo, title: "Address Info")
            }
        }
    }
    
    func getTxInfo(_ utxo: UTXO) {
        addNavBarSpinner()
        let p: Get_Tx = .init(["txid": utxo.txid, "verbose": true, "include_watchonly": true])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Transaction Info")
            }
        }
    }
    
    func getDescriptorInfo(_ utxo: UTXO) {
        addNavBarSpinner()
        guard let descriptor = utxo.desc else {
            showAlert(vc: self, title: "", message: "No descriptor associated with this UTXO.")
            return
        }
        let p: Get_Descriptor_Info = .init(["descriptor": descriptor])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getdescriptorinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Descriptor Info")
            }
        }
    }
    
    func didTapNodeless(_ utxo: UTXO) {
        self.sweepUtxo(utxo: utxo)
    }
    
    func didTapToSpendUtxo(_ utxo: UTXO) {
        amountTotal = utxo.amount
        let input:[String:Any] = ["txid": utxo.txid, "vout": utxo.vout, "sequence": 1]
        inputArray.append(input)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
        }
    }
    
    func copyAddress(_ utxo: UTXO) {
        UIPasteboard.general.string = utxo.address!
        showAlert(vc: self, title: "", message: "Address copied ✓")
    }
    
    func copyTxid(_ utxo: UTXO) {
        UIPasteboard.general.string = utxo.txid
        showAlert(vc: self, title: "", message: "Transaction ID copied ✓")
    }
    
    func copyDesc(_ utxo: UTXO) {
        UIPasteboard.general.string = utxo.desc!
        showAlert(vc: self, title: "", message: "Descriptor copied ✓")
    }
    
    func editLabel(_ utxo: UTXO) {
        promptToEditLabel(utxo)
    }
    
    func didTapToLock(_ utxo: UTXO) {
        lock(utxo)
    }
    
}

// Mark: UITableViewDataSource
extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        cell.configure(wallet: wallet, utxo: utxo, isLocked: false, fxRate: fxRate, delegate: self)
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return unlockedUtxos.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
}


// Mark: UITableViewDelegate
extension UTXOViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 5
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        return headerView
    }
}
