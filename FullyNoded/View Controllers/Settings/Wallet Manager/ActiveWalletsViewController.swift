//
//  ActiveWalletsViewController.swift
//  BitSense
//
//  Created by Peter on 14/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var table: UITableView!
    var activeWallets: [[String: Any]] = []
    var fnWallets: [Wallet] = []
    let connectingView = ConnectingView.shared
    private var initialLoad = true

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        table.delegate = self
        table.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            getAllActiveWallets()
            initialLoad = false
        }
    }
    
    private func getAllActiveWallets() {
        connectingView.show(vc: self, description: "getting all loaded wallets...")
        activeWallets.removeAll()
        
        OnchainUtils.listWallets { [weak self] (wallets, message) in
            guard let self = self else { return }
            
            guard let loadedWallets = wallets else {
                self.connectingView.dismiss()
                showAlert(vc: self, title: "Error", message: "There was an error getting your active wallets in order to deactivate them: \(message ?? "")")
                return
            }
            
            guard loadedWallets.count > 0 else {
                self.connectingView.dismiss()
                return
            }
            
            var walletDict: [String: Any] = [:]
            print("loadedWallets.count: \(loadedWallets.count)")
            
            for (i, walletName) in loadedWallets.enumerated() {
                if walletName != "" {
                    walletDict["name"] = walletName
                    
                    for fnWallet in fnWallets {
                        if fnWallet.name == walletName {
                            walletDict["label"] = fnWallet.label
                        }
                    }
                    
                    self.activeWallets.append(walletDict)
                }
                
                if i + 1 == loadedWallets.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        table.reloadData()
                        connectingView.dismiss()
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return activeWallets.count
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "activeWallet", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        label.lineBreakMode = .byTruncatingMiddle
        if let walletLabel = activeWallets[indexPath.row]["label"] as? String {
            label.text = walletLabel
        } else {
            label.text = (activeWallets[indexPath.row]["name"] as! String)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        connectingView.show(vc: self, description: "unloading wallet...")
        
        let p = Unload_Wallet(["wallet_name": activeWallets[indexPath.row]["name"] as! String])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .unloadwallet(param: p)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let _ = response else {
                self.connectingView.dismiss()
                showAlert(vc: self, title: "Error", message: "There was an error unloading your wallet: \(errorMessage!)")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if self.activeWallets.count == 0 {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
                
                showAlert(title: "", message: "Wallet unloaded.")
                self.connectingView.dismiss()
                self.getAllActiveWallets()
            }
        }
    }   
}
