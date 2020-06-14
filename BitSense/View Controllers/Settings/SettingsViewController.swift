//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
//import KeychainSwift

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarControllerDelegate {
    
    let ud = UserDefaults.standard
    var miningFeeText = ""
    @IBOutlet var settingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController!.delegate = self
        settingsTable.delegate = self
        
    }

    override func viewDidAppear(_ animated: Bool) {
        
        settingsTable.reloadData()
        
    }
    
    func updateFeeLabel(label: UILabel, numberOfBlocks: Int) {
        
        let seconds = ((numberOfBlocks * 10) * 60)
        
        func updateFeeSetting() {
            
            ud.set(numberOfBlocks, forKey: "feeTarget")
            
        }
        
        DispatchQueue.main.async {
            
            if seconds < 86400 {
                
                //less then a day
                
                if seconds < 3600 {
                    
                    DispatchQueue.main.async {
                        
                        //less then an hour
                        label.text = "Target \(numberOfBlocks) blocks (\(seconds / 60) minutes)"
                        //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                        
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        //more then an hour
                        label.text = "Target \(numberOfBlocks) blocks (\(seconds / 3600) hours)"
                        //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                        
                    }
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    //more then a day
                    label.text = "Target \(numberOfBlocks) blocks (\(seconds / 86400) days)"
                    //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                    
                }
                
            }
            
            updateFeeSetting()
            
        }
            
    }
    
    @objc func setFee(_ sender: UISlider) {
        
        let cell = settingsTable.cellForRow(at: IndexPath.init(row: 0, section: 4))
        let label = cell?.viewWithTag(1) as! UILabel
        let numberOfBlocks = Int(sender.value) * -1
        updateFeeLabel(label: label, numberOfBlocks: numberOfBlocks)
            
    }
    
    private func settingsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let settingsCell = settingsTable.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        let label = settingsCell.viewWithTag(1) as! UILabel
        label.textColor = .lightGray
        settingsCell.selectionStyle = .none
        label.adjustsFontSizeToFitWidth = true
        let background = settingsCell.viewWithTag(2)!
        let icon = settingsCell.viewWithTag(3) as! UIImageView
        icon.tintColor = .white
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        switch indexPath.section {
        case 0:
            label.text = "Node Manager"
            icon.image = UIImage(systemName: "desktopcomputer")
            background.backgroundColor = .systemBlue
        case 1:
            label.text = "Wallet Manager"
            icon.image = UIImage(systemName: "square.stack.3d.down.right")
            background.backgroundColor = .systemGreen
        case 2:
            label.text = "Security Center"
            icon.image = UIImage(systemName: "lock.shield")
            background.backgroundColor = .systemOrange
        case 3:
            label.text = "Kill Switch ☠️"
            icon.image = UIImage(systemName: "exclamationmark.triangle")
            background.backgroundColor = .systemRed
        default:
            break
        }
        return settingsCell
    }
    
    private func miningFeeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = settingsTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let slider = cell.viewWithTag(2) as! UISlider
        label.adjustsFontSizeToFitWidth = true
        let background = cell.viewWithTag(3)!
        let icon = cell.viewWithTag(4) as! UIImageView
        icon.image = UIImage(systemName: "timer")
        icon.tintColor = .white
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        background.backgroundColor = .systemIndigo
        slider.addTarget(self, action: #selector(setFee), for: .allEvents)
        slider.maximumValue = 2 * -1
        slider.minimumValue = 1008 * -1
        if ud.object(forKey: "feeTarget") != nil {
            let numberOfBlocks = ud.object(forKey: "feeTarget") as! Int
            slider.value = Float(numberOfBlocks) * -1
            updateFeeLabel(label: label, numberOfBlocks: numberOfBlocks)
        } else {
            label.text = "Minimum fee set (you can always bump it)"
            slider.value = 1008 * -1
        }
        label.text = ""
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 1, 2, 3:
            return settingsCell(indexPath)
            
        case 4:
            return miningFeeCell(indexPath)
            
        default:
            let cell = UITableViewCell()
            cell.backgroundColor = UIColor.clear
            return cell
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
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        switch section {
        case 0:
            textLabel.text = "Nodes"
            
        case 1:
            textLabel.text = "Wallets"
            
        case 2:
            textLabel.text = "Security"
            
        case 3:
            textLabel.text = "Reset"
            
        case 4:
            textLabel.text = "Mining Fee"
            
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
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 4 {
            return 78
        } else {
            return 54
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        impact()
        
        switch indexPath.section {
            
        case 0:
            
            //node manager
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "goToNodes", sender: self)
                
            }
            
        case 1:
            
            //Wallet manager
            switch indexPath.row {
                
            case 0:
                
                self.goToWalletManager()
                
            default:
                
                break
                
            }
            
        case 2:
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "goToSecurity", sender: self)
                
            }
            
        case 3:
            
            kill()
            
        case 4:
            
            //mining fee
            print("do nothing")
            
        default:
            
            break
            
        }
        
    }
    
    func kill() {
        
        let tit = "Danger!"
        let mess = "This will DELETE all the apps data, are you sure you want to proceed?"
        let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { action in
            
            let killswitch = KillSwitch()
            let killed = killswitch.resetApp(vc: self.navigationController!)
            
            if killed {
                
                displayAlert(viewController: self,
                             isError: false,
                             message: "app has been reset")
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "error reseting app")
                
            }
            
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
            
        }))
        
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func goToWalletManager() {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "goManageWallets", sender: self)
            
        }
        
    }
        
}

public extension Int {
    
    func withCommas() -> String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
}

extension SettingsViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}



