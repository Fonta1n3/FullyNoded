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
    var accountPubkey: String!
    var accountPath: String!
    var addressToExport = ""
    var derivationToExport = ""
    var network: WalletLogic.BDKNetwork!
    let spinner = ConnectingView.shared

    override func viewDidLoad() {
        super.viewDidLoad()
        CoreDataService.deleteAllData(entity: .usedAddresses) { deleted in
            
        }
        tableView.register(BitcoinAddressCell.self, forCellReuseIdentifier: "BitcoinCell")
        load()
    }
    
    func load() {
        spinner.show(vc: self, description: "Loading...")
        
        guard var decryptedData = Crypto.decrypt(signer.words!) else {
            spinner.dismiss()
            return
        }
        
        var passphrase: String?
        
        if signer.passphrase != nil {
            guard var decryptedPassphrase = Crypto.decrypt(signer.passphrase!) else {
                spinner.dismiss()
                return
            }
            
            defer {
                decryptedPassphrase.secureZero()
            }
            
            passphrase = String(bytes: decryptedPassphrase, encoding: .utf8)
        }
        
        if network == nil {
            guard let networkCheck = WalletLogic.shared.bdkNetwork() else {
                spinner.dismiss()
                return
            }
            
            network = networkCheck
        }        
        
        guard var words = String(bytes: decryptedData, encoding: .utf8) else {
            spinner.dismiss()
            return
        }
        
        guard let secretMasterKey = WalletLogic.shared.bdkMasterKey(network: network, mnemonic: words, passphrase: passphrase) else {
            spinner.dismiss()
            return
        }
        
        guard let persister = WalletLogic.shared.persistor() else {
            spinner.dismiss()
            return
        }
        
        defer {
            words.secureWipe()
            passphrase?.secureWipe()
            decryptedData.secureZero()
        }
        
        var recDesc: WalletLogic.BDKDescriptor!
        var changeDesc: WalletLogic.BDKDescriptor!
        
        if accountPath.hasPrefix("m/86") {
            recDesc = WalletLogic.BDKDescriptor.newBip86(secretKey: secretMasterKey, keychainKind: .external, network: network)
            changeDesc = WalletLogic.BDKDescriptor.newBip86(secretKey: secretMasterKey, keychainKind: .internal, network: network)
        }
        
        if accountPath.hasPrefix("m/84") {
            recDesc = WalletLogic.BDKDescriptor.newBip84(secretKey: secretMasterKey, keychainKind: .external, network: network)
            changeDesc = WalletLogic.BDKDescriptor.newBip84(secretKey: secretMasterKey, keychainKind: .internal, network: network)
        }
        
        guard let bdkWallet = try? WalletLogic.BDKWallet(descriptor: recDesc, changeDescriptor: changeDesc, network: network, persister: persister) else {
            spinner.dismiss()
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            for i in 0...999 {
                print("i: \(i)")
                let addressInfo = bdkWallet.peekAddress(keychain: .external, index: UInt32(i))
                
                let str = AddressStruct(dictionary: [
                    "address": addressInfo.address.description,
                    "used": false,
                    "balance": 0.0,
                    "derivation": "\(accountPath!)/0/\(i)"
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
                checkUsedAddresses()
                return
            }
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                for (u, utxo) in utxos.enumerated() {
                    for (i, address) in addresses.enumerated() {
                        if address.address == utxo["address"] as? String {
                            saveUsedAddress(address: address.address, balance: utxo["amount"] as! Double)
                        }
                        if u + 1 == utxos.count && i + 1 == addresses.count {
                            checkUsedAddresses()
                        }
                    }
                }
            }
        }
    }
    
    func saveUsedAddress(address: String, balance: Double) {
        let usedAddress: [String: Any] = [
            "address": address,
            "balance": balance,
            "id": UUID()
        ]
        
        CoreDataService.saveEntity(dict: usedAddress, entityName: .usedAddresses) { _ in }
    }
    
    private func checkUsedAddresses() {
        CoreDataService.retrieveEntity(entityName: .usedAddresses) { [weak self] usedAddresses in
            guard let self = self else { return }
            
            guard let usedAddresses = usedAddresses, usedAddresses.count > 0 else {
                spinner.dismiss()
                reload()
                return
            }
            
            DispatchQueue.global(qos: .background).async { [weak self] in
                guard let self = self else { return }
                for (u, usedAddresses) in usedAddresses.enumerated() {
                    for (i, address) in addresses.enumerated() {
                        if address.address == usedAddresses["address"] as? String {
                            self.addresses[i].balance = usedAddresses["amount"] as! Double
                            self.addresses[i].used = true
                        }
                        if u + 1 == usedAddresses.count && i + 1 == addresses.count {
                            spinner.dismiss()
                            self.reload()
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
            checkBalance(address: addressStr.address)
        }
        
        cell.exportAction = { [weak self] in
            guard let self = self else { return }
            segueToShowQR(address: addressStr)
        }
        
        cell.copyAction = { [weak self] in
            guard let self = self else { return }
            copyAddress(address: addressStr.address)
        }
        
        return cell
    }
    
    private func checkBalance(address: String) {
        ConnectingView.shared.show(vc: self, description: "")
        let isMainnet = (network == .bitcoin)
        NodelessBalanceFetcher.shared.fetchAddressBalance(address: address, isTestnet: !isMainnet) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let balance):
                if balance > 0 {
                    updateUsedAddress(address: address, balance: balance)
                } else {
                    ConnectingView.shared.dismiss()
                    showAlert(vc: self, title: "", message: "Balance for \(address.addressExpanded) is 0.")
                }
            case .failure(let error):
                ConnectingView.shared.dismiss()
                showAlert(vc: self, title: "", message: error.localizedDescription)
            }
        }
    }
    
    private func updateUsedAddress(address: String, balance: Double) {
        CoreDataService.retrieveEntity(entityName: .usedAddresses) { [weak self] usedAddresses in
            guard let self = self else { return }
            
            guard let usedAddresses = usedAddresses, usedAddresses.count > 0 else {
                saveUsedAddress(address: address, balance: balance)
                checkUsedAddresses()
                return
            }
            
            for (i, usedAddress) in usedAddresses.enumerated() {
                if usedAddress["address"] as? String == address {
                    let id = usedAddress["id"] as! UUID
                    let balance = usedAddress["balance"] as! Double
                    CoreDataService.update(id: id, keyToUpdate: "balance", newValue: balance, entity: .usedAddresses) { updated in
                        guard updated else {
                            print("error updating used address")
                            return
                        }
                    }
                }
                
                if i + 1 == usedAddresses.count {
                    checkUsedAddresses()
                }
            }
        }
    }
    
    private func copyAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UIPasteboard.general.string = address
            showAlert(vc: self, title: "", message: "Address copied ✓")
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
            vc.descriptionText = self.derivationToExport
        default:
            break
        }
    }
    

}
