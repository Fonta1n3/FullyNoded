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

    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return activeWallets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "activeWallet", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        label.text = activeWallets[indexPath.section]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        unloadWallet(wallet: activeWallets[indexPath.section], index: indexPath.section)
    }
    
    private func unloadWallet(wallet: String, index: Int) {
        connectingView.addConnectingView(vc: self, description: "unloading wallet...")
        Reducer.makeCommand(command: .unloadwallet, param: "\"\(wallet)\"") { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.activeWallets.remove(at: index)
                    if vc.activeWallets.count == 0 {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                        vc.unloadedSuccess()
                    }
                    vc.table.reloadData()
                    vc.connectingView.removeConnectingView()
                }
            } else {
                vc.connectingView.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: "There was an error unloading your wallet: \(errorMessage!)")
            }
        }
    }
    
    private func unloadedSuccess() {
        DispatchQueue.main.async { [unowned vc = self] in
            let alert = UIAlertController(title: "All wallets unloaded!", message: "You may now work with the default wallet, we are now refreshing the wallet screen. Tap Done to go back.", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
}
