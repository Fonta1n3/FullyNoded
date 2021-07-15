//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let ud = UserDefaults.standard
    @IBOutlet var settingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
                        
        if UserDefaults.standard.object(forKey: "useEsplora") == nil && UserDefaults.standard.object(forKey: "useEsploraWarning") == nil {            
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
            if indexPath.row == 0 {
                label.text = "Wallet Backup"
                icon.image = UIImage(systemName: "square.grid.3x1.folder.badge.plus")
                background.backgroundColor = .systemGreen
            } else {
                label.text = "Wallet Recovery"
                icon.image = UIImage(systemName: "square.grid.3x1.folder.badge.plus")
                background.backgroundColor = .systemPurple
            }
            
        case 2:
            label.text = "Security Center"
            icon.image = UIImage(systemName: "lock.shield")
            background.backgroundColor = .systemOrange
            
        
            
        default:
            break
        }
        
        return settingsCell
    }
    
    func esploraCell(_ indexPath: IndexPath) -> UITableViewCell {
        let esploraCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCell", for: indexPath)
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
        let blockchainInfoCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCell", for: indexPath)
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
        let coinDeskCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCell", for: indexPath)
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
    
    func currencyCell(_ indexPath: IndexPath, _ currency: String) -> UITableViewCell {
        let currencyCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCell", for: indexPath)
        configureCell(currencyCell)
        
        let label = currencyCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = currencyCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        label.text = currency
        
        let icon = currencyCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let toggle = currencyCell.viewWithTag(4) as! UISwitch
        toggle.restorationIdentifier = currency
        toggle.addTarget(self, action: #selector(toggleCurrency(_:)), for: .valueChanged)
        
        let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        if currencyToUse == currency {
            background.backgroundColor = .systemGreen
        } else {
            background.backgroundColor = .systemGray
        }
        
        toggle.setOn(currencyToUse == currency, animated: true)
        
        switch currency {
        case "USD":
            icon.image = UIImage(systemName: "dollarsign.circle")
        case "GBP":
            icon.image = UIImage(systemName: "sterlingsign.circle")
        case "EUR":
            icon.image = UIImage(systemName: "eurosign.circle")
        default:
            break
        }
        
        return currencyCell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 1, 2:
            return settingsCell(indexPath)
            
        case 3:
            return esploraCell(indexPath)
            
        case 4:
            if indexPath.row == 0 {
                return blockchainInfoCell(indexPath)
            } else {
                return coinDeskCell(indexPath)
            }
            
        case 5:
            switch indexPath.row {
            case 0:
                return currencyCell(indexPath, "USD")
            case 1:
                return currencyCell(indexPath, "GBP")
            case 2:
                return currencyCell(indexPath, "EUR")
            default:
                return UITableViewCell()
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
            textLabel.text = "Wallet Backup/Recovery"
            
        case 2:
            textLabel.text = "Security"
            
        case 3:
            textLabel.text = "Privacy"
            
        case 4:
            textLabel.text = "Exchange Rate API"
            
        case 5:
            textLabel.text = "Fiat Currency"
            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 4 || section == 1 {
            return 2
        } else if section == 5 {
            return 3
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
            if indexPath.row == 0 {
                warnToBackup()
            } else {
                alertToRecover()
            }
            
        case 2:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "goToSecurity", sender: self)
            }
            
        case 3:
            print("enable Esplora")        
            
        default:
            break
            
        }
    }
    
    @objc func toggleCurrency(_ sender: UISwitch) {
        let currency = sender.restorationIdentifier!
        
        if sender.isOn {
            UserDefaults.standard.setValue(currency, forKey: "currency")
        } else {
            UserDefaults.standard.setValue("USD", forKey: "currency")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.settingsTable.reloadData()
        }
    }
    
    private func alertToRecover() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToRecoveryDetail", sender: self)
        }
    }
    
    private func warnToBackup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "WARNING!"
            let mess = "THIS BACKUP DOES ***NOT*** INCLUDE ANY PRIVATE KEY MATERIAL!\n\nAlways backup your signers offline on paper or metal, ensuring you keep them safe and secure."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                self.alertToBackup()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func alertToBackup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Master Wallet Backup"
            let mess = "Backup all of your wallets so that you can easily recover them in the future. This file will be saved unencrypted and only contains *PUBLIC* keys, you must always backup your signers seperately."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create backup", style: .default, handler: { action in
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
                        
                        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
                            guard let self = self else { return }
                            var processedUtxoArray:[[String:Any]] = []
                            
                            if let utxos = utxos, utxos.count > 0 {
                                processedUtxoArray = utxos
                                
                                for (u, utxo) in utxos.enumerated() {
                                    let utxoStr = UtxosStruct(dictionary: utxo)
                                    processedUtxoArray[u]["id"] = utxoStr.id!.uuidString
                                    processedUtxoArray[u]["walletId"] = utxoStr.walletId!.uuidString
                                    
                                    if u + 1 == utxos.count {
                                        let file:[String:Any] = ["wallets": jsonArray, "transactions": transactions, "utxos": processedUtxoArray.json() ?? []]
                                        self.saveFile(file)
                                    }
                                }
                            } else {
                                let file:[String:Any] = ["wallets": jsonArray, "transactions": transactions, "utxos": processedUtxoArray.json() ?? []]
                                self.saveFile(file)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveFile(_ file: [String:Any]) {
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



