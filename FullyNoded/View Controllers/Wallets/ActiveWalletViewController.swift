//
//  ActiveWalletViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletViewController: UIViewController {
    
    private var existingWallet = ""
    private var walletDisabled = Bool()
    private var onchainBalance = ""
    private var offchainBalance = ""
    private var onchainFiat = ""
    private var offchainFiat = ""
    private var sectionZeroLoaded = Bool()
    private var wallets = NSArray()
    private var transactionArray = [[String:Any]]()
    private var tx = String()
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel:String!
    private var wallet:Wallet?
    private var isBolt11 = false
    private var fxRate:Double?
    private var alertStyle = UIAlertController.Style.actionSheet
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
    
    @IBOutlet weak private var backgroundView: UIVisualEffectView!
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var sendView: UIView!
    @IBOutlet weak private var invoiceView: UIView!
    @IBOutlet weak private var utxosView: UIView!
    @IBOutlet weak private var advancedView: UIView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        walletTable.delegate = self
        walletTable.dataSource = self
        configureUi()
        NotificationCenter.default.addObserver(self, selector: #selector(broadcast(_:)), name: .broadcastTxn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signPsbt(_:)), name: .signPsbt, object: nil)
        existingWallet = ud.object(forKey: "walletName") as? String ?? ""
        sectionZeroLoaded = false
        setNotifications()
        addNavBarSpinner()
        getFxRate()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if KeyChain.getData("UnlockPassword") == nil && UserDefaults.standard.object(forKey: "doNotShowWarning") == nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let alert = UIAlertController(title: "", message: "You really ought to add a password that is used to lock the app if you are doing wallet related stuff!", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: "set password", style: .default, handler: { action in
                    DispatchQueue.main.async {
                        self.performSegue(withIdentifier: "segueToAddPassword", sender: self)
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "do not show again", style: .destructive, handler: { action in
                    UserDefaults.standard.set(true, forKey: "doNotShowWarning")
                }))
                
                alert.addAction(UIAlertAction(title: "cancel", style: .cancel, handler: { action in }))
                
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
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
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
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
    
    @IBAction func invoiceSettings(_ sender: Any) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else { return }
            
            var uncleJim = false
            for node in nodes {
                let nodeStruct = NodeStruct(dictionary: node)
                if nodeStruct.isActive {
                    if let uj = node["uncleJim"] as? Bool {
                        uncleJim = uj
                    }
                }
            }
            
            if !uncleJim {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.performSegue(withIdentifier: "goToInvoiceSetting", sender: vc)
                }
            } else {
                showAlert(vc: self, title: "Restricted access!", message: "That area is for the node owner only.")
            }
        }
    }
    
    @IBAction func goToUtxos(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToUtxos", sender: vc)
        }
    }
    
    @objc func importWallet(_ notification: NSNotification) {
        spinner.addConnectingView(vc: self, description: "importing your Coldcard wallet, this can take a minute...")
        
        guard let accountMap = notification.userInfo as? [String:Any] else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Ooops", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
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
            showAlert(vc: self, title: "Wallet imported ✅", message: "It has been activated and is refreshing now.")
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
            showAlert(vc: self, title: "Coldcard Wallet imported ✅", message: "It has been activated and is refreshing now.")
            self.refreshWallet()
        }
    }
    
    private func loadTable() {
        existingWallet = ""
        walletLabel = ""
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                self.wallet = nil
                self.walletLabel = UserDefaults.standard.object(forKey: "walletName") as? String ?? "Default Wallet"
                self.loadBalances()
                return
            }
            
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
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.walletTable.reloadData()
            self.removeSpinner()
            self.getWalletInfo()
        }
    }
    
    private func updateTransactionArray() {
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0, self.transactionArray.count > 0 else {
                self.finishedLoading()
                return
            }
            
            for (i, transaction) in transactions.enumerated() {
                let localTransactionStruct = TransactionStruct(dictionary: transaction)
                
                for (t, tx) in self.transactionArray.enumerated() {
                    if !(tx["isLightning"] as! Bool) && (tx["txID"] as! String) == localTransactionStruct.txid {
                        self.transactionArray[t]["memo"] = localTransactionStruct.memo
                        self.transactionArray[t]["transactionLabel"] = localTransactionStruct.label
                        
                        if let originRate = localTransactionStruct.fxRate, originRate > 0 {
                            self.transactionArray[t]["originRate"] = originRate
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
        
        Reducer.makeCommand(command: .gettransaction, param: "\"\(id)\", true") { [weak self] (response, errorMessage) in
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
    
    private func balancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "BalancesCell", for: indexPath)
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        let offchainBalanceLabel = cell.viewWithTag(2) as! UILabel
        let onchainFiatLabel = cell.viewWithTag(4) as! UILabel
        let offchainFiatLabel = cell.viewWithTag(5) as! UILabel
        let onchainIconBackground = cell.viewWithTag(7)!
        let offchainIconBackground = cell.viewWithTag(8)!
        
        if onchainBalance == "" {
            onchainBalance = "0.00000000"
        }
        
        if offchainBalance == "" {
            offchainBalance = "0.00000000"
        }
        
        onchainIconBackground.layer.cornerRadius = 5
        offchainIconBackground.layer.cornerRadius = 5
        onchainFiatLabel.text = onchainFiat
        offchainFiatLabel.text = offchainFiat
        onchainBalanceLabel.text = onchainBalance
        offchainBalanceLabel.text = offchainBalance
        onchainBalanceLabel.adjustsFontSizeToFitWidth = true
        offchainBalanceLabel.adjustsFontSizeToFitWidth = true
        
        return cell
    }
    
    private func transactionsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let categoryImage = cell.viewWithTag(1) as! UIImageView
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let confirmationsLabel = cell.viewWithTag(3) as! UILabel
        let utxoLabel = cell.viewWithTag(4) as! UILabel
        let dateLabel = cell.viewWithTag(5) as! UILabel
        let lightningImage = cell.viewWithTag(7) as! UIImageView
        let onchainImage = cell.viewWithTag(8) as! UIImageView
        let currentFiatValueLabel = cell.viewWithTag(9) as! UILabel
        let memoLabel = cell.viewWithTag(10) as! UILabel
        let transactionLabel = cell.viewWithTag(11) as! UILabel
        let originFiatValueLabel = cell.viewWithTag(12) as! UILabel
        let fetchOriginRateButton = cell.viewWithTag(13) as! UIButton
        let seeDetailButton = cell.viewWithTag(14) as! UIButton
        let editLabelButton = cell.viewWithTag(15) as! UIButton
        
        amountLabel.alpha = 1
        confirmationsLabel.alpha = 1
        utxoLabel.alpha = 1
        dateLabel.alpha = 1
        fetchOriginRateButton.alpha = 0
        
        let index = indexPath.section - 1
        
        fetchOriginRateButton.addTarget(self, action: #selector(getHistoricRate(_:)), for: .touchUpInside)
        fetchOriginRateButton.restorationIdentifier = "\(index)"
        
        seeDetailButton.addTarget(self, action: #selector(goToDetail(_:)), for: .touchUpInside)
        seeDetailButton.restorationIdentifier = "\(index)"
        
        editLabelButton.addTarget(self, action: #selector(editTx(_:)), for: .touchUpInside)
        editLabelButton.restorationIdentifier = "\(index)"
        
        let dict = self.transactionArray[index]
        
        let selfTransfer = dict["selfTransfer"] as! Bool
        
        let confs = dict["confirmations"] as! String
        if confs.contains("complete") {
            confirmationsLabel.text = confs
        } else if confs.contains("incomplete") || confs.contains("unpaid") || confs.contains("expired") || confs.contains("paid") {
            confirmationsLabel.text = confs
        } else {
            confirmationsLabel.text = confs + " " + "confs"
        }
        
        var utxoLabelText = dict["label"] as? String ?? "no utxo label"
        
        if utxoLabelText == "" || utxoLabelText == "," {
            utxoLabelText = "no utxo label"
        }
        
        let isOnchain = dict["onchain"] as? Bool ?? false
        if isOnchain {
            onchainImage.alpha = 1
        } else {
            onchainImage.alpha = 0
        }
        
        let isLightning = dict["isLightning"] as? Bool ?? false
        if isLightning {
            lightningImage.alpha = 1
        } else {
            lightningImage.alpha = 0
        }
        
        dateLabel.text = dict["date"] as? String
        
        if dict["abandoned"] as? Bool == true {
            cell.backgroundColor = .red
        }
        
        let amount = dict["amount"] as! String
        
        if isOnchain {
            utxoLabel.text = utxoLabelText
            editLabelButton.alpha = 1
            seeDetailButton.alpha = 1
            fetchOriginRateButton.alpha = 1
            
            if let exchangeRate = fxRate {
                var dbl = round((amount.doubleValue * exchangeRate))
                if dbl < 0 {
                    dbl = dbl * -1.0
                }
                currentFiatValueLabel.text = "$\(dbl.withCommas()) USD"
            } else {
                currentFiatValueLabel.text = "current exchange rate missing"
            }
            
            if let originRate = dict["originRate"] as? Double {
                var amountProcessed = amount.doubleValue
                if amountProcessed < 0.0 {
                    amountProcessed = amountProcessed * -1.0
                }
                var dbl = round((amountProcessed * originRate))
                if dbl < 0.0 {
                    dbl = dbl * -1.0
                }
                originFiatValueLabel.text = "$\(round((dbl)).withCommas()) USD"
                
                if let exchangeRate = fxRate {
                    var gain = round((amountProcessed * exchangeRate) - (dbl))
                    if Int(gain) > 0 {
                        originFiatValueLabel.text! += " / gain of $\(gain.withCommas()) USD / \(Int((gain / dbl) * 100.0))%"
                    } else if Int(gain) < 0 {
                        gain = gain * -1.0
                        originFiatValueLabel.text! += " / loss of $\(gain.withCommas()) USD / \(Int((gain / dbl) * 100.0))%"
                    } else {
                        originFiatValueLabel.text! += " (no change)"
                    }
                }
                fetchOriginRateButton.alpha = 0
                
            } else {
                originFiatValueLabel.text = "origin exchange rate missing"
                fetchOriginRateButton.alpha = 1
            }
            
            memoLabel.text = dict["memo"] as? String ?? "no transaction memo"
            transactionLabel.text = dict["transactionLabel"] as? String ?? "no transaction label"
        } else {
            memoLabel.text = "N/A"
            transactionLabel.text = "N/A"
            currentFiatValueLabel.text = "N/A"
            originFiatValueLabel.text = "N/A"
            utxoLabel.text = "N/A"
            editLabelButton.alpha = 0
            seeDetailButton.alpha = 0
            fetchOriginRateButton.alpha = 0
        }
                
        if amount.hasPrefix("-") {
            categoryImage.image = UIImage(systemName: "arrow.up.right")
            categoryImage.tintColor = .systemRed
            amountLabel.text = amount
            amountLabel.textColor = UIColor.darkGray
        } else {
            categoryImage.image = UIImage(systemName: "arrow.down.left")
            categoryImage.tintColor = .systemGreen
            amountLabel.text = "+" + amount
            amountLabel.textColor = .white
        }
        
        if selfTransfer {
            amountLabel.text = (amountLabel.text!).replacingOccurrences(of: "+", with: "")
            amountLabel.text = (amountLabel.text!).replacingOccurrences(of: "-", with: "")
            amountLabel.textColor = .darkGray
            categoryImage.image = UIImage.init(systemName: "arrow.2.circlepath")
            categoryImage.tintColor = .darkGray
        }
        
        return cell
    }
        
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
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
        NodeLogic.loadBalances { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeSpinner()
                
                guard let errorMessage = errorMessage else {
                    return
                }
                
                guard errorMessage.contains("Wallet file not specified (must request wallet RPC through") else {
                    displayAlert(viewController: self, isError: true, message: errorMessage)
                    return
                }
                
                self.removeSpinner()
                self.existingWallet = "multiple wallets"
                self.chooseWallet()
                
                return
            }
            
            let balances = Balances(dictionary: response)
            self.onchainBalance = balances.onchainBalance
            self.offchainBalance = balances.offchainBalance
            
            DispatchQueue.main.async {
                if let exchangeRate = self.fxRate {
                    let onchainBalance = balances.onchainBalance.doubleValue
                    let onchainBalanceFiat = onchainBalance * exchangeRate
                    self.onchainFiat = "$\(round(onchainBalanceFiat).withCommas())"
                    
                    let offchainBalance = balances.offchainBalance.doubleValue
                    let offchainBalanceFiat = offchainBalance * exchangeRate
                    self.offchainFiat = "$\(round(offchainBalanceFiat).withCommas())"
                }
                
                self.sectionZeroLoaded = true
                self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                self.loadTransactions()
            }
        }
    }
    
    private func chooseWallet() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets, wallets.count > 0 else { self.promptToCreateWallet(); return }
            
            self.promptToChooseWallet()
        }
    }
    
    private func getFxRate() {
        FiatConverter.sharedInstance.getFxRate { [weak self] rate in
            guard let self = self else { return }
            
            guard let rate = rate else {
                self.onchainFiat = ""
                self.offchainFiat = ""
                DispatchQueue.main.async {
                    self.fxRateLabel.text = "no fx rate data"
                }
                self.loadTable()
                return
            }
            
            self.fxRate = rate
            
            DispatchQueue.main.async { [unowned vc = self] in
                vc.fxRateLabel.text = "$\(rate.withCommas()) / btc"
            }
            
            DispatchQueue.main.async {
                self.loadTable()
            }
        }
    }
    
    @objc func getHistoricRate(_ sender: UIButton) {
        print("getHistoricRate")
        spinner.addConnectingView(vc: self, description: "fetching historic rate...")
        
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Unable to determine historic rate.")
            return
        }
        
        let tx = transactionArray[int]
        let id = tx["txID"] as! String
        
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "Unable to determine historic rate.")
                return
            }
            
            var foundMatch = false
            
            for (t, transaction) in transactions.enumerated() {
                let txStruct = TransactionStruct(dictionary: transaction)
                if txStruct.txid == id {
                    guard let date = txStruct.date, let uuid = txStruct.id else { return }
                    
                    foundMatch = true
                    self.addOriginRate(date, uuid)
                }
                
                if t + 1 == transactions.count && !foundMatch {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "No matching locally saved transactions. This usually means you are using the nodes default wallet, this feature only works with Fully Noded wallets.")
                }
            }
        }
    }
    
    private func addOriginRate(_ date: Date, _ id: UUID) {
        print("addOriginRate")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let today = dateFormatter.string(from: Date())
        
        if dateString == today {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "You need to wait for the transaction to be at least one day old before fetching the historic rate.")
        } else {
            FiatConverter.sharedInstance.getOriginRate(date: dateString) { [weak self] originRate in
                guard let self = self else { return }
                
                guard let originRate = originRate else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "There was an issue fetching the historic exchange rate, please let us know about it.")
                    return
                }
                
                CoreDataService.update(id: id, keyToUpdate: "originFxRate", newValue: originRate, entity: .transactions) { success in
                    guard success else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "", message: "There was an issue saving the historic exchange rate, please let us know about it.")
                        return
                    }
                    
                    self.transactionArray.removeAll()
                    self.loadTransactions()
                }
            }
        }
    }
    
    private func getWalletInfo() {
        Reducer.makeCommand(command: .getwalletinfo, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary,
                let scanning = dict["scanning"] as? NSDictionary,
                let progress = scanning["progress"] as? Double else {
                return
            }
            
            showAlert(vc: self, title: "Wallet scanning \(Int(progress * 100))% complete", message: "Your wallet is currently rescanning the blockchain, you need to wait until it completes before you will see your balances and transactions.")
        }
    }
    
    private func promptToCreateWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Looks like you have not yet created a Fully Noded wallet, tap create to get started, if you are not yet ready you can always tap the + button in the top left.", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { action in
                DispatchQueue.main.async {
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
            
            let alert = UIAlertController(title: "None of your wallets seem to be toggled on, please choose which wallet you want to use.", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Choose", style: .default, handler: { action in
                self.goChooseWallet()
            }))
            
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
        
        NodeLogic.loadBalances { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeSpinner()
                
                guard let errorMessage = errorMessage else {
                    displayAlert(viewController: self, isError: true, message: "unknown error")
                    return
                }
                
                displayAlert(viewController: self, isError: true, message: errorMessage)
                return
            }
            
            let balances = Balances(dictionary: response)
            self.onchainBalance = balances.onchainBalance
            
            DispatchQueue.main.async {
                self.sectionZeroLoaded = true
                self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .none)
            }
            
            self.loadTransactions()
        }
    }
    
    private func loadTransactions() {
        NodeLogic.walletDisabled = walletDisabled
        NodeLogic.loadSectionTwo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeSpinner()
                
                guard let errorMessage = errorMessage else {
                    return
                }
                
                displayAlert(viewController: self, isError: true, message: errorMessage)
                return
            }
            
            DispatchQueue.main.async {
                self.transactionArray = response
                self.updateTransactionArray()
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
        wallet = nil
        walletLabel = nil
        existingWallet = ""
        onchainBalance = ""
        offchainBalance = ""
        onchainFiat = ""
        offchainFiat = ""
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            self.transactionArray.removeAll()
            self.walletTable.reloadData()
        }
        
        addNavBarSpinner()
        getFxRate()
    }
    
    @objc func refreshData(_ sender: Any) {
        refreshAll()
    }
    
    private func goToDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToActiveWalletDetail", sender: vc)
        }
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        
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
            
            if let json = AccountMap.create(wallet: wallet!) {
                vc.text = json
            }
            
        case "createFullyNodedWallet":
            guard let vc = segue.destination as? CreateFullyNodedWalletViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.refreshWallet()
                    
                    guard let uncleJim = UserDefaults.standard.object(forKey: "UncleJim") as? Bool, uncleJim else {
                        showAlert(vc: self, title: "Wallet imported ✅", message: "Wallet imported successfully, it is now rescanning the blockchain you can monitor rescan status by refreshing this page, balances and historic transactions will not display until the rescan completes.")
                        
                        return
                    }
                    
                    showAlert(vc: self, title: "Wallet imported ✅", message: "")
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
                return balancesCell(indexPath)
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
        
        switch section {
        case 0:
            textLabel.text = walletLabel
            
        case 1:
            if self.transactionArray.count > 0 {
                textLabel.text = "Transactions"
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
                return 116
            } else {
                return 47
            }
        default:
            if sectionZeroLoaded {
                return 303
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
            return 1 + transactionArray.count
        } else {
            return 2
        }
    }
}
