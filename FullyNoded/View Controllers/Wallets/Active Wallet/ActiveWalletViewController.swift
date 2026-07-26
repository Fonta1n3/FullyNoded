//
//  ActiveWalletViewController.swift
//  BitSense
//
//  Created by Peter on 15/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ActiveWalletViewController: UIViewController {
    
    private var onchainBalanceBtc = ""
    private var onchainBalanceFiat = ""
    private var sectionZeroLoaded = Bool()
    private var onchainTransactions: ListTransactionsResponse? = nil
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel: String!
    private var wallet: Wallet?
    private var fxRate: Double?
    private let barSpinner = UIActivityIndicatorView(style: .medium)
    private let spinner = ConnectingView.shared
    private var hex = ""
    private var confs = 0
    private var txToEdit = ""
    private var labelToEdit = ""
    private var psbt = ""
    private var rawTx = ""
    private var dateFormatter = DateFormatter()
    private var initialLoad = true
    var fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    
    @IBOutlet weak private var fiatBalanceLabel: UILabel!
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UserDefaults.standard.object(forKey: "hasPromptedToRescan") == nil {
            UserDefaults.standard.setValue(false, forKey: "hasPromptedToRescan")
        }
        
        walletTable.delegate = self
        walletTable.dataSource = self
        walletTable.layer.cornerRadius = 8
        walletTable.clipsToBounds = true
        NotificationCenter.default.addObserver(self, selector: #selector(broadcast(_:)), name: .broadcastTxn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signPsbt(_:)), name: .signPsbt, object: nil)
        if let savedRate = UserDefaults.standard.object(forKey: "fxRate") as? Double {
            fxRate = savedRate
        }
        setNotifications()
        sectionZeroLoaded = false
        addNavBarSpinner()
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double
        
        if let fxRate = fxRate {
            fxRateLabel.text = fxRate.exchangeRate
        }
        
        if initialLoad {
            initialLoad = false
            loadTable()
        }
    }
    
    @IBAction func getWalletDetail(_ sender: Any) {
        if let _ = wallet?.id {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                performSegue(withIdentifier: "segueToActiveWalletDetail", sender: self)
            }
        } else {
            showAlert(vc: self, title: "", message: "Fully Noded can only show wallet details for wallets created or imported with Fully Noded. ")
        }
    }
    
    
    private func hideData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onchainBalanceBtc = ""
            self.onchainBalanceFiat = ""
            self.sectionZeroLoaded = false
            self.onchainTransactions?.transactions.removeAll()
            self.walletTable.reloadData()
        }
    }
    
    
    
    
    

    
    @objc func importTx() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSignPsbt", sender: self)
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
    
    private func configureButton(_ button: UIView) {
        button.layer.cornerRadius = 5
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
    
    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let modalVC = TextModalViewController(data: data, viewTitle: title)
            let nav = UINavigationController(rootViewController: modalVC)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            present(nav, animated: true)
        }
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
        spinner.show(vc: self, description: "Creating your wallet, this can take a minute...")
        
        guard let accountMap = notification.userInfo as? [String:Any] else {
            self.spinner.dismiss()
            showAlert(vc: self, title: "", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.spinner.dismiss()
                showAlert(vc: self, title: "Error importing wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.spinner.dismiss()
            OnchainUtils.rescan { _ in }
            showAlert(vc: self, title: "Wallet created ✓", message: "It has been activated and is refreshing now. A rescan has been initiated, you may not see balances or transaction history until the rescan completes.")
            self.refreshWallet()
        }
    }
    
    @objc func addColdcard(_ notification: NSNotification) {
        spinner.show(vc: self, description: "creating your Coldcard wallet, this can take a minute...")
        
        guard let coldCard = notification.userInfo as? [String:Any] else {
            self.spinner.dismiss()
            showAlert(vc: self, title: "Ooops", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.coldcard(dict: coldCard) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.spinner.dismiss()
                showAlert(vc: self, title: "Error creating Coldcard wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.spinner.dismiss()
            showAlert(vc: self, title: "Coldcard Wallet imported ✓", message: "It has been activated and is refreshing now.")
            self.refreshWallet()
        }
    }
    
    private func loadTable() {
        addNavBarSpinner()
        sectionZeroLoaded = false
        walletLabel = ""
        onchainTransactions?.transactions.removeAll()
        
        activeWallet { [weak self] wallet in
            guard let self = self else { return }
            
            guard let wallet = wallet else {
                guard let walletName = UserDefaults.standard.string(forKey: "walletName") else {
                    self.finishedLoading()
                    showAlert(vc: self, title: "", message: "No wallet activated, create a wallet by tapping the plus sign in the top left or if you are an expert tap the Advanced button at the bottom of the screen > Bitcoin Core Wallets and tap one to activate it.")
                    return
                }
                
                walletLabel = walletName
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    walletTable.reloadData()
                }
                
                getWalletBalance()
                
                return
            }
                                    
            self.wallet = wallet
            walletLabel = wallet.label
            getWalletBalance()
            
            guard let backup = wallet.walletBackup else {
                backupWalletNow()
                return
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .secondsSince1970

            do {
                let loadedBackup = try decoder.decode(WalletBackup.self, from: backup)
                
                if isMoreThanOneMonthAgo(loadedBackup.lastUpdate) {
                    backupWalletNow()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func backupWalletNow() {
        var descriptors: [BackupItem] = []
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            do {
                guard let response = response else { return }
                
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                                
                for (i, descriptor) in listDescriptorResponse.descriptors.enumerated() {
                    var rangeValue: [Int]? = nil
                    
                    if let range = descriptor.range {
                        if range.count == 2 {
                            rangeValue = [range[0],range[1]]
                        } else if range.count == 1 {
                            rangeValue = [range[0]]
                        }
                    }
                    
                    var timestamp: Int? = nil
                    if let timestampt = descriptor.timestamp {
                        timestamp = timestampt
                    }
                    
                    let backupitem: BackupItem = .init(desc: descriptor.desc, active: descriptor.active, range: rangeValue, nextIndex: descriptor.nextIndex ?? 0, timestamp: timestamp, internal: descriptor.internal_, label: descriptor.label)
                    
                    descriptors.append(backupitem)
                                        
                    if i + 1 == listDescriptorResponse.descriptors.count {
                        let backup = WalletBackup(
                            lastUpdate: Date(),
                            descriptors: descriptors
                        )
                        updateNow(backup: backup)
                    }
                }
            } catch {
                print("listdescritpors response logic failed: \(error.localizedDescription)")
            }
        }
        return
    }
    
    @IBAction func loadBackupTapped(_ sender: Any) {
        exportBackup()
    }
    
    func isMoreThanOneMonthAgo(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let oneMonthAgo = calendar.date(byAdding: .month, value: -1, to: now) else {
            return false // Safety fallback
        }
        return date < oneMonthAgo
    }
    
    private func exportBackup() {
        guard let backup = wallet?.walletBackup else {
            // this shouldnt happen as we are creating it automatically.
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        do {
            let loadedBackup = try decoder.decode(WalletBackup.self, from: backup)
            promptForBackupExportFormat(backup: loadedBackup)
        } catch {
            print("Decoding failed: \(error)")
        }
    }
    
    private func promptForBackupExportFormat(backup: WalletBackup) {
        WalletExportFormatView.show(in: self) { [weak self] format in
            guard let self = self, let format = format else { return }
            
            do {
                switch format {
                case .qr:
                    let qrVC = QRViewController(
                        text: try backup.jsonData().hex,
                        headerText: "\(wallet!.label) Backup",
                        descriptionText: "Last updated: " + backup.lastUpdate.formattedDate,
                        headerIcon: UIImage(systemName: "qrcode"),
                        isBbqr: true,
                        isUR: false
                    )
                    
                    let nav = UINavigationController(rootViewController: qrVC)
                    nav.modalPresentationStyle = .fullScreen
                    
                    present(nav, animated: true)
                    
                case .file:
                    self.exportAsFile(backup: backup)
                case .text:
                    self.copyAsText(backup: backup)
                }
                
            } catch {
                print("error completing export format: \(error.localizedDescription)")
            }
        }
    }
    
    private func copyAsText(backup: WalletBackup) {
        do {
            // Encode WalletBackup to JSON data
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys] // Optional: consistent ordering
            encoder.dateEncodingStrategy = .secondsSince1970
            
            let jsonData = try encoder.encode(backup)
            let hexString = jsonData.hexString
            UIPasteboard.general.string = hexString
            
            // Show success with explanation
            let byteCount = jsonData.count
            let charCount = hexString.count
            
            SuccessView.show(
                in: self,
                title: "Backup Copied as Hex",
                subtitle: "Hex-encoded backup (\(byteCount) bytes → \(charCount) chars) is now in your clipboard.\n\nPaste it into a secure location."
            ) {
                print("User acknowledged hex backup copy")
            }
            
            // Haptic feedback
            let feedback = UIImpactFeedbackGenerator(style: .medium)
            feedback.impactOccurred()
            
        } catch {
            showAlert(title: "Encoding Failed", message: "Could not encode backup: \(error.localizedDescription)")
        }
    }
    
    private func exportAsFile(backup: WalletBackup) {
        print("exportAsFile: \(backup.descriptors.count)")
        
        do {
            // 2. Encode to pretty-printed JSON
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .secondsSince1970
            
            let jsonData = try encoder.encode(backup).hex.utf8
            let fileName = "\(backup.lastUpdate.formattedDate).txt"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            
            let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            
            activityVC.excludedActivityTypes = [
                .addToReadingList,
                .assignToContact,
                .markupAsPDF
            ]
            
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = self.view.bounds
                popover.permittedArrowDirections = []
            }
            
            // Not sure this fires off...
            activityVC.completionWithItemsHandler = { [weak self] activityType, completed, items, error in
                try? FileManager.default.removeItem(at: tempURL)
                
                if completed {
                    SuccessView.show(in: self!, title: "Backup Exported", subtitle: "Your wallet backup has been saved.") { }
                } else if let error = error {
                    showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
            
            present(activityVC, animated: true)
            
        } catch {
            showAlert(title: "Error", message: "Failed to create backup file: \(error.localizedDescription)")
        }
    }
    
    private func updateNow(backup: WalletBackup) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970  // optional, but matches our custom logic

        do {
            let jsonData = try encoder.encode(backup)
            CoreDataService.update(id: wallet!.id, keyToUpdate: "walletBackup", newValue: jsonData, entity: .wallets) { walletBackupUpdated in
                guard walletBackupUpdated else {
                    showAlert(title: "", message: "Updating wallet backup failed.")
                    return
                }
            }
            
        } catch {
            showAlert(title: "", message: "Updating failed: \(error.localizedDescription)")
        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            getFxRate()
            walletTable.reloadData()
        }
    }
    
    private func updateTransactionArray() {
        guard let _ = onchainTransactions, onchainTransactions!.transactions.count > 0 else {
            finishedLoading()
            return
        }
        
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                finishedLoading()
                return
            }
            
            for (i, transaction) in transactions.enumerated() {
                let localTransactionStruct = TransactionStruct(dictionary: transaction)
                
                for (t, tx) in self.onchainTransactions!.transactions.enumerated() {
                    if tx.txid == localTransactionStruct.txid {
                        if let originRate = localTransactionStruct.fxRate, originRate > 0 {
                            if localTransactionStruct.fiatCurrency == currency {
                                self.onchainTransactions!.transactions[t].originRate = originRate
                            }
                        }
                        self.onchainTransactions!.transactions[t].label = localTransactionStruct.label
                    }
                    if i + 1 == transactions.count && t + 1 == self.onchainTransactions!.transactions.count {
                        finishedLoading()
                    }
                }
            }
        }
    }
    
    
    @objc func goToDetail(_ sender: UIButton) {
        spinner.show(vc: self, description: "getting raw transaction...")
        
        guard let intString = sender.restorationIdentifier, let int = Int(intString) else { return }
        guard let onchainTransactions = onchainTransactions else { return }
        let txid = onchainTransactions.transactions[int].txid
        let param:Get_Tx = .init(["txid": txid, "verbose": true])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            self.spinner.dismiss()
            guard let dict = response as? NSDictionary, let hex = dict["hex"] as? String else {
                showAlert(vc: self, title: "There was an issue getting the transaction.", message: errorMessage ?? "unknown error")
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                confs = onchainTransactions.transactions[int].confirmations
                self.hex = hex
                self.performSegue(withIdentifier: "segueToTxDetail", sender: self)
            }
        }
    }
    
    
    private func onchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "OnBalancesCell", for: indexPath)
        let fiatBalanceLabel = cell.viewWithTag(3) as! UILabel
        
        if let offchainBalanceLabel = cell.viewWithTag(2) as? UILabel, let offchainBalanceView = cell.viewWithTag(66) {
            offchainBalanceLabel.removeFromSuperview()
            offchainBalanceView.removeFromSuperview()
        }
        
        let onchainBalanceLabel = cell.viewWithTag(1) as! UILabel
        
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0"
        }
                
        onchainBalanceLabel.text = onchainBalanceBtc.withCommas
        fiatBalanceLabel.text = onchainBalanceFiat
                
        return cell
    }
        
    private func transactionsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: "TransactionCell", for: indexPath)
        cell.selectionStyle = .none
        
        let categoryImage = cell.viewWithTag(1) as! UIImageView
        let amountLabel = cell.viewWithTag(2) as! UILabel
        let confirmationsLabel = cell.viewWithTag(3) as! UILabel
        let dateLabel = cell.viewWithTag(5) as! UILabel
        let currentFiatValueLabel = cell.viewWithTag(9) as! UILabel
        let transactionLabel = cell.viewWithTag(11) as! UILabel
        let seeDetailButton = cell.viewWithTag(14) as! UIButton
        
        amountLabel.alpha = 1
        confirmationsLabel.alpha = 1
        dateLabel.alpha = 1
        
        let index = indexPath.section - 1
                
        seeDetailButton.addTarget(self, action: #selector(goToDetail(_:)), for: .touchUpInside)
        seeDetailButton.restorationIdentifier = "\(index)"

        guard let onchainTransactions = onchainTransactions else { return blankCell() }
        
        guard onchainTransactions.transactions.count > 0 else { return blankCell() }
        
        let transaction = onchainTransactions.transactions[index]
        seeDetailButton.alpha = 1
        confirmationsLabel.text = "\(transaction.confirmations)" + " " + "confs"
        dateLabel.text = transaction.time.dateFromUnixTimestampInt
        
        var gainText = ""
        
        if let originRate = transaction.originRate {
            var btcAmount = 0.0
                        
            if transaction.amount < 0.0 {
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
        
        if let fxRate = fxRate {
            
            if transaction.amount < 0.0 {
                let positiveDouble = transaction.amount * -1.0
                currentFiatValueLabel.text = (fxRate * positiveDouble).fiatString + gainText
            } else {
                currentFiatValueLabel.text = (fxRate * transaction.amount).fiatString + gainText
            }
            
        } else {
            currentFiatValueLabel.text = "Exchange rate missing."
        }
        
        if let _ = transaction.label {
            transactionLabel.text = transaction.label
        }
        
        if transactionLabel.text == "" {
            transactionLabel.text = "No label."
        }
        
        if transaction.amount < 0.0 {
            categoryImage.image = UIImage(systemName: "arrow.up.right")
            categoryImage.tintColor = .systemRed
            
            amountLabel.textColor = .secondaryLabel
            
            var amountText = ""
            amountText = transaction.amount.btcBalanceWithSpaces
            amountText = amountText.replacingOccurrences(of: "-", with: "")
            amountLabel.text = amountText
            
        } else {
            categoryImage.image = UIImage(systemName: "arrow.down.left")
            categoryImage.tintColor = .systemGreen
            amountLabel.textColor = .label
            
            var amountText = ""
            amountText = transaction.amount.btcBalanceWithSpaces
            amountText = amountText.replacingOccurrences(of: "+", with: "")
            amountLabel.text = amountText
        }
        
        return cell
    }
    
    private func loadTransactions() {
        if let _ = onchainTransactions {
            onchainTransactions!.transactions.removeAll()
            onchainTransactions!.rawData.removeAll()
        }
        
        let param: List_Transactions = .init(["count": 100])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listtransactions(param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response as? NSArray else {
                removeSpinner()
                showAlert(vc: self, title: "", message: errorMessage ?? "Unable to cast listransactions rsponse as an NSArray.")
                return
            }
            
            guard let listTransactionsResponse = try? ListTransactionsResponse(from: response) else {
                removeSpinner()
                showAlert(vc: self, title: "", message: "Failed parsing listtransactions response.")
                return
            }
            
            onchainTransactions = listTransactionsResponse
            
            onchainTransactions?.transactions.removeAll { tx in
                return tx.confirmations < 0
            }

            updateTransactionArray()
        }
    }
        
    private func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        return cell
    }
    
    @objc func refreshWallet() {
        refreshAll()
    }
    
    private func getFxRate() {
        removeSpinner()
        let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        FiatConverter.sharedInstance.getFxRate(currency: fiatCurrency) { [weak self] rate in
            guard let self = self else { return }
            
            guard let rate = rate else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    walletTable.reloadData()
                }
                return
            }
            
            self.fxRate = rate
            UserDefaults.standard.setValue(rate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRateLabel.text = rate.exchangeRate
                self.onchainBalanceFiat = (self.onchainBalanceBtc.condenseWhitespace().doubleValue * rate).fiatString
                walletTable.reloadData()
            }
        }
    }
    
    private func dateFromStr(date: String) -> Date? {
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.date(from: date)
    }
    
    private func getWalletBalance() {
        if let _ = UserDefaults.standard.object(forKey: "walletName") as? String {
            OnchainUtils.getBalance { [weak self] (balance, message) in
                guard let self = self else { return }
                
                guard let balance = balance else {
                    removeSpinner()
                    showAlert(vc: self, title: "", message: message ?? "Unknown error getting balance.")
                    
                    return
                }
                
                DispatchQueue.main.async {
                    self.onchainBalanceBtc = balance.btcBalanceWithSpaces
                    
                    if let exchangeRate = self.fxRate {
                        let onchainBalanceFiat = balance * exchangeRate
                        self.onchainBalanceFiat = round(onchainBalanceFiat).fiatString
                    }
                    
                    self.sectionZeroLoaded = true
                    self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                    self.loadTransactions()
                }
            }
        }
    }
    
    func reloadWalletData() {
        onchainTransactions?.transactions.removeAll()
        sectionZeroLoaded = false
        getWalletBalance()
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
            
            self.spinner.dismiss()
            self.barSpinner.stopAnimating()
            self.barSpinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            self.refreshButton.tintColor = UIColor.systemBlue.withAlphaComponent(1)
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    private func refreshAll() {
        sectionZeroLoaded = false
        wallet = nil
        walletLabel = nil
        onchainBalanceFiat = ""
        onchainBalanceBtc = ""
        onchainTransactions?.transactions.removeAll()
        
        DispatchQueue.main.async { [ weak self] in
            guard let self = self else { return }
            
            walletTable.reloadData()
        }
        
        addNavBarSpinner()
        loadTable()
    }
    
    @objc func refreshData(_ sender: Any) {
        refreshAll()
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            walletTable.reloadData()
        }
    }
    
    @objc func sortTxs(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Sort by", message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Amount", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                guard let _ = onchainTransactions else { return }
                
                self.onchainTransactions!.transactions = self.onchainTransactions!.transactions.sorted { $0.amount > $1.amount }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Newest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                guard let _ = onchainTransactions else { return }
                
                self.onchainTransactions!.transactions = self.onchainTransactions!.transactions.sorted { $0.time > $1.time }
                
                self.reloadTable()
                
            }))
            
            alert.addAction(UIAlertAction(title: "Oldest first", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                guard let _ = onchainTransactions else { return }
                
                self.onchainTransactions!.transactions = self.onchainTransactions!.transactions.sorted { $0.time < $1.time }
                
                self.reloadTable()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "segueToInvoice":
            guard let vc = segue.destination as? InvoiceViewController else { fallthrough }
            
            vc.wallet = wallet
            
        case "spendFromWallet":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            vc.balance = onchainBalanceBtc
            vc.fxRate = fxRate
        
        case "segueToSignPsbt":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.unsignedPsbt = self.psbt.condenseWhitespace()
            vc.signedRawTx = self.rawTx.condenseWhitespace()
            vc.fxRate = self.fxRate
            
        case "segueToEditTx":
            guard let vc = segue.destination as? TransactionLabelMemoViewController else { fallthrough }
            
            vc.labelText = labelToEdit
            vc.txid = txToEdit
            vc.doneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                showAlert(vc: self, title: "", message: "Transaction updated ✓")
                self.spinner.show(vc: self, description: "refreshing transactions...")
                self.loadTransactions()
            }
            
        case "segueToTxDetail":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.alreadyBroadcast = true
            vc.signedRawTx = hex
            vc.confs = confs
            print("confs: \(confs)")
            
        case "segueToUtxos":
            guard let vc = segue.destination as? UTXOViewController else { fallthrough }
            
            vc.fxRate = fxRate
            vc.wallet = wallet
            
        case "segueToActiveWalletDetail":
            guard let vc = segue.destination as? WalletDetailViewController else { fallthrough }
            
            guard let idDetail = self.wallet?.id else {
                return
            }
                        
            vc.walletId = idDetail
            
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
                return onchainBalancesCell(indexPath)
            } else {
                return blankCell()
            }
        default:
            guard let onchainTransactions = onchainTransactions else { return blankCell() }
            
            guard onchainTransactions.transactions.count > 0  else { return blankCell() }
            
            return transactionsCell(indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 0, y: 0, width: 400, height: 50)
        
        let sortButton = UIButton()
        let sortImage = UIImage(systemName: "arrow.up.arrow.down.circle", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
        sortButton.setImage(sortImage, for: .normal)
        sortButton.frame = CGRect(x: header.frame.size.width - 50, y: 0, width: 50, height: 50)
        sortButton.center.y = textLabel.center.y
        sortButton.addTarget(self, action: #selector(sortTxs(_:)), for: .touchUpInside)
        
        let importButton = UIButton()
        let importImage = UIImage(systemName: "square.and.arrow.down", withConfiguration: UIImage.SymbolConfiguration(scale: .large))
        importButton.setImage(importImage, for: .normal)
        importButton.frame = CGRect(x: header.frame.size.width - 108, y: 0, width: 50, height: 50)
        importButton.center.y = textLabel.center.y
        importButton.addTarget(self, action: #selector(importTx), for: .touchUpInside)
        
        switch section {
        case 0:
            if walletLabel != "" && walletLabel != nil {
                textLabel.text = walletLabel
            } else {
                textLabel.text = "Wallet balance"
            }
            
        case 1:
            textLabel.text = "Transactions"
            header.addSubview(sortButton)
            header.addSubview(importButton)
            
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
                return 80
            } else {
                return 47
            }
        default:
            if sectionZeroLoaded {
                return 175
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
        guard let onchainTransactions = onchainTransactions, onchainTransactions.transactions.count > 0 else { return 2 }
            
        return 1 + onchainTransactions.transactions.count
    }
}
