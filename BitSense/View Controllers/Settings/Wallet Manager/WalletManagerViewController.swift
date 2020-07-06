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
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "addWallet", sender: vc)
        }
    }
    
    @IBAction func unloadAction(_ sender: Any) {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        Reducer.makeCommand(command: .listwallets, param: "") { [unowned vc = self] (response, errorMessage) in
            if let loadedWallets = response as? NSArray {
                for (i, w) in loadedWallets.enumerated() {
                    if (w as! String) != "" {
                        vc.walletsToUnload.append(w as! String)
                    }
                    if i + 1 == loadedWallets.count {
                        if vc.walletsToUnload.count > 0 {
                            vc.goUnload()
                        } else {
                            vc.connectingView.removeConnectingView()
                            showAlert(vc: self, title: "Only the Default Wallet is loaded", message: "You can not unload the default wallet.")
                        }
                    }
                }
            } else {
                vc.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them: \(errorMessage ?? "")")
            }
        }
    }
    
    
    
    func refresh() {
        connectingView.addConnectingView(vc: self, description: "getting wallets...")
        DispatchQueue.main.async { [unowned vc = self] in
            vc.activeWallets.removeAll()
            vc.inactiveWallets.removeAll()
            vc.wallets.removeAll()
            vc.walletTable.reloadData()
            Reducer.makeCommand(command: .listwalletdir, param: "") { [unowned vc = self] (response, errorMessage) in
                if let dict =  response as? NSDictionary {
                    vc.parseWallets(walletDict: dict)
                } else {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.connectingView.removeConnectingView()
                        displayAlert(viewController: vc, isError: true, message: "error getting wallets: \(errorMessage ?? "")")
                    }
                }
            }
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
                let wallet = (wallets[index]["name"] as! String)
                if sender.isOn {
                    if wallet != "Default Wallet" {
                        UserDefaults.standard.set(wallet, forKey: "walletName")
                        wallets.removeAll()
                        didChange = true
                        refresh()
                    } else {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        getAllActiveWallets()
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
            }
        }
    }
    
    private func getAllActiveWallets() {
        connectingView.addConnectingView(vc: self, description: "getting all loaded wallets...")
        Reducer.makeCommand(command: .listwallets, param: "") { [unowned vc = self] (response, errorMessage) in
            if let loadedWallets = response as? NSArray {
                if loadedWallets.count > 1 {
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
                }
            } else {
                vc.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them: \(errorMessage ?? "")")
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
