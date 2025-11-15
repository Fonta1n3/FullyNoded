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
    @IBOutlet var settingsTable: UITableView!
    
    private let coindeskCurrencies:[[String:String]] = [
        ["USD": "dollarsign.circle"],
        ["GBP": "sterlingsign.circle"],
        ["EUR": "eurosign.circle"]
    ]
        
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
        
        if UserDefaults.standard.object(forKey: "useBlockchainInfo") == nil {
            UserDefaults.standard.set(true, forKey: "useBlockchainInfo")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        settingsTable.reloadData()
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        cell.tintColor = .systemBlue
    }
    
    private func settingsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let settingsCell = settingsTable.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        configureCell(settingsCell)
        
        let label = settingsCell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        let icon = settingsCell.viewWithTag(3) as! UIImageView
        
        switch indexPath.section {
        case 0:
            label.text = "Node Manager"
            icon.image = UIImage(systemName: "desktopcomputer")
            
        case 1:
            label.text = "Security Center"
            icon.image = UIImage(systemName: "lock.shield")
            
        default:
            break
        }
        
        return settingsCell
    }
    
    func exchangeRateApiCell(_ indexPath: IndexPath) -> UITableViewCell {
        let exchangeRateApiCell = settingsTable.dequeueReusableCell(withIdentifier: "checkmarkCell", for: indexPath)
        configureCell(exchangeRateApiCell)
        
        let label = exchangeRateApiCell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        let icon = exchangeRateApiCell.viewWithTag(3) as! UIImageView
        
        let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
        
        icon.image = UIImage(systemName: "server.rack")
        
        switch indexPath.row {
        case 0:
            label.text = "Blockchain.info"
            if useBlockchainInfo {
                //background.backgroundColor = .systemBlue
                exchangeRateApiCell.isSelected = true
                exchangeRateApiCell.accessoryType = .checkmark
            } else {
                //background.backgroundColor = .systemGray
                exchangeRateApiCell.isSelected = false
                exchangeRateApiCell.accessoryType = .none
            }
        case 1:
            label.text = "Coindesk"
            if !useBlockchainInfo {
                exchangeRateApiCell.isSelected = true
                exchangeRateApiCell.accessoryType = .checkmark
            } else {
                exchangeRateApiCell.isSelected = false
                exchangeRateApiCell.accessoryType = .none
            }
        default:
            break
        }
        
        return exchangeRateApiCell
    }
    
    func currencyCell(_ indexPath: IndexPath, _ currency: [String:String]) -> UITableViewCell {
        let currencyCell = settingsTable.dequeueReusableCell(withIdentifier: "checkmarkCell", for: indexPath)
        configureCell(currencyCell)
        
        let label = currencyCell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
                
        let icon = currencyCell.viewWithTag(3) as! UIImageView
        
        let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        for (key, value) in currency {
            if currencyToUse == key {
                currencyCell.accessoryType = .checkmark
                currencyCell.isSelected = true
            } else {
                currencyCell.accessoryType = .none
                currencyCell.isSelected = false
            }
            label.text = key
            icon.image = UIImage(systemName: value)
        }
        
        return currencyCell
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 1:
            return settingsCell(indexPath)
            
        case 2:
            return exchangeRateApiCell(indexPath)
            
        case 3:
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            
            var currencies:[[String:String]] = Currencies.currenciesWithCircle
            
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
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        switch section {
        case 0:
            textLabel.text = "Nodes"
                        
        case 1:
            textLabel.text = "Security"
            
        case 2:
            textLabel.text = "Exchange Rate API"
            
        case 3:
            textLabel.text = "Fiat Currency"
            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 2: return 2
        case 3:
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            if useBlockchainInfo {
                return Currencies.currenciesWithCircle.count
            } else {
                return coindeskCurrencies.count
            }
        default:
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
            switch indexPath.row {
            case 0: UserDefaults.standard.setValue(true, forKey: "useBlockchainInfo")
            case 1: UserDefaults.standard.setValue(false, forKey: "useBlockchainInfo")
            default:
                break
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.settingsTable.reloadSections(.init(arrayLiteral: 2, 3), with: .none)
            }
            
        case 3:
            spinner.addConnectingView(vc: self, description: "fetching fx rate...")
            let useBlockchainInfo = UserDefaults.standard.object(forKey: "useBlockchainInfo") as? Bool ?? true
            var currencies:[[String:String]] = []
            if useBlockchainInfo {
                currencies = Currencies.currenciesWithCircle
            } else {
                currencies = coindeskCurrencies
            }
            let currencyDict = currencies[indexPath.row]
            for (key, _) in currencyDict {
                UserDefaults.standard.setValue(key, forKey: "currency")
                //UserDefaults.standard.setValue(key.lowercased(), forKey: "unit")
                
                FiatConverter.sharedInstance.getFxRate(currency: key) { [weak self] fxRate in
                    guard let self = self else { return }
                    
                    spinner.removeConnectingView()
                    
                    guard let fxRate = fxRate else {
                        showAlert(vc: self, title: "", message: "There was an error fetching the exchange rate for \(key).")
                        return
                    }
                    
                    UserDefaults.standard.setValue(fxRate, forKey: "fxRate")
                    
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        //self.settingsTable.reloadSections(.init(arrayLiteral: 2, 4), with: .none)
                        settingsTable.reloadData()
                        
                        showAlert(vc: self, title: "", message: "You need to tap the refresh button on the active wallet view to update the balance currency.")
                    }
                }
            }
        default:
            break
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
}



