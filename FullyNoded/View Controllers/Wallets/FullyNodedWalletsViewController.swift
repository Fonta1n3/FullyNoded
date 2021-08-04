//
//  FullyNodedWalletsViewController.swift
//  BitSense
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class FullyNodedWalletsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var fxRateLabel: UILabel!
    @IBOutlet weak var balanceFiatLabel: UILabel!
    @IBOutlet weak var totalBalanceLabel: UILabel!
    @IBOutlet weak var walletsTable: UITableView!
    
    var wallets = [[String:Any]]()
    var walletId:UUID!
    var index = 0
    var existingActiveWalletName = ""
    var totalBtcBalance = 0.0
    var fxRate = 0.0
    var bitcoinCoreWallets = [String]()
    let spinner = ConnectingView()
    var initialLoad = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        walletsTable.delegate = self
        walletsTable.dataSource = self
        totalBalanceLabel.alpha = 0
        totalBalanceLabel.text = ""
        balanceFiatLabel.alpha = 0
        balanceFiatLabel.text = ""
        fxRateLabel.alpha = 0
        fxRateLabel.text = ""
        existingActiveWalletName = UserDefaults.standard.object(forKey: "walletName") as? String ?? ""
        spinner.addConnectingView(vc: self, description: "getting total balance...")
        initialLoad = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getBitcoinCoreWallets()
    }
    
    @IBAction func seeAllWalletsAction(_ sender: Any) {
    }
    
    
    private func getBitcoinCoreWallets() {
        bitcoinCoreWallets.removeAll()
        Reducer.makeCommand(command: .listwalletdir, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary else {
                DispatchQueue.main.async {
                    self.spinner.removeConnectingView()
                    self.initialLoad = false
                    displayAlert(viewController: self, isError: true, message: "error getting wallets: \(errorMessage ?? "")")
                }
                return
            }
            
            self.parseWallets(walletDict: dict)
        }
    }
    
    private func parseWallets(walletDict: NSDictionary) {
        guard let walletArr = walletDict["wallets"] as? NSArray else { self.spinner.removeConnectingView(); return }
        
        for (i, wallet) in walletArr.enumerated() {
            guard let walletDict = wallet as? NSDictionary,
                  let walletName = walletDict["name"] as? String else {
                self.initialLoad = false
                self.spinner.removeConnectingView()
                return
            }
            
            bitcoinCoreWallets.append(walletName)
            
            if i + 1 == walletArr.count {
                getFullyNodedWallets()
            }
        }
    }
    
    private func getFullyNodedWallets() {
        wallets.removeAll()
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] ws in
            guard let self = self else { return }
            
            guard let ws = ws, ws.count > 0 else {
                self.spinner.removeConnectingView()
                let title = "No Fully Noded Wallets"
                let message = "Looks like you have not yet created any Fully Noded wallets, on the active wallet tab you can tap the plus sign (top left) to create a Fully Noded wallet."
                self.initialLoad = false
                showAlert(vc: self, title: title, message: message)
                
                return
            }
                        
            for (i, wallet) in ws.enumerated() {
                let walletStruct = Wallet(dictionary: wallet)
                
                for bitcoinCoreWallet in self.bitcoinCoreWallets {
                    if bitcoinCoreWallet == walletStruct.name {
                        self.wallets.append(wallet)
                    }
                }
                
                if i + 1 == ws.count {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.walletsTable.reloadData()
                        self.loadTotalBalance()
                    }
                }
            }
        }
    }
    
    private func loadTotalBalance() {
        if !initialLoad {
            spinner.addConnectingView(vc: self, description: "getting total balance...")
        }
        
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self else { return }
            
            guard let fxRate = fxRate else { self.spinner.removeConnectingView(); return }
            guard self.wallets.count > 0 else { self.spinner.removeConnectingView(); return }
            self.fxRate = fxRate
            self.getTotals()
        }
    }
    
    private func getTotals() {
        if index < wallets.count {
            let wallet = wallets[index]
            let walletStruct = Wallet(dictionary: wallet)
            UserDefaults.standard.set(walletStruct.name, forKey: "walletName")
            
            Reducer.makeCommand(command: .listunspent, param: "0") { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let utxos = response as? NSArray else {
                    self.spinner.removeConnectingView()
                    
                    guard let errorMessage = errorMessage else {
                        showAlert(vc: self, title: "Ooops", message: "There was an unknown error getting your balances")
                        UserDefaults.standard.set(self.existingActiveWalletName, forKey: "walletName")
                        self.initialLoad = false
                        return
                    }
                    
                    showAlert(vc: self, title: "Ooops", message: "There was an error getting your balances: \(errorMessage)")
                    UserDefaults.standard.set(self.existingActiveWalletName, forKey: "walletName")
                    self.initialLoad = false
                    return
                }
                
                if utxos.count > 0 {
                    for (x, utxo) in utxos.enumerated() {
                        let utxoDict = utxo as! NSDictionary
                        let balance = utxoDict["amount"] as! Double
                        self.totalBtcBalance += balance
                        
                        if x + 1 == utxos.count {
                            self.index += 1
                            self.getTotals()
                        }
                    }
                } else {
                    self.index += 1
                    self.getTotals()
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                UserDefaults.standard.set(self.existingActiveWalletName, forKey: "walletName")
                
                let roundedFiat = self.totalBtcBalance * self.fxRate
                
                self.totalBalanceLabel.text = "\(self.totalBtcBalance.avoidNotation) btc"
                self.totalBalanceLabel.alpha = 1
                self.fxRateLabel.text = self.fxRate.exchangeRate
                self.fxRateLabel.alpha = 1
                self.balanceFiatLabel.text = roundedFiat.fiatString
                self.balanceFiatLabel.alpha = 1
                self.initialLoad = false
                self.spinner.removeConnectingView()
            }
        }
    }
    
    @IBAction func showHelp(_ sender: Any) {
        let message = "These are the wallets you created via \"Create a Fully Noded Wallet\". They are special wallets which utilize your node in a smarter way than manual Bitcoin Core wallet creation. You will only see \"Fully Noded Wallets\" here. You can activate/deactivate them, rename them, and delete them here by tapping the > button. In the detail view you have more powerful options related to your wallet, to read about it tap the > button to see the detail view and tap the help button there."
        showAlert(vc: self, title: "Fully Noded Wallets", message: message)
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
        if self.existingActiveWalletName == walletStruct.name {
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
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.existingActiveWalletName = name
                        UserDefaults.standard.set(name, forKey: "walletName")
                        NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                        self.navigationController?.popViewController(animated: true)
                    }
                } else {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                }
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
