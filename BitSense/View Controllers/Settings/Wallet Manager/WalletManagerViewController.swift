//
//  WalletManagerViewController.swift
//  BitSense
//
//  Created by Peter on 06/08/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class WalletManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet var walletTable: UITableView!
    
    let connectingView = ConnectingView()
    var activeWallets = [String]()
    var inactiveWallets = [String]()
    
    let ud = UserDefaults.standard
    
    @IBAction func addWallet(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "addWallet", sender: self)
        }
        
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        walletTable.delegate = self
        walletTable.tableFooterView = UIView(frame: .zero)
    
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        connectingView.addConnectingView(vc: self,
                                         description: "getting wallets")
        
        refresh()
        
    }
    
    @IBAction func infoButtonAction(_ sender: Any) {
        
        showAlert(vc: self, title: "Wallet Manager Info", message: "Your node can have many \"loaded\" or \"unloaded\" wallets. In order to work with a specific wallet you need to ensure it is loaded. To unload and load wallets simply tap them.\n\nLoading a wallet will trigger your home screen to refresh and subsequently fires off many node commands so please do not attempt to load many wallets for no reason.\n\nFullyNoded will remember the wallet you last loaded and work with that wallet.\n\nFor best results unload all wallets, then load the one you want to work with.\n\nTo use the default wallet just unload all wallets. Bitcoin Core does not allow you to unload or load the default wallet, it happens implicitly.")
        
    }
    
    
    func refresh() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.activeWallets.removeAll()
            vc.inactiveWallets.removeAll()
            vc.executeNodeCommand(method: .listwallets, param: "")
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            
            if activeWallets.count == 0 {
                
                return 1
                
            } else {
                
                return activeWallets.count
                
            }
            
        } else {
            
            return inactiveWallets.count
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        
        cell.selectionStyle = .none
        
        if indexPath.section == 0 {
            
            if activeWallets.count == 0 {
                
                cell.textLabel?.text = "Default Wallet"
                
            } else {
                
               cell.textLabel?.text = activeWallets[indexPath.row]
                
            }
            
        } else {
            
            cell.textLabel?.text = inactiveWallets[indexPath.row]
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            return "LOADED WALLETS"
            
        } else {
            
            return "UNLOADED WALLETS"
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.systemFont(ofSize: 12)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = .darkGray
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)!
        
        DispatchQueue.main.async {
            
            impact()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                }) { _ in
                    
                    if indexPath.section == 0 {
                        
                        if self.activeWallets.count > 0 {
                            
                            self.unloadWallet(walletName: self.activeWallets[indexPath.row])
                            
                        }
                        
                    } else {
                        
                       self.loadWallet(walletname: self.inactiveWallets[indexPath.row])
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func parseWallets(walletDict: NSDictionary) {
        
        let walletArr = walletDict["wallets"] as! NSArray
        
        for wallet in walletArr {
            
            let dict = wallet as! NSDictionary
            let walletName = dict["name"] as! String
            
            if walletName != "" {
                
                var isActive = false
                
                for aw in activeWallets {
                    
                    if aw == walletName {
                        
                        isActive = true
                    }
                    
                }
                
                if !isActive {
                    
                    inactiveWallets.append(walletName)
                    
                }
                
            }
            
        }
        
        DispatchQueue.main.async {
            
            self.connectingView.removeConnectingView()
            self.walletTable.reloadData()
            
        }
        
    }
    
    func parseActiveWallets(wallets: NSArray) {
        
        for wallet in wallets {
            
            let walletName = wallet as! String
            
            if walletName != "" {
                
               activeWallets.append(walletName)
                
            }
            
        }
        
        executeNodeCommand(method: .listwalletdir,
                              param: "")
        
    }
    
    func loadWallet(walletname: String) {
        
        connectingView.addConnectingView(vc: self,
                                         description: "Loading \(walletname)")
        
        executeNodeCommand(method: .loadwallet,
                              param: "\"\(walletname)\"")
        
    }
    
    func unloadWallet(walletName: String) {
        
        self.connectingView.addConnectingView(vc: self,
                                              description: "Unloading \(walletName)")
        
        if ud.object(forKey: "walletName") != nil {
            
            if ud.object(forKey: "walletName") as! String == walletName {
                
                ud.removeObject(forKey: "walletName")
                
            }
            
        }
        
        self.executeNodeCommand(method: BTC_CLI_COMMAND.unloadwallet,
                                   param: "\"\(walletName)\"")
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.loadwallet:
                    
                    let result = reducer.dictToReturn
                    
                    let name = result["name"] as! String
                    let warning = result["warning"] as! String
                    
                    ud.set(name, forKey: "walletName")
                    
                    if warning != "" {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "Wallet \"\(name)\" loaded with warning: \(warning)")
                        
                    }
                    
                    refresh()
                    NotificationCenter.default.post(name: .refreshHome, object: nil, userInfo: nil)
                    
                    displayAlert(viewController: self, isError: false, message: "Wallet loaded, we are now refreshing the home screen.")
                    
                case BTC_CLI_COMMAND.listwalletdir:
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.label.text = "getting wallets"
                        
                    }
                    
                    let dict =  reducer.dictToReturn
                    parseWallets(walletDict: dict)
                    
                case BTC_CLI_COMMAND.listwallets:
                    
                    DispatchQueue.main.async {
                        
                        self.connectingView.label.text = "getting wallets"
                        
                    }
                    
                    let array = reducer.arrayToReturn
                    
                    if array.count > 0 {
                        
                        parseActiveWallets(wallets: array)
                        
                    } else {
                        
                        connectingView.removeConnectingView()
                        
                        DispatchQueue.main.async {
                            
                            self.walletTable.reloadData()
                            
                        }
                        
                    }
                    
                case BTC_CLI_COMMAND.unloadwallet:
                    
                    let response = reducer.stringToReturn
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: response)
                    
                    refresh()
                    
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

}
