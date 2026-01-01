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
    let connectingView = ConnectingView.shared
    var activeWallets: [String] = []
    var inactiveWallets: [String] = []
    var wallets: [[String:Any]] = []
    var walletsToUnload: [[String: Any]] = []
    var fnWallets: [Wallet] = []
    
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
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "addWallet", sender: self)
        }
    }
    
    @IBAction func unloadAction(_ sender: Any) {
        goUnload()
    }
        
    func refresh() {
        connectingView.show(vc: self, description: "getting wallets...")
        
        self.fnWallets.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] fnWallets in
            guard let self = self else { return }
            
            if let fnWallets = fnWallets, fnWallets.count > 0 {
                for fnWallet in fnWallets {
                    let w = Wallet(dictionary: fnWallet)
                    self.fnWallets.append(w)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.activeWallets.removeAll()
                self.inactiveWallets.removeAll()
                self.wallets.removeAll()
                self.walletTable.reloadData()
                
                OnchainUtils.listWalletDir { [weak self] (walletDir, message) in
                    guard let self = self else { return }
                    
                    guard let walletDir = walletDir else {
                        DispatchQueue.main.async { [weak self] in
                             guard let self = self else { return }
                            
                            self.connectingView.dismiss()
                            displayAlert(viewController: self, isError: true, message: "error getting wallets: \(message ?? "")")
                        }
                        return
                    }
                    self.parseWallets(wallets_: walletDir.wallets)
                }
            }
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "walletCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        let dict = wallets[indexPath.row]
        let isActive = dict["isActive"] as! Bool
        let name = dict["name"] as! String
        if let walletLabel = dict["label"] as? String {
            label.text = walletLabel
        } else {
            label.text = name
        }
        
        label.lineBreakMode = .byTruncatingMiddle
        if isActive {
            cell.accessoryType = .checkmark
            cell.isSelected = true
            label.textColor = .label
        } else {
            cell.accessoryType = .none
            cell.isSelected = false
            label.textColor = .secondaryLabel
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    private func activateWallet(walletName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UserDefaults.standard.set(walletName, forKey: "walletName")
            refresh()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let wallet = wallets[indexPath.row]
        let name = wallet["name"] as! String
        let isActive = wallet["isActive"] as! Bool
                
        if !isActive {
            if name != "Default Wallet" {
                syncCoreWalletToFN(walletName: name)
            } else {
                showAlert(title: "", message: "Fully Noded no longer supports default wallet usage.")
            }
        }
    }
    
    private func syncCoreWalletToFN(walletName: String) {
        UserDefaults.standard.set(walletName, forKey: "walletName")
        
        ConnectingView.shared.show(vc: self)
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response else {
                ConnectingView.shared.dismiss()
                showAlert(title: "Wallet activated, with an error:", message: (errorDesc ?? "Unknown error from listdescriptors.") + " Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
                return
            }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: response, options: []) else {
                ConnectingView.shared.dismiss()
                showAlert(title: "Wallet activated with an error:", message: "Could not serialize listdescriptors response to jsonData. Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
                return
            }
            
            guard let listDescriptorResponse = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData) else {
                ConnectingView.shared.dismiss()
                showAlert(title: "Wallet activated with an error:", message: "Could not decode listdescriptors response from jsonData. Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
                return
            }
            
            guard listDescriptorResponse.descriptors.count > 0 else {
                ConnectingView.shared.dismiss()
                showAlert(title: "Wallet activated.", message: "This is not a descriptor wallet, therefore you will get limited functionality when utilizing this wallet. Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
                return
            }
            
            var externalDescriptors: [String] = []
            var internalDescriptors: [String] = []
            
            for descriptor in listDescriptorResponse.descriptors {
                guard let isInternal = descriptor.internal_ else {
                    continue
                }
                
                if isInternal {
                    internalDescriptors.append(descriptor.desc)
                } else {
                    externalDescriptors.append(descriptor.desc)
                }
            }
            
            ConnectingView.shared.dismiss()
            prompToChoosePrimaryDesc(externalDescriptors: externalDescriptors, internalDescriptors: internalDescriptors, walletName: walletName)
        }
    }
    
    private func prompToChoosePrimaryDesc(externalDescriptors: [String], internalDescriptors: [String], walletName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Choose a wallet format.", message: "Bitcoin Core wallets can consist of multiple formats, Fully Noded works with one at a time, please choose one.", preferredStyle: .alert)
            
            for descriptor in externalDescriptors {
                let descStr = Descriptor(descriptor)
                
                alert.addAction(UIAlertAction(title: descStr.scriptType, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.selectChangeDescriptor(externalDescriptorToUse: descStr, internalDescriptors: internalDescriptors, walletName: walletName)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = view
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func selectChangeDescriptor(externalDescriptorToUse: Descriptor, internalDescriptors: [String], walletName: String) {
        // Find the first internal descriptor whose script type matches the external one
        guard let changeDescriptorString = internalDescriptors.first(where: {
            Descriptor($0).scriptType == externalDescriptorToUse.scriptType
        }) else {
            showAlert(title: "No matching change descriptor.", message: "\(walletName) has been activated however it will not be synced as a Fully Noded wallet therefore you will get limited functionality. Navigate back to the active wallet view and tap the refresh button.")
            
            activateWallet(walletName: walletName)
            return
        }
        
        // Build the wallet dictionary
        let walletDict: [String: Any] = [
            "blockheight": 0,
            "changeDescriptor": changeDescriptorString,
            "id": UUID(),
            "label": walletName,
            "name": walletName,
            "receiveDescriptor": externalDescriptorToUse.string
        ]
        
        guard fnWallets.count > 0 else {
            saveNewFnWallet(walletDict: walletDict, walletName: walletName)
            return
        }
        
        var walletAlreadySaved = false
        for (i, fnWallet) in fnWallets.enumerated() {
            if fnWallet.receiveDescriptor == externalDescriptorToUse.string && changeDescriptorString == fnWallet.changeDescriptor && walletName == fnWallet.name {
                walletAlreadySaved = true
            }
            
            if i + 1 == fnWallets.count {
                if walletAlreadySaved {
                    showAlert(title: "Wallet activated.", message: "Navigate back to the active wallet view and tap the refresh button.")
                    activateWallet(walletName: walletName)
                } else {
                    saveNewFnWallet(walletDict: walletDict, walletName: walletName)
                }
            }
        }
    }
    
    private func saveNewFnWallet(walletDict: [String: Any], walletName: String) {
        CoreDataService.saveEntity(dict: walletDict, entityName: .wallets) { [weak self] saved in
            guard let self = self else { return }
            
            if saved {
                showAlert(title: "Fully Noded wallet synced.", message: "\(walletName) has been activated and synced to Fully Noded, you will get full functionality from Fully Noded. Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
            } else {
                showAlert(title: "Failed to save wallet.", message: "\(walletName) has been activated but you will not get full functionality from Fully Noded. Navigate back to the active wallet view and tap the refresh button.")
                activateWallet(walletName: walletName)
            }
        }
    }
    
    private func goUnload() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToUnloadWallets", sender: self)
        }
    }
    
    func parseWallets(wallets_: [String]) {
        let activeWallet = UserDefaults.standard.object(forKey: "walletName") as? String ?? ""
        
        guard wallets_.count > 0 else {
            doneLoading()
            return
        }
        
        for (i, walletName) in wallets_.enumerated() {
            var isActive = false
            let nameToDisplay = walletName
            
            if nameToDisplay == activeWallet {
                isActive = true
            }
            
            var dict: [String: Any] = [:]
            
            if walletName == "" {
                dict["label"] = "Default Wallet"
            }
            
            for fnWallet in fnWallets {
                if fnWallet.name == walletName {
                    dict["label"] = fnWallet.label
                }
            }
            
            dict["name"] = walletName
            dict["isActive"] = isActive
            
            self.wallets.append(dict)
            
            if i + 1 == wallets_.count {
                doneLoading()
            }
        }
    }
    
    private func doneLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.connectingView.dismiss()
            self.walletTable.reloadData()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let id = segue.identifier
        switch id {
        case "segueToUnloadWallets":
            if let vc = segue.destination as? ActiveWalletsViewController {
                vc.activeWallets = walletsToUnload
                vc.fnWallets = fnWallets
                walletsToUnload.removeAll()
            }
        default:
            break
        }
    }

}
