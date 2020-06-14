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
    var didChange = Bool()
    let connectingView = ConnectingView()
    var activeWallets = [String]()
    var inactiveWallets = [String]()
    var wallets = [[String:Any]]()
    var walletsToUnload:[String] = []
    
    let ud = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        walletTable.delegate = self
        walletTable.tableFooterView = UIView(frame: .zero)
    
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        refresh()
    }
    
    @IBAction func addWallet(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "addWallet", sender: self)
        }
        
    }
    
    @IBAction func unloadAction(_ sender: Any) {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        let reducer = Reducer()
        reducer.makeCommand(command: .listwallets, param: "") { [unowned vc = self] in
            if !reducer.errorBool {
                let loadedWallets = reducer.arrayToReturn
                for (i, w) in loadedWallets.enumerated() {
                    if (w as! String) != "" {
                        vc.walletsToUnload.append(w as! String)
                    }
                    if i + 1 == loadedWallets.count {
                        if vc.walletsToUnload.count > 0 {
                            vc.goUnload()
                        }
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them.")
            }
        }
    }
    
    
    
    func refresh() {
        connectingView.addConnectingView(vc: self, description: "getting wallets...")
        DispatchQueue.main.async { [unowned vc = self] in
            vc.activeWallets.removeAll()
            vc.inactiveWallets.removeAll()
            vc.executeNodeCommand(method: .listwalletdir, param: "")
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        let toggle = cell.viewWithTag(2) as! UISwitch
        let dict = wallets[indexPath.section]
        let isActive = dict["isActive"] as! Bool
        let name = dict["name"] as! String
        label.text = name
        toggle.setOn(isActive, animated: true)
        toggle.restorationIdentifier = "\(indexPath.section)"
        toggle.addTarget(self, action: #selector(toggleAction(_:)), for: .valueChanged)
        if isActive {
            label.textColor = .white
        } else {
            label.textColor = .darkGray
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    @objc func toggleAction(_ sender: UISwitch) {
        if sender.restorationIdentifier != nil {
            if let index = Int(sender.restorationIdentifier!) {
                if sender.isOn {
                    let walletToActivate = (wallets[index]["name"] as! String)
                    if walletToActivate != "Default Wallet" {
                        UserDefaults.standard.set(walletToActivate, forKey: "walletName")
                        wallets.removeAll()
                        didChange = true
                        refresh()
                    } else {
                        getAllActiveWallets()
                    }
                }
            }
        }
    }
    
    private func getAllActiveWallets() {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        let reducer = Reducer()
        reducer.makeCommand(command: .listwallets, param: "") { [unowned vc = self] in
            if !reducer.errorBool {
                let loadedWallets = reducer.arrayToReturn
                for (i, w) in loadedWallets.enumerated() {
                    if (w as! String) != "" {
                        vc.walletsToUnload.append(w as! String)
                    }
                    if i + 1 == loadedWallets.count {
                        if vc.walletsToUnload.count > 0 {
                            vc.promptToUnloadWallets()
                        } else {
                            vc.connectingView.removeConnectingView()
                            UserDefaults.standard.removeObject(forKey: "walletName")
                        }
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them.")
            }
        }
    }
    
    private func goUnload() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToUnloadWallets", sender: vc)
        }
    }
    
    private func promptToUnloadWallets() {
        connectingView.removeConnectingView()
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "In order to use the default wallet you need to unload all loaded wallets.", message: "In the next view you can tap each wallet to unload them, ensure you unload them all.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [unowned vc = self] action in
                vc.wallets.removeAll()
                vc.walletTable.reloadData()
                vc.goUnload()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    func parseWallets(walletDict: NSDictionary) {
        
        let walletArr = walletDict["wallets"] as! NSArray
        let activeWallet = UserDefaults.standard.object(forKey: "walletName") as? String ?? ""
        var activeIndex = -1
        for (i, wallet) in walletArr.enumerated() {
            let walletDict = wallet as! NSDictionary
            let walletName = walletDict["name"] as! String
            var isActive = false
            var dictName = walletName
            if walletName == activeWallet {
                isActive = true
                activeIndex = i
            }
            if walletName == "" {
                dictName = "Default Wallet"
                if isActive && !didChange {
                    getAllActiveWallets()
                }
            }
            let dict = ["name":dictName, "isActive":isActive] as [String : Any]
            wallets.append(dict)
            if i + 1 == walletArr.count {
                DispatchQueue.main.async { [unowned vc = self] in
                    if activeIndex > 0 {
                        vc.wallets.swapAt(0, activeIndex)
                    }
                    vc.connectingView.removeConnectingView()
                    vc.walletTable.reloadData()
                    if vc.didChange {
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                        vc.didChange = false
                        displayAlert(viewController: vc, isError: false, message: "Wallet set to active, refreshing home screen...")
                    }
                }
            }
        }
    }
    

    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.listwalletdir:
                    let dict =  reducer.dictToReturn
                    parseWallets(walletDict: dict)
                    
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
        let id = segue.identifier
        switch id {
        case "segueToUnloadWallets":
            if let vc = segue.destination as? ActiveWalletsViewController {
                vc.activeWallets = walletsToUnload
                walletsToUnload.removeAll()
            }
        default:
            break
        }
    }

}
