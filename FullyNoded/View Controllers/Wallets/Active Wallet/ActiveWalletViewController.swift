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
    private var onchainBalance: Double?
    private var sectionZeroLoaded = Bool()
    private var onchainTransactions: ListTransactionsResponse? = nil
    private var refreshButton = UIBarButtonItem()
    private var dataRefresher = UIBarButtonItem()
    private var walletLabel: String!
    private var wallet: Wallet?
    private var fxRate: Double?
    private let barSpinner = UIActivityIndicatorView(style: .medium)
    private var initialLoad = true
    private var backupButton: UIBarButtonItem?
    
    @IBOutlet weak private var walletTable: UITableView!
    @IBOutlet weak private var fxRateLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if UserDefaults.standard.object(forKey: "hasPromptedToRescan") == nil {
            UserDefaults.standard.setValue(false, forKey: "hasPromptedToRescan")
        }
        
        walletTable.delegate = self
        walletTable.dataSource = self
        NotificationCenter.default.addObserver(self, selector: #selector(broadcast(_:)), name: .broadcastTxn, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(signPsbt(_:)), name: .signPsbt, object: nil)
        if let savedRate = UserDefaults.standard.object(forKey: "fxRate") as? Double {
            fxRate = savedRate
        }
        // The storyboard's export (backup) button. Kept next to the refresh/spinner item
        // instead of being replaced by it.
        backupButton = navigationItem.rightBarButtonItems?.first(where: { $0.action != nil })
        applyTheme()
        setNotifications()
        sectionZeroLoaded = false
        addNavBarSpinner()
    }
    
    // MARK: - Theme
    
    /// Cypherpunk teal / black look (see WalletTheme). Same structure as the green home /
    /// wallet detail screens and the purple signer screens.
    private func applyTheme() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = WalletTheme.bg
        WalletTheme.styleNavigation(navigationItem)
        navigationItem.leftBarButtonItems?.forEach { $0.tintColor = WalletTheme.accent }
        navigationItem.rightBarButtonItems?.forEach { $0.tintColor = WalletTheme.accent }
        barSpinner.color = WalletTheme.accent
        
        fxRateLabel.font = WalletTheme.mono(11, weight: .medium)
        fxRateLabel.textColor = WalletTheme.dim
        fxRateLabel.textAlignment = .center
        
        walletTable.backgroundColor = WalletTheme.bg
        walletTable.separatorStyle = .none
        walletTable.indicatorStyle = .white
        walletTable.layer.cornerRadius = 0
        walletTable.estimatedRowHeight = 120
        // The storyboard table is now "grouped" (not inset-grouped): inset-grouped tables
        // round and clip each section's corners, which hid the card borders' corners.
        // Grouped draws nothing of its own, so the square cards are fully visible.
        walletTable.separatorStyle = .none
        walletTable.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        walletTable.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        if #available(iOS 15.0, *) { walletTable.sectionHeaderTopPadding = 0 }
        walletTable.register(WalletBalanceCell.self, forCellReuseIdentifier: WalletBalanceCell.reuseId)
        walletTable.register(WalletTransactionCell.self, forCellReuseIdentifier: WalletTransactionCell.reuseId)
        
        styleActionButtons()
    }
    
    /// Restyles the storyboard's Invoice / UTXO's / Send buttons (the row under the table).
    private func styleActionButtons() {
        guard let column = walletTable.superview as? UIStackView,
              let row = column.arrangedSubviews.last as? UIStackView else { return }
        
        for case let button as UIButton in row.arrangedSubviews {
            let title = (button.configuration?.title ?? button.title(for: .normal) ?? "")
                .trimmingCharacters(in: .whitespaces)
            let key = title.lowercased()
            let isPrimary = key.contains("send")
            let symbol: String
            if key.contains("send") {
                symbol = "arrow.up.right"
            } else if key.contains("invoice") {
                symbol = "arrow.down.left"
            } else {
                symbol = "square.stack.3d.up"
            }
            button.configuration = WalletTheme.buttonConfiguration(title: title.uppercased(),
                                                                    systemImage: symbol,
                                                                    filled: isPrimary)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
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
    
    /// Opens the (programmatic) transaction verifier: a psbt, a signed raw transaction
    /// (already broadcast if `confirmations` is given), or empty to add one. Main thread.
    private func showTransactionVerifier(psbt: String = "", rawTx: String = "", confirmations: Int? = nil) {
        let vc = VerifyTransactionViewController()
        vc.unsignedPsbt = psbt.condenseWhitespace()
        vc.signedRawTx = rawTx.condenseWhitespace()
        vc.fxRate = fxRate
        if let confirmations = confirmations {
            vc.alreadyBroadcast = true
            vc.confs = confirmations
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc func importTx() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showTransactionVerifier()
        }
    }
    
    @objc func signPsbt(_ notification: NSNotification) {
        guard let psbtDict = notification.userInfo as? [String:Any], let psbtCheck = psbtDict["psbt"] as? String else {
            showAlert(vc: self, title: "Uh oh", message: "That does not appear to be a psbt...")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showTransactionVerifier(psbt: psbtCheck)
        }
    }
    
    @objc func broadcast(_ notification: NSNotification) {
        guard let txnDict = notification.userInfo as? [String:Any], let txn = txnDict["txn"] as? String else {
            showAlert(vc: self, title: "Uh oh", message: "That does not appear to be a signed raw transaction...")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.showTransactionVerifier(rawTx: txn)
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
        showActivity("Creating your wallet, this can take a minute...")
        
        guard let accountMap = notification.userInfo as? [String:Any] else {
            self.hideActivity()
            showAlert(vc: self, title: "", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.hideActivity()
                showAlert(vc: self, title: "Error importing wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.hideActivity()
            OnchainUtils.rescan { _ in }
            SuccessView.show(in: self, title: "Wallet created", subtitle: "It has been activated and is refreshing now. A rescan has been started, so balances and history may take a while to appear.")
            self.refreshWallet()
        }
    }
    
    @objc func addColdcard(_ notification: NSNotification) {
        showActivity("creating your Coldcard wallet, this can take a minute...")
        
        guard let coldCard = notification.userInfo as? [String:Any] else {
            self.hideActivity()
            showAlert(vc: self, title: "Ooops", message: "That file does not seem to be a compatible wallet import, please raise an issue on the github so we can add support for it.")
            return
        }
        
        ImportWallet.coldcard(dict: coldCard) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            guard success else {
                self.hideActivity()
                showAlert(vc: self, title: "Error creating Coldcard wallet", message: errorDescription ?? "unknown")
                return
            }
            
            self.hideActivity()
            SuccessView.show(in: self, title: "Coldcard wallet imported", subtitle: "It has been activated and is refreshing now.")
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
                
                reloadTable()
                
                getWalletBalance()
                
                return
            }
                                    
            self.wallet = wallet
            walletLabel = wallet.label
            getWalletBalance()
            
            // Refresh the stored backup when missing or more than five minutes old.
            if let backup = Self.decodeBackup(wallet.walletBackup), !isMoreThanFiveMinutesAgo(backup.lastUpdate) {
                return
            }
            backupWalletNow(walletId: wallet.id, walletName: wallet.name)
        }
    }
    
    private static func decodeBackup(_ data: Data?) -> WalletBackup? {
        guard let data = data else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(WalletBackup.self, from: data)
    }

    /// Snapshots the node wallet's descriptors (public, from listdescriptors) as this
    /// wallet's backup. Only saved when the node answered for THIS wallet and returned
    /// descriptors, so a hiccup can never replace a good backup with an empty or wrong one.
    private func backupWalletNow(walletId: UUID, walletName: String) {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard let response = response,
                  let json = try? JSONSerialization.data(withJSONObject: response),
                  let listed = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: json) else {
                print("wallet backup skipped: \(errorDesc ?? "unreadable listdescriptors response")")
                return
            }
            guard listed.walletName == walletName, !listed.descriptors.isEmpty else {
                print("wallet backup skipped: response was for \(listed.walletName) with \(listed.descriptors.count) descriptors")
                return
            }
            let backup = WalletBackup(lastUpdate: Date(), descriptors: listed.descriptors.map(BackupItem.init(listed:)))
            self.updateNow(backup: backup, walletId: walletId)
        }
    }
    
    @IBAction func loadBackupTapped(_ sender: Any) {
        exportBackup()
    }
    
    func isMoreThanFiveMinutesAgo(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        guard let fiveMinutesAgo = calendar.date(byAdding: .minute, value: -5, to: now) else {
            return false // Safety fallback
        }
        return date < fiveMinutesAgo
    }
    
    private func exportBackup() {
        guard let backup = Self.decodeBackup(wallet?.walletBackup) else {
            showAlert(vc: self, title: "No backup yet", message: "The wallet backup is created automatically when the wallet loads. Refresh and try again.")
            return
        }
        promptForBackupExportFormat(backup: backup)
    }
    
    private func promptForBackupExportFormat(backup: WalletBackup) {
        WalletExportFormatView.show(in: self) { [weak self] format in
            guard let self = self, let format = format else { return }
            
            do {
                switch format {
                case .qr:
                    let qrVC = QRViewController(
                        text: try backup.hexEncoded(),
                        headerText: "\(self.wallet?.label ?? "Wallet") Backup",
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
            let hexString = try backup.hexEncoded()
            UIPasteboard.general.string = hexString
            
            // Show success with explanation
            let byteCount = hexString.count / 2
            let charCount = hexString.count
            
            SuccessView.show(
                in: self,
                title: "Backup copied",
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
        do {
            // Same hex as the QR and text exports (what the importer reads).
            let jsonData = try backup.hexEncoded().utf8
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
                    guard let self = self else { return }
                    SuccessView.show(in: self, title: "Backup exported", subtitle: "Your wallet backup has been saved.") { }
                } else if let error = error {
                    showAlert(title: "Export Failed", message: error.localizedDescription)
                }
            }
            
            present(activityVC, animated: true)
            
        } catch {
            showAlert(title: "Error", message: "Failed to create backup file: \(error.localizedDescription)")
        }
    }
    
    private func updateNow(backup: WalletBackup, walletId: UUID) {
        do {
            let jsonData = try backup.jsonData()
            CoreDataService.update(id: walletId, keyToUpdate: "walletBackup", newValue: jsonData, entity: .wallets) { walletBackupUpdated in
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
            
            // Saved labels and the fx rate at send/receive time, by txid.
            var saved: [String: TransactionStruct] = [:]
            for dict in transactions {
                let tx = TransactionStruct(dictionary: dict)
                saved[tx.txid] = tx   // a later record for the same txid wins, as before
            }
            
            for t in self.onchainTransactions!.transactions.indices {
                guard let local = saved[self.onchainTransactions!.transactions[t].txid] else { continue }
                if let originRate = local.fxRate, originRate > 0, local.fiatCurrency == currency {
                    self.onchainTransactions!.transactions[t].originRate = originRate
                }
                self.onchainTransactions!.transactions[t].label = local.label
            }
            finishedLoading()
        }
    }
    
    
    /// Opens the transaction at `index` (index into `onchainTransactions.transactions`).
    private func showTransactionDetail(at index: Int) {
        guard let onchainTransactions = onchainTransactions,
              onchainTransactions.transactions.indices.contains(index) else { return }
        
        showActivity("getting raw transaction...")
        
        let transaction = onchainTransactions.transactions[index]
        let param:Get_Tx = .init(["txid": transaction.txid, "verbose": true])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            self.hideActivity()
            guard let dict = response as? NSDictionary, let hex = dict["hex"] as? String else {
                showAlert(vc: self, title: "There was an issue getting the transaction.", message: errorMessage ?? "unknown error")
                return
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.showTransactionVerifier(rawTx: hex, confirmations: transaction.confirmations)
            }
        }
    }
    
    private func onchainBalancesCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = walletTable.dequeueReusableCell(withIdentifier: WalletBalanceCell.reuseId, for: indexPath) as! WalletBalanceCell
        
        if onchainBalanceBtc == "" || onchainBalanceBtc == "0.0" {
            onchainBalanceBtc = "0"
        }
        
        cell.configure(btc: onchainBalanceBtc.withCommas, fiat: onchainBalanceFiat)
        return cell
    }
        
    private func transactionsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let index = indexPath.section - 1
        
        guard let onchainTransactions = onchainTransactions,
              onchainTransactions.transactions.indices.contains(index) else { return blankCell() }
        
        let cell = walletTable.dequeueReusableCell(withIdentifier: WalletTransactionCell.reuseId, for: indexPath) as! WalletTransactionCell
        let transaction = onchainTransactions.transactions[index]
        let isOutgoing = transaction.amount < 0.0
        let btcAmount = Swift.abs(transaction.amount)
        
        var amountText = btcAmount.btcBalanceWithSpaces
        amountText = amountText.replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "+", with: "")
        
        // Gain / loss since the transaction, when the fx rate at the time was recorded.
        var gainText = ""
        if let originRate = transaction.originRate, let exchangeRate = fxRate {
            let originValueFiat = btcAmount * originRate
            if originValueFiat > 0 {
                let gain = round((btcAmount * exchangeRate) - originValueFiat)
                let percent = Int((Swift.abs(gain) / originValueFiat) * 100.0)
                if Int(gain) > 0 {
                    gainText = " · +\(gain.fiatString) / \(percent)%"
                } else if Int(gain) < 0 {
                    gainText = " · -\(Swift.abs(gain).fiatString) / \(percent)%"
                }
            }
        }
        
        let fiatText: String
        if let fxRate = fxRate {
            fiatText = (fxRate * btcAmount).fiatString + gainText
        } else {
            fiatText = "exchange rate missing"
        }
        
        var label = transaction.label ?? ""
        if label.isEmpty { label = "no label" }
        
        cell.configure(isOutgoing: isOutgoing,
                       amount: amountText,
                       confirmations: transaction.confirmations,
                       label: label,
                       fiat: fiatText,
                       date: transaction.time.dateFromUnixTimestampInt,
                       txid: transaction.txid)
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
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        return cell
    }
    
    /// Shown in the transactions section once the wallet has loaded but has no history.
    private func emptyTransactionsCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.automaticallyUpdatesBackgroundConfiguration = false
        cell.backgroundConfiguration = WalletTheme.cardConfiguration(horizontalInset: 0)
        WalletTheme.squareCorners(cell)
        
        var content = cell.defaultContentConfiguration()
        content.text = "> no transactions yet_"
        content.textProperties.font = WalletTheme.mono(13)
        content.textProperties.color = WalletTheme.dim
        content.textProperties.alignment = .center
        content.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 18, leading: 12, bottom: 18, trailing: 12)
        cell.contentConfiguration = content
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
                reloadTable()
                return
            }
            
            self.fxRate = rate
            UserDefaults.standard.setValue(rate, forKey: "fxRate")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRateLabel.text = rate.exchangeRate
                self.updateFiatBalance()
                walletTable.reloadData()
            }
        }
    }
    
    private func updateFiatBalance() {
        guard let balance = onchainBalance, let rate = fxRate else { return }
        onchainBalanceFiat = round(balance * rate).fiatString
    }
    
    private func getWalletBalance() {
        guard UserDefaults.standard.object(forKey: "walletName") is String else {
            finishedLoading()   // nothing to fetch: stop the spinner
            return
        }
        do {
            OnchainUtils.getBalance { [weak self] (balance, message) in
                guard let self = self else { return }
                
                guard let balance = balance else {
                    removeSpinner()
                    showAlert(vc: self, title: "", message: message ?? "Unknown error getting balance.")
                    
                    return
                }
                
                DispatchQueue.main.async {
                    self.onchainBalance = balance
                    self.onchainBalanceBtc = balance.btcBalanceWithSpaces
                    self.updateFiatBalance()
                    
                    self.sectionZeroLoaded = true
                    self.walletTable.reloadSections(IndexSet.init(arrayLiteral: 0), with: .fade)
                    self.loadTransactions()
                }
            }
        }
    }
    
    private func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.barSpinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.barSpinner.color = WalletTheme.accent
            self.dataRefresher = UIBarButtonItem(customView: self.barSpinner)
            self.setRightBarItem(self.dataRefresher)
            self.barSpinner.startAnimating()
            self.barSpinner.alpha = 1
        }
    }
    
    private func removeSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.hideActivity()
            self.barSpinner.stopAnimating()
            self.barSpinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshWallet))
            self.refreshButton.tintColor = WalletTheme.accent
            self.setRightBarItem(self.refreshButton)
        }
    }
    
    /// Puts the spinner / refresh item on the right, keeping the backup export button.
    private func setRightBarItem(_ item: UIBarButtonItem) {
        var items = [item]
        if let backupButton = backupButton {
            backupButton.tintColor = WalletTheme.accent
            items.append(backupButton)
        }
        navigationItem.setRightBarButtonItems(items, animated: true)
    }
    
    private func refreshAll() {
        sectionZeroLoaded = false
        wallet = nil
        walletLabel = nil
        onchainBalanceFiat = ""
        onchainBalanceBtc = ""
        onchainBalance = nil
        onchainTransactions?.transactions.removeAll()
        
        reloadTable()
        
        addNavBarSpinner()
        loadTable()
    }
    
    private func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            self?.walletTable.reloadData()
        }
    }
    
    @objc func sortTxs(_ sender: UIButton) {
        let orders: [(String, (TransactionInfo, TransactionInfo) -> Bool)] = [
            ("Amount", { $0.amount > $1.amount }),
            ("Newest first", { $0.time > $1.time }),
            ("Oldest first", { $0.time < $1.time })
        ]
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Sort by", message: "", preferredStyle: .alert)
            for (title, order) in orders {
                alert.addAction(UIAlertAction(title: title, style: .default) { [weak self] _ in
                    guard let self = self, self.onchainTransactions != nil else { return }
                    self.onchainTransactions!.transactions.sort(by: order)
                    self.reloadTable()
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
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
            
        case "createFullyNodedWallet":
            guard let vc = segue.destination as? CreateFullyNodedWalletViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    self.refreshWallet()
                    
                    SuccessView.show(in: self, title: "Wallet imported", subtitle: "It's now the active wallet.")
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
            
            guard onchainTransactions.transactions.count > 0 else {
                return sectionZeroLoaded ? emptyTransactionsCell() : blankCell()
            }
            
            return transactionsCell(indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section > 0 else { return }
        showTransactionDetail(at: indexPath.section - 1)
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section < 2 else { return nil }
        
        let header = UIView()
        header.backgroundColor = .clear
        
        let textLabel = UILabel()
        textLabel.font = WalletTheme.mono(14, weight: .semibold)
        textLabel.textColor = WalletTheme.accent
        textLabel.lineBreakMode = .byTruncatingMiddle
        textLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        let row = UIStackView(arrangedSubviews: [textLabel])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 4
        row.translatesAutoresizingMaskIntoConstraints = false
        
        if section == 0 {
            if let walletLabel = walletLabel, walletLabel != "" {
                textLabel.text = "> " + walletLabel
            } else {
                textLabel.text = "> wallet balance"
            }
        } else {
            textLabel.text = "> transactions"
            row.addArrangedSubview(WalletTheme.iconButton("square.and.arrow.down", target: self, action: #selector(importTx)))
            row.addArrangedSubview(WalletTheme.iconButton("arrow.up.arrow.down", target: self, action: #selector(sortTxs(_:))))
        }
        
        header.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 4),
            row.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -4),
            row.topAnchor.constraint(equalTo: header.topAnchor),
            row.bottomAnchor.constraint(equalTo: header.bottomAnchor)
        ])
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if section == 0 || section == 1 {
            return 44
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return UIView()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return sectionZeroLoaded ? UITableView.automaticDimension : 47
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

// MARK: - Cells

/// Balance card: caption, large BTC balance, fiat value.
private final class WalletBalanceCell: UITableViewCell {
    static let reuseId = "WalletBalanceCell"

    private let caption = UILabel()
    private let btcLabel = UILabel()
    private let fiatLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        automaticallyUpdatesBackgroundConfiguration = false
        backgroundConfiguration = WalletTheme.cardConfiguration(horizontalInset: 0)
        WalletTheme.squareCorners(self)

        caption.text = "ONCHAIN BALANCE"
        caption.font = WalletTheme.mono(11, weight: .medium)
        caption.textColor = WalletTheme.dim

        btcLabel.font = WalletTheme.mono(30, weight: .semibold)
        btcLabel.textColor = WalletTheme.accent
        btcLabel.adjustsFontSizeToFitWidth = true
        btcLabel.minimumScaleFactor = 0.5
        btcLabel.textAlignment = .center

        fiatLabel.font = WalletTheme.mono(14)
        fiatLabel.textColor = WalletTheme.text
        fiatLabel.textAlignment = .center

        caption.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [caption, btcLabel, fiatLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = WalletTheme.radius   // override the inset-grouped section rounding
    }

    func configure(btc: String, fiat: String) {
        btcLabel.text = "\(btc) BTC"
        fiatLabel.text = fiat.isEmpty ? " " : "≈ \(fiat)"
    }
}

/// Transaction card: direction glyph, amount, confirmations badge, label, fiat value,
/// date and a shortened txid. The whole card is tappable (see didSelectRowAt).
private final class WalletTransactionCell: UITableViewCell {
    static let reuseId = "WalletTransactionCell"

    private let glyphBox = UIView()
    private let glyph = UIImageView()
    private let amountLabel = UILabel()
    private let confsLabel = PaddedLabel()
    private let txLabel = UILabel()
    private let fiatLabel = UILabel()
    private let dateLabel = UILabel()
    private let txidLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        automaticallyUpdatesBackgroundConfiguration = false
        backgroundConfiguration = WalletTheme.cardConfiguration(horizontalInset: 0)
        WalletTheme.squareCorners(self)

        glyphBox.translatesAutoresizingMaskIntoConstraints = false
        glyphBox.layer.cornerRadius = WalletTheme.radius
        glyphBox.layer.borderWidth = 1
        glyph.translatesAutoresizingMaskIntoConstraints = false
        glyph.contentMode = .scaleAspectFit
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        glyphBox.addSubview(glyph)
        NSLayoutConstraint.activate([
            glyphBox.widthAnchor.constraint(equalToConstant: 30),
            glyphBox.heightAnchor.constraint(equalToConstant: 30),
            glyph.centerXAnchor.constraint(equalTo: glyphBox.centerXAnchor),
            glyph.centerYAnchor.constraint(equalTo: glyphBox.centerYAnchor)
        ])

        amountLabel.font = WalletTheme.mono(17, weight: .semibold)
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.6
        amountLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        confsLabel.font = WalletTheme.mono(10, weight: .semibold)
        confsLabel.layer.borderWidth = 1
        confsLabel.layer.cornerRadius = WalletTheme.radius
        confsLabel.setContentHuggingPriority(.required, for: .horizontal)
        confsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let topRow = UIStackView(arrangedSubviews: [glyphBox, amountLabel, confsLabel])
        topRow.axis = .horizontal
        topRow.alignment = .center
        topRow.spacing = 10

        txLabel.font = WalletTheme.mono(13)
        txLabel.textColor = WalletTheme.text
        txLabel.numberOfLines = 2

        fiatLabel.font = WalletTheme.mono(12)
        fiatLabel.textColor = WalletTheme.dim
        fiatLabel.numberOfLines = 0

        dateLabel.font = WalletTheme.mono(11)
        dateLabel.textColor = WalletTheme.dim

        txidLabel.font = WalletTheme.mono(11)
        txidLabel.textColor = WalletTheme.dim.withAlphaComponent(0.8)
        txidLabel.textAlignment = .right
        txidLabel.lineBreakMode = .byTruncatingMiddle

        chevron.tintColor = WalletTheme.accent
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let bottomRow = UIStackView(arrangedSubviews: [dateLabel, txidLabel, chevron])
        bottomRow.axis = .horizontal
        bottomRow.alignment = .center
        bottomRow.spacing = 8

        let divider = UIView()
        divider.backgroundColor = WalletTheme.line.withAlphaComponent(0.25)
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let stack = UIStackView(arrangedSubviews: [topRow, txLabel, fiatLabel, divider, bottomRow])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(12, after: topRow)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = WalletTheme.radius   // override the inset-grouped section rounding
    }

    /// Teal highlight while the card is pressed.
    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        backgroundConfiguration = WalletTheme.cardConfiguration(highlighted: state.isHighlighted || state.isSelected, horizontalInset: 0)
    }

    func configure(isOutgoing: Bool, amount: String, confirmations: Int, label: String,
                   fiat: String, date: String, txid: String) {
        let color = isOutgoing ? WalletTheme.outgoing : WalletTheme.accent
        glyph.image = UIImage(systemName: isOutgoing ? "arrow.up.right" : "arrow.down.left")
        glyph.tintColor = color
        glyphBox.layer.borderColor = color.withAlphaComponent(0.6).cgColor
        glyphBox.backgroundColor = color.withAlphaComponent(0.08)

        amountLabel.text = (isOutgoing ? "-" : "+") + amount + " BTC"
        amountLabel.textColor = isOutgoing ? WalletTheme.text : WalletTheme.accent

        let confColor: UIColor
        if confirmations <= 0 {
            confsLabel.text = "UNCONFIRMED"
            confColor = WalletTheme.pending
        } else if confirmations < 6 {
            confsLabel.text = "\(confirmations)/6 CONFS"
            confColor = WalletTheme.pending
        } else {
            confsLabel.text = "\(confirmations) CONFS"
            confColor = WalletTheme.dim
        }
        confsLabel.textColor = confColor
        confsLabel.layer.borderColor = confColor.withAlphaComponent(0.6).cgColor

        txLabel.text = label
        txLabel.textColor = label == "no label" ? WalletTheme.dim : WalletTheme.text
        fiatLabel.text = fiat
        dateLabel.text = date
        txidLabel.text = txid.count > 16 ? "\(txid.prefix(8))…\(txid.suffix(8))" : txid
    }
}
