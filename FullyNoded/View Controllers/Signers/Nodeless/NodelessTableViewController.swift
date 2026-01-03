//
//  NodelessTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/5/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit


class NodelessTableViewController: UITableViewController, UIDocumentPickerDelegate {
    
    var savedUtxos: [UTXO] = []
    var addresses: [AddressStruct] = []
    var signer: SignerStruct?
    var addressToExport = ""
    var derivationToExport = ""
    var network: WalletLogic.BDKNetwork!
    let spinner = ConnectingView.shared
    var primaryDescriptor = ""
    var changeDescriptor: String?
    var watchOnlyBdkWallet: WalletLogic.BDKWallet?
    var initialLoad = true

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(BitcoinAddressCell.self, forCellReuseIdentifier: "BitcoinCell")
        
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        FiatConverter.sharedInstance.getFxRate(currency: currency) { fxRate in
            UserDefaults.standard.set(fxRate, forKey: "fxRate")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            load()
            initialLoad = false
        }
    }
    
    @IBAction func importTransaction(_ sender: Any) {
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Import a transaction",
                                          message: "You can import a transaction in a number of ways, Nodeless will analyze the transaction and allow you to sign, export and/or broadcast it. No node required.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Upload File", style: .default, handler: { action in
                self.presentUploader()
            }))
            
            alert.addAction(UIAlertAction(title: "Paste Text", style: .default, handler: { action in
                self.pasteAction()
            }))
            
            alert.addAction(UIAlertAction(title: "QR Code", style: .default, handler: { action in
                self.scanQr()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
        
    }
    
    private func scanQr() {
        presentQRScanner(fromSignAndVerify: true) { scannedResult in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                processString(string: scannedResult)
            }
        }
    }
    
    private func pasteAction() {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "Not a psbt?", message: "Looks like you do not have valid text on your clipboard")
                return
            }
            
            processString(string: string)
        } else if let string = UIPasteboard.general.string {
            
            processString(string: string)
        } else {
            
            showAlert(vc: self, title: "", message: "Not valid text. You can copy and paste the base64 text of a psbt or a signed raw transaction with this button.")
        }
    }
    
    private func processString(string: String) {
        if let psbt = validPsbt(string: string) {
            let reviewVC = PsbtReviewViewController(
                psbt: psbt,
                rawTransaction: nil,
                wallet: watchOnlyBdkWallet!,
                signer: signer,
                network: network,
                inputs: [],
                fxRate: UserDefaults.standard.object(forKey: "fxRate") as? Double
            )
            
            navigationController?.pushViewController(reviewVC, animated: true)
            
        } else if let tx = validTransaction(string: string) {
            let reviewVC = PsbtReviewViewController(
                psbt: nil,
                rawTransaction: tx,
                wallet: watchOnlyBdkWallet!,
                signer: signer,
                network: network,
                inputs: [],
                fxRate: UserDefaults.standard.object(forKey: "fxRate") as? Double
            )
            
            navigationController?.pushViewController(reviewVC, animated: true)
        }
    }
    
    private func fetchInputs(tx: WalletLogic.BDKTransaction) -> [Esplora_Utxo] {
        var ourUtxos: [Esplora_Utxo] = []
        for input in tx.input() {
            let vout = input.previousOutput.vout
            let txid = input.previousOutput.txid.description
            
            for savedUtxo in savedUtxos {
                if savedUtxo.vout == vout && savedUtxo.txid == txid {
                    var status = Esplora_Utxo.Status(confirmed: false, blockHeight: nil, blockHash: nil, blockTime: nil)
                    
                    if let confs = savedUtxo.confirmations {
                        if confs > 0 {
                            status = Esplora_Utxo.Status(confirmed: true, blockHeight: nil, blockHash: nil, blockTime: nil)
                        }
                    }
                    
                    let esplorUtxo = Esplora_Utxo(txid: savedUtxo.txid, vout: savedUtxo.vout, value: Int64(savedUtxo.amount / 100000000.0), status: status)
                    ourUtxos.append(esplorUtxo)
                }
            }
        }
        return ourUtxos
    }
    
    private func fetchInputs(psbt: WalletLogic.BDKPsbt, completion: @escaping (([Esplora_Utxo])) -> Void) {
        var ourUtxos: [Esplora_Utxo] = []
        guard let tx = try? psbt.extractTx() else {
            completion([])
            return
        }
        
        for input in tx.input() {
            let vout = input.previousOutput.vout
            let txid = input.previousOutput.txid.description
            
            for (i, savedUtxo) in savedUtxos.enumerated() {
                if savedUtxo.vout == vout && savedUtxo.txid == txid {
                    var status = Esplora_Utxo.Status(confirmed: false, blockHeight: nil, blockHash: nil, blockTime: nil)
                    
                    if let confs = savedUtxo.confirmations {
                        if confs > 0 {
                            status = Esplora_Utxo.Status(confirmed: true, blockHeight: nil, blockHash: nil, blockTime: nil)
                        }
                    }
                    
                    let esplorUtxo = Esplora_Utxo(txid: savedUtxo.txid, vout: savedUtxo.vout, value: Int64(savedUtxo.amount / 100000000.0), status: status)
                    ourUtxos.append(esplorUtxo)
                }
                
                if i + 1 == savedUtxos.count {
                    completion((ourUtxos))
                }
            }
        }
    }
    
    private func validPsbt(string: String) -> WalletLogic.BDKPsbt? {
        return try? WalletLogic.BDKPsbt(psbtBase64: string)
    }
    
    private func validTransaction(string: String) -> WalletLogic.BDKTransaction? {
        guard let hexData = Data(hexString: string) else {
            return nil
        }
        return try? WalletLogic.BDKTransaction(transactionBytes: hexData)
    }
    
    private func presentQRScanner(
        fromSignAndVerify: Bool = false,
        isQuickConnect: Bool = false,
        isScanningAddress: Bool = false,
        completion: @escaping (String) -> Void
    ) {
        let scannerVC = ScanQRViewController()
        
        // Configure based on your use case
        scannerVC.fromSignAndVerify = fromSignAndVerify
        scannerVC.isQuickConnect = isQuickConnect
        scannerVC.isScanningAddress = isScanningAddress
        
        // This is called when scanning completes successfully
        scannerVC.onCompletion = { resultString in
            // Handle the scanned result here (e.g., process PSBT, address, etc.)
            completion(resultString)
        }
        
        // Modal presentation style (full screen on iPhone, sheet on iPad)
        scannerVC.modalPresentationStyle = .fullScreen
        
        // Present it
        self.present(scannerVC, animated: true, completion: nil)
    }
    
    private func presentUploader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var documentPicker:UIDocumentPickerViewController!
            
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let text = try? String(contentsOf: urls[0].absoluteURL) else {
            
            guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
                spinner.dismiss()
                showAlert(vc: self, title: "Invalid File", message: "That is not a recognized format, generally it will be a .psbt or .txn file.")
                return
            }
                        
            if let _ = validPsbt(string: data.base64EncodedString()) {
                processString(string: data.base64EncodedString())
                
            } else if let string = data.utf8String {
                processString(string: string)
            }
            
            return
        }
        
        processString(string: text)
    }
    
    @IBAction func refreshAction(_ sender: Any) {
        load()
    }
    
    
    @IBAction func deleteCacheAction(_ sender: Any) {
        Task {
            await deleteItem()
        }
    }
    
    @MainActor
    func deleteItem() async {
        let confirmed = await confirmAction(
            title: "Delete entire Utxo cache?",
            message: "This action cannot be undone. This will hide all balances, you will either need to use this wallet with a node and load your utxos or manually tap the check balance button.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel"
        )
        
        if confirmed {
            // Proceed with deletion
            CoreDataService.deleteAllData(entity: .utxos) { [weak self] deleted in
                guard let self = self else { return }
                
                guard deleted else {
                    showAlert(vc: self, title: "", message: "Unable to delete all cached utxos...")
                    return
                }
                
                showAlert(vc: self, title: "", message: "All cached UTXO's deleted.")
                load()
            }
        }
    }
    
    func load() {
        spinner.show(vc: self, description: "Loading...")
        savedUtxos.removeAll()
        addresses.removeAll()
        
        let descArr = primaryDescriptor.components(separatedBy: "#")
        var changeDesc = ""
        if let changeDescriptor = changeDescriptor {
            changeDesc = changeDescriptor
        } else {
            changeDesc = "\(descArr[0])".replacingOccurrences(of: "/0/", with: "/1/")
        }
        
        network = WalletLogic.shared.bdkNetwork()
                
        guard let bdkPrimDesc = try? WalletLogic.BDKDescriptor(descriptor: primaryDescriptor, network: network) else {
            spinner.dismiss()
            showAlert(vc: self, title: "", message: "Unable to derive BDK primary descriptor.")
            return
        }
        
        guard let bdkChangeDesc = try? WalletLogic.BDKDescriptor(descriptor: changeDesc, network: network) else {
            spinner.dismiss()
            showAlert(vc: self, title: "", message: "Unable to derive BDK change descriptor.")
            return
        }
        
        guard let persister = WalletLogic.shared.persistor() else {
            spinner.dismiss()
            showAlert(vc: self, title: "", message: "Unable to create persistor.")
            return
        }
        
        guard let bdkWallet = try? WalletLogic.BDKWallet(descriptor: bdkPrimDesc, changeDescriptor: bdkChangeDesc, network: network, persister: persister) else {
            spinner.dismiss()
            showAlert(vc: self, title: "", message: "Unable to derive BDK wallet.")
            return
        }
        
        watchOnlyBdkWallet = bdkWallet
       
        
//        guard let encryptedWords = signer.words else {
//            spinner.dismiss()
//            showAlert(vc: self, title: "", message: "For now the BIP39 words need to be present to use this feature. Watch-only nodeless functionality coming soon.")
//            return
//        }
//        
//        guard var decryptedData = Crypto.decrypt(encryptedWords) else {
//            spinner.dismiss()
//            return
//        }
//        
//        var passphrase: String?
//        
//        if signer.passphrase != nil {
//            guard var decryptedPassphrase = Crypto.decrypt(signer.passphrase!) else {
//                spinner.dismiss()
//                return
//            }
//            
//            defer {
//                decryptedPassphrase.secureZero()
//            }
//            
//            passphrase = String(bytes: decryptedPassphrase, encoding: .utf8)
//        }
//        
//        if network == nil {
//            guard let networkCheck = WalletLogic.shared.bdkNetwork() else {
//                spinner.dismiss()
//                return
//            }
//            
//            network = networkCheck
//        }        
//        
//        guard var words = String(bytes: decryptedData, encoding: .utf8) else {
//            spinner.dismiss()
//            return
//        }
//        
//        guard let secretMasterKey = WalletLogic.shared.bdkMasterKey(network: network, mnemonic: words, passphrase: passphrase) else {
//            spinner.dismiss()
//            return
//        }
//        
//        guard let persister = WalletLogic.shared.persistor() else {
//            spinner.dismiss()
//            return
//        }
//        
//        defer {
//            words.secureWipe()
//            passphrase?.secureWipe()
//            decryptedData.secureZero()
//        }
//        
//        var recDesc: WalletLogic.BDKDescriptor!
//        var changeDesc: WalletLogic.BDKDescriptor!
//        
//        if accountPath.hasPrefix("m/86") {
//            recDesc = WalletLogic.BDKDescriptor.newBip86(secretKey: secretMasterKey, keychainKind: .external, network: network)
//            changeDesc = WalletLogic.BDKDescriptor.newBip86(secretKey: secretMasterKey, keychainKind: .internal, network: network)
//        }
//        
//        if accountPath.hasPrefix("m/84") {
//            recDesc = WalletLogic.BDKDescriptor.newBip84(secretKey: secretMasterKey, keychainKind: .external, network: network)
//            changeDesc = WalletLogic.BDKDescriptor.newBip84(secretKey: secretMasterKey, keychainKind: .internal, network: network)
//        }
//        
//        guard let bdkWallet = try? WalletLogic.BDKWallet(descriptor: recDesc, changeDescriptor: changeDesc, network: network, persister: persister) else {
//            spinner.dismiss()
//            return
//        }
        
        let path = Descriptor(primaryDescriptor).derivation
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            for i in 0...999 {
                let addressInfo = bdkWallet.peekAddress(keychain: .external, index: UInt32(i))
                
                let str = AddressStruct(dictionary: [
                    "address": addressInfo.address.description,
                    "balance": 0.0,
                    "derivation": "\(path)/0/\(i)",
                    "utxos": [],
                    "used": false
                ])
                
                addresses.append(str)
                
                if i == 999 {
                    checkSavedUtxos()
                }
            }
        }
    }
    
    func checkSavedUtxos() {
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
            guard let self = self else { return }
            
            guard let utxos = utxos else {
                reload()
                return
            }
            
            guard utxos.count > 0 else {
                reload()
                return
            }
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                for (u, utxo) in utxos.enumerated() {
                    let utxoStruct = UTXO(from: utxo)
                    savedUtxos.append(utxoStruct)
                    
                    for (i, address) in addresses.enumerated() {
                        if address.address == utxoStruct.address {
                            if utxoStruct.amount > 0.0 {
                                addresses[i].balance += utxoStruct.amount
                                saveUsedAddress(address: address.address)
                            }
                            
                            let satsValue = Int64(utxoStruct.amount * 100000000.0)
                            var confirmed = false
                            
                            if let confirmations = utxoStruct.confirmations {
                                confirmed = (confirmations > 0)
                            }
                            
                            let esploraUtxo = Esplora_Utxo(
                                txid: utxoStruct.txid,
                                vout: utxoStruct.vout,
                                value: satsValue,
                                status: Esplora_Utxo.Status(confirmed: confirmed,
                                                            blockHeight: nil,
                                                            blockHash: nil,
                                                            blockTime: nil),
                                address: address.address,
                                lastUpdated: utxoStruct.lastUpdated,
                                id: utxoStruct.id
                            )
                            
                            addresses[i].utxos.append(esploraUtxo)
                            addresses[i].confirmed = confirmed
                        }
                        
                        if i + 1 == addresses.count && u + 1 == utxos.count {
                            checkUsedAddresses()
                        }
                    }
                }
            }
        }
    }
    
    private func checkUsedAddresses() {
        CoreDataService.retrieveEntity(entityName: .usedAddresses) { [weak self] usedAddresses in
            guard let self = self else { return }
            
            guard let usedAddresses = usedAddresses else {
                reload()
                return
            }
            
            guard usedAddresses.count > 0 else {
                reload()
                return
            }
            
            for (i, address) in self.addresses.enumerated() {
                for (x, usedAddress) in usedAddresses.enumerated() {
                    let usedAddressStr = UsedAddress(dictionary: usedAddress)
                    if address.address == usedAddressStr.address {
                        self.addresses[i].used = true
                    }
                    
                    if i + 1 == addresses.count && x + 1 == usedAddresses.count {
                        reload()
                    }
                }                
            }
        }
    }
    
    private func saveUsedAddress(address: String) {
        CoreDataService.retrieveEntity(entityName: .usedAddresses) { usedAddresses in
            guard let usedAddresses = usedAddresses else {
                return
            }
            
            var alreadySaved = false
            
            func saveNow() {
                let dict: [String: Any] = ["address": address, "id": UUID()]
                CoreDataService.saveEntity(dict: dict, entityName: .usedAddresses) { saved in
                    guard saved else {
                        showAlert(title: "", message: "Unable to save used address.")
                        return
                    }
                }
            }
            
            guard usedAddresses.count > 0 else {
                saveNow()
                return
            }
            
            for (i, usedAddress) in usedAddresses.enumerated() {
                let str = UsedAddress(dictionary: usedAddress)
                if str.address == address {
                    alreadySaved = true
                }
                
                if i + 1 == usedAddresses.count, !alreadySaved {
                    saveNow()
                }
            }
        }
    }
    
    private func reload() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            tableView.reloadData()
            spinner.dismiss()
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "BitcoinCell", for: indexPath) as! BitcoinAddressCell
        let addressStr = addresses[indexPath.row]
        cell.configure(with: addressStr)
        
        cell.checkBalanceAction = { [weak self] in
            guard let self = self else { return }
            checkBalance(address: addressStr.address, indexPath: indexPath, cell: cell)
        }
        
        cell.exportAction = { [weak self] in
            guard let self = self else { return }
            segueToShowQR(address: addressStr)
        }
        
        cell.copyAction = { [weak self] in
            guard let self = self else { return }
            copyAddress(address: addressStr.address)
        }
        
        cell.sweepAction = { [weak self] in
            guard let self = self else { return }
            createPsbt(addressStruct: addressStr)
        }
        
        return cell
    }
    
    private func createPsbt(addressStruct: AddressStruct) {
        guard let watchOnlyBdkWallet = watchOnlyBdkWallet else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let vc = SweepViewController(utxos: addressStruct.utxos, watchOnlyBdkWallet: watchOnlyBdkWallet, signer: signer, network: network)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func checkBalance(address: String, indexPath: IndexPath, cell: BitcoinAddressCell) {
        Task {
            let result = try await NodelessUtxoFetcher.shared.fetchUtxos(for: address, network: network)
            
            switch result {
            case .success(utxos: var utxos):
                var confirmed = true
                cell.hideBalanceLoading()
                
                if utxos.count == 0 {
                    deleteUtxoFromCache(address: address)
                }
                
                for (i, utxo) in utxos.enumerated() {
                    if !utxo.status.confirmed {
                        confirmed = false
                    }
                    utxos[i].address = address
                    utxos[i].lastUpdated = Date()
                    saveUtxo(utxo: utxo, address: address)
                }
                
                let totalBalanceBTC = utxos.reduce(0.0) { $0 + Double($1.value) / 100_000_000.0 }
                
                addresses[indexPath.row].balance = totalBalanceBTC
                addresses[indexPath.row].confirmed = confirmed
                addresses[indexPath.row].utxos = utxos
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tableView.reloadRows(at: [indexPath], with: .fade)
                }
                
            case.failure(errorMessage: let msg):
                cell.hideBalanceLoading()
                showAlert(vc: self, title: "", message: msg)
            }
        }
    }
    
    private func saveUtxo(utxo: Esplora_Utxo, address: String) {
        let utxoAlreadySaved = savedUtxos.contains { savedUtxo in
            savedUtxo.txid == utxo.txid && savedUtxo.vout == utxo.vout
        }
        var confirmed = 0
        if utxo.status.confirmed {
            confirmed = 1
        }
        
        if !utxoAlreadySaved {
            let dict: [String: Any] = [
                "txid": utxo.txid,
                "walletId": UUID(),
                "vout": Int64(utxo.vout),
                "address": address,
                "amount": Double(utxo.value) / 100_000_000.0,
                "confirmations": confirmed,
                "lastUpdated": Date(),
                "id": UUID()
            ]
            
            CoreDataService.saveEntity(dict: dict, entityName: .utxos) { saved in
                guard saved else { return }
                #if DEBUG
                print("utxo saved")
                #endif
            }
        } else {
        
            for savedUtxo in savedUtxos {
                if savedUtxo.txid == utxo.txid && savedUtxo.vout == utxo.vout {
                    guard let id = savedUtxo.id else { return }
                    CoreDataService.update(id: id, keyToUpdate: "lastUpdated", newValue: Date(), entity: .utxos) { updated in
                        guard updated else {
                            return
                        }
                        #if DEBUG
                        print("updated")
                        #endif
                        
                        CoreDataService.update(id: id, keyToUpdate: "confirmations", newValue: confirmed, entity: .utxos) { updated in
                            guard updated else {
                                return
                            }
                            #if DEBUG
                            print("updated")
                            #endif
                        }
                    }
                }
            }
        }
    }
    
    private func deleteUtxoFromCache(address: String) {
        for savedUtxo in savedUtxos {
            if savedUtxo.address == address {
                guard let id = savedUtxo.id else {
                    showAlert(title: "", message: "Cached utxo for \(address) was not deleted due to a missing UUID.")
                    return
                }
                CoreDataService.deleteEntity(id: id, entityName: .utxos) { deleted in
                    guard deleted else {
                        showAlert(title: "", message: "Cached utxo for \(address) was not deleted due to an error.")
                        return
                    }
                }
            }
        }
    }
        
    private func copyAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityVC = UIActivityViewController(activityItems: [address], applicationActivities: nil)
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                            y: self.view.bounds.midY,
                                            width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            self.present(activityVC, animated: true, completion: nil)
        }
    }
    
    private func segueToShowQR(address: AddressStruct) {
        self.addressToExport = address.address
        self.derivationToExport = address.derivation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToShowAddressQrFromNodeless", sender: self)
        }
    }

    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "segueToShowAddressQrFromNodeless":
            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
            
            vc.headerText = "Address"
            vc.text = self.addressToExport
            vc.descriptionText = self.derivationToExport + "\n\(self.addressToExport.addressExpanded)"
        default:
            break
        }
    }
    

}
