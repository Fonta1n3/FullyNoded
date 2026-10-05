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
    private var hex = ""
    private var confs = 0
    private var txToEdit = ""
    private var labelToEdit = ""
    private var psbt = ""
    private var rawTx = ""
    private var dateFormatter = DateFormatter()
    private var initialLoad = true
    private var backupButton: UIBarButtonItem?
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
    
    /// Opens the (programmatic) transaction verifier for `psbt` / `rawTx`, or empty to add one.
    private func showTransactionVerifier() {
        let vc = VerifyTransactionViewController()
        vc.unsignedPsbt = psbt.condenseWhitespace()
        vc.signedRawTx = rawTx.condenseWhitespace()
        vc.fxRate = fxRate
        navigationController?.pushViewController(vc, animated: true)
    }

    /// Opens the verifier for a transaction that's already been broadcast.
    private func showBroadcastTransaction() {
        let vc = VerifyTransactionViewController()
        vc.alreadyBroadcast = true
        vc.signedRawTx = hex
        vc.confs = confs
        vc.fxRate = fxRate
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
            
            self.psbt = psbtCheck
            self.showTransactionVerifier()
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
            self.showTransactionVerifier()
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
            showAlert(vc: self, title: "Wallet created ✓", message: "It has been activated and is refreshing now. A rescan has been initiated, you may not see balances or transaction history until the rescan completes.")
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
                
                if isMoreThanFiveMinutesAgo(loadedBackup.lastUpdate) {
                    backupWalletNow()
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    private func backupWalletNow() {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            do {
                guard let response = response else {
                    print("listdescriptors returned nil response")
                    return
                }
                
                let jsonData = try JSONSerialization.data(withJSONObject: response, options: [])
                let listDescriptorResponse = try JSONDecoder().decode(ListDescriptorsResponse.self, from: jsonData)
                
                let descriptors: [BackupItem] = listDescriptorResponse.descriptors.map { descriptor in
                    var rangeValue: [Int]? = nil
                    if let range = descriptor.range {
                        switch range.count {
                        case 2: rangeValue = [range[0], range[1]]
                        case 1: rangeValue = [range[0]]
                        default: break
                        }
                    }
                    
                    return BackupItem(
                        desc: descriptor.desc,
                        active: descriptor.active,
                        range: rangeValue,
                        nextIndex: descriptor.nextIndex ?? 0,
                        timestamp: descriptor.timestamp,
                        internal: descriptor.internal_,
                        label: descriptor.label
                    )
                }
                
                // TODO: Compare to existing before actually updating.
                let backup = WalletBackup(
                    lastUpdate: Date(),
                    descriptors: descriptors
                )
                updateNow(backup: backup)
                
            } catch {
                print("listdescriptors response logic failed: \(error.localizedDescription)")
            }
        }
    }
    
    /// Helper to compare two descriptor arrays (order-independent)
    private func areDescriptorsEqual(_ lhs: [BackupItem], _ rhs: [BackupItem]) -> Bool {
        guard lhs.count == rhs.count else { return false }
        
        // Compare by the unique `desc` string (most important field)
        let lhsSet = Set(lhs.map { $0.desc })
        let rhsSet = Set(rhs.map { $0.desc })
        
        return lhsSet == rhsSet
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
            //SuccessView(title: "Backup updated", subtitle: <#T##String#>)
            
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
                confs = transaction.confirmations
                self.hex = hex
                self.showBroadcastTransaction()
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
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
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
        
        case "segueToEditTx":
            guard let vc = segue.destination as? TransactionLabelMemoViewController else { fallthrough }
            
            vc.labelText = labelToEdit
            vc.txid = txToEdit
            vc.doneBlock = { [weak self] _ in
                guard let self = self else { return }
                
                showAlert(vc: self, title: "", message: "Transaction updated ✓")
                self.showActivity("refreshing transactions...")
                self.loadTransactions()
            }
            
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

// MARK: - Theme

/// Cypherpunk teal / black theme for the wallet screen and every screen that branches off
/// it (send, invoice, UTXOs, wallet creation, wallets list, transaction verifier...).
/// Same structure as the green `Cypher` palette (home, wallet detail) and the purple
/// `SignerTheme` (signers).
///
/// Most screens are storyboard-built, so instead of rewriting each one the theme walks a
/// view hierarchy and restyles standard UIKit controls in place:
///  - `WalletTheme.apply(to: self, tint:)` at the end of `viewDidLoad`
///  - `WalletTheme.styleCell(_:tint:)` from `tableView(_:willDisplay:forRowAt:)`
///  - `WalletTheme.styleHeader(_:tint:)` from `tableView(_:willDisplayHeaderView:forSection:)`
///  - `WalletTheme.stylePrimary(_:tint:)` for a screen's main action button
enum WalletTheme {

    /// Per-screen accent, all within the teal family so the wallet flow reads as one place.
    enum Tint {
        case wallet, send, receive, utxo, create, transaction, settings, home, signer

        var accent: UIColor {
            switch self {
            case .wallet, .transaction:
                return UIColor(red: 0.18, green: 0.96, blue: 0.88, alpha: 1)   // teal
            case .send:
                return UIColor(red: 0.22, green: 0.86, blue: 1.0, alpha: 1)    // cyan-teal
            case .receive:
                return UIColor(red: 0.32, green: 1.0, blue: 0.74, alpha: 1)    // mint-teal
            case .utxo:
                return UIColor(red: 0.14, green: 0.88, blue: 0.80, alpha: 1)   // deep teal
            case .create:
                return UIColor(red: 0.30, green: 0.93, blue: 0.96, alpha: 1)   // aqua
            case .settings:
                return UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1)    // terminal amber
            case .home:
                return UIColor(red: 0.25, green: 1.0, blue: 0.48, alpha: 1)    // terminal green
            case .signer:
                return SignerTheme.accent                                      // deep purple
            }
        }

        /// Body text / secondary text for this palette (the signer screens have their own
        /// purple-gray ones).
        var text: UIColor { self == .signer ? SignerTheme.text : WalletTheme.text }
        var dim: UIColor { self == .signer ? SignerTheme.dim : WalletTheme.dim }

        var line: UIColor { accent.withAlphaComponent(0.45) }
    }

    /// Corner radius for cards, cells, fields and buttons: square, so 1pt borders stay
    /// crisp all the way into the corners.
    static let radius: CGFloat = 0

    // MARK: Square corners

    /// Inset-grouped tables round the corners of the first / last cell in every section by
    /// setting a corner radius on the cell's layer (which also clips the cell). That clipped
    /// our 1pt card borders at the corners. This keeps a view's layer square: it resets the
    /// radius immediately whenever UIKit changes it. Safe to call repeatedly (one guard per view).
    static func squareCorners(_ view: UIView) {
        view.layer.cornerRadius = radius
        guard objc_getAssociatedObject(view, squareGuardKey) == nil else { return }
        objc_setAssociatedObject(view, squareGuardKey, SquareCornerGuard(layer: view.layer), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private static let squareGuardKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// Watches a layer's corner radius and puts it back to `WalletTheme.radius`.
    private final class SquareCornerGuard: NSObject {
        private var observation: NSKeyValueObservation?

        init(layer: CALayer) {
            super.init()
            observation = layer.observe(\.cornerRadius, options: [.new]) { layer, _ in
                if layer.cornerRadius != WalletTheme.radius {
                    layer.cornerRadius = WalletTheme.radius
                }
            }
        }

        deinit { observation?.invalidate() }
    }

    static let bg = UIColor(red: 0.02, green: 0.04, blue: 0.045, alpha: 1)      // near-black, teal tint
    static let card = UIColor(red: 0.05, green: 0.09, blue: 0.095, alpha: 1)    // dark teal-gray
    static let line = Tint.wallet.line                                          // teal border
    static let accent = Tint.wallet.accent                                      // teal neon
    static let dim = UIColor(red: 0.42, green: 0.62, blue: 0.62, alpha: 1)      // muted teal-gray
    static let text = UIColor(red: 0.80, green: 0.95, blue: 0.94, alpha: 1)     // pale aqua
    static let outgoing = UIColor(red: 1.0, green: 0.36, blue: 0.48, alpha: 1)  // hot pink-red
    static let pending = UIColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 1)   // amber
    static let danger = UIColor(red: 1.0, green: 0.28, blue: 0.32, alpha: 1)

    /// Marks a button as the screen's primary (solid) action, so re-styling keeps it filled.
    private static let primaryMarker = "WalletTheme.primary"
    /// Tag on the padding view we add to text fields (so it's only added once).
    private static let fieldPaddingTag = 0x57A1

    static func mono(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    /// Monospaced version of `font`, same size and (roughly) the same weight.
    static func mono(from font: UIFont?, fallbackSize: CGFloat = 14) -> UIFont {
        guard let font = font else { return mono(fallbackSize) }
        var weight = UIFont.Weight.regular
        if let traits = font.fontDescriptor.object(forKey: .traits) as? [UIFontDescriptor.TraitKey: Any],
           let raw = traits[.weight] as? CGFloat {
            weight = UIFont.Weight(rawValue: raw)
        }
        if font.fontDescriptor.symbolicTraits.contains(.traitBold), weight.rawValue < UIFont.Weight.semibold.rawValue {
            weight = .semibold
        }
        return mono(font.pointSize, weight: weight)
    }

    // MARK: Colour mapping

    /// Maps any colour (system or custom) into the palette, keeping its meaning:
    /// grays → text / dim, reds → danger, oranges / yellows → amber, everything else → accent.
    static func mapped(_ color: UIColor?, tint: Tint = .wallet) -> UIColor {
        guard let color = color else { return text }
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard resolved.getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return text }
        if a < 0.05 { return color }
        // The screen's own accent stays the accent (amber would otherwise read as "pending").
        var accentHue: CGFloat = 0, accentSaturation: CGFloat = 0
        if s >= 0.35,
           tint.accent.getHue(&accentHue, saturation: &accentSaturation, brightness: nil, alpha: nil),
           abs(h - accentHue) < 0.02 {
            return tint.accent
        }
        if s < 0.35 {
            return (b * a) > 0.72 ? text : dim
        }
        if h < 0.04 || h > 0.9 { return danger }
        if h < 0.18 { return pending }
        return tint.accent
    }

    // MARK: Screens

    /// Restyles a whole screen: background, navigation bar, and every control in it.
    static func apply(to vc: UIViewController, tint: Tint = .wallet) {
        vc.overrideUserInterfaceStyle = .dark
        vc.view.backgroundColor = bg
        vc.view.tintColor = tint.accent
        styleNavigation(vc.navigationItem, tint: tint)
        let items = (vc.navigationItem.leftBarButtonItems ?? []) + (vc.navigationItem.rightBarButtonItems ?? [])
        for item in items {
            item.tintColor = mapped(item.tintColor ?? tint.accent, tint: tint)
            if let customView = item.customView { style(customView, tint: tint) }
        }
        // A UITableViewController's root view IS its table (no container to inset it in).
        if let table = vc.view as? UITableView {
            styleRootTable(table)
        }
        for sub in vc.view.subviews {
            style(sub, tint: tint)
        }
    }

    /// The table that is a UITableViewController's root view: same look as other tables,
    /// but it can't be inset by constraints, so its cards are inset 16pt instead
    /// (`styleCell` reads the marker).
    static func styleRootTable(_ table: UITableView) {
        objc_setAssociatedObject(table, rootTableKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        styleTable(table)
    }

    private static let rootTableKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    // MARK: Tab bar

    /// Cypherpunk tab bar: opaque near-black bar, a faint top hairline, dim icons, and each
    /// tab's selected icon in that section's own accent (home green, wallet teal, signers
    /// purple, settings amber). The colours are baked into the items' images, so they're
    /// right however a tab gets selected (including `selectedIndex` set in code). Safe to
    /// call more than once.
    static func styleTabBar(_ tabBarController: UITabBarController) {
        let tabBar = tabBarController.tabBar
        tabBar.overrideUserInterfaceStyle = .dark

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = bg
        appearance.shadowColor = UIColor(white: 1, alpha: 0.10)
        for layout in [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance] {
            layout.normal.iconColor = dim
            layout.normal.titleTextAttributes = [.foregroundColor: dim, .font: mono(10)]
            layout.selected.iconColor = Tint.home.accent
            layout.selected.titleTextAttributes = [.foregroundColor: Tint.home.accent, .font: mono(10, weight: .semibold)]
        }
        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = Tint.home.accent
        tabBar.unselectedItemTintColor = dim

        let symbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
        for controller in tabBarController.viewControllers ?? [] {
            guard let item = controller.tabBarItem else { continue }
            let tint = tabTint(for: controller)
            // Keep the storyboard symbol as the template, so restyling never re-tints a tinted copy.
            let base: UIImage?
            if let stored = objc_getAssociatedObject(item, tabImageKey) as? UIImage {
                base = stored
            } else {
                base = item.image
                if let image = base {
                    objc_setAssociatedObject(item, tabImageKey, image, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                }
            }
            guard let image = base else { continue }
            item.image = image.withTintColor(dim, renderingMode: .alwaysOriginal)
            item.selectedImage = image.applyingSymbolConfiguration(symbolConfiguration)?
                .withTintColor(tint.accent, renderingMode: .alwaysOriginal)
                ?? image.withTintColor(tint.accent, renderingMode: .alwaysOriginal)
        }
    }

    private static let tabImageKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// The accent of the section a tab opens.
    private static func tabTint(for controller: UIViewController) -> Tint {
        let root = (controller as? UINavigationController)?.viewControllers.first ?? controller
        switch root {
        case is MainMenuViewController: return .home
        case is ActiveWalletViewController: return .wallet
        case is SignersViewController: return .signer
        case is SettingsViewController: return .settings
        default: return .send   // nodeless wallets: cyan-teal
        }
    }

    /// Per-screen navigation bar look (set on the navigationItem, so it doesn't leak into
    /// screens with their own palettes).
    static func styleNavigation(_ item: UINavigationItem, tint: Tint = .wallet) {
        let appearance = navigationAppearance(background: bg, line: tint.line, accent: tint.accent)
        appearance.doneButtonAppearance = appearance.buttonAppearance
        setNavigationAppearance(appearance, on: item)
    }

    /// Opaque cypherpunk bar: `background`, a `line` hairline, monospaced `accent` titles
    /// and bar buttons. Shared with the signer screens' palette (SignerTheme).
    static func navigationAppearance(background: UIColor, line: UIColor, accent: UIColor) -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = background
        appearance.shadowColor = line
        appearance.titleTextAttributes = [.foregroundColor: accent, .font: mono(15, weight: .semibold)]
        appearance.largeTitleTextAttributes = [.foregroundColor: accent, .font: mono(28, weight: .semibold)]

        let buttons = UIBarButtonItemAppearance()
        buttons.normal.titleTextAttributes = [.foregroundColor: accent, .font: mono(15)]
        appearance.buttonAppearance = buttons
        appearance.backButtonAppearance = buttons
        return appearance
    }

    /// Uses `appearance` for every bar state of `item`.
    static func setNavigationAppearance(_ appearance: UINavigationBarAppearance, on item: UINavigationItem) {
        item.standardAppearance = appearance
        item.scrollEdgeAppearance = appearance
        item.compactAppearance = appearance
    }

    /// Restyles `view` and everything inside it.
    static func style(_ view: UIView, tint: Tint = .wallet) {
        switch view {
        case let cell as UITableViewCell:
            styleCell(cell, tint: tint)
        case let table as UITableView:
            styleTable(table)
        case let collection as UICollectionView:
            collection.backgroundColor = .clear
        case let label as UILabel:
            label.font = mono(from: label.font)
            label.textColor = mapped(label.textColor, tint: tint)
            styleContainer(label, tint: tint)
        case let button as UIButton:
            styleButton(button, tint: tint)
        case let field as UITextField:
            styleField(field, tint: tint)
        case let textView as UITextView:
            styleTextView(textView, tint: tint)
        case let toggle as UISwitch:
            toggle.onTintColor = tint.accent
            toggle.thumbTintColor = text
        case let slider as UISlider:
            slider.minimumTrackTintColor = tint.accent
            slider.maximumTrackTintColor = tint.line
            slider.thumbTintColor = tint.accent
        case let control as UISegmentedControl:
            style(control, tint: tint)
        case let spinner as UIActivityIndicatorView:
            spinner.color = tint.accent
        case let progress as UIProgressView:
            progress.progressTintColor = tint.accent
            progress.trackTintColor = tint.line
        case let imageView as UIImageView:
            // Only recolour symbol / template images (not QR codes or photos).
            if imageView.image == nil || imageView.image?.isSymbolImage == true || imageView.image?.renderingMode == .alwaysTemplate {
                imageView.tintColor = mapped(imageView.tintColor, tint: tint)
            }
        case let picker as UIDatePicker:
            picker.tintColor = tint.accent
        case is UIPickerView:
            break
        case let blur as UIVisualEffectView:
            blur.effect = nil
            blur.backgroundColor = bg.withAlphaComponent(0.96)
            blur.layer.borderWidth = 0
            blur.contentView.subviews.forEach { style($0, tint: tint) }
        case let scroll as UIScrollView:
            if scroll.backgroundColor != nil { scroll.backgroundColor = .clear }
            scroll.indicatorStyle = .white
            scroll.subviews.forEach { style($0, tint: tint) }
        default:
            styleContainer(view, tint: tint)
            view.subviews.forEach { style($0, tint: tint) }
        }
    }

    /// Tables: transparent, no separators, and (for grouped / plain tables) inset 16pt from
    /// the screen edges so the full-width cards keep a margin.
    ///
    /// Wallet tables use the "grouped" style rather than "inset grouped": inset-grouped
    /// tables round and clip each section's corners, which cuts off the corners of the
    /// cards' 1pt borders. Cells are styled as they're displayed (willDisplay), not here.
    static func styleTable(_ table: UITableView) {
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.indicatorStyle = .white
        table.layer.cornerRadius = 0
        if #available(iOS 15.0, *) { table.sectionHeaderTopPadding = 0 }
        if table.style == .grouped, table.tableHeaderView == nil {
            // Grouped tables otherwise add ~35pt of empty space at the top.
            table.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: CGFloat.leastNonzeroMagnitude))
        }
        if table.style != .insetGrouped {
            insetHorizontally(table, by: 16)
        }
    }

    /// Changes leading / trailing constraints that pin `view` flush (constant 0) to its
    /// container so it sits `inset` points in instead. Constraints with a margin already
    /// are left alone, and it only ever runs once per view.
    private static func insetHorizontally(_ view: UIView, by inset: CGFloat) {
        guard objc_getAssociatedObject(view, insetKey) == nil, let container = view.superview else { return }
        objc_setAssociatedObject(view, insetKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        for constraint in container.constraints where abs(constraint.constant) < 1 && constraint.relation == .equal {
            if constraint.firstItem === view {
                if constraint.firstAttribute == .leading { constraint.constant = inset }
                if constraint.firstAttribute == .trailing { constraint.constant = -inset }
            } else if constraint.secondItem === view {
                if constraint.secondAttribute == .leading { constraint.constant = -inset }
                if constraint.secondAttribute == .trailing { constraint.constant = inset }
            }
        }
    }

    private static let insetKey = UnsafeRawPointer(UnsafeMutableRawPointer.allocate(byteCount: 1, alignment: 1))

    /// Plain container views: coloured backgrounds become cards, rounded / bordered ones
    /// get the thin teal border, and hairlines become teal hairlines.
    private static func styleContainer(_ view: UIView, tint: Tint) {
        let hasBackground: Bool = {
            guard let color = view.backgroundColor else { return false }
            var a: CGFloat = 0
            color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)).getWhite(nil, alpha: &a)
            return a > 0.05
        }()
        let size = view.bounds.size
        let isHairline = hasBackground && size != .zero && min(size.width, size.height) <= 2

        if isHairline {
            view.backgroundColor = tint.line
            return
        }
        if hasBackground {
            view.backgroundColor = card
        }
        if view.layer.cornerRadius > 0 || view.layer.borderWidth > 0 {
            view.layer.cornerRadius = radius
            view.layer.borderWidth = 1
            view.layer.borderColor = tint.line.cgColor
        }
    }

    static func style(_ control: UISegmentedControl, tint: Tint = .wallet) {
        styleSegmented(control, background: card, accent: tint.accent, text: dim, selectedText: bg)
    }

    /// Monospaced segmented control in any palette (shared with SignerTheme).
    static func styleSegmented(_ control: UISegmentedControl, background: UIColor, accent: UIColor, text: UIColor, selectedText: UIColor) {
        control.backgroundColor = background
        control.selectedSegmentTintColor = accent
        control.setTitleTextAttributes([.font: mono(12), .foregroundColor: text], for: .normal)
        control.setTitleTextAttributes([.font: mono(12, weight: .semibold), .foregroundColor: selectedText], for: .selected)
    }

    // MARK: Buttons

    /// Solid accent button: use for the one main action on a screen.
    static func stylePrimary(_ button: UIButton, tint: Tint = .wallet) {
        button.layer.name = primaryMarker
        styleButton(button, tint: tint)
    }

    static func styleButton(_ button: UIButton, tint: Tint = .wallet) {
        // Hero buttons are fully styled by `styleHero`; leave them alone.
        guard button.layer.name != heroMarker else { return }
        let isPrimary = button.layer.name == primaryMarker

        if var config = button.configuration {
            // Only real, visible text counts as a title: storyboard / xib icon buttons can carry
            // an empty attributed title, and those must stay borderless icons.
            let plainTitle = config.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let attributedTitle = config.attributedTitle.map { String($0.characters) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Interface Builder's placeholder "Button" title on an image button is not a real
            // title either (it's never shown once the configuration has an image).
            let isPlaceholder = config.image != nil && (plainTitle == "Button" || attributedTitle == "Button")
            let hasTitle = (!plainTitle.isEmpty || !attributedTitle.isEmpty) && !isPlaceholder
            let color = isPrimary ? tint.accent : mapped(config.baseForegroundColor ?? button.tintColor, tint: tint)

            guard hasTitle else {
                // Icon-only button.
                config.baseForegroundColor = color
                config.background.backgroundColor = .clear
                config.background.strokeWidth = 0
                config.background.strokeColor = .clear
                button.configuration = config
                button.backgroundColor = .clear
                button.layer.borderWidth = 0
                return
            }

            config.baseForegroundColor = isPrimary ? bg : color
            config.background.backgroundColor = isPrimary ? color : card
            config.background.strokeColor = isPrimary ? color : color.withAlphaComponent(0.45)
            config.background.strokeWidth = 1
            config.background.cornerRadius = radius
            config.cornerStyle = .fixed
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var attributes = incoming
                let size = (incoming.font?.pointSize).map { min($0, 15) } ?? 13
                attributes.font = WalletTheme.mono(size, weight: .semibold)
                return attributes
            }
            button.configuration = config
            button.layer.cornerRadius = radius
            return
        }

        // Legacy (non-configuration) buttons.
        let color = isPrimary ? tint.accent : mapped(button.currentTitleColor, tint: tint)
        let hasTitle = !(button.currentTitle ?? button.currentAttributedTitle?.string ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        button.tintColor = isPrimary ? tint.accent : mapped(button.tintColor, tint: tint)
        if let font = button.titleLabel?.font {
            button.titleLabel?.font = mono(from: font)
        }

        let hasBackground: Bool = {
            guard let bgColor = button.backgroundColor else { return false }
            var a: CGFloat = 0
            bgColor.getWhite(nil, alpha: &a)
            return a > 0.05
        }()

        if isPrimary {
            button.backgroundColor = tint.accent
            button.setTitleColor(bg, for: .normal)
            button.tintColor = bg
            button.layer.borderWidth = 0
            button.layer.cornerRadius = radius
        } else if hasTitle && (hasBackground || button.layer.cornerRadius > 0 || button.layer.borderWidth > 0) {
            button.backgroundColor = card
            button.setTitleColor(color, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = color.withAlphaComponent(0.45).cgColor
            button.layer.cornerRadius = radius
        } else {
            button.setTitleColor(color, for: .normal)
            if hasBackground { button.backgroundColor = .clear }
            if button.layer.cornerRadius > 0 { button.layer.cornerRadius = radius }
        }
        button.setTitleColor(dim, for: .disabled)
    }

    private static let heroMarker = "WalletTheme.hero"

    /// The big call-to-action at the bottom of a screen (e.g. "Create transaction"):
    /// solid accent slab, uppercase spaced monospace label, trailing arrow, soft neon glow,
    /// darker while pressed and a dim outlined look while disabled.
    static func styleHero(_ button: UIButton, title: String, systemImage: String = "arrow.right", tint: Tint = .wallet) {
        button.layer.name = heroMarker
        button.backgroundColor = .clear
        button.clipsToBounds = false
        button.layer.cornerRadius = radius
        button.layer.borderWidth = 0

        var config = UIButton.Configuration.filled()
        config.cornerStyle = .fixed
        config.background.cornerRadius = radius
        config.image = UIImage(systemName: systemImage,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
        config.imagePlacement = .trailing
        config.imagePadding = 10
        config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)

        var attributed = AttributedString(title.uppercased())
        attributed.font = mono(15, weight: .bold)
        attributed.kern = 2
        config.attributedTitle = attributed
        button.configuration = config

        button.configurationUpdateHandler = { button in
            guard var config = button.configuration else { return }
            if !button.isEnabled {
                config.baseForegroundColor = WalletTheme.dim
                config.background.backgroundColor = WalletTheme.card
                config.background.strokeColor = tint.line
                config.background.strokeWidth = 1
                button.layer.shadowOpacity = 0
            } else {
                let pressed = button.isHighlighted
                config.baseForegroundColor = WalletTheme.bg
                config.background.backgroundColor = pressed ? tint.accent.withAlphaComponent(0.7) : tint.accent
                config.background.strokeWidth = 0
                button.layer.shadowOpacity = pressed ? 0.15 : 0.45
            }
            button.configuration = config
        }

        // Neon glow.
        button.layer.shadowColor = tint.accent.cgColor
        button.layer.shadowRadius = 12
        button.layer.shadowOffset = .zero
        button.layer.shadowOpacity = 0.45
        button.setNeedsUpdateConfiguration()
    }

    /// Makes `button` a bare icon: no fill, no border, accent (or mapped) tint.
    static func styleIconButton(_ button: UIButton, tint: Tint = .wallet) {
        let color = mapped(button.configuration?.baseForegroundColor ?? button.tintColor, tint: tint)
        if var config = button.configuration {
            config.baseForegroundColor = color
            config.background.backgroundColor = .clear
            config.background.strokeWidth = 0
            config.background.strokeColor = .clear
            button.configuration = config
        }
        button.tintColor = color
        button.backgroundColor = .clear
        button.layer.borderWidth = 0
    }

    /// Bordered square button for the wallet's action row. `filled` = primary action.
    static func buttonConfiguration(title: String, systemImage: String, filled: Bool, tint: Tint = .wallet) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.image = UIImage(systemName: systemImage,
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        config.imagePadding = 6
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 8, bottom: 12, trailing: 8)
        config.baseForegroundColor = filled ? bg : tint.accent
        config.background.backgroundColor = filled ? tint.accent : card
        config.background.strokeColor = filled ? tint.accent : tint.line
        config.background.strokeWidth = 1
        config.background.cornerRadius = radius
        config.cornerStyle = .fixed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(13, weight: .semibold)
            return attributes
        }
        return config
    }

    /// Small outlined, monospaced button: chips (Paste / Wallet / …) and inline actions
    /// ("Sign", "verify owner", "edit").
    static func chipConfiguration(title: String,
                                  systemImage: String? = nil,
                                  tint: Tint = .wallet,
                                  fontSize: CGFloat,
                                  imageSize: CGFloat,
                                  imagePadding: CGFloat,
                                  insets: NSDirectionalEdgeInsets,
                                  background: UIColor = WalletTheme.card,
                                  clipsTitle: Bool = false) -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = title
        if let systemImage = systemImage {
            config.image = UIImage(systemName: systemImage,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: imageSize, weight: .semibold))
            config.imagePadding = imagePadding
        }
        if clipsTitle { config.titleLineBreakMode = .byClipping }
        config.contentInsets = insets
        config.baseForegroundColor = tint.accent
        config.background.backgroundColor = background
        config.background.strokeColor = tint.line
        config.background.strokeWidth = 1
        config.background.cornerRadius = radius
        config.cornerStyle = .fixed
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(fontSize, weight: .semibold)
            return attributes
        }
        return config
    }

    // MARK: Cards and captions (screens built in code)

    /// "> TITLE" section caption: 11pt bold monospaced, in the accent colour.
    static func caption(_ text: String, tint: Tint = .wallet) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = mono(11, weight: .bold)
        label.textColor = tint.accent
        label.setContentHuggingPriority(.required, for: .vertical)
        return label
    }

    /// Bordered card (square corners) holding `rows` in a vertical stack, 12pt padding.
    static func cardView(_ rows: [UIView], tint: Tint = .wallet, spacing: CGFloat = 10, background: UIColor? = nil) -> UIView {
        let card = UIView()
        card.backgroundColor = background ?? WalletTheme.card
        card.layer.borderWidth = 1
        card.layer.borderColor = tint.line.cgColor
        card.layer.cornerRadius = radius

        let stack = UIStackView(arrangedSubviews: rows)
        stack.axis = .vertical
        stack.spacing = spacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        return card
    }

    /// Small accent icon button for section headers.
    static func iconButton(_ systemName: String, target: Any, action: Selector, tint: Tint = .wallet) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName,
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                        for: .normal)
        button.tintColor = tint.accent
        button.addTarget(target, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40)
        ])
        return button
    }

    // MARK: Text input

    static func styleField(_ field: UITextField, tint: Tint = .wallet) {
        let size = field.font?.pointSize ?? 15
        field.borderStyle = .none
        field.backgroundColor = card
        field.textColor = text
        field.tintColor = tint.accent
        field.font = mono(size)
        field.keyboardAppearance = .dark
        field.layer.cornerRadius = radius
        field.layer.borderWidth = 1
        field.layer.borderColor = tint.line.cgColor
        if let placeholder = field.placeholder {
            field.attributedPlaceholder = NSAttributedString(string: placeholder,
                                                             attributes: [.foregroundColor: dim, .font: mono(size)])
        }
        // Inner padding + a sensible minimum height now that the rounded border is gone.
        if field.leftView == nil {
            let padding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
            padding.tag = fieldPaddingTag
            field.leftView = padding
            field.leftViewMode = .always
            let minHeight = field.heightAnchor.constraint(greaterThanOrEqualToConstant: 36)
            minHeight.priority = UILayoutPriority(760)
            minHeight.isActive = true
        }
    }

    static func styleTextView(_ textView: UITextView, tint: Tint = .wallet) {
        textView.backgroundColor = card
        textView.textColor = mapped(textView.textColor, tint: tint)
        textView.tintColor = tint.accent
        textView.font = mono(from: textView.font)
        textView.keyboardAppearance = .dark
        textView.indicatorStyle = .white
        textView.layer.cornerRadius = radius
        textView.layer.borderWidth = 1
        textView.layer.borderColor = tint.line.cgColor
        textView.linkTextAttributes = [.foregroundColor: tint.accent]
    }

    // MARK: Table cells and headers

    /// A bordered card background with a tiny corner radius, inset vertically so rows
    /// read as separate cards.
    static func cardConfiguration(tint: Tint = .wallet, highlighted: Bool = false, horizontalInset: CGFloat = 5) -> UIBackgroundConfiguration {
        var background = UIBackgroundConfiguration.clear()
        background.backgroundColor = highlighted ? tint.accent.withAlphaComponent(0.12) : card
        background.strokeColor = highlighted ? tint.accent : tint.line
        background.strokeWidth = 1
        background.cornerRadius = radius
        // Inset on all sides so the inset-grouped table's rounded section corners (which
        // clip the cell) never reach the card's border.
        background.backgroundInsets = NSDirectionalEdgeInsets(top: 4, leading: horizontalInset, bottom: 4, trailing: horizontalInset)
        return background
    }

    /// Restyles a table cell (storyboard, xib or code) as a card. Call it from
    /// `tableView(_:willDisplay:forRowAt:)` so it runs after the cell is configured.
    static func styleCell(_ cell: UITableViewCell, in tableView: UITableView? = nil, tint: Tint = .wallet) {
        // Full-width cards in grouped / plain tables (the table itself is inset); a small
        // inset inside inset-grouped tables keeps the border clear of the section rounding.
        var table = tableView
        if table == nil {
            var ancestor = cell.superview
            while let current = ancestor, table == nil {
                table = current as? UITableView
                ancestor = current.superview
            }
        }
        let horizontalInset: CGFloat
        if table?.style == .insetGrouped {
            horizontalInset = 5
        } else if let table = table, objc_getAssociatedObject(table, rootTableKey) != nil {
            horizontalInset = 16
        } else {
            horizontalInset = 0
        }
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        cell.automaticallyUpdatesBackgroundConfiguration = false
        cell.backgroundConfiguration = cardConfiguration(tint: tint, horizontalInset: horizontalInset)
        squareCorners(cell)                 // defeat the inset-grouped section rounding
        cell.layer.borderWidth = 0          // the card stroke replaces any old cell border
        cell.tintColor = tint.accent

        if var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.font = mono(from: content.textProperties.font)
            content.textProperties.color = text
            content.secondaryTextProperties.font = mono(from: content.secondaryTextProperties.font)
            content.secondaryTextProperties.color = dim
            content.imageProperties.tintColor = tint.accent
            cell.contentConfiguration = content
        } else {
            cell.contentView.subviews.forEach { style($0, tint: tint) }
        }
        if let accessory = cell.accessoryView { style(accessory, tint: tint) }
    }

    /// Section headers: monospaced accent titles on a clear background.
    static func styleHeader(_ view: UIView, tint: Tint = .wallet) {
        if let header = view as? UITableViewHeaderFooterView {
            var background = UIBackgroundConfiguration.clear()
            background.backgroundColor = .clear
            header.backgroundConfiguration = background
            if var content = header.contentConfiguration as? UIListContentConfiguration {
                content.textProperties.font = mono(12, weight: .semibold)
                content.textProperties.color = tint.accent
                header.contentConfiguration = content
            } else {
                header.textLabel?.font = mono(12, weight: .semibold)
                header.textLabel?.textColor = tint.accent
                header.contentView.subviews.forEach { style($0, tint: tint) }
            }
            return
        }
        view.backgroundColor = .clear
        view.subviews.forEach { sub in
            style(sub, tint: tint)
            if let label = sub as? UILabel {
                label.font = mono(14, weight: .semibold)
                label.textColor = tint.accent
            }
        }
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

/// UILabel with inner padding (for the confirmations badge).
/// UILabel with inner padding (badges, pills). Shared by the wallet and home screens.
final class PaddedLabel: UILabel {
    var insets = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right,
                      height: size.height + insets.top + insets.bottom)
    }
}
