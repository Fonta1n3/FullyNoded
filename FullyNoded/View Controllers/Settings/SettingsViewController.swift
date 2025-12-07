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
    @IBOutlet var settingsTable: UITableView!
    
        
    override func viewDidLoad() {
        super.viewDidLoad()
        settingsTable.delegate = self
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
            
        case 2:
            let currencyToUse = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
            label.text = currencyToUse
            
            for currency in Currencies.currenciesWithCircle {
                for (key, value) in currency {
                    if key == currencyToUse {
                        icon.image = UIImage(systemName: value)
                    }
                }
            }
        
        case 3:
            label.text = "App Icon"
            icon.image = UIImage(systemName: "photo")
            
        default:
            break
        }
        
        return settingsCell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return settingsCell(indexPath)
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
            textLabel.text = "Fiat Currency"
            
        case 3:
            textLabel.text = "App Icon"
            
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
        return 1
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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "segueToCurrencies", sender: self)
            }
            
        case 3:
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "segueToAppIconSelector", sender: self)
            }
        default:
            break
        }
    }
}



