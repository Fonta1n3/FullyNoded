//
//  UtilitieMenuViewController.swift
//  BitSense
//
//  Created by Peter on 12/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UtilitieMenuViewController: UIViewController, UITabBarControllerDelegate, UITableViewDelegate, UITableViewDataSource {

    var activeNode = [String:Any]()
    let connectingView = ConnectingView()
    var getBlockchainInfo = Bool()
    var getAddressInfo = Bool()
    var listAddressGroups = Bool()
    var getNetworkInfo = Bool()
    var getWalletInfo = Bool()
    var getMiningInfo = Bool()
    var decodeScript = Bool()
    var getpeerinfo = Bool()
    var getMempoolInfo = Bool()
    var listLabels = Bool()
    var getaddressesbylabel = Bool()
    var getTransaction = Bool()
    var getbestblockhash = Bool()
    var getblock = Bool()
    var goSign = Bool()
    var goVerify = Bool()
    var getUtxos = Bool()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController?.delegate = self
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        getaddressesbylabel = false
        getMiningInfo = false
        getBlockchainInfo = false
        getWalletInfo = false
        getNetworkInfo = false
        listAddressGroups = false
        getAddressInfo = false
        decodeScript = false
        getpeerinfo = false
        getMempoolInfo = false
        listLabels = false
        getTransaction = false
        getbestblockhash = false
        getblock = false
        goVerify = false
        goSign = false
        getUtxos = false
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0: return 2
        case 1: return 7
        case 2: return 7
        case 3: return 2
        case 4: return 1
        default: return 0}
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "toolsCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        switch indexPath.section {
            
        case 0:
            
            switch indexPath.row {
            case 0: label.text = "Sign Message"
            case 1: label.text = "Verify Message"
            default: break}
            
        case 1:
            
            //Blockchain
            switch indexPath.row {
            case 0: label.text = "Rescan Blockchain"
            case 1: label.text = "Abort Blockchain Rescan"
            case 2: label.text = "Get Blockchain Info"
            case 3: label.text = "Get Mempool Info"
            case 4: label.text = "Get Transaction"
            case 5: label.text = "Get Last Block"
            case 6: label.text = "Get Block"
            default:break}
            
        case 2:
            
            //wallet
            switch indexPath.row {
            case 0: label.text = "Get Address Info"
            case 1: label.text = "List Address Groups"
            case 2: label.text = "Get Wallet Info"
            case 3: label.text = "Decode Script"
            case 4: label.text = "List Labels"
            case 5: label.text = "Addresses By Label"
            case 6: label.text = "UTXO's By Address"
            default:break}
            
        case 3:
            
            //network
            switch indexPath.row {
            case 0: label.text = "Get Network Info"
            case 1: label.text = "Get Peer Info"
            default:break}
            
        case 4:
            
            //mining
            switch indexPath.row {
            case 0: label.text = "Get Mining Info"
            default:break}
            
        default:
            
            break
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                switch indexPath.section {
                    
                case 0:
                    
                    switch indexPath.row {
                        
                    case 0: self.goSign = true
                    case 1: self.goVerify = true
                    default: break}
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goSign", sender: self)
                        
                    }
                    
                case 1:
                    
                    //Blockchain
                    switch indexPath.row {
                        
                    case 0:
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "starting rescan, this can take an hour or so and will affect the apps functionality")
                        
                        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.rescanblockchain,
                                                   param: "")
                        
                    case 1:
                        
                        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.abortrescan,
                                                   param: "")
                        
                    case 2:
                        
                        self.getBlockchainInfo = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                    case 3:
                        
                        self.getMempoolInfo = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                    case 4:
                        
                        self.getTransaction = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                    case 5:
                        
                        self.getbestblockhash = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                        
                    case 6:
                        
                        self.getblock = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                    default:
                        
                        break
                        
                    }
                    
                case 2:
                    
                    //wallet
                    switch indexPath.row {
                    case 0: self.getAddressInfo = true
                    case 1: self.listAddressGroups = true
                    case 2: self.getWalletInfo = true
                    case 3: self.decodeScript = true
                    case 4: self.listLabels = true
                    case 5: self.getaddressesbylabel = true
                    case 6: self.getUtxos = true
                    default:break}
                    
                    self.performSegue(withIdentifier: "goGetInfo", sender: self)
                    
                case 3:
                    
                    //network
                    switch indexPath.row {
                    case 0: self.getNetworkInfo = true
                    case 1: self.getpeerinfo = true
                    default:break}
                    
                    self.performSegue(withIdentifier: "goGetInfo", sender: self)
                    
                case 4:
                    
                    //mining
                    switch indexPath.row {
                        
                    case 0:
                        
                        self.getMiningInfo = true
                        self.performSegue(withIdentifier: "goGetInfo", sender: self)
                        
                    default:
                        
                        break
                        
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
        
        switch section {
        case 0: return "Identity"
        case 1: return "Blockchain"
        case 2: return "Wallet"
        case 3: return "Network"
        case 4: return "Mining"
        default: return ""}
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 12)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 20
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .rescanblockchain:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Rescanning completed")
                    
                case .abortrescan:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Rescan aborted")
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goGetInfo":
            
            if let vc = segue.destination as? GetInfoViewController {
                
                vc.getBlockchainInfo = self.getBlockchainInfo
                vc.getNetworkInfo = self.getNetworkInfo
                vc.listAddressGroups = self.listAddressGroups
                vc.getAddressInfo = self.getAddressInfo
                vc.getWalletInfo = self.getWalletInfo
                vc.getMiningInfo = self.getMiningInfo
                vc.decodeScript = self.decodeScript
                vc.getPeerInfo = self.getpeerinfo
                vc.getMempoolInfo = self.getMempoolInfo
                vc.listLabels = self.listLabels
                vc.getaddressesbylabel = self.getaddressesbylabel
                vc.getTransaction = self.getTransaction
                vc.getbestblockhash = self.getbestblockhash
                vc.getblock = self.getblock
                vc.getUtxos = self.getUtxos
                
            }
            
        case "goSign":
            
            if let vc = segue.destination as? IdentityViewController {
                
                vc.sign = goSign
                vc.verify = goVerify
                
            }
            
        default:
            
            break
            
        }
        
    }
    
}

extension UtilitieMenuViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
