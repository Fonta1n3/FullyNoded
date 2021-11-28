//
//  ExternalFNWalletsViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/10/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class ExternalFNWalletsViewController: UIViewController {
    
    @IBOutlet weak private var externWalletsTable: UITableView!
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    
    var externalWallets = [Wallet]()
    var mainnetWallets = [Wallet]()
    var testnetWallets = [Wallet]()
    var walletToView:UUID!
    var network = 0
    var activeChain = "main"

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        externWalletsTable.delegate = self
        
        let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if chain != "main" {
            network = 1
        }
        activeChain = chain
        segmentedControl.selectedSegmentIndex = network
        
        for wallet in externalWallets {
            let desc = Descriptor(wallet.receiveDescriptor)
            
            if desc.chain == "Mainnet" {
                mainnetWallets.append(wallet)
            } else {
                print("wallet: \(wallet.receiveDescriptor)")
                testnetWallets.append(wallet)
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        reloadTableData()
    }
    
    @IBAction func switchSegmentedControlAction(_ sender: Any) {
        network = segmentedControl.selectedSegmentIndex
        reloadTableData()
    }
    
    
    private func reloadTableData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.externWalletsTable.reloadData()
        }
    }
    
    private func promptToDelete(_ wallet: Wallet, _ index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Delete \(wallet.label)?"
            
            let mess = "⚠️ Are you sure!? This action is irreversible."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                self.deleteNow(wallet, index)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func deleteNow(_ wallet: Wallet, _ index: Int) {
        CoreDataService.deleteEntity(id: wallet.id, entityName: .wallets) { [weak self] deleted in
            guard let self = self else { return }
            
            guard deleted else {
                showAlert(vc: self, title: "Deletion failed...", message: "Please let us know about this bug.")
                return
            }
            
            if self.network == 0 {
                self.mainnetWallets.remove(at: index)
            } else {
                self.testnetWallets.remove(at: index)
            }
            self.reloadTableData()
        }
    }
    
    @objc func deleteWallet(_ sender: UIButton) {
        var wallet:Wallet!
        if network == 0 {
            wallet = mainnetWallets[sender.tag]
        } else {
            wallet = testnetWallets[sender.tag]
        }
        promptToDelete(wallet, sender.tag)
    }
    
    private func deleteButton(_ x: CGFloat) -> UIButton {
        let deleteButton = UIButton()
        deleteButton.frame = CGRect(x: x, y: 10, width: 40, height: 40)
        deleteButton.addTarget(self, action: #selector(deleteWallet(_:)), for: .touchUpInside)
        deleteButton.setImage(.init(systemName: "trash"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.showsTouchWhenHighlighted = true
        return deleteButton
    }
    
    @objc func seeDetail(_ sender: UIButton) {
        var wallet:Wallet!
        if network == 0 {
            wallet = mainnetWallets[sender.tag]
        } else {
            wallet = testnetWallets[sender.tag]
        }
        
        walletToView = wallet.id
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToShowExternalWalletDetail", sender: self)
        }
    }
    
    private func infoButton(_ x: CGFloat) -> UIButton {
        let infoButton = UIButton()
        infoButton.frame = CGRect(x: x, y: 10, width: 40, height: 40)
        infoButton.addTarget(self, action: #selector(seeDetail(_:)), for: .touchUpInside)
        infoButton.setImage(.init(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = .systemTeal
        infoButton.showsTouchWhenHighlighted = true
        return infoButton
    }
    
    private func promptToRecover(_ wallet: Wallet, _ index: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Recover \(wallet.label)?"
            
            let mess = "This will create the wallet on your active node and trigger a rescan. If you want to recover multiple wallets quickly you will want to abort the rescan each time or you may see an error. Home tab > tools (wrench button) > Abort rescan"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Recover", style: .default, handler: { action in
                self.recoverNow(wallet, index)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func recoverNow(_ wallet: Wallet, _ index: Int) {
        let accountMap = ["descriptor": wallet.receiveDescriptor, "blockheight": Int(wallet.blockheight), "watching": wallet.watching ?? [], "label": wallet.label] as [String : Any]
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.navigationController?.popToRootViewController(animated: true)
            NotificationCenter.default.post(name: .importWallet, object: nil, userInfo: accountMap)
        }
    }
    
    @objc func recoverWallet(_ sender: UIButton) {
        var wallet:Wallet!
        if network == 0 && activeChain == "main" {
            wallet = mainnetWallets[sender.tag]
            promptToRecover(wallet, sender.tag)
        } else if activeChain != "main" && network == 1 {
            wallet = testnetWallets[sender.tag]
            promptToRecover(wallet, sender.tag)
        } else {
            showAlert(vc: self, title: "Network mismatch...", message: "The active node is not on the same network as the wallet you are attempting to recover.")
        }        
    }
    
    private func recoverButton(_ x: CGFloat) -> UIButton {
        let recoverButton = UIButton()
        recoverButton.frame = CGRect(x: x, y: 10, width: 40, height: 40)
        recoverButton.addTarget(self, action: #selector(recoverWallet(_:)), for: .touchUpInside)
        recoverButton.setImage(.init(systemName: "square.and.arrow.down.fill"), for: .normal)
        recoverButton.tintColor = .systemTeal
        recoverButton.showsTouchWhenHighlighted = true
        return recoverButton
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        
        switch segue.identifier {
        case "segueToShowExternalWalletDetail":
            guard let vc = segue.destination as? WalletDetailViewController else { fallthrough }
            
            vc.walletId = walletToView
        default:
            break
        }
    }

}

extension ExternalFNWalletsViewController: UITableViewDelegate {}

extension ExternalFNWalletsViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if network == 0 {
            return mainnetWallets.count
        } else {
            return testnetWallets.count
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "externalWalletCell", for: indexPath)
        cell.selectionStyle = .none
        
        var wallet:Wallet!
        
        if network == 0 {
            wallet = mainnetWallets[indexPath.section]
        } else {
            wallet = testnetWallets[indexPath.section]
        }
        
        cell.textLabel?.text = wallet.label
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        cell.textLabel?.textColor = .lightGray
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.lineBreakMode = .byWordWrapping
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let deleteButton = deleteButton(header.frame.maxX - 80)
        deleteButton.tag = section
        header.addSubview(deleteButton)
        
        let infoButton = infoButton(deleteButton.frame.minX - 48)
        infoButton.tag = section
        header.addSubview(infoButton)
        
        let recoverButton = recoverButton(infoButton.frame.minX - 48)
        recoverButton.tag = section
        header.addSubview(recoverButton)
        
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    
}
