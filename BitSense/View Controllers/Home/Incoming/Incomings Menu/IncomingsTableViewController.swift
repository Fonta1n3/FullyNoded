//
//  IncomingsTableViewController.swift
//  BitSense
//
//  Created by Peter on 22/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import NMSSH

class IncomingsTableViewController: UITableViewController, NMSSHChannelDelegate, UITabBarControllerDelegate {
    
    var isSingleKey = Bool()
    var isPrivKey = Bool()
    
    var isPruned = Bool()
    var isTestnet = Bool()
    
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    let userDefaults = UserDefaults.standard
    
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    
    var activeNode = [String:Any]()
    @IBOutlet var incomingsTable: UITableView!
    
    var isExtendedKey = Bool()
    var isHDMultisig = Bool()
    
    let cd = CoreDataService()
    var wallets = [[String:Any]]()
    var wallet = [String:Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController?.delegate = self

        incomingsTable.tableFooterView = UIView(frame: .zero)
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(),
                                                               for: UIBarMetrics.default)
        
        navigationController?.navigationBar.shadowImage = UIImage()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        isPrivKey = false
        isSingleKey = false
        
        getSettings()
        
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 5
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numberOfRows = 0
        switch section {
        case 0: numberOfRows = 2
        case 1: numberOfRows = 6
        case 2: numberOfRows = 1
        case 3: numberOfRows = 3
        default:
            break
        }
        
        return numberOfRows
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
            
        case 0:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            
            var labelString = ""
            switch indexPath.row {
            case 0: labelString = "Invoice"
            case 1: labelString = "HD Musig Cold Storage"
            default: break
            }
            cell.textLabel?.text = labelString
            return cell
            
        case 1:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            var labelString = ""
            
            switch indexPath.row {
            case 0:labelString = "Address"
            case 1:labelString = "Public key"
            case 2:labelString = "Private key"
            case 3:labelString = "XPUB"
            case 4:labelString = "XPRV"
            case 5:labelString = "Multisig"
            //case 6:labelString = "HD multisig"
            default:
                break
            }
            
            cell.textLabel?.text = labelString
            
            return cell
            
        case 2:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            var labelString = ""
            
            switch indexPath.row {
            case 0:labelString = "Create"
            //case 1:labelString = "HD"
            default:
                break
            }
            
            cell.textLabel?.text = labelString
            
            return cell
            
        case 3:
            
            let importSettingsCell = tableView.dequeueReusableCell(withIdentifier: "importSettingsCell", for: indexPath)
            let label = importSettingsCell.viewWithTag(1) as! UILabel
            let check = importSettingsCell.viewWithTag(2) as! UIImageView
            let switcher = importSettingsCell.viewWithTag(3) as! UISwitch
            let rangeLabel = importSettingsCell.viewWithTag(4) as! UILabel
            switcher.alpha = 0
            importSettingsCell.selectionStyle = .none
            
            //address type
            rangeLabel.alpha = 0
            
            switch indexPath.row {
                
            case 0:
                
                label.text = "Native Segwit"
                
                if nativeSegwit {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
                
            case 1:
                
                label.text = "P2SH Segwit"
                
                if p2shSegwit {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            case 2:
                
                label.text = "Legacy"
                
                if legacy {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            default:
                
                break
                
            }
            
            return importSettingsCell
            
        default:
            
            let cell = UITableViewCell()
            return cell
            
        }
        
    }
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row,
                                                           section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                switch indexPath.section {
                    
                case 0:
                    
                    var segueString = ""
                    switch indexPath.row {
                        
                    case 0: segueString = "createInvoice"
                        
                    case 1:
                        
                        if self.wallets.count > 1 {
                            
                            segueString = "showWallets"
                            
                        } else {
                            
                            segueString = "getHDmusigAddress"
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: segueString,
                                          sender: self)
                    }
                    
                case 1:
                    
                    DispatchQueue.main.async {
                        
                        var segueString = ""
                        
                        switch indexPath.row {
                            
                        case 2:
                            
                            segueString = "importAKey"
                            self.isPrivKey = true
                            self.isSingleKey = true
                            
                        case 3, 4:
                            
                            segueString = "goImportExtendedKeys"
                            
                        case 5:
                            
                            segueString = "importMultiSig"
                            
//                        case 6:
//
//                            segueString = "importHDMultisig"
                            
                        default:
                            
                            segueString = "importAKey"
                            self.isSingleKey = true
                            
                        }
                        
                        self.performSegue(withIdentifier: segueString,
                                          sender: self)
                    }
                    
                case 2:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "importMultiSig",
                                          sender: self)
                    }
                    
