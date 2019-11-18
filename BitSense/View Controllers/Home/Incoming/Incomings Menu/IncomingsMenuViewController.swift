//
//  IncomingsMenuViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class IncomingsMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITabBarControllerDelegate {
    
    var isSingleKey = Bool()
    var isPrivKey = Bool()
    var isPruned = Bool()
    var isTestnet = Bool()
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    let ud = UserDefaults.standard
    var isExtendedKey = Bool()
    var isHDMultisig = Bool()
    let cd = CoreDataService()
    var wallets = [[String:Any]]()
    var wallet = [String:Any]()
    var descriptors = [[String:Any]]()
    @IBOutlet var incomingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tabBarController?.delegate = self
        incomingsTable.tableFooterView = UIView(frame: .zero)
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        descriptors.removeAll()
        wallets.removeAll()
        isPrivKey = false
        isSingleKey = false
        getSettings()
        
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 4
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numberOfRows = 0
        switch section {
        case 0: numberOfRows = 2
        case 1: numberOfRows = 7
        case 2: numberOfRows = 1
        case 3: numberOfRows = 3
        default:
            break
        }
        
        return numberOfRows
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                 for: indexPath)
        
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        let check = cell.viewWithTag(2) as! UIImageView
        var labelString = ""
        
        switch indexPath.section {
            
        case 0:
            
            check.alpha = 0
            label.textColor = UIColor.white
            
            switch indexPath.row {
            case 0: labelString = "Invoice"
            case 1: labelString = "HD Multisig"
            default: break
            }
            
            label.text = labelString
            
        case 1:
            
            check.alpha = 0
            label.textColor = UIColor.white
            
            switch indexPath.row {
            case 0:labelString = "Address"
            case 1:labelString = "Public key"
            case 2:labelString = "Private key"
            case 3:labelString = "XPUB"
            case 4:labelString = "XPRV"
            case 5:labelString = "Multisig"
            case 6:labelString = "Descriptor"
            default:
                break
            }
            
            label.text = labelString
            
        case 2:
            
            check.alpha = 0
            label.textColor = UIColor.white
            
            switch indexPath.row {
            case 0:labelString = "Descriptors"
            default:
                break
            }
            
            label.text = labelString
            
        case 3:
            
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
            
        default:
            
            break
            
        }
        
        return cell
        
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
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
                    
                    switch indexPath.row {
                        
                    case 0:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "createInvoice",
                                              sender: self)
                        }
                        
                    case 1:
                        
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
                        
                    default:
                        
                        break
                        
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
                            
                        case 6:
                            
                            segueString = "importDescriptor"
                            
                        default:
                            
                            segueString = "importAKey"
                            self.isSingleKey = true
                            
                        }
                        
                        self.performSegue(withIdentifier: segueString,
                                          sender: self)
                    }
                    
                case 2:
                    
                    print("show descriptor")
                    
                    self.cd.retrieveEntity(entityName: .descriptors) {
                        
                        if !self.cd.errorBool {
                            
                            self.descriptors = self.cd.entities
                            
                            if self.descriptors.count > 0 {
                                
                                DispatchQueue.main.async {
                                    
                                    self.performSegue(withIdentifier: "showDescriptors",
                                                      sender: self)
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: self,
                                             isError: true,
                                             message: "no xpubs, xprvs or multisig wallets imported yet")
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: self, isError: true, message: "error getting descriptors from core data")
                            
                        }
                        
                    }
                    
                case 3:
                    
                    //Address format
                    for row in 0 ..< tableView.numberOfRows(inSection: 3) {
                        
                        if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 3)) {
                            
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
                                    tableView.reloadRows(at: [IndexPath(row: row, section: 3)], with: .none)
                                    
                                }
                                
                            } else {
                                
                                cell.isSelected = false
                                self.ud.set(false, forKey: key)
                                
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
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        var string = ""
        switch section {
        case 0: string = "Get an address"
        case 1: string = "Import"
        case 2: string = "Export"
        case 3: string = "Invoice address format"
        default:
            break
        }
        
        return string
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
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
            
        case "importMultiSig":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isSingleKey = false
                vc.isPrivKey = false
                vc.isMultisig = true
            }
            
        case "showDescriptors":
            
            if let vc = segue.destination as? DescriptorsViewController {
                
                vc.descriptors = descriptors
                
            }
            
        case "importDescriptor":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isDescriptor = true
                vc.isSingleKey = false
                vc.isMultisig = false
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    func getSettings() {
        
        nativeSegwit = ud.object(forKey: "nativeSegwit") as? Bool ?? true
        p2shSegwit = ud.object(forKey: "p2shSegwit") as? Bool ?? false
        legacy = ud.object(forKey: "legacy") as? Bool ?? false
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !self.cd.errorBool {
                
                let nodes = self.cd.entities
                //only display HDWallets that were imported into this node
                for nodeDict in nodes {
                    
                    let node = NodeStruct(dictionary: nodeDict)
                    
                    if node.isActive {
                        
                        let activeNodeID = node.id
                        
                        self.cd.retrieveEntity(entityName: .hdWallets) {
                            
                            if !self.cd.errorBool {
                                
                                let allWallets = self.cd.entities
                                for walletDict in allWallets {
                                    
                                    let wallet = Wallet(dictionary: walletDict)
                                    let walletsNodeID = wallet.nodeID
                                    
                                    if activeNodeID == walletsNodeID {
                                        
                                        self.wallets.append(walletDict)
                                        
                                    }
                                    
                                }
                                
                            } else {
                                
                                displayAlert(viewController: self, isError: true, message: "error getting hd wallets from coredata")
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
                if self.wallets.count == 1 {
                    
                    self.wallet = self.wallets[0]
                    
                }
                
                DispatchQueue.main.async {
                    
                    self.incomingsTable.reloadData()
                    
                }
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "error getting nodes from coredata")
                
            }
            
        }
        
    }
    
}

extension IncomingsMenuViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
