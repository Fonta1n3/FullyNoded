//
//  ActiveWalletViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletViewController: UIViewController {
    
    private var walletInfo: WalletInfo?
    private var showOnchainOnly = false
    private var showOnchain = false
    private var showOffchain = false
    private var existingWallet = ""
    private var walletDisabled = Bool()
    private var onchainBalanceBtc = ""
    private var onchainBalanceSats = ""
    private var onchainBalanceFiat = ""
    private var offchainBalanceBtc = ""
    private var offchainBalanceSats = ""
    private var offchainBalanceFiat = ""
    private var sectionZeroLoaded = Bool()
    private var wallets = NSArray()
    private var transactionArray = [[String:Any]]()
    private var offchainTxArray = [[String:Any]]()
    private var onchainTxArray = [[String:Any]]()
    private var tx = String()
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel:String!
    private var wallet:Wallet?
    private var isBolt11 = false
    private var fxRate:Double?
    private var alertStyle = UIAlertController.Style.alert
    private let barSpinner = UIActivityIndicatorView(style: .medium)
    private let ud = UserDefaults.standard
    private let spinner = ConnectingView()
    private var hex = ""
    private var confs = 0
    private var txToEdit = ""
    private var memoToEdit = ""
    private var labelToEdit = ""
    private var psbt = ""
    private var rawTx = ""
    private var dateFormatter = DateFormatter()
    private var isFiat = false
    private var isBtc = true
    private var isSats = false
    private var initialLoad = true
    private var isRecovering = false
    var fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    
    @IBOutlet weak private var currencyControl: UISegmentedControl!
    @IBOutlet weak private var backgroundView: UIVisualEffectView!
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var sendView: UIView!
    @IBOutlet weak private var invoiceView: UIView!
    @IBOutlet weak private var utxosView: UIView!
    @IBOutlet weak private var advancedView: UIView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.setValue(false, forKey: "hasPromptedToRescan")
        walletTable.delegate = self
        walletTable.dataSource = self
        configureUi()
        NotificationCenter.default.addObserver(self, selector: #selector(broadcast(_:)), name: .broadcastTxn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signPsbt(_:)), name: .signPsbt, object: nil)
        existingWallet = ud.object(forKey: "walletName") as? String ?? ""
        setCurrency()
        setNotifications()
        sectionZeroLoaded = false
        addNavBarSpinner()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        currencyControl.setTitle(fiatCurrency.lowercased(), forSegmentAt: 2)
        if initialLoad {
            initialLoad = false
            getFxRate()
        }
    }
    
    private func hideData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onchainBalanceBtc = ""
            self.onchainBalanceSats = ""
            self.onchainBalanceFiat = ""
            self.offchainBalanceBtc = ""
            self.offchainBalanceSats = ""
            self.offchainBalanceFiat = ""
            self.sectionZeroLoaded = false
            self.transactionArray.removeAll()
            self.offchainTxArray.removeAll()
            self.onchainTxArray.removeAll()
            self.walletTable.reloadData()
        }
    }
    
    private func setCurrency() {
        if ud.object(forKey: "unit") != nil {
            let unit = ud.object(forKey: "unit") as! String
            var index = 0
            switch unit {
            case "btc":
                index = 0
                isBtc = true
                isFiat = false
                isSats = false
            case "sats":
                index = 1
                isSats = true
                isFiat = false
                isBtc = false
            case "fiat":
                index = 2
                isFiat = true
                isBtc = false
                isSats = false
            default:
                break
            }
            
            DispatchQueue.main.async { [unowned vc = self] in
                vc.currencyControl.selectedSegmentIndex = index
            }
            
        } else {
            isBtc = true
            isFiat = false
            isSats = false
            
            DispatchQueue.main.async { [unowned vc = self] in
                vc.currencyControl.selectedSegmentIndex = 0
            }
        }
    }
    
    @IBAction func advancedAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self .performSegue(withIdentifier: "goToInvoiceSetting", sender: nil)
        }
    }
    
    
    @IBAction func switchCurrency(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            isFiat = false
            isBtc = true
            isSats = false
            ud.set("btc", forKey: "unit")
        case 1:
            isFiat = false
            isBtc = false
            isSats = true
            ud.set("sats", forKey: "unit")
        case 2:
            isFiat = true
            isBtc = false
            isSats = false
            ud.set("fiat", forKey: "unit")
        default:
            break
        }
        
        reloadTable()
    }
    
    
    @objc func signPsbt(_ notification: NSNotification) {
        guard let psbtDict = notification.userInfo as? [String:Any], let psbtCheck = psbtDict["psbt"] as? String else {
            showAlert(vc: self, title: "Uh oh", message: "That does not appear to be a psbt...")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.psbt = psbtCheck
            self.performSegue(withIdentifier: "segueToSignPsbt", sender: self)
        }
    }
    
    @objc func broadcast(_ notification: NSNotification) {
        guard let txnDict = notification.userInfo as? [String:Any], let txn = txnDict["txn"] as? String else {
            showAlert(vc: self, title: "Uh oh", message: "That does not appear to be a signed raw transaction...")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.rawTx = txn
            self.performSegue(withIdentifier: "segueToSignPsbt", sender: self)
        }
    }
    
    @IBAction func signPsbtAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSignPsbt", sender: self)
        }
    }
    
    private func configureButton(_ button: UIView) {
        button.layer.borderColor = UIColor.darkGray.cgColor
        button.layer.borderWidth = 0.5
        button.layer.cornerRadius = 5
    }
    
    private func configureUi() {
        configureButton(sendView)
        configureButton(invoiceView)
        configureButton(utxosView)
        configureButton(advancedView)
        
        fxRateLabel.text = ""
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
    }
    
    private func setNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(refreshWallet), name: .refreshWallet, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(addColdcard(_:)), name: .addColdCard, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(importWallet(_:)), name: .importWallet, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLabel), name: .updateWalletLabel, object: nil)
    }
    
    @objc func updateLabel() {
        activeWallet { [weak self] wallet in
            guard let self = self, let wallet = wallet else { return }
                        
            self.walletLabel = wallet.label
            
            DispatchQueue.main.async {
                self.walletTable.reloadData()
            }
        }
    }
    
    @IBAction func getDetails(_ sender: Any) {
        guard let wallet = wallet else {
            showAlert(vc: self, title: "", message: "That button only works for \"Fully Noded Wallets\" which can be created by tapping the plus button, you can see your Fully Noded Wallets by tapping the squares button. Fully Noded allows you to access, use and create wallets with ultimate flexibility using your node but it comes with some limitations. In order to get a better user experience we recommend creating a Fully Noded Wallet.")
            return
        }
        
        walletLabel = wallet.label
        goToDetail()
    }
    
    @IBAction func goToFullyNodedWallets(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToWallets", sender: vc)
        }
    }
    
    @IBAction func createWallet(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "createFullyNodedWallet", sender: vc)
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "spendFromWallet", sender: vc)
        }
    }
    
    @IBAction func invoiceAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToInvoice", sender: vc)
        }
    }
    
    @IBAction func goToUtxos(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToUtxos", sender: vc)
        }
    }
    
    @objc func importWallet(_ notification: NSNotification) {
        isRecovering = true
        spinner.addConnectingView(vc: self, description: "Creating your wallet, this can take a minute...")
        
        guard let accountMap = notification.userInfo as? [String:Any] else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error importing wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.spinner.removeConnectingView()
            OnchainUtils.rescan { _ in }
            showAlert(vc: self, title: "Wallet created ✓", message: "It has been activated and is refreshing now. A rescan has been initiated, you may not see balances or transaction history until the rescan completes.")
            self.refreshWallet()
        }
    }
    
    @objc func addColdcard(_ notification: NSNotification) {
        spinner.addConnectingView(vc: self, description: "creating your Coldcard wallet, this can take a minute...")
        
        guard let coldCard = notification.userInfo as? [String:Any] else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Ooops", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.coldcard(dict: coldCard) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error creating Coldcard wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Coldcard Wallet imported ✓", message: "It has been activated and is refreshing now.")
            self.refreshWallet()
        }
    }
    
    private func loadTable() {
        sectionZeroLoaded = false
        existingWallet = ""
        walletLabel = ""
        transactionArray.removeAll()
        walletTable.reloadData()
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
                    guard let self = self, let nodes = nodes else { return }
                    
                    guard nodes.count > 0 else {
                        self.finishedLoading()
                        showAlert(vc: self, title: "", message: "No nodes added.")
                        return
                    }
                    
                    var anyOffchain = false
                    
                    for (i, node) in nodes.enumerated() {
                        let nodeStr = NodeStruct(dictionary: node)
                        if nodeStr.isActive && nodeStr.isLightning {
                            anyOffchain = true
                        }
                        if i + 1 == nodes.count {
                            if anyOffchain {
                                self.showOnchain = false
                                self.showOffchain = true
                                self.loadLightning()
                            } else {
                                guard let walletName = UserDefaults.standard.string(forKey: "walletName") else {
                                    self.finishedLoading()
                                    showAlert(vc: self, title: "", message: "No wallet currently toggled on.")
                                    return
                                }
                                
                                self.showOnchain = true
                                self.existingWallet = walletName
                                self.walletLabel = walletName
                                self.loadBalances()
                            }
                        }
                    }
                }
                return
            }
            
            self.showOnchain = true
            self.wallet = wallet
            self.existingWallet = wallet.name
            self.walletLabel = wallet.label
            
            DispatchQueue.main.async {
                self.transactionArray.removeAll()
                self.walletTable.reloadData()
            }
            
            self.loadBalances()
        }
    }
    
    private func promptToChooseJmWallet(jmWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            
            let tit = "Join Market wallet"
            
            let mess = "Please select which wallet you'd like to use."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            for jmWallet in jmWallets {
                alert.addAction(UIAlertAction(title: jmWallet, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
                        guard let wallets = wallets else { return }
                        
                        guard wallets.count > 0 else {
                            showAlert(vc: self, title: "", message: "No existing wallets, tap the + button to create a wallet.")
                            return
                        }
                        
                        for wallet in wallets {
                            if wallet["id"] != nil {
                                let wStr = Wallet(dictionary: wallet)
                                if wStr.isJm && wStr.jmWalletName == jmWallet {
                                    UserDefaults.standard.set(wStr.name, forKey: "walletName")
                                    self.wallet = wStr
                                    self.existingWallet = wStr.name
                                    self.walletLabel = wStr.label
                                    self.loadBalances()
                                }
                            }
                        }
                    }
                    
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
            self.removeSpinner()
        }
    }
    
    private func updateTransactionArray() {
       CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0, self.transactionArray.count > 0 else {
                self.finishedLoading()
                return
            }
            
            let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"

            for (i, transaction) in transactions.enumerated() {
                
               let localTransactionStruct = TransactionStruct(dictionary: transaction)
                
                for (t, tx) in self.transactionArray.enumerated() {
                    if (tx["txID"] as! String) == localTransactionStruct.txid {
                        self.transactionArray[t]["memo"] = localTransactionStruct.memo
                        self.transactionArray[t]["transactionLabel"] = localTransactionStruct.label
                        if let originRate = localTransactionStruct.fxRate, originRate > 0 {
                            if localTransactionStruct.fiatCurrency == currency {
                                self.transactionArray[t]["originRate"] = originRate
                            }
                        }
                    }

                    if i + 1 == transactions.count && t + 1 == self.transactionArray.count {
                        self.finishedLoading()
                    }
                }
            }
        }
    }
    
    
    @objc func goToDetail(_ sender: UIButton) {
        spinner.addConnectingView(vc: self, description: "getting raw transaction...")
        
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        let tx = transactionArray[int]
        let id = tx["txID"] as! String
        let param:Get_Tx = .init(["txid":id, "verbose": true])
        Reducer.sharedInstance.makeCommand(command: .gettransaction(param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            guard let dict = response as? NSDictionary, let hex = dict["hex"] as? String else {
                showAlert(vc: self, title: "There was an issue getting the transaction.", message: errorMessage ?? "unknown error")
                return
            }
            DispatchQueue.main.async {
                self.confs = Int(tx["confirmations"] as! String)!
                self.hex = hex
                self.performSegue(withIdentifier: "segueToTxDetail", sender: self)
            }
        }
    }
    
    
    private func onchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OnBalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let iconImageView = cell.viewWithTag(67) as! UIImageView
        iconImageView.image = .init(systemName: "link")
        
        if let offchainBalanceLabel = cell.viewWithTag(2) as? UILabel, let offchainBalanceView = cell.viewWithTag(66) {
            offchainBalanceLabel.removeFromSuperview()
            offchainBalanceView.removeFromSuperview()
        }
        
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0.00 000 000"
        }
                
        if isBtc {
            onchainBalanceLabel.text = onchainBalanceBtc
        }
        
        if isSats {
            onchainBalanceLabel.text = onchainBalanceSats
        }
        
        if isFiat {
            onchainBalanceLabel.text = onchainBalanceFiat
        }
                
        return cell
    }
    
    private func offchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OnBalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let offchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        let iconImageView = cell.viewWithTag(67) as! UIImageView
        iconImageView.image = .init(systemName: "bolt")
        
        if offchainBalanceBtc == "" {
            offchainBalanceBtc = "0.00 000 000"
        }
        if isBtc {
            offchainBalanceLabel.text = offchainBalanceBtc
        }
        if isSats {
            offchainBalanceLabel.text = offchainBalanceSats
        }
        if isFiat {
            offchainBalanceLabel.text = offchainBalanceFiat
        }
                
        return cell
    }
    
    private func offchainOnchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OffOnBalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        let offchainBalanceLabel = cell.viewWithTag(2) as! UILabel
        let offchainBalanceView = cell.viewWithTag(66)!
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        
        if offchainBalanceBtc == "" {
            offchainBalanceBtc = "0.00 000 000"
        }
        if isBtc {
            offchainBalanceLabel.text = offchainBalanceBtc
        }
        if isSats {
            offchainBalanceLabel.text = offchainBalanceSats
        }
        if isFiat {
            offchainBalanceLabel.text = offchainBalanceFiat
        }
        offchainBalanceLabel.alpha = 1
        offchainBalanceView.alpha = 1
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0.00 000 000"
        }
                
        if isBtc {
            onchainBalanceLabel.text = onchainBalanceBtc
        }
        
        if isSats {
            onchainBalanceLabel.text = onchainBalanceSats
        }
        
        if isFiat {
            onchainBalanceLabel.text = onchainBalanceFiat
        }
                
        return cell
    }
    
    private func transactionsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        let categoryImage = cell.viewWithTag(1) as! UIImageView
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let confirmationsLabel = cell.viewWithTag(3) as! UILabel
        let dateLabel = cell.viewWithTag(5) as! UILabel
        let lightningImage = cell.viewWithTag(7) as! UIImageView
        let onchainImage = cell.viewWithTag(8) as! UIImageView
        let currentFiatValueLabel = cell.viewWithTag(9) as! UILabel
        let memoLabel = cell.viewWithTag(10) as! UILabel
        let transactionLabel = cell.viewWithTag(11) as! UILabel
        let seeDetailButton = cell.viewWithTag(14) as! UIButton
        let editLabelButton = cell.viewWithTag(15) as! UIButton
        
        amountLabel.alpha = 1
        confirmationsLabel.alpha = 1
        dateLabel.alpha = 1
        
        let index = indexPath.section - 1
                
        seeDetailButton.addTarget(self, action: #selector(goToDetail(_:)), for: .touchUpInside)
        seeDetailButton.restorationIdentifier = "\(index)"
        
        editLabelButton.addTarget(self, action: #selector(editTx(_:)), for: .touchUpInside)
        editLabelButton.restorationIdentifier = "\(index)"
        
        var dict = self.transactionArray[index]
        
        if showOnchainOnly  {
            dict = self.onchainTxArray[index]
        }
        
        if showOffchain && offchainTxArray.count > 0 {
            dict = self.offchainTxArray[index]
            let confs = dict["confirmations"] as! String
            
            if confs.contains("complete") {
                confirmationsLabel.text = "Sent"
            } else if confs.contains("paid") {
                confirmationsLabel.text = "Received"
            } else if confs.contains("Sent") {
                confirmationsLabel.text = "Sent"
            } else {
                confirmationsLabel.text = confs + " " + "confs"
            }
        }
        
        let isOnchain = dict["onchain"] as? Bool ?? false
        if isOnchain {
            seeDetailButton.alpha = 1
            onchainImage.alpha = 1
            let confs = dict["confirmations"] as! String
            confirmationsLabel.text = confs + " " + "confs"
        } else {
            onchainImage.alpha = 0
        }
        
        let isLightning = dict["isLightning"] as? Bool ?? false        
        
        if isLightning {
            lightningImage.alpha = 1
            
            if !isOnchain {
                seeDetailButton.alpha = 0
            }
        } else {
            lightningImage.alpha = 0
        }
        
        dateLabel.text = dict["date"] as? String
        
        if dict["abandoned"] as? Bool == true {
            cell.backgroundColor = .red
        }
        
        let amountBtc = dict["amountBtc"] as! String
        let amountSats = dict["amountSats"] as! String
        let amountFiat = dict["amountFiat"] as! String
        editLabelButton.alpha = 1
        
        var gainText = ""
        
        if let originRate = dict["originRate"] as? Double {
            var btcAmount = 0.0
            
            btcAmount = amountBtc.doubleValue
            
            if btcAmount < 0.0 {
                btcAmount = btcAmount * -1.0
            }
            
            var originValueFiat = 0.0
            
            originValueFiat = btcAmount * originRate
            
            if originValueFiat < 0.0 {
                originValueFiat = originValueFiat * -1.0
            }
            
            if let exchangeRate = fxRate {
                var gain = round((btcAmount * exchangeRate) - originValueFiat)
                
                if Int(gain) > 0 {
                    gainText = " / gain of \(gain.fiatString) / \(Int((gain / originValueFiat) * 100.0))%"
                } else if Int(gain) < 0 {
                    gain = gain * -1.0
                    gainText = " / loss of \(gain.fiatString) / \(Int((gain / originValueFiat) * 100.0))%"
                }
            }
        }
        
        if let _ = fxRate {
            currentFiatValueLabel.text = amountFiat + gainText
        } else {
            currentFiatValueLabel.text = "current exchange rate missing"
        }
        
        memoLabel.text = dict["memo"] as? String ?? "no transaction memo"
        transactionLabel.text = dict["transactionLabel"] as? String ?? "no transaction label"
        
        if memoLabel.text == "" {
            memoLabel.text = "no transaction memo"
        }
        
        if transactionLabel.text == "" {
            transactionLabel.text = "no transaction label"
        }
        
        if amountBtc.hasPrefix("-") || amountSats.hasPrefix("-") {
            categoryImage.image = UIImage(systemName: "arrow.up.right")
            categoryImage.tintColor = .systemRed
            
            amountLabel.textColor = UIColor.darkGray
            
            var amountText = ""
            
            if isBtc {
                amountText = amountBtc
            } else if isSats {
                amountText = amountSats.sats
            } else if isFiat {
                amountText = amountFiat
            }
            
            amountText = amountText.replacingOccurrences(of: "-", with: "")
            amountLabel.text = amountText
            
        } else {
            categoryImage.image = UIImage(systemName: "arrow.down.left")
            categoryImage.tintColor = .systemGreen
            amountLabel.textColor = .white
            
            var amountText = ""
            
            if isBtc {
                amountText = "+" + amountBtc
            } else if isSats {
                amountText = "+" + amountSats.sats
            } else if isFiat {
                amountText = "+" + amountFiat
            }
            
            amountText = amountText.replacingOccurrences(of: "+", with: "")
            amountLabel.text = amountText
        }
        
        return cell
    }
        
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
    @objc func fetchMemo(_ sender: UIButton) {
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        
        var tx:[String:Any]!
        
        if self.showOffchain {
            tx = self.offchainTxArray[int]
        } else if self.showOnchain {
            tx = self.onchainTxArray[int]
        } else {
            tx = self.transactionArray[int]
        }
                        
        guard let invoice = tx["address"] as? String, invoice != "" else {
            showAlert(vc: self, title: "No invoice.", message: "We do not seem to have an invoice for that transaction.  You can add your own memo by tapping the \"edit memo\" button.")
            return
        }
        
        spinner.addConnectingView(vc: self, description: "decoding invoice...")
        
        isLndNode { isLnd in
            if isLnd {
                self.decodeInvoiceLND(invoice: invoice, section: int)
            } else {
                self.decodeInvoiceCL(invoice: invoice, section: int)
            }
        }
    }
    
    private func decodeInvoiceCL(invoice: String, section: Int) {
        let commandId = UUID()
        //bolt11 [description]
        LightningRPC.sharedInstance.command(id: commandId, method: .decodepay, param: ["bolt11": invoice]) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
                        
            guard let dict = response as? [String:Any], let txid = dict["payment_hash"] as? String, let description = dict["description"] as? String else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                return
            }
            
            self.updateMemo(txid: txid, memo: description)
        }
    }
    
    private func decodeInvoiceLND(invoice: String, section: Int) {
        LndRpc.sharedInstance.command(.decodepayreq, nil, invoice, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response,
                  let memo = response["description"] as? String,
                  memo != "",
                  let txid = response["payment_hash"] as? String else {
                
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No memo.", message: "This invoice does not include a memo. You can add your own by tapping the \"edit memo\" button.")
                return
            }
            
            self.updateMemo(txid: txid, memo: memo)
        }
    }
    
    private func updateMemo(txid: String, memo: String) {
        addNavBarSpinner()
        
        CoreDataService.retrieveEntity(entityName: .transactions) { savedTxs in
            guard let savedTxs = savedTxs, savedTxs.count > 0 else {
                self.removeSpinner()
                return
            }
                        
            for savedTx in savedTxs {
                let txStruct = TransactionStruct(dictionary: savedTx)
                if txStruct.txid == txid {
                    CoreDataService.update(id: txStruct.id!, keyToUpdate: "memo", newValue: memo, entity: .transactions) { [weak self] updated in
                        guard let self = self else { return }
                        
                        if updated {
                            self.spinner.label.text = "reloading..."
                            self.addNavBarSpinner()
                            self.loadTable()
                            showAlert(vc: self, title: "Memo updated ✓", message: "")
                        } else {
                            self.removeSpinner()
                            showAlert(vc: self, title: "Error", message: "There was an issue updatinng your memo.")
                        }
                    }
                }
            }
        }
    }
    
    @objc func editTx(_ sender: UIButton) {
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        
        let tx = transactionArray[int]
        let id = tx["txID"] as! String
        
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                return
            }
            
            for transaction in transactions {
                let txStruct = TransactionStruct(dictionary: transaction)
                if txStruct.txid == id {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.txToEdit = id
                        self.memoToEdit = txStruct.memo
                        self.labelToEdit = txStruct.label
                        self.performSegue(withIdentifier: "segueToEditTx", sender: self)
                    }
                }
            }
        }
    }
    
    @objc func refreshWallet() {
        refreshAll()
    }
    
    private func checkIfWalletsChanged() {
        let walletName = ud.object(forKey: "walletName") as? String ?? ""
        
        if walletName != existingWallet {
            existingWallet = walletName
            reloadWalletData()
        }
    }
    
    private func loadBalances() {
        NodeLogic.walletDisabled = walletDisabled
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            self.showOffchain = false
            for node in nodes ?? [] {
                let s = NodeStruct(dictionary: node)
                if s.isLightning && s.isActive || s.isNostr && s.isActive {
                    self.showOffchain = true
                }
            }
            self.getWalletBalance()
        }
    }
    
    private func chooseWallet() {
        OnchainUtils.listWalletDir { (coreWallets, message) in
            guard let coreWallets = coreWallets, !coreWallets.wallets.isEmpty else { self.promptToCreateWallet(); return }
            
            CoreDataService.retrieveEntity(entityName: .wallets) { localWallets in
                guard let localWallets = localWallets, !localWallets.isEmpty else { self.promptToCreateWallet(); return }
                
                var walletExists = false
                
                for (i, coreWallet) in coreWallets.wallets.enumerated() {
                    for (x, localWallet) in localWallets.enumerated() {
                        if localWallet["id"] != nil {
                            let localWalletStruct = Wallet(dictionary: localWallet)
                            if coreWallet == localWalletStruct.name {
                                walletExists = true
                            }
                            
                            if i + 1 == coreWallets.wallets.count && x + 1 == localWallets.count {
                                if walletExists {
                                    self.promptToChooseWallet()
                                } else {
                                    self.promptToCreateWallet()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    
    private func getFxRate() {
        FiatConverter.sharedInstance.getFxRate { [weak self] rate in
            guard let self = self else { return }
            
            guard let rate = rate else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.fxRateLabel.text = "no fx rate data"
                }
                loadTable()
                return
            }
            
            self.fxRate = rate
            UserDefaults.standard.setValue(rate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRateLabel.text = rate.exchangeRate
                self.onchainBalanceFiat = (self.onchainBalanceBtc.doubleValue * Double(rate)).fiatString
                loadTable()
            }
        }
    }
    
    private func dateFromStr(date: String) -> Date? {
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.date(from: date)
    }
    
    private func getWalletBalance() {
        if let _ = UserDefaults.standard.object(forKey: "walletName") as? String {
            
            func getOnchainWalletBalance() {
                OnchainUtils.getBalance { [weak self] (balance, message) in
                    guard let self = self else { return }
                    
                    guard let balance = balance else {
                        self.removeSpinner()
                        if (message ?? "").hasPrefix("loadwallet") {
                            self.chooseWallet()
                        } else {
                            showAlert(vc: self, title: "", message: message ?? "Unknown error getting balance.")
                        }
                        
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.onchainBalanceBtc = balance.btcBalanceWithSpaces
                        self.onchainBalanceSats = balance.sats.replacingOccurrences(of: " sats", with: "")
                        
                        if let exchangeRate = self.fxRate {
                            let onchainBalanceFiat = balance * exchangeRate
                            self.onchainBalanceFiat = round(onchainBalanceFiat).fiatString
                        }
                        
                        self.sectionZeroLoaded = true
                        self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                        self.getWalletInfo()
                    }
                }
            }
            
            guard let wallet = wallet else {
                getOnchainWalletBalance()
                return
            }
            
            if wallet.isJm {
                JMRPC.sharedInstance.command(method: .listutxos(jmWallet: wallet), param: nil) { [weak self] (response, errorDesc) in
                    guard let self = self else { return }
                    guard let response = response as? [String:Any] else {
                        if errorDesc == "Invalid credentials." {
                            JMUtils.unlockWallet(wallet: self.wallet!) { (unlockedWallet, unlock_message) in
                                guard let _ = unlockedWallet else {
                                    showAlert(vc: self, title: "", message: unlock_message ?? "Unknown error unlocking wallet.")
                                    return
                                }
                                CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
                                    for w in wallets! {
                                        if w["id"] != nil {
                                            let s = Wallet(dictionary: w)
                                            if s.jmWalletName == self.wallet!.jmWalletName {
                                                self.wallet = s
                                                self.getWalletBalance()
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            showAlert(vc: self, title: "", message: errorDesc ?? "Unknown issue getting jm utxos.")
                        }
                        
                        return
                    }
                    guard let utxos = response["utxos"] as? [[String:Any]] else { return }
                    var totalBalance = 0.0
                    for utxo in utxos {
                        let value = utxo["value"] as! Int
                        totalBalance += value.satsToBtcDouble
                    }
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        totalBalance = Double(round(100000000 * totalBalance) / 100000000)
                        self.onchainBalanceBtc = totalBalance.btcBalanceWithSpaces
                        self.onchainBalanceSats = totalBalance.sats.replacingOccurrences(of: " sats", with: "")
                        self.sectionZeroLoaded = true
                        self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                        self.getWalletInfo()
                    }
                }
            } else {
                getOnchainWalletBalance()
            }
        } else {
            chooseWallet()
        }
    }
    
    private func getWalletInfo() {
        OnchainUtils.getWalletInfo { [weak self] (walletInfo, message) in
            guard let self = self else { return }
            
            guard let walletInfo = walletInfo else {
                if let message = message {
                    showAlert(vc: self, title: "", message: message)
                    self.removeSpinner()
                }
                return
            }
            
            self.walletInfo = walletInfo
            self.syncIndexes()
            
            guard let progress = walletInfo.progress else {
                return
            }
            
            showAlert(vc: self, title: "Wallet scanning \(Int(progress * 100))% complete", message: "Your wallet is currently rescanning the blockchain, you need to wait until it completes before you will see your balances and transactions.")
        }
    }
    
    private func loadLightning() {
        NodeLogic.loadBalances { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            guard let response = response else {
                guard let errorMessage = errorMessage else { return }
                self.removeSpinner()
                showAlert(vc: self, title: "", message: errorMessage)
                return
            }
            
            let balances = Balances(dictionary: response)
            self.offchainBalanceBtc = balances.offchainBalance.doubleValue.btcBalanceWithSpaces
            self.offchainBalanceSats = balances.offchainBalance.btcToSats
            
            if let exchangeRate = self.fxRate {
                let offchainBalance = balances.offchainBalance.doubleValue
                let offchainBalanceFiat = offchainBalance * exchangeRate
                self.offchainBalanceFiat = round(offchainBalanceFiat).fiatString
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.sectionZeroLoaded = true
                self.walletTable.reloadSections(.init(arrayLiteral: 0), with: .none)
                self.loadTransactions()
            }
        }
    }
    
    private func syncIndexes() {
        let p:List_Unspent = .init(["minconf":0])
        OnchainUtils.listUnspent(param: p) { [weak self] (utxos, message) in
            guard let self = self else { return }
            
            guard let utxos = utxos, utxos.count > 0, let wallet = self.wallet else {
                self.getOffchainBalanceAndTransactions()
                return
            }
            
            for (i, utxo) in utxos.enumerated() {
                guard let utxo_desc = utxo.desc else {
                    if i + 1 == utxos.count {
                        self.getOffchainBalanceAndTransactions()
                    }
                    return
                }
                
                let desc = Descriptor(utxo_desc)
                
                guard let index = desc.index else {
                    if i + 1 == utxos.count {
                        self.getOffchainBalanceAndTransactions()
                    }
                    return
                }
                
                if index >= wallet.index {
                    let newIndex = Int64(index + 1)
                    if newIndex >= wallet.maxIndex {
                        showAlert(vc: self, title: "Action required", message: "Go to wallet info, scroll to \"gap limit\", and tap the + button to increase the gap limit.")
                    }
                    CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: newIndex, entity: .wallets) { updated in
                        #if DEBUG
                        print("incremented index to \(newIndex): \(updated)")
                        #endif
                        guard updated else {
                            if i + 1 == utxos.count {
                                self.getOffchainBalanceAndTransactions()
                            }
                            showAlert(vc: self, title: "", message: "Unable to update your wallet index.")
                            return
                        }
                    }
                }
                
                if i + 1 == utxos.count {
                    self.getOffchainBalanceAndTransactions()
                }
            }
        }
    }
    
    private func getOffchainBalanceAndTransactions() {
        if self.showOffchain {
            self.loadLightning()
        } else {
            self.loadTransactions()
        }
    }
    
    private func promptToRescan() {
        let hasPrompted = UserDefaults.standard.value(forKey: "hasPromptedToRescan") as? Bool ?? false
        if !hasPrompted {
            UserDefaults.standard.setValue(true, forKey: "hasPromptedToRescan")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "No transactions found.", message: "Would you like to rescan the blockchain to search for transaction history and balances? Input the year you'd like to rescan from.", preferredStyle: self.alertStyle)
                
                let rescan = UIAlertAction(title: "Rescan", style: .default) { [weak self] (alertAction) in
                    guard let self = self else { return }
                    let textField = (alert.textFields![0] as UITextField)
                    var blockheight = 0
                    let currentYear = Int(Calendar.current.component(.year, from: .now))
                    if let text = textField.text {
                        var yearToScanFrom = Int(text) ?? 2009
                        
                        if yearToScanFrom <= currentYear {
                            if yearToScanFrom < 2010 {
                                yearToScanFrom = 2010
                            }
                            let yearsToScan = (currentYear - yearToScanFrom) + 1
                            let blocksToScan = yearsToScan * 55000
                            
                            spinner.addConnectingView(vc: self, description: "rescanning...")
                            
                            OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
                                guard let self = self else { return }
                                
                                guard let blockchainInfo = blockchainInfo else {
                                    spinner.removeConnectingView()
                                    showAlert(vc: self, title: "", message: message ?? "Unknown issue getblockchaininfo.")
                                    return
                                }
                                
                                if !blockchainInfo.initialblockdownload {
                                    blockheight = blockchainInfo.blockheight - blocksToScan
                                    
                                    if blockchainInfo.pruned {
                                        if blockheight < blockchainInfo.pruneheight {
                                            blockheight = blockchainInfo.pruneheight
                                        }
                                    }
                                    
                                    OnchainUtils.rescanNow(from: blockheight) { [weak self] (started, message) in
                                        guard let self = self else { return }
                                        
                                        guard started else {
                                            spinner.removeConnectingView()
                                            showAlert(vc: self, title: "", message: message ?? "Unknown issue from rescan.")
                                            return
                                        }
                                        
                                        self.spinner.removeConnectingView()
                                        showAlert(vc: self, title: "", message: "Rescanning, you can refresh this page to see completion status.")
                                    }
                                } else {
                                    spinner.removeConnectingView()
                                    showAlert(vc: self, title: "", message: "Wait till your node is done syncing before attempting to rescan or use wallets.")
                                }
                            }
                        }
                    }
                }
                
                alert.addTextField { (textField) in
                    textField.placeholder = "From year"
                    textField.keyboardAppearance = .dark
                    textField.keyboardType = .numberPad
                    textField.text = "2009"
                }
                
                alert.addAction(rescan)
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Create a wallet.", message: "Or do it later by tapping the + button in the top left.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tabBarController?.selectedIndex = 1
                    self.performSegue(withIdentifier: "createFullyNodedWallet", sender: self)
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToChooseWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.removeSpinner()
            
            let alert = UIAlertController(title: "None of your wallets seem to be toggled on, please choose which wallet you want to use.", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Activate a Fully Noded wallet", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.tabBarController?.selectedIndex = 1
                    self.goChooseWallet()
                }
            }))
            
            CoreDataService.retrieveEntity(entityName: .wallets) { potentialJmWallets in
                guard let potentialJmWallets = potentialJmWallets else { return }
                
                var showJMOption = false
                
                for (i, potentialJmWallet) in potentialJmWallets.enumerated() {
                    if potentialJmWallet["id"] != nil {
                        let wStr = Wallet(dictionary: potentialJmWallet)
                        if wStr.isJm {
                            showJMOption = true
                        }
                        
                        if i + 1 == potentialJmWallets.count && showJMOption {
                            alert.addAction(UIAlertAction(title: "Activate a Join Market wallet", style: .default, handler: { action in
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    
                                    JMUtils.wallets { (response, message) in
                                        guard let jmwallets = response else {
                                            self.finishedLoading()
                                            showAlert(vc: self, title: "", message: message ?? "Unknown issue getting your JM wallets.")
                                            return
                                        }
                                        
                                        if jmwallets.count > 0 {
                                            self.promptToChooseJmWallet(jmWallets: jmwallets)
                                        }
                                    }
                                }
                            }))
                        }
                    }
                }
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func goChooseWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToWallets", sender: vc)
        }
    }
    
    func reloadWalletData() {
        transactionArray.removeAll()
        sectionZeroLoaded = false
        self.getWalletBalance()
    }
    
    private func loadTransactions() {
        NodeLogic.walletDisabled = walletDisabled
        NodeLogic.arrayToReturn.removeAll()
        transactionArray.removeAll()
        
        NodeLogic.loadSectionTwo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeSpinner()
                
                guard let errorMessage = errorMessage else {
                    return
                }
                showAlert(vc: self, title: "", message: errorMessage)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.transactionArray = response
                if let scanning = walletInfo?.scanning {
                    if !scanning && transactionArray.count == 0 {
                        promptToRescan()
                    }
                }
                
                self.updateTransactionArray()
                self.isRecovering = false
            }
        }
    }
    
    private func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.barSpinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.barSpinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.barSpinner.startAnimating()
            self.barSpinner.alpha = 1
        }
    }
    
    private func removeSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            self.barSpinner.stopAnimating()
            self.barSpinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            self.refreshButton.tintColor = UIColor.lightGray.withAlphaComponent(1)
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    private func refreshAll() {
        sectionZeroLoaded = false
        wallet = nil
        walletLabel = nil
        existingWallet = ""
        onchainBalanceSats = ""
        onchainBalanceFiat = ""
        onchainBalanceBtc = ""
        offchainBalanceSats = ""
        offchainBalanceFiat = ""
        offchainBalanceBtc = ""
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            self.transactionArray.removeAll()
            self.walletTable.reloadData()
        }
        
        addNavBarSpinner()
        getFxRate()
        //loadTable()
    }
    
    @objc func refreshData(_ sender: Any) {
        refreshAll()
    }
    
    private func goToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToActiveWalletDetail", sender: vc)
        }
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
        }
    }
    
    @objc func filterTxs(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Filter by", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Offchain", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                
                for (i, tx) in self.transactionArray.enumerated() {
                    if let isOnchain = tx["onchain"] as? Bool, !isOnchain, let isLightning = tx["isLightning"] as? Bool, isLightning {
                        self.offchainTxArray.append(tx)
                    }
                    
                    if i + 1 == self.transactionArray.count, self.offchainTxArray.count > 0 {
                        self.showOffchain = true
                        self.showOnchainOnly = false
                        self.reloadTable()
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Onchain", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                
                for (i, tx) in self.transactionArray.enumerated() {
                    if let isOnchain = tx["onchain"] as? Bool, isOnchain, let isLightning = tx["isLightning"] as? Bool, !isLightning {
                        self.onchainTxArray.append(tx)
                    }
                    
                    if i + 1 == self.transactionArray.count, self.onchainTxArray.count > 0 {
                        self.showOnchainOnly = true
                        self.showOffchain = false
                        self.reloadTable()
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Show all", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.showOnchainOnly = false
                self.showOffchain = false
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func sortTxs(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Sort by", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Amount", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                if self.showOffchain {
                    self.offchainTxArray = self.offchainTxArray.sorted{ ($0["amountBtc"] as! String).doubleValue > ($1["amountBtc"] as! String).doubleValue }
                } else if self.showOnchain {
                    self.onchainTxArray = self.onchainTxArray.sorted{ ($0["amountBtc"] as! String).doubleValue > ($1["amountBtc"] as! String).doubleValue }
                } else {
                    self.transactionArray = self.transactionArray.sorted{ ($0["amountBtc"] as! String).doubleValue > ($1["amountBtc"] as! String).doubleValue }
                }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Newest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                if self.showOffchain {
                    self.offchainTxArray = self.offchainTxArray.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                } else if self.showOnchain {
                    self.onchainTxArray = self.onchainTxArray.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                } else {
                    self.transactionArray = self.transactionArray.sorted{ ($0["sortDate"] as? Date ?? Date()) > ($1["sortDate"] as? Date ?? Date()) }
                }
                
                self.reloadTable()
                
            }))
            
            alert.addAction(UIAlertAction(title: "Oldest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                if self.showOffchain {
                    self.offchainTxArray = self.offchainTxArray.sorted{ ($0["sortDate"] as? Date ?? Date()) < ($1["sortDate"] as? Date ?? Date()) }
                } else if self.showOnchain {
                    self.onchainTxArray = self.onchainTxArray.sorted{ ($0["sortDate"] as? Date ?? Date()) < ($1["sortDate"] as? Date ?? Date()) }
                } else {
                    self.transactionArray = self.transactionArray.sorted{ ($0["sortDate"] as? Date ?? Date()) < ($1["sortDate"] as? Date ?? Date()) }
                }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "spendFromWallet":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            if isBtc {
                vc.balance = onchainBalanceBtc
            }
            
            if isSats {
                vc.balance = onchainBalanceSats
            }
            
            if isFiat {
                vc.balance = onchainBalanceFiat
            }
        
        case "segueToInvoice":
            guard let vc = segue.destination as? InvoiceViewController else { fallthrough }
            
            vc.isBtc = isBtc
            vc.isSats = isSats
            vc.isFiat = isFiat
        
        case "segueToSignPsbt":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.unsignedPsbt = self.psbt.condenseWhitespace()
            vc.signedRawTx = self.rawTx.condenseWhitespace()
            
        case "segueToEditTx":
            guard let vc = segue.destination as? TransactionLabelMemoViewController else { fallthrough }
            
            vc.memoText = memoToEdit
            vc.labelText = labelToEdit
            vc.txid = txToEdit
            vc.doneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                showAlert(vc: self, title: "", message: "Transaction updated ✓")
                self.spinner.addConnectingView(vc: self, description: "refreshing transactions...")
                self.loadTransactions()
            }
            
        case "segueToTxDetail":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.alreadyBroadcast = true
            vc.signedRawTx = hex
            vc.confs = confs
            
        case "segueToUtxos":
            guard let vc = segue.destination as? UTXOViewController else { fallthrough }
            
            vc.fxRate = fxRate
            vc.isBtc = isBtc
            vc.isSats = isSats
            vc.isFiat = isFiat
            
        case "segueToActiveWalletDetail":
            guard let vc = segue.destination as? WalletDetailViewController else { fallthrough }
            
            guard let idDetail = self.wallet?.id else {
                showAlert(vc: self, title: "", message: "Fully Noded can only show wallet details for wallets created with Fully Noded.")
                return
            }
                        
            vc.walletId = idDetail
            
        case "chooseAWallet":
            guard let vc = segue.destination as? ChooseWalletViewController else { fallthrough }
            
            vc.wallets = wallets
            
            vc.doneBlock = { result in
                self.loadTable()
            }
            
        case "segueToAccountMap":
            guard let vc = segue.destination as? QRDisplayerViewController else { fallthrough }
            
            if let json = CreateAccountMap.create(wallet: wallet!) {
                vc.text = json
            }
            
        case "createFullyNodedWallet":
            guard let vc = segue.destination as? CreateFullyNodedWalletViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.refreshWallet()
                    
                    guard let uncleJim = UserDefaults.standard.object(forKey: "UncleJim") as? Bool, uncleJim else {
                        //showAlert(vc: self, title: "Wallet imported ✓", message: "Your node is now rescanning the blockchain you can monitor rescan status by refreshing this page, balances and historic transactions will not display until the rescan completes.\n\n⚠️ Always verify the addresses match what you expect them to. Just tap the info button above and scroll down till you see the address explorer.")
                        
                        return
                    }
                    
                    showAlert(vc: self, title: "Wallet imported ✓", message: "")
                }
            }
                    
        default:
            break
        }
    }
}

