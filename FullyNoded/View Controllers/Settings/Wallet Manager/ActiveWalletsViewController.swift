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
    var activeWallets:[String] = []
    var connectingView = ConnectingView()
    var alertStyle = UIAlertController.Style.actionSheet

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
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
        //cell.layer.borderColor = UIColor.lightGray.cgColor
        //cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        label.text = activeWallets[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unloadWallet(wallet: activeWallets[indexPath.row], index: indexPath.row)
    }
    
    private func unloadWallet(wallet: String, index: Int) {
        connectingView.addConnectingView(vc: self, description: "unloading wallet...")
        let p = Unload_Wallet(["wallet_name": wallet])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .unloadwallet(param: p)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let _ = response else {
                self.connectingView.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "There was an error unloading your wallet: \(errorMessage!)")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.activeWallets.remove(at: index)
                
                if self.activeWallets.count == 0 {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                }
                
                self.unloadedSuccess()
                self.table.reloadData()
                self.connectingView.removeConnectingView()
            }
        }
    }
    
    private func unloadedSuccess() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "", message: "Wallet unloaded.", preferredStyle: self.alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
}
