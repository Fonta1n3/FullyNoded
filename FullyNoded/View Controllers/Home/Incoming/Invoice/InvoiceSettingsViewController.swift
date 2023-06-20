//
//  InvoiceSettingsViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 4/30/23.
//  Copyright © 2023 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class InvoiceSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!
    //@IBOutlet weak var table: UITableView!
    var isSingleKey = Bool()
    var isPrivKey = Bool()

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        getSettings()
        isPrivKey = false
        isSingleKey = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isSingleKey = false
        isPrivKey = false
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return 1
        case 1:
            return 2
        default:
            return 0
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
            label.text = "Bitcoin Core Wallets"
            label.textColor = .white
            chevron.alpha = 1
            return cell
            
        case 1:
            switch indexPath.row {
            case 0:label.text = "Address"
            case 1:label.text = "Private key"
            default:
                break
            }
            chevron.alpha = 1
            label.textColor = .white
            check.alpha = 0
            return cell
            
//        case 2:
//            chevron.alpha = 0
//            switch indexPath.row {
//            case 0:
//                label.text = "Native Segwit"
//                if nativeSegwit {
//                    check.alpha = 1
//                    label.textColor = .white
//                } else {
//                    check.alpha = 0
//                    label.textColor = .darkGray
//                }
//                return cell
//            case 1:
//                label.text = "P2SH Segwit"
//                if p2shSegwit {
//                    check.alpha = 1
//                    label.textColor = .white
//                } else {
//                    check.alpha = 0
//                    label.textColor = .darkGray
//                }
//                return cell
//            case 2:
//                label.text = "Legacy"
//                if legacy {
//                    check.alpha = 1
//                    label.textColor = .white
//                } else {
//                    check.alpha = 0
//                    label.textColor = .darkGray
//                }
//                return cell
//            default:
//                return UITableViewCell()
//            }
        default:
            return UITableViewCell()
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
            
        case 0:
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToBitcoinCoreWallets", sender: vc)
            }
            
        case 1:
            switch indexPath.row {
                
            case 0:
                isSingleKey = true
                
            case 1:
                isPrivKey = true
                
            default:
                break
            }
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToImportFromAdvanced", sender: vc)
            }
            
        //case 2:
            
            //Address format
//            for row in 0 ..< tableView.numberOfRows(inSection: 2) {
//
//                if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 2)) {
//
//                    var key = ""
//
//                    switch row {
//                    case 0: key = "nativeSegwit"
//                    case 1: key = "p2shSegwit"
//                    case 2: key = "legacy"
//                    default:
//                        break
//                    }
//
//                    if indexPath.row == row && cell.isSelected {
//
//                        cell.isSelected = true
//                        self.ud.set(true, forKey: key)
//
//                        DispatchQueue.main.async {
//
//                            self.getSettings()
//                            tableView.reloadRows(at: [IndexPath(row: row, section: 2)], with: .none)
//
//                        }
//
//                    } else {
//
//                        cell.isSelected = false
//                        self.ud.set(false, forKey: key)
//
//                        DispatchQueue.main.async {
//
//                            self.getSettings()
//                            tableView.reloadRows(at: [IndexPath(row: row, section: 2)], with: .none)
//
//                        }
//
//                    }
//
//                }
//
//            }
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
            textLabel.text = "Bitcoin Core Wallets"
            
        case 1:
            textLabel.text = "Import"
            
//        case 2:
//            textLabel.text = "Address script type"
            
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
        DispatchQueue.main.async { [unowned vc = self] in
            vc.table.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            case "segueToImportFromAdvanced":
                
                if let vc = segue.destination as? AddLabelViewController {
                    vc.isSingleKey = isSingleKey
                    vc.isPrivKey = isPrivKey
                }

        default:
            break
        }
    }
}