                case 3:
                    
                    //Address format
                    for row in 0 ..< tableView.numberOfRows(inSection: 3) {
                        
                        if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 3)) {
                            
                            var key = ""
                            
                            switch row {
                            case 0:
                                key = "nativeSegwit"
                            case 1:
                                key = "p2shSegwit"
                            case 2:
                                key = "legacy"
                            default:
                                break
                            }
                            
                            if indexPath.row == row && cell.isSelected {
                                
                                cell.isSelected = true
                                self.userDefaults.set(true, forKey: key)
                                
                                DispatchQueue.main.async {
                                    
                                    self.getSettings()
                                    tableView.reloadRows(at: [IndexPath(row: row, section: 3)], with: .none)
                                    
                                }
                                
                            } else {
                                
                                cell.isSelected = false
                                self.userDefaults.set(false, forKey: key)
                                
                                DispatchQueue.main.async {
                                    
                                    self.getSettings()
                                    tableView.reloadRows(at: [IndexPath(row: row, section: 3)], with: .none)
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
    
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var string = ""
        switch section {
        case 0: string = "Get an address"
        case 1: string = "Import"
        case 2: string = "Create multisig"
        case 3: string = "Invoice address format"
        default:
            break
        }
        
        return string
        
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .right
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
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
            
        case "importAKey":
            
            if let vc = segue.destination as? AddLabelViewController {

                vc.isSingleKey = isSingleKey
                vc.isPrivKey = isPrivKey
            }
            
            print("prepare for segue importAKey")
            
        case "importMultiSig":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isSingleKey = false
                vc.isPrivKey = false
                vc.isMultisig = true
            }
            
        case "goImportExtendedKeys":
            
            print("prepare for segue goImportExtendedKeys")
            
//        case "importHDMultisig":
//
//            print("prepare for segue hdmusig")
            
        default:
            
            break
            
        }
        
    }
    
    func getSettings() {
        
        if userDefaults.object(forKey: "nativeSegwit") != nil {
            
            nativeSegwit = userDefaults.bool(forKey: "nativeSegwit")
            
        } else {
            
            nativeSegwit = true
            
        }
        
        if userDefaults.object(forKey: "p2shSegwit") != nil {
            
            p2shSegwit = userDefaults.bool(forKey: "p2shSegwit")
            
        } else {
            
            p2shSegwit = false
            
        }
        
        if userDefaults.object(forKey: "legacy") != nil {
            
            legacy = userDefaults.bool(forKey: "legacy")
            
        } else {
            
            legacy = false
            
        }
        
        let nodes = cd.retrieveCredentials()
        let isActive = isAnyNodeActive(nodes: nodes)
        var nodeID = ""
        
        if isActive {
            
            for node in nodes {
                
                let active = node["isActive"] as! Bool
                
                if active {
                    
                    nodeID = node["id"] as! String
                    
                }
                
            }
            
        }
        
        wallets = cd.getHDWallets(nodeID: nodeID)
        print("wallets = \(wallets)")
        
        if wallets.count == 1 {
            
            wallet = wallets[0]
            
        }
        
        DispatchQueue.main.async {
            
            self.tableView.reloadData()
            
        }
        
    }
    
    func isAnyNodeActive(nodes: [[String:Any]]) -> Bool {
        
        var boolToReturn = false
        
        for node in nodes {
            
            let isActive = node["isActive"] as! Bool
            
            if isActive {
                
                boolToReturn = true
                
            }
            
        }
        
        return boolToReturn
        
    }

}

extension IncomingsTableViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
