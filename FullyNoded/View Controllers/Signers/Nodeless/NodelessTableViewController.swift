//
//  NodelessTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/5/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import UIKit


class NodelessTableViewController: UITableViewController {
    
    var savedUtxos: [UTXO] = []
    var addresses: [AddressStruct] = []
    var signer: SignerStruct!
    var addressToExport = ""
    var derivationToExport = ""
    var network: WalletLogic.BDKNetwork!
    let spinner = ConnectingView.shared
    var primaryDescriptor = ""
    var watchOnlyBdkWallet: WalletLogic.BDKWallet?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(BitcoinAddressCell.self, forCellReuseIdentifier: "BitcoinCell")
    }
    
    override func viewDidAppear(_ animated: Bool) {
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
            message: "This action cannot be undone.",
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
        let changeDesc = "\(descArr[0])".replacingOccurrences(of: "/0/", with: "/1/")
                
        if network != .bitcoin {
            network = .testnet
        }
        
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
                    "utxos": []
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
            
            guard let utxos = utxos, utxos.count > 0 else {
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
                            }
                            
                            let satsValue = Int64(utxoStruct.amount / 100000000)
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
                            reload()
                        }
                    }
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
        
//        cell.sweepAction = { [weak self] in
//            guard let self = self else { return }
//            createPsbt(addressStruct: addressStr)
//        }
        
        return cell
    }
    
//    private func createPsbt(addressStruct: AddressStruct) {
//        guard let watchOnlyBdkWallet = watchOnlyBdkWallet else {
//            print("no wallet")
//            return
//        }
//        
//        var totalAmount: UInt64 = 0
//        
//        for utxo in addressStruct.utxos {
//            totalAmount += UInt64(utxo.value)
//        }
//        
//        do {
//            let psbt = try WalletLogic.shared.createPsbtWithManualInputs(
//                wallet: watchOnlyBdkWallet,
//                utxos: addressStruct.utxos,
//                outputs: [(address: "tb1q9956wfhq9jzqvhmlapz5849axc35s35q6uwc5a", amount: totalAmount)],
//                network: network
//            )
//            print("psbt: \(psbt)")
//        } catch {
//            print(error.localizedDescription)
//        }        
//    }
    
    private func checkBalance(address: String, indexPath: IndexPath, cell: BitcoinAddressCell) {
        let isTestnet = (network == .testnet)
        Task {
            do {
                var utxos = try await NodelessUtxoFetcher.shared.fetchUtxos(for: address, isTestnet: isTestnet)
                var confirmed = true
                cell.hideBalanceLoading()
                
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
                
            } catch {
                cell.hideBalanceLoading()
                showAlert(vc: self, title: "", message: error.localizedDescription)
            }
        }
    }
    
    private func saveUtxo(utxo: Esplora_Utxo, address: String) {
        let utxoAlreadySaved = savedUtxos.contains { savedUtxo in
            savedUtxo.txid == utxo.txid && savedUtxo.vout == utxo.vout
        }
        print("utxoAlreadySaved: \(utxoAlreadySaved)")
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
