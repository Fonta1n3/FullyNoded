//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIDocumentPickerDelegate {
    
    let ud = UserDefaults.standard
    @IBOutlet var settingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
                
        if UserDefaults.standard.object(forKey: "useEsplora") == nil && UserDefaults.standard.object(forKey: "useEsploraWarning") == nil {
            showAlert(vc: self, title: "New Privacy Setting", message: "When using a pruned node users may look up external transaction input details with Esplora over Tor.\n\nEnabling Esplora may have negative privacy implications and is discouraged.\n\n**ONLY APPLIES TO PRUNED NODES**")
            
            UserDefaults.standard.setValue(true, forKey: "useEsploraWarning")
        }
        
        if UserDefaults.standard.object(forKey: "useBlockchainInfo") == nil {
            UserDefaults.standard.set(true, forKey: "useBlockchainInfo")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        settingsTable.reloadData()
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
    }
    
    private func settingsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let settingsCell = settingsTable.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        configureCell(settingsCell)
        
        let label = settingsCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = settingsCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let icon = settingsCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        switch indexPath.section {
        case 0:
            label.text = "Node Manager"
            icon.image = UIImage(systemName: "desktopcomputer")
            background.backgroundColor = .systemBlue
            
        case 1:
            label.text = "Security Center"
            icon.image = UIImage(systemName: "lock.shield")
            background.backgroundColor = .systemOrange
            
        case 4:
            if indexPath.row == 0 {
                label.text = "Wallet Backup"
                icon.image = UIImage(systemName: "triangle")
                background.backgroundColor = .systemGreen
            } else {
                label.text = "Wallet Recovery"
                icon.image = UIImage(systemName: "triangle.fill")
                background.backgroundColor = .systemPurple
            }
            
            
        default:
            break
        }
        
        return settingsCell
    }
    
    func esploraCell(_ indexPath: IndexPath) -> UITableViewCell {
        let esploraCell = settingsTable.dequeueReusableCell(withIdentifier: "esploraCell", for: indexPath)
        configureCell(esploraCell)
        
        let label = esploraCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = esploraCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let icon = esploraCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let toggle = esploraCell.viewWithTag(4) as! UISwitch
        toggle.addTarget(self, action: #selector(toggleEsplora(_:)), for: .valueChanged)
        
        guard let useEsplora = UserDefaults.standard.object(forKey: "useEsplora") as? Bool, useEsplora else {
            toggle.setOn(false, animated: true)
            label.text = "Esplora disabled"
            icon.image = UIImage(systemName: "shield.fill")
            background.backgroundColor = .systemGreen
            return esploraCell
        }
        
        toggle.setOn(true, animated: true)
        label.text = "Esplora enabled"
        icon.image = UIImage(systemName: "shield.slash.fill")
        background.backgroundColor = .systemOrange
        
        return esploraCell
    }
    
    func blockchainInfoCell(_ indexPath: IndexPath) -> UITableViewCell {
        let blockchainInfoCell = settingsTable.dequeueReusableCell(withIdentifier: "esploraCell", for: indexPath)
        configureCell(blockchainInfoCell)
        
        let label = blockchainInfoCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = blockchainInfoCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let icon = blockchainInfoCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let toggle = blockchainInfoCell.viewWithTag(4) as! UISwitch
        toggle.addTarget(self, action: #selector(toggleBlockchainInfo(_:)), for: .valueChanged)
        
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        toggle.setOn(useBlockchainInfo, animated: true)
        label.text = "Blockchain.info"
        icon.image = UIImage(systemName: "dollarsign.circle")
        
        if useBlockchainInfo {
            background.backgroundColor = .systemBlue
        } else {
            background.backgroundColor = .systemGray
        }
        
        return blockchainInfoCell
    }
    
    func coinDeskCell(_ indexPath: IndexPath) -> UITableViewCell {
        let coinDeskCell = settingsTable.dequeueReusableCell(withIdentifier: "esploraCell", for: indexPath)
        configureCell(coinDeskCell)
        
        let label = coinDeskCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = coinDeskCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        let icon = coinDeskCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let toggle = coinDeskCell.viewWithTag(4) as! UISwitch
        toggle.addTarget(self, action: #selector(toggleCoindesk(_:)), for: .valueChanged)
        
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        toggle.setOn(!useBlockchainInfo, animated: true)
        label.text = "Coindesk"
        icon.image = UIImage(systemName: "dollarsign.circle")
        
        if useBlockchainInfo {
            background.backgroundColor = .systemGray
        } else {
            background.backgroundColor = .systemBlue
        }
        
        return coinDeskCell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 1, 4:
            return settingsCell(indexPath)
            
        case 2:
            return esploraCell(indexPath)
            
        case 3:
            if indexPath.row == 0 {
                return blockchainInfoCell(indexPath)
            } else {
                return coinDeskCell(indexPath)
            }
            
        default:
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        switch section {
        case 0:
            textLabel.text = "Nodes"
            
        case 1:
            textLabel.text = "Security"
            
        case 2:
            textLabel.text = "Privacy"
            
        case 3:
            textLabel.text = "Exchange Rate API"
            
        case 4:
            textLabel.text = "Wallet Backup/Recovery"
            
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 3 {
            return 2
        } else if section == 4 {
            return 2
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        impact()
        
        switch indexPath.section {
        case 0:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "goToNodes", sender: self)
            }
            
        case 1:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "goToSecurity", sender: self)
            }
            
        case 2:
            print("enable Esplora")
            
//        case 3:
//            kill()
        
        case 4:
            if indexPath.row == 0 {
                alertToBackup()
            } else {
                alertToRecover()
            }
            
            
        default:
            break
            
        }
    }
    
    private func alertToRecover() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Master Wallet Recovery"
            let mess = "Recover wallet backup file."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Recover", style: .default, handler: { action in
                self.importJson()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func importJson() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)//public.item in iOS and .import
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if controller.documentPickerMode == .import {
            
            guard let data = try? Data(contentsOf: urls[0].absoluteURL),
                  let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup file. This is only compatible with Fully Noded wallet backup files.")
                return
            }
            
            if let wallets = dict["wallets"] as? [[String:Any]], let transactions = dict["transactions"] as? [[String:Any]] {
                var mainnetWallets = [[String:Any]]()
                var testnetWallets = [[String:Any]]()
                
                for (i, wallet) in wallets.enumerated() {
                    for (_, value) in wallet {
                        guard let string = value as? String else { return }
                        
                        let data = string.dataUsingUTF8StringEncoding
                        
                        guard let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                            showAlert(vc: self, title: "", message: "That does not appear to be a recognized wallet backup file. This is only compatible with Fully Noded wallet backup files.")
                            return
                        }
                        
                        guard let desc = dict["descriptor"] as? String else { return }
                        
                        let descriptorParser = DescriptorParser()
                        let descStr = descriptorParser.descriptor(desc)
                        if descStr.chain == "Mainnet" {
                            mainnetWallets.append(dict)
                        } else if descStr.chain == "Testnet" {
                            testnetWallets.append(dict)
                        }
                    }
                    
                    if i + 1 == wallets.count {
                        alertToRecoverWalletsTransactions(mainnetWallets, testnetWallets, transactions)
                    }
                }
            }
        }
    }
    
    private func alertToRecoverWalletsTransactions(_ mainnetWallets: [[String:Any]], _ testnetWallets: [[String:Any]], _ transactions: [[String:Any]]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let chain = UserDefaults.standard.object(forKey: "chain") as? String else {
                showAlert(vc: self, title: "", message: "Could not determine which chain the node is using. Please reload the home screen and try again.")
                return
            }
            
            var wallets = mainnetWallets
            
            if chain == "test" {
                wallets = testnetWallets
            }
            
            let mess = "This will recover \(wallets.count) wallets and transaction metadata (labels and memos) for \(transactions.count) transactions."
            
            let tit = "Recover Now?"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Recover", style: .default, handler: { action in
                self.recover(wallets, transactions)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recover(_ wallets: [[String:Any]], _ transactions: [[String:Any]]) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        
        CoreDataService.retrieveEntity(entityName: .transactions) { existingTxs in
            for (i, tx) in transactions.enumerated() {
                
                func saveNew() {
                    if let date = dateFormatter.date(from: tx["date"] as! String) {
                        let dict = [
                            "txid":tx["txid"] as! String,
                            "id":UUID(),
                            "memo":tx["memo"] as! String,
                            "date":date as Date,
                            "label":tx["label"] as! String,
                            "originFxRate":tx["originFxRate"] as? Double ?? 0.0
                        ] as [String:Any]
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { success in
                            guard success else {
                                showAlert(vc: self, title: "", message: "Error saving your transaction.")
                                return
                            }
                            
                            if i + 1 == transactions.count {
                                showAlert(vc: self, title: "Transaction metadata recovered ✓", message: "When you reload your wallet you will see the recovered memos, labels and capital gains data.")
                            }
                        }
                    }
                }
                
                if let existingTxs = existingTxs, existingTxs.count > 0 {
                    var alreadySaved = false
                    var idToUpdate:UUID!
                    
                    for (e, existingTx) in existingTxs.enumerated() {
                        let existingTxStruct = TransactionStruct(dictionary: existingTx)
                        
                        func update() {
                            CoreDataService.update(id: idToUpdate, keyToUpdate: "memo", newValue: tx["memo"] as! String, entity: .transactions) { success in
                                guard success else {
                                    showAlert(vc: self, title: "", message: "Error updating existing transaction memo.")
                                    return
                                }
                                CoreDataService.update(id: idToUpdate, keyToUpdate: "label", newValue: tx["label"] as! String, entity: .transactions) { success in
                                    guard success else {
                                        showAlert(vc: self, title: "", message: "Error updating existing transaction label.")
                                        return
                                    }
                                    CoreDataService.update(id: idToUpdate, keyToUpdate: "originFxRate", newValue: tx["originFxRate"] as? Double ?? 0.0, entity: .transactions) { success in
                                        guard success else {
                                            showAlert(vc: self, title: "", message: "Error updating existing transaction origin rate.")
                                            return
                                        }
                                        
                                        if i + 1 == transactions.count {
                                            showAlert(vc: self, title: "Transaction metadata recovered ✓", message: "When you reload your wallet you will see the recovered memos, labels and capital gains data.")
                                        }
                                    }
                                }
                            }
                        }
                        
                        if existingTxStruct.txid == tx["txid"] as! String {
                            alreadySaved = true
                            idToUpdate = existingTxStruct.id
                        }
                        
                        if e + 1 == existingTxs.count {
                            if !alreadySaved {
                                saveNew()
                            } else {
                                update()
                            }
                        }
                    }
                } else {
                    saveNew()
                }
            }
        }
    }
    
    private func alertToBackup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Master Wallet Backup"
            let mess = "Backup wallet files."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Backup", style: .default, handler: { action in
                self.exportJson()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func exportJson() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else { return }
            
            CoreDataService.retrieveEntity(entityName: .transactions) { transactions in
                guard var transactions = transactions else { return }
                
                let dateFormatter = DateFormatter()
                
                for (i, tx) in transactions.enumerated() {
                    if let id = tx["id"] as? UUID {
                        transactions[i]["id"] = id.uuidString
                    }
                    
                    if let walletId = tx["walletId"] as? UUID {
                        transactions[i]["walletId"] = walletId.uuidString
                    }
                    
                    if let date = tx["date"] as? Date {
                        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
                        let dateString = dateFormatter.string(from: date)
                        transactions[i]["date"] = dateString
                    }
                }
                
                var jsonArray = [[String:Any]]()
                
                for (i, wallet) in wallets.enumerated() {
                    let walletStruct = Wallet(dictionary: wallet)
                    let accountMapString = AccountMap.create(wallet: walletStruct) ?? ""
                    jsonArray.append(["\(walletStruct.label)":accountMapString])
                    
                    if i + 1 == wallets.count {
                        let file:[String:Any] = ["wallets": jsonArray, "transactions": transactions]
                        
                        let fileManager = FileManager.default
                        let fileURL = fileManager.temporaryDirectory.appendingPathComponent("wallets.fullynoded")
                        guard let json = file.json() else { return }
                        try? json.dataUsingUTF8StringEncoding.write(to: fileURL)
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            if #available(iOS 14, *) {
                                let controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
                                self.present(controller, animated: true)
                            } else {
                                let controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                                self.present(controller, animated: true)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @objc func toggleEsplora(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "useEsplora")
        
        if sender.isOn {
            showAlert(vc: self, title: "Esplora enabled ✓", message: "Enabling Esplora may have negative privacy implications and is discouraged.\n\n**ONLY APPLIES TO PRUNED NODES**")
        } else {
            showAlert(vc: self, title: "", message: "Esplora disabled ✓")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.settingsTable.reloadData()
        }
    }
    
    @objc func toggleBlockchainInfo(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "useBlockchainInfo")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.settingsTable.reloadData()
        }
    }
    
    @objc func toggleCoindesk(_ sender: UISwitch) {
        UserDefaults.standard.setValue(!sender.isOn, forKey: "useBlockchainInfo")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.settingsTable.reloadData()
        }
    }
        
}



