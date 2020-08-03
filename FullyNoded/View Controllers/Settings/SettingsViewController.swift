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
    }

    override func viewDidAppear(_ animated: Bool) {
        
        settingsTable.reloadData()
        
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
            label.text = "Security Center"
            icon.image = UIImage(systemName: "lock.shield")
            background.backgroundColor = .systemOrange
        case 2:
            label.text = "Kill Switch ☠️"
            icon.image = UIImage(systemName: "exclamationmark.triangle")
            background.backgroundColor = .systemRed
        default:
            break
        }
        return settingsCell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0, 1, 2:
            return settingsCell(indexPath)
            
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
            textLabel.text = "Security"
            
        case 2:
            textLabel.text = "Reset"
            
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 3 {
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
            
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "goToSecurity", sender: self)
                
            }
            
        case 2:
            
            kill()
            
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
        
}



