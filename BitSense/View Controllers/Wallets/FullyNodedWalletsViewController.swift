//
//  FullyNodedWalletsViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class FullyNodedWalletsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var walletsTable: UITableView!
    var wallets = [[String:Any]]()
    var walletId:UUID!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        walletsTable.delegate = self
        walletsTable.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getWallets()
    }
    
    @IBAction func goToSigners(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "showSignersSegue", sender: vc)
        }
    }
    
    
    @IBAction func showHelp(_ sender: Any) {
        let message = "These are the wallets you created via \"Create a Fully Noded Wallet\". They are special wallets which utilize your node in a smarter way then manual Bitcoin Core wallet creation. You will only see \"Fully Noded Wallets\" here. You can activate/deactivate them, rename them, and delete them here by tapping the > button. In the detail view you have more powerful options related to your wallet, to read about it tap the > button to see the detail view and tap the help button there."
        showAlert(vc: self, title: "Fully Noded Wallets", message: message)
    }
    
    private func getWallets() {
        wallets.removeAll()
        CoreDataService.retrieveEntity(entityName: .wallets) { [unowned vc = self] ws in
            if ws != nil {
                if ws!.count > 0 {
                    for (i, wallet) in ws!.enumerated() {
                        vc.wallets.append(wallet)
                        if i + 1 == ws!.count {
                            DispatchQueue.main.async { [unowned vc = self] in
                                vc.walletsTable.reloadData()
                            }
                        }
                    }
                } else {
                    showAlert(vc: vc, title: "No Fully Noded Wallets", message: "Looks like you have not yet created any Fully Noded wallets, on the active wallet tab you can tap the plus sign (top left) to create a Fully Noded wallet.")
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return wallets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "fnWalletCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let label = cell.viewWithTag(1) as! UILabel
        let button = cell.viewWithTag(2) as! UIButton
        let toggle = cell.viewWithTag(3) as! UISwitch
        let walletStruct = Wallet(dictionary: wallets[indexPath.section])
        label.text = walletStruct.label
        button.restorationIdentifier = "\(indexPath.section)"
        toggle.restorationIdentifier = "\(indexPath.section)"
        button.addTarget(self, action: #selector(goToDetail(_:)), for: .touchUpInside)
        toggle.addTarget(self, action: #selector(toggleAction(_:)), for: .valueChanged)
        if UserDefaults.standard.object(forKey: "walletName") as? String == walletStruct.name {
            toggle.setOn(true, animated: true)
        } else {
            toggle.setOn(false, animated: true)
        }
        return cell
    }
    
    @objc func toggleAction(_ sender: UISwitch) {
        if sender.restorationIdentifier != nil {
            if let section = Int(sender.restorationIdentifier!) {
                let name = Wallet(dictionary: wallets[section]).name
                if sender.isOn {
                    DispatchQueue.main.async {
                        UserDefaults.standard.set(name, forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
                getWallets()
            }
        }
    }
    
    @objc func goToDetail(_ sender: UIButton) {
        if sender.restorationIdentifier != nil {
            if let section = Int(sender.restorationIdentifier!) {
                walletId = Wallet(dictionary: wallets[section]).id
                goToDetail()
            }
        }
    }
    
    private func goToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "showWalletDetail", sender: vc)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "showWalletDetail" {
            if let vc = segue.destination as? WalletDetailViewController {
                vc.walletId = walletId
            }
        }
    }
    

}
