//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import Foundation

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource  {
    
    let ud = UserDefaults.standard
    let spinner = ConnectingView()
    private var authenticated = false
    @IBOutlet var settingsTable: UITableView!
    
    private let blockchainInfoCurrencies:[[String:String]] = [
        ["USD": "dollarsign.circle"],
        ["GBP": "sterlingsign.circle"],
        ["EUR": "eurosign.circle"],
        ["AUD":"dollarsign.circle"],
        ["BRL": "brazilianrealsign.circle"],
        ["CAD": "dollarsign.circle"],
        ["CHF": "francsign.circle"],
        ["CLP": "dollarsign.circle"],
        ["CNY": "yensign.circle"],
        ["DKK": "k.circle"],
        ["HKD": "dollarsign.circle"],
        ["INR": "indianrupeesign.circle"],
        ["ISK": "k.circle"],
        ["JPY": "yensign.circle"],
        ["KRW": "wonsign.circle"],
        ["NZD": "dollarsign.circle"],
        ["PLN": "z.circle"],
        ["RUB": "rublesign.circle"],
        ["SEK": "k.circle"],
        ["SGD": "dollarsign.circle"],
        ["THB": "bahtsign.circle"],
        ["TRY": "turkishlirasign.circle"],
        ["TWD": "dollarsign.circle"]
    ]
    
    private let coindeskCurrencies:[[String:String]] = [
        ["USD": "dollarsign.circle"],
        ["GBP": "sterlingsign.circle"],
        ["EUR": "eurosign.circle"]
    ]
        
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
        
        if UserDefaults.standard.object(forKey: "useEsplora") == nil && UserDefaults.standard.object(forKey: "useEsploraWarning") == nil {            
            UserDefaults.standard.setValue(true, forKey: "useEsploraWarning")
        }
        
        if UserDefaults.standard.object(forKey: "useBlockchainInfo") == nil {
            UserDefaults.standard.set(true, forKey: "useBlockchainInfo")
        }
        
        let lastAuthenticated = (UserDefaults.standard.object(forKey: "LastAuthenticated") as? Date ?? Date()).secondsSince
        authenticated = (KeyChain.getData("userIdentifier") == nil || !(lastAuthenticated > authTimeout) && !(lastAuthenticated == 0))
        
        guard authenticated else {
            self.authenticateWith2FA { [weak self] response in
                guard let self = self else { return }
                
                self.authenticated = response
                
                if !response {
                    showAlert(vc: self, title: "⚠️ Authentication failed...", message: "You can not access settings unless you successfully authenticate with 2FA.")
                } else {
                    self.settingsTable.reloadData()
                }
            }
            return
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        settingsTable.reloadData()
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
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
            label.text = "Node manager"
            icon.image = UIImage(systemName: "desktopcomputer")
            background.backgroundColor = .systemBlue
            
        case 1:
            switch indexPath.row {
            case 0:
                label.text = "Wallet backup"
                icon.image = UIImage(systemName: "square.grid.3x1.folder.badge.plus")
                background.backgroundColor = .systemGreen
            case 1:
                label.text = "Wallet recovery"
                icon.image = UIImage(systemName: "square.grid.3x1.folder.badge.plus")
                background.backgroundColor = .systemPurple
            case 2:
                label.text = "Create/update iCloud backup"
                icon.image = UIImage(systemName: "icloud.and.arrow.up")
                background.backgroundColor = .systemIndigo
            case 3:
                label.text = "Recover from iCloud"
                icon.image = UIImage(systemName: "icloud.and.arrow.down")
                background.backgroundColor = .systemBlue
            case 4:
                label.text = "Delete iCloud backup"
                icon.image = UIImage(systemName: "xmark.icloud")
                background.backgroundColor = .systemRed
            case 5:
                label.text = "iCloud health check"
                icon.image = UIImage(systemName: "heart.text.square")
                background.backgroundColor = .systemPink
            default:
                break
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
        let esploraCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleEsploraCell", for: indexPath)
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
        let blockchainInfoCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleFxrateCell", for: indexPath)
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
        let coinDeskCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleFxrateCell", for: indexPath)
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
    
    func currencyCell(_ indexPath: IndexPath, _ currency: [String:String]) -> UITableViewCell {
        let currencyCell = settingsTable.dequeueReusableCell(withIdentifier: "toggleCurrencyCell", for: indexPath)
        configureCell(currencyCell)
        
        let label = currencyCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        
        let background = currencyCell.viewWithTag(2)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
                
        let icon = currencyCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        
        let toggle = currencyCell.viewWithTag(4) as! UISwitch
        let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        for (key, value) in currency {
            if currencyToUse == key {
                background.backgroundColor = .systemGreen
            } else {
                background.backgroundColor = .systemGray
            }
            
            toggle.restorationIdentifier = key
            toggle.setOn(currencyToUse == key, animated: true)
            
            label.text = key
            icon.image = UIImage(systemName: value)
        }
        
        toggle.addTarget(self, action: #selector(toggleCurrency(_:)), for: .valueChanged)
        
        return currencyCell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 2:
            return settingsCell(indexPath)
            
        case 1:
            switch indexPath.row {
            case 0, 1, 2, 3, 4, 5: return settingsCell(indexPath)
            default:
                return UITableViewCell()
            }
            
        case 3:
            switch indexPath.row {
            case 0: return esploraCell(indexPath)
            default:
                return UITableViewCell()
            }
            
        case 4:
            if indexPath.row == 0 {
                return blockchainInfoCell(indexPath)
            } else {
                return coinDeskCell(indexPath)
            }
            
        case 5:
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            
            var currencies:[[String:String]] = blockchainInfoCurrencies
            
            if !useBlockchainInfo {
                currencies = coindeskCurrencies
            }
            
            return currencyCell(indexPath, currencies[indexPath.row])
            
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
            textLabel.text = "Backup/Recovery"
            
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
        if authenticated {
            return 6
        } else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if authenticated {
            if section == 4 {
                return 2
            } else if section == 5 {
                let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
                if useBlockchainInfo {
                    return blockchainInfoCurrencies.count
                } else {
                    return coindeskCurrencies.count
                }
            } else if section == 1 {
                return 6
            } else {
                return 1
            }
        } else {
            return 0
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
            switch indexPath.row {
            case 0:
                warnToBackup()
            case 1:
                alertToRecover()
            case 2:
                promptToEnableiCloud()
            case 3:
                confirmiCloudRecovery()
            case 4:
                promptToDeleteiCloud()
            case 5:
                healthCheck()
            default:
                break
            }
        case 2:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "goToSecurity", sender: self)
            }
            
        default:
            break
            
        }
    }
    
    private func healthCheck() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToHealthCheck", sender: self)
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

            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 5), with: .fade)
        }
    }
    
    private func promptToEnableiCloud() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Create/update iCloud backup?"
            
            let mess = "Create an independent, encrypted iCloud database using a password of your choice. If you already created a backup this updates it.\n\nIf you forget your encryption password this backup will be completely useless! YOU MUST SAVE THE ENCRYPTION PASSWORD OFFLINE IN ORDER TO RECOVER YOUR BACKUP\n\nThis backs up signers, nodes, wallets, and Tor auth keys."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create/update backup", style: .default, handler: { action in
                self.confirmiCloudEnable()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDeleteiCloud() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Delete iCloud backup?"
            
            let mess = "This will delete your iCloud backup!"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete iCloud backup", style: .destructive, handler: { action in
                self.spinner.addConnectingView(vc: self, description: "deleting iCloud data...")
                
                BackupiCloud.destroy { destroyed in
                    UserDefaults.standard.setValue(false, forKey: "iCloudBackup")
                    self.spinner.removeConnectingView()
                    
                    if destroyed {
                        let _ = KeyChain.remove(key: "iCloudSHA")
                        
                        showAlert(vc: self, title: "", message: "iCloud backup deleted.")
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                        }
                    } else {
                        showAlert(vc: self, title: "Error", message: "iCloud backup NOT deleted.")
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
    }
    
    private func confirmiCloudEnable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Create/update iCloud backup?"
            let message = "You need to input a password which will be used to encrypt your iCloud backup."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let enable = UIAlertAction(title: "Create/update", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let text = (alert.textFields![0] as UITextField).text
                let confirmText = (alert.textFields![1] as UITextField).text
                
                guard let text = text,
                      let confirmText = confirmText,
                      confirmText == text,
                      let hash = self.hash(text) else {
                    showAlert(vc: self, title: "", message: "Please ensure both encryption passwords match.")
                    
                    return
                }
                
                self.createiCloudBackupNow(hash)
            }
            
            alert.addTextField { textField in
                textField.placeholder = "encryption password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addTextField { textField in
                textField.placeholder = "confirm password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(enable)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func createiCloudBackupNow(_ passwordHash: Data) {
        self.spinner.addConnectingView(vc: self, description: "creating iCloud backup...")
        
        BackupiCloud.backup(encryptionKey: passwordHash) { (backedup, message) in
            self.spinner.removeConnectingView()
            
            guard backedup else {
                showAlert(vc: self, title: "", message: message ?? "There was an error creating your iCould backup.")
                
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                showAlert(vc: self, title: "", message: "Encrypted iCloud backup updated ✓")
                self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
            }
        }
    }
    
    private func confirmiCloudRecovery() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Recover iCloud backup?"
            let message = "Input the encryption password that was used when you created this backup. Inputting the incorrect password here means your recovery data will get bricked."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let enable = UIAlertAction(title: "Recover", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let text = (alert.textFields![0] as UITextField).text
                let confirmText = (alert.textFields![1] as UITextField).text
                
                guard let text = text,
                      let confirmText = confirmText,
                      text == confirmText,
                      let hash = self.hash(text) else {
                    showAlert(vc: self, title: "", message: "Passwords don't match.")
                    
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "recovering...")
                
                BackupiCloud.recover(passwordHash: hash) { [weak self] (recovered, message) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    
                    if recovered {
                        let def = "Your data was recovered."
                        showAlert(vc: self, title: "", message: message == "" ? def : message ?? def)
                    } else {
                        showAlert(vc: self, title: "", message: message ?? "There was an issue recovering your data... Please let us know about it.")
                    }
                }
            }
            
            alert.addTextField { textField in
                textField.placeholder = "encryption password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addTextField { textField in
                textField.placeholder = "confirm password"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(enable)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            
            self.present(alert, animated:true, completion: nil)
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
                                    let utxoStr = Utxo(utxo)
                                    
                                    if let uxtoArrayId = processedUtxoArray[u]["id"] as? UUID {
                                        processedUtxoArray[u]["id"] = uxtoArrayId.uuidString
                                    }
                                    
                                    if let walletid = utxoStr.walletId {
                                        processedUtxoArray[u]["walletId"] = walletid.uuidString
                                    }
                                    
                                    
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
        
        guard let json = file.json() else { showAlert(vc: self, title: "", message: "Unable to convert your backup data into json..."); return }
        
        try? json.utf8.write(to: fileURL)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var controller:UIDocumentPickerViewController!
            
            if #available(iOS 14, *) {
                controller = UIDocumentPickerViewController(forExporting: [fileURL]) // 5
            } else {
                controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
            }
            
            self.present(controller, animated: true)
        }
    }
    
    @objc func toggleEsplora(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "useEsplora")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.settingsTable.reloadRows(at: [IndexPath(row: 0, section: 3)], with: .none)
        }
    }
    
    @objc func toggleBlockchainInfo(_ sender: UISwitch) {
        UserDefaults.standard.setValue(sender.isOn, forKey: "useBlockchainInfo")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 4, 5), with: .fade)
        }
    }
    
    @objc func toggleCoindesk(_ sender: UISwitch) {
        UserDefaults.standard.setValue(!sender.isOn, forKey: "useBlockchainInfo")
        
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        if sender.isOn {
            switch currency {
            case "USD", "GBP", "EUR":
                fallthrough
            default:
                UserDefaults.standard.setValue("USD", forKey: "currency")
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.settingsTable.reloadSections(IndexSet(arrayLiteral: 4, 5), with: .fade)
        }
    }
        
}



