//
//  InvoiceSettingsViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class InvoiceSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!
    var wallets = [[String:Any]]()
    var wallet = [String:Any]()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    let ud = UserDefaults.standard
    let cd = CoreDataService()

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        getSettings()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        } else {
            return 3
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "invoiceCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        let check = cell.viewWithTag(2) as! UIImageView
        let chevron = cell.viewWithTag(3) as! UIImageView
        switch indexPath.section {
        case 0:
            check.alpha = 0
            label.text = "HD Multisig"
            return cell
        case 1:
            chevron.alpha = 0
            switch indexPath.row {
            case 0:
                label.text = "Native Segwit"
                if nativeSegwit {
                    check.alpha = 1
                    label.textColor = .white
                } else {
                    check.alpha = 0
                    label.textColor = .darkGray
                }
                return cell
            case 1:
                label.text = "P2SH Segwit"
                if p2shSegwit {
                    check.alpha = 1
                    label.textColor = .white
                } else {
                    check.alpha = 0
                    label.textColor = .darkGray
                }
                return cell
            case 2:
                label.text = "Legacy"
                if legacy {
                    check.alpha = 1
                    label.textColor = .white
                } else {
                    check.alpha = 0
                    label.textColor = .darkGray
                }
                return cell
            default:
                return UITableViewCell()
            }
        default:
            return UITableViewCell()
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 0:
            
            if self.wallets.count > 0 {
                
                if self.wallets.count > 1 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "showWallets",
                                          sender: self)
                        
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "getHDmusigAddress",
                                          sender: self)
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "no hd musig wallets created yet")
                
            }
            
        case 1:
            
            //Address format
            for row in 0 ..< tableView.numberOfRows(inSection: 1) {
                
                if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 1)) {
                    
                    var key = ""
                    
                    switch row {
                    case 0: key = "nativeSegwit"
                    case 1: key = "p2shSegwit"
                    case 2: key = "legacy"
                    default:
                        break
                    }
                    
                    if indexPath.row == row && cell.isSelected {
                        
                        cell.isSelected = true
                        self.ud.set(true, forKey: key)
                        
                        DispatchQueue.main.async {
                            
                            self.getSettings()
                            tableView.reloadRows(at: [IndexPath(row: row, section: 1)], with: .none)
                            
                        }
                        
                    } else {
                        
                        cell.isSelected = false
                        self.ud.set(false, forKey: key)
                        
                        DispatchQueue.main.async {
                            
                            self.getSettings()
                            tableView.reloadRows(at: [IndexPath(row: row, section: 1)], with: .none)
                            
                        }
                        
                    }
                    
                }
                
            }
        default:
            break
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
            textLabel.text = "Multisig invoice"
            
        case 1:
            textLabel.text = "Invoice format"
            
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func getSettings() {
        nativeSegwit = ud.object(forKey: "nativeSegwit") as? Bool ?? true
        p2shSegwit = ud.object(forKey: "p2shSegwit") as? Bool ?? false
        legacy = ud.object(forKey: "legacy") as? Bool ?? false
        
        cd.retrieveEntity(entityName: .newHdWallets) { [unowned vc = self] in
            
            if !vc.cd.errorBool {
                
                if vc.cd.entities.count > 0 {
                    vc.wallets = vc.cd.entities
                    if vc.wallets.count == 1 {
                        vc.wallet = vc.wallets[0]
                    }
                }
                
            } else {
                
                displayAlert(viewController: vc, isError: true, message: "error getting hd wallets from coredata")
                
            }
            
        }
        DispatchQueue.main.async { [unowned vc = self] in
            vc.table.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "showWallets":
            if let vc = segue.destination as? WalletsViewController {
                vc.wallets = wallets
                vc.isHDInvoice = true
            }
        case "getHDmusigAddress":
            if let vc = segue.destination as? InvoiceViewController {
                vc.isHDInvoice = true
                vc.wallet = wallet
            }
        default:
            break
        }
    }
}