extension ActiveWalletViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            if sectionZeroLoaded {
                if showOnchain && !showOffchain {
                    return onchainBalancesCell(indexPath)
                } else if showOffchain && !showOnchain {
                    return offchainBalancesCell(indexPath)
                } else {
                    return offchainOnchainBalancesCell(indexPath)
                }
            } else {
                return blankCell()
            }
        default:
            if transactionArray.count > 0 {
                return transactionsCell(indexPath)
            } else {
                return blankCell()
            }
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 400, height: 50)
        
        let filterButton = UIButton()
        let filterImage = UIImage(systemName: "line.horizontal.3.decrease.circle", withConfiguration: UIImage.SymbolConfiguration.init(scale: .large))
        filterButton.setImage(filterImage, for: .normal)
        filterButton.frame = CGRect(x: header.frame.size.width - 50, y: 0, width: 50, height: 50)
        filterButton.tintColor = .systemTeal
        filterButton.center.y = textLabel.center.y
        //filterButton.showsTouchWhenHighlighted = true
        filterButton.addTarget(self, action: #selector(filterTxs(_:)), for: .touchUpInside)
        
        let sortButton = UIButton()
        let sortImage = UIImage(systemName: "arrow.up.arrow.down.circle", withConfiguration: UIImage.SymbolConfiguration.init(scale: .large))
        sortButton.setImage(sortImage, for: .normal)
        sortButton.frame = CGRect(x: filterButton.frame.minX - 60, y: 0, width: 50, height: 50)
        sortButton.tintColor = .systemTeal
        sortButton.center.y = textLabel.center.y
        //sortButton.showsTouchWhenHighlighted = true
        sortButton.addTarget(self, action: #selector(sortTxs(_:)), for: .touchUpInside)
        
        switch section {
        case 0:
            if let w = self.wallet, w.isJm {
                textLabel.text = w.name + ": " + walletLabel
            } else {
                textLabel.text = walletLabel
            }
            
        case 1:
            if self.transactionArray.count > 0 {
                textLabel.text = "Transactions"
                header.addSubview(filterButton)
                header.addSubview(sortButton)
            } else {
                textLabel.text = ""
            }
            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 || section == 1 {
            return 50
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            if sectionZeroLoaded {
                if showOffchain && showOnchain {
                    return 100
                } else {
                    return 80
                }
            } else {
                return 47
            }
        default:
            if sectionZeroLoaded {
                return 230
            } else {
                return 47
            }
        }
    }
}

extension ActiveWalletViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if transactionArray.count > 0 {
            if showOnchainOnly {
                return 1 + onchainTxArray.count
            } else if showOffchain && !showOnchain {
                return 1 + offchainTxArray.count
            } else {
                return 1 + transactionArray.count
            }

        } else {
            return 2
        }
    }
}
