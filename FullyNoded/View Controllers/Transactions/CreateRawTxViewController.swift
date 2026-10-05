//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Denton LLC. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var fxRate: Double?
    var address = String()
    var outputs: [[String:Any]] = []
    var inputs: [[String:Any]] = []
    var utxoTotal: Double = 0.0
    let ud = UserDefaults.standard
    var invoice:[String:Any]?
    var balance = ""
    var utxoToSweep: UTXO?
    /// The coin-control notice is shown once, not every time the screen reappears.
    private var shownCoinControlNotice = false

    /// The address label's storyboard placeholder (the label is never empty).
    private static let addressPlaceholder = "Paste or scan an address or invoice."

    /// The entered recipient, without the display dashes; nil when none has been entered.
    private var recipientAddress: String? {
        let text = (addressInput.text ?? "").replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, addressInput.text != Self.addressPlaceholder else { return nil }
        return text
    }
    
    
    @IBOutlet weak private var addressInput: UILabel!
    @IBOutlet weak private var createOutlet: UIButton!
    @IBOutlet weak private var balanceLabel: UILabel!
    @IBOutlet weak private var batchOutlet: UIButton!
    @IBOutlet weak private var miningTargetLabel: UILabel!
    @IBOutlet weak private var satPerByteLabel: UILabel!
    @IBOutlet weak private var denominationImage: UIImageView!
    @IBOutlet weak private var slider: UISlider!
    @IBOutlet weak private var amountInput: UITextField!
    @IBOutlet weak private var outputsTable: UITableView!
    @IBOutlet weak private var feeRateInputField: UITextField!
    
    /// "≈ $1,234.56" under the amount, updated live as the BTC amount is typed
    /// (display / reference only, never used to build the transaction).
    private let fiatAmountLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        outputsTable.delegate = self
        feeRateInputField.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        slider.isContinuous = false
        
        if balance.condenseWhitespace().isEmpty {
            balanceLabel.text = "—"          // balance not loaded (no active wallet)
        } else if let fxRate = fxRate {
            balanceLabel.text = balance + " btc" + " / " + (fxRate * balance.condenseWhitespace().doubleValue).fiatString
        } else {
            balanceLabel.text = balance + " btc"
        }
        
        addTapGesture()
        
        slider.addTarget(self, action: #selector(setFee), for: .allEvents)
        slider.maximumValue = 2 * -1
        slider.minimumValue = 432 * -1
        
        if ud.object(forKey: "feeTarget") != nil {
            let numberOfBlocks = ud.object(forKey: "feeTarget") as! Int
            slider.value = Float(numberOfBlocks) * -1
            updateFeeLabel(label: miningTargetLabel, numberOfBlocks: numberOfBlocks)
        } else {
            miningTargetLabel.text = "Minimum fee set (you can always bump it)"
            slider.value = 432 * -1
            ud.set(432, forKey: "feeTarget")
        }
        
        showFeeSetting()
        
        slider.addTarget(self, action: #selector(didFinishSliding(_:)), for: .valueChanged)
        
        amountInput.text = ""
        if address != "" {
            addAddress(address)
        }
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        // Regroup the storyboard rows into cards first, so the theme styles the result.
        groupIntoCards()
        WalletTheme.apply(to: self, tint: .send)
        styleCards()
        flattenInfoButtons()
        configureCreateButton()
    }
    
    @IBAction func sendToWalletAction(_ sender: Any) {
        guard !isShowingActivity else { return }
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets, !wallets.isEmpty else {
                showAlert(vc: self, title: "No wallets...", message: "")
                return
            }
            var walletsToSendTo:[Wallet] = []
            
            let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
            
            for (i, wallet) in wallets.enumerated() {
                let walletStruct = Wallet(dictionary: wallet)
                let desc = Descriptor(walletStruct.receiveDescriptor)
                
                if chain == "main" && desc.chain == "Mainnet" {
                    walletsToSendTo.append(walletStruct)
                } else if chain != "main" && desc.chain != "Mainnet" {
                    walletsToSendTo.append(walletStruct)
                }
                
                if i + 1 == wallets.count {
                    self.selectWalletRecipient(walletsToSendTo)
                }
            }
        }
    }
    
    private func selectWalletRecipient(_ wallets: [Wallet]) {
        guard !wallets.isEmpty else {
            showAlert(vc: self, title: "No wallets...", message: "None of the wallets you have saved are on the same network as your active node.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Select a wallet to send to."
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            
            for wallet in wallets {
                alert.addAction(UIAlertAction(title: wallet.label, style: .default, handler: { action in
                    self.getAddressFromWallet(wallet)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getAddressFromWallet(_ walletToFetchFrom: Wallet) {
        guard let currentActiveWallet = UserDefaults.standard.object(forKey: "walletName") else { return }
        
        showActivity("getting address from \(walletToFetchFrom.label)...")
        
        // Temporarily set the active wallet to the wallet we are deriving an address from.
        UserDefaults.standard.set(walletToFetchFrom.name, forKey: "walletName")
        
        let addressType = Descriptor(walletToFetchFrom.receiveDescriptor).addressType
        
        let p = Get_New_Address(["address_type": addressType])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            UserDefaults.standard.set(currentActiveWallet, forKey: "walletName")
            hideActivity()
            
            guard let response = response as? String else {
                showAlert(vc: self, title: "", message: errorDesc ?? "Unknown error fetching a new address.")
                return
            }
            
            addAddressNow(address: response, wallet: walletToFetchFrom)
        }
    }
    
    private func addAddressNow(address: String, wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addAddress("\(address.addressExpanded)")
            SuccessView.toast("Address added from \(wallet.label)", in: self)
        }
    }
    
    @IBAction func showAddressInfoAction(_ sender: Any) {
        guard let address = recipientAddress else {
            showAlert(vc: self, title: "", message: "Not a valid address or invoice.")
            return
        }
        showActivity("getting address info...")
        OnchainUtils.getAddressInfo(address: address) { [weak self] (addressInfo, message) in
            guard let self = self else { return }
            
            hideActivity()
            
            guard let addressInfo = addressInfo else {
                showAlert(vc: self, title: "Error getting address info.", message: message ?? "Unknown.")
                return
            }
            
            showModal(data: addressInfo.rawData, title: "address info")
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        let modalVC = TextModalViewController(data: data, viewTitle: title)
        let nav = UINavigationController(rootViewController: modalVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        present(nav, animated: true)
    }
    
    @IBAction func closeFeeRate(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UserDefaults.standard.removeObject(forKey: "feeRate")
            self.feeRateInputField.text = ""
            self.slider.alpha = 1
            self.miningTargetLabel.alpha = 1
            self.feeRateInputField.endEditing(true)
            self.showFeeSetting()
        }
    }
    
    @IBAction func donateAction(_ sender: Any) {
        guard let donationAddress = Keys.donationAddress() else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            addressInput.text = donationAddress.addressExpanded
            showAlert(vc: self, title: "Thank you!", message: "Any amount you send to this address will help directly support Fully Noded and is greatly appreciated. ❤️")
        }
    }
    
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let item = UIPasteboard.general.string else { return }
        
        processBIP21(url: item)
    }
    
    @IBAction func createOnchainAction(_ sender: Any) {
        guard !isShowingActivity else { return }
        view.endEditing(true)
        tryRaw()
    }
    
    private func convertedAmount() -> String? {
        // The field shows spaces between digit groups; strip them before parsing.
        guard let amount = amountInput.text?.condenseWhitespace(), amount != "" else { return nil }
        
        let dblAmount = amount.doubleValue
        
        guard dblAmount > 0.0 else {
            showAlert(vc: self, title: "", message: "Amount needs to be greater than 0.")
            return nil
        }
        
        return "\(dblAmount.avoidNotation)"
    }
    
    @IBAction func addToBatchAction(_ sender: Any) {
        guard let address = recipientAddress, let amount = convertedAmount() else {
            
            showAlert(vc: self,
                      title: "",
                      message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
            return
        }
        
        outputs.append([address: amount])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.outputsTable.alpha = 1
            self.amountInput.text = ""
            self.updateFiatAmount()
            self.addressInput.text = ""
            self.outputsTable.reloadData()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if inputs.count > 0, !shownCoinControlNotice {
            shownCoinControlNotice = true
            
            if let fxRate = fxRate {
                balanceLabel.text = utxoTotal.btcBalanceWithSpaces + " / " + (fxRate * utxoTotal).fiatString
            } else {
                balanceLabel.text = utxoTotal.btcBalanceWithSpaces
            }
            
            showAlert(vc: self, title: "Coin control ✓", message: "Only the utxo's you have just selected will be used in this transaction. You may send the total balance of the *selected utxo's* by tapping the \"Send all\" button or enter a custom amount as normal.")
        }
    }
    
    private func addAddress(_ address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressInput.text = address
        }
    }
    
    @IBAction func scanNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerToGetAddress", sender: vc)
        }
    }
    
    @objc func setFee(_ sender: UISlider) {
        let numberOfBlocks = Int(sender.value) * -1
        updateFeeLabel(label: miningTargetLabel, numberOfBlocks: numberOfBlocks)
    }
    
    @objc func didFinishSliding(_ sender: UISlider) {
        estimateSmartFee()
    }
    
    /// "Target: 6 blocks ~1 hours" for the slider, and remembers the target.
    func updateFeeLabel(label: UILabel, numberOfBlocks: Int) {
        ud.set(numberOfBlocks, forKey: "feeTarget")
        let seconds = numberOfBlocks * 10 * 60
        let eta: String
        switch seconds {
        case ..<3600: eta = "\(seconds / 60) minutes"
        case ..<86400: eta = "\(seconds / 3600) hours"
        default: eta = "\(seconds / 86400) days"
        }
        DispatchQueue.main.async {
            label.text = "Target: \(numberOfBlocks) blocks ~\(eta)"
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return outputs.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = view.backgroundColor
        if outputs.count > 0 {
            if outputs.count > 1 {
                tableView.separatorColor = .darkGray
                tableView.separatorStyle = .singleLine
            }
            let dict = outputs[indexPath.row]
            for (key, value) in dict {
                cell.textLabel?.text = "\n#\(indexPath.row + 1)\n\nSending: \(String(describing: value))\n\nTo: \(String(describing: key))"
                cell.textLabel?.textColor = .lightGray
            }
        } else {
            cell.textLabel?.text = ""
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, outputs.indices.contains(indexPath.row) else { return }
        outputs.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        if outputs.isEmpty { tableView.alpha = 0 }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: User Actions
    
    private func promptToSweep() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var title = "⚠️ Send total balance?\n\nYou will not be able to use RBF when sweeping!"
            var message = "This action will send ALL the bitcoin this wallet holds to the provided address. If your fee is too low this transaction could get stuck for a long time."
            
            if self.inputs.count > 0 {
                title = "⚠️ Send total balance from the selected utxo's?"
                message = "You selected specific utxo's to sweep, this action will sweep \(self.utxoTotal) btc to the address you provide.\n\nIt is important to set a high fee as you may not use RBF if you sweep all your utxo's!"
            }
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Send all", style: .default, handler: { action in
                self.sweep()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func sweepUtxos(utxosToSweep: [UTXO], receivingAddress: String) {
        var inputArray: [[String: Any]] = []
        var amount = Double()
        var spendFromCold = Bool()
        var locktime: UInt32 = 0

        for utxo in utxosToSweep {
            if utxo.spendable == false { spendFromCold = true }
            amount += utxo.amount

            guard let confirmations = utxo.confirmations, confirmations > 0 else {
                hideActivity()
                showAlert(vc: self, title: "", message: "You have unconfirmed utxo's, wait till they get a confirmation before trying to sweep them.")
                return
            }

            if let ws = utxo.witnessScript,
               let cltv = WalletLogic.shared.extractCLTV(fromWitnessScript: ws) {
                locktime = max(locktime, cltv)
            }

            var input = utxo.input
            input["sequence"] = 1
            inputArray.append(input)
        }

        func buildParams(lock: UInt32) -> [String: Any] {
            var paramDict: [String: Any] = [:]
            paramDict["inputs"] = inputArray
            paramDict["outputs"] = [[receivingAddress: "\(rounded(number: amount))"]]
            paramDict["bip32derivs"] = true
            if lock > 0 { paramDict["locktime"] = lock }

            var options: [String: Any] = [:]
            options["includeWatching"] = spendFromCold
            options["replaceable"] = true
            options["subtractFeeFromOutputs"] = [0]
            options["changeAddress"] = receivingAddress
            if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                options["fee_rate"] = feeRate
            } else {
                options["conf_target"] = ud.object(forKey: "feeTarget") as? Int ?? 432
            }
            paramDict["options"] = options
            return paramDict
        }

        func processAndVerify(_ psbt: String) {
            let processParam: Wallet_Process_PSBT = .init(["psbt": psbt])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: processParam)) { [weak self] response, errorMessage in
                guard let self else { return }
                guard let dict = response as? NSDictionary, let processedPSBT = dict["psbt"] as? String else {
                    hideActivity()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                openVerifier(psbt: processedPSBT)
            }
        }

        func locktimeFromDecodedPsbt(_ decoded: [String: Any]) -> UInt32 {
            var needed: UInt32 = 0
            guard let inputs = decoded["inputs"] as? [[String: Any]] else { return 0 }

            for input in inputs {
                if let scripts = input["taproot_scripts"] as? [[String: Any]] {
                    for s in scripts {
                        if let hex = s["script"] as? String,
                           let v = WalletLogic.shared.extractCLTV(fromWitnessScript: hex) {
                            needed = max(needed, v)
                        }
                    }
                }
                if let ws = input["witness_script"] as? [String: Any],
                   let hex = ws["hex"] as? String,
                   let v = WalletLogic.shared.extractCLTV(fromWitnessScript: hex) {
                    needed = max(needed, v)
                }
            }
            return needed
        }

        func fund(lock: UInt32, completion: @escaping (String?) -> Void) {
            let param: Wallet_Create_Funded_Psbt = .init(buildParams(lock: lock))
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletcreatefundedpsbt(param: param)) { [weak self] response, errorMessage in
                guard let self else { return }
                guard let result = response as? NSDictionary, let psbt = result["psbt"] as? String else {
                    hideActivity()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    completion(nil)
                    return
                }
                completion(psbt)
            }
        }

        fund(lock: locktime) { psbt1 in
            guard let psbt1 else { return }

            let decodeParam: Decode_Psbt = .init(["psbt": psbt1])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: decodeParam)) { response, _ in
                let decoded = response as? [String: Any] ?? [:]
                let txLock = ((decoded["tx"] as? [String: Any])?["locktime"] as? NSNumber)?.uint32Value ?? 0
                let needed = max(locktime, locktimeFromDecodedPsbt(decoded))

                if needed == 0 || txLock >= needed {
                    processAndVerify(psbt1)
                    return
                }

                fund(lock: needed) { psbt2 in
                    guard let psbt2 else { return }
                    processAndVerify(psbt2)
                }
            }
        }
    }
        
    /// Sends everything: the one coin passed in from the UTXO screen, the coins selected
    /// there (coin control), or the whole wallet.
    private func sweepWallet(_ receivingAddress: String) {
        let selected = Set(inputs.compactMap { input -> String? in
            guard let txid = input["txid"] as? String, let vout = input["vout"] as? Int else { return nil }
            return "\(txid):\(vout)"
        })
        let single = utxoToSweep

        let param: List_Unspent = .init(["minconf": 0])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listunspent(param)) { [weak self] response, errorDesc in
            guard let self else { return }

            guard let response = response as? [[String: Any]] else {
                hideActivity()
                displayAlert(viewController: self, isError: true, message: errorDesc ?? "error fetching utxo's")
                return
            }

            var utxos = [UTXO].from(rawArray: response)
            if let single = single {
                utxos = [single]
            } else if !selected.isEmpty {
                utxos = utxos.filter { selected.contains("\($0.txid):\($0.vout)") }
            }
            guard !utxos.isEmpty else {
                hideActivity()
                showAlert(vc: self, title: "Nothing to send", message: "There are no coins to send.")
                return
            }
            sweepUtxos(utxosToSweep: utxos, receivingAddress: receivingAddress)
        }
    }
    
    private func sweep() {
        guard let receivingAddress = recipientAddress else {
            showAlert(vc: self, title: "Add an address first", message: "")
            return
        }
        guard !SilentPaymentSend.isSilentPaymentAddress(receivingAddress) else {
            showAlert(vc: self, title: "Silent payments", message: "Send all isn't supported to a silent payment address. Enter an amount instead.")
            return
        }
        showActivity("sweeping wallet...", button: createOutlet)
        sweepWallet(receivingAddress)
    }
    
    @IBAction func sweep(_ sender: Any) {
        guard !isShowingActivity else { return }
        promptToSweep()
    }
    
    /// Pushes the (programmatic) transaction verifier with what was just created, and
    /// clears the form (batch, coin control, address, amount). Safe from any thread.
    private func openVerifier(psbt: String? = nil, rawTx: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.hideActivity()
            let vc = VerifyTransactionViewController()
            vc.fxRate = self.fxRate
            if let rawTx = rawTx {
                vc.signedRawTx = rawTx
            } else if let psbt = psbt {
                vc.unsignedPsbt = psbt
            }

            self.outputs.removeAll()
            self.outputsTable.reloadData()
            self.inputs.removeAll()
            self.utxoToSweep = nil
            self.addressInput.text = Self.addressPlaceholder
            self.amountInput.text = ""
            self.updateFiatAmount()

            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    /// Builds the transaction for the batch, or for the single recipient on screen. The
    /// batch itself is only cleared once a transaction has been created.
    @objc func tryRaw() {
        let hasAmount = !(amountInput.text ?? "").condenseWhitespace().isEmpty
        let recipients: [[String: Any]]
        if outputs.isEmpty {
            guard let address = recipientAddress, hasAmount, let amount = convertedAmount() else {
                showAlert(vc: self, title: "", message: "You need to fill out an amount and a recipient.")
                return
            }
            recipients = [[address: amount]]
        } else {
            guard !hasAmount, recipientAddress == nil else {
                displayAlert(viewController: self, isError: true, message: "To add this recipient to the batch, tap \"Batch\" first. Or clear the amount and address to send the batch as it is.")
                return
            }
            recipients = outputs
        }
        showActivity("creating psbt...", button: createOutlet)
        getRawTx(outputs: recipients)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
        feeRateInputField.resignFirstResponder()
    }
    
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountInput else { return true }
        
        // The amount is shown grouped like balances ("0.01 234 567"), so edits are applied
        // to the raw digits (typing / pasting appends, backspace removes the last digit)
        // and the field is reformatted. Max 8 whole digits and 8 decimals.
        var raw = (textField.text ?? "").condenseWhitespace()
        if string.isEmpty {
            if !raw.isEmpty { raw.removeLast() }
        } else {
            raw += string.replacingOccurrences(of: ",", with: ".")
        }
        textField.text = Self.formatAmount(raw)
        // Live fiat reference. (Returning false means no editingChanged event fires,
        // so it's updated here, on every keystroke.)
        updateFiatAmount()
        return false
    }
    
    /// "1234.01234567" → "1 234.01 234 567". Keeps only digits and the first ".", drops
    /// leading zeros, caps whole digits at 8 (21 000 000) and decimals at 8. Decimals are
    /// grouped 2-3-3 like `btcBalanceWithSpaces`; whole digits in threes.
    static func formatAmount(_ input: String) -> String {
        var whole = ""
        var fraction = ""
        var hasPoint = false
        for c in input {
            if c == "." {
                hasPoint = true
            } else if c.isASCII, c.isNumber {
                if hasPoint {
                    if fraction.count < 8 { fraction.append(c) }
                } else if whole.count < 8 {
                    whole.append(c)
                }
            }
        }
        // No leading zeros ("007" → "7"), but "0" before a decimal point.
        while whole.count > 1 && whole.hasPrefix("0") { whole.removeFirst() }
        if whole.isEmpty && hasPoint { whole = "0" }
        guard !whole.isEmpty else { return "" }
        
        // Whole part in threes from the right.
        var groupedWhole = ""
        for (i, c) in whole.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { groupedWhole.append(" ") }
            groupedWhole.append(c)
        }
        groupedWhole = String(groupedWhole.reversed())
        guard hasPoint else { return groupedWhole }
        
        // Decimals: 2, then 3, then 3 ("01 234 567").
        var groupedFraction = ""
        for (i, c) in fraction.enumerated() {
            if i == 2 || i == 5 { groupedFraction.append(" ") }
            groupedFraction.append(c)
        }
        return groupedWhole + "." + groupedFraction
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        
        if textField == amountInput {
            updateFiatAmount()
        }
        
        if textField == feeRateInputField {
            guard let text = textField.text else { return }
            
            guard text != "" else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.slider.alpha = 1
                    self.miningTargetLabel.alpha = 1
                    
                    UserDefaults.standard.removeObject(forKey: "feeRate")
                    
                    showAlert(vc: self, title: "", message: "Your transaction fee will be determined by the slider. To specify a manual s/vB fee rate add a value greater then 0.")
                    
                    self.estimateSmartFee()
                }
                
                return
            }
            
            guard let int = Int(text.trimmingCharacters(in: .whitespaces)) else {
                showAlert(vc: self, title: "Whole sats per vbyte", message: "Enter the fee rate as a whole number of sats per vbyte (e.g. 3). Your fee setting hasn't changed.")
                return
            }
            
            guard int > 0 else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.feeRateInputField.text = ""
                    self.slider.alpha = 1
                    self.miningTargetLabel.alpha = 1
                    
                    UserDefaults.standard.removeObject(forKey: "feeRate")
                    self.estimateSmartFee()
                    
                    showAlert(vc: self, title: "", message: "Fee rate must be above 0. To specify a fee rate ensure it is above 0 otherwise the fee defaults to the slider setting.")
                }
                
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.slider.alpha = 0
                self.miningTargetLabel.alpha = 0
                self.satPerByteLabel.text = "\(int) s/vB"
                UserDefaults.standard.setValue(int, forKey: "feeRate")
                
                showAlert(vc: self, title: "", message: "Your transaction fee rate has been set to \(int) sats per vbyte. To revert to the slider you can delete the fee rate or set it to 0.")
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    //MARK: Helpers
    private func estimateSmartFee() {
        NodeLogic.sharedInstance.estimateSmartFee { (response, errorMessage) in
            guard let response = response, let feeRate = response["feeRate"] as? String else { return }
            
            DispatchQueue.main.async {
                self.satPerByteLabel.text = "\(feeRate)"
            }
        }
    }
    
    private func showFeeSetting() {
        if UserDefaults.standard.object(forKey: "feeRate") == nil {
            estimateSmartFee()
        } else {
            guard let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int else {
                UserDefaults.standard.removeObject(forKey: "feeRate")
                estimateSmartFee()
                return
            }
            self.slider.alpha = 0
            self.miningTargetLabel.alpha = 0
            self.feeRateInputField.text = "\(feeRate)"
            self.satPerByteLabel.text = "\(feeRate) s/vB"
        }
    }
    
    func processBIP21(url: String) {
        let (address, amount, label, message) = AddressParser.sharedInstance.parse(url: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.amountInput.resignFirstResponder()
            
            guard let address = address else {
                showAlert(vc: self, title: "", message: "Not a valid address or BIP21 invoice.")
                return
            }
            
            self.addAddress(address.addressExpanded)
            
            if amount != nil || label != nil || message != nil {
                var amountText = "not specified"
                
                if amount != nil {
                    amountText = amount!.avoidNotation
                    self.amountInput.text = Self.formatAmount(amountText.replacingOccurrences(of: ",", with: ""))
                    self.updateFiatAmount()
                }
                
                showAlert(vc: self, title: "BIP21 Invoice\n", message: "Address: \(address)\n\nAmount: \(amountText) btc\n\nLabel: " + (label ?? "no label") + "\n\nMessage: \((message ?? "no message"))")
            }
        }
    }
    
    func getRawTx(outputs: [[String: Any]]) {
        // Silent payment recipient (sp1… / tsp1…): the output key depends on the inputs
        // and their private keys, so SilentPaymentSend builds the psbt. It comes back
        // UNSIGNED and goes to VerifyTransactionViewController like any other psbt,
        // where the normal sign / broadcast flow happens.
        if outputs.contains(where: { $0.keys.contains(where: { SilentPaymentSend.isSilentPaymentAddress($0) }) }) {
            guard outputs.count == 1, let entry = outputs.first?.first else {
                hideActivity()
                showAlert(vc: self, title: "Silent payments", message: "A silent payment address must be the only recipient in the transaction.")
                return
            }

            createSilentPayment(to: entry.key, amount: "\(entry.value)", change: .wallet)
            return
        }

        CreatePSBT.create(inputs: self.inputs, outputs: outputs) { [weak self] (psbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            if let rawTx = rawTx {
                self.openVerifier(rawTx: rawTx)
                
            } else if let psbt = psbt {
                // Spending silent payment outputs? Ask where the change should go.
                self.offerSilentPaymentChange(psbt: psbt, recipients: outputs.count) { [weak self] pinnedInputs in
                    self?.createWithSilentPaymentChange(inputs: pinnedInputs, outputs: outputs)
                }
                
            } else {
                // The batch is kept: fix it (swipe to remove a recipient) and try again.
                self.hideActivity()
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error creating transaction")
            }
        }
    }
    
    // MARK: - Silent payment change
    
    /// Silent payment recipient: SilentPaymentSend builds the (unsigned) psbt.
    /// Built with the wallet's own change (Fully Noded wallets always have a change
    /// descriptor). If it spends silent payment outputs, ask whether the change goes to
    /// your silent payment address or stays with the wallet. Silent payment change uses
    /// k = 1 automatically when you pay your own address (BIP352 numbering).
    /// - inputs: coin-control inputs (nil = the screen's selection).
    private func createSilentPayment(to address: String,
                                     amount: String,
                                     change: SilentPaymentChange.Destination,
                                     inputs pinned: [[String: Any]]? = nil) {
        showActivity("creating silent payment...", button: createOutlet)
        SilentPaymentSend.create(spAddress: address, amount: amount, inputs: pinned ?? inputs, change: change) { [weak self] psbt, errorMessage in
            guard let self = self else { return }
            
            self.hideActivity()
            
            if let psbt = psbt {
                guard case .wallet = change else {
                    self.openVerifier(psbt: psbt)
                    return
                }
                self.offerSilentPaymentChange(psbt: psbt, recipients: 1) { [weak self] pinnedInputs in
                    self?.createSilentPayment(to: address, amount: amount, change: .silentPayment, inputs: pinnedInputs)
                }
                
            } else {
                showAlert(vc: self, title: "Silent payment error", message: errorMessage ?? "unknown error creating silent payment transaction")
            }
        }
    }
    
    /// After building with the wallet's own change: if the transaction spends silent
    /// payment outputs (detected exactly as the verifier does) and has a change output,
    /// ask whether the change should go to your silent payment address instead.
    /// - rebuildWithSilentPaymentChange: gets the same inputs, pinned, so the change is
    ///   computed for exactly the coins that were chosen.
    private func offerSilentPaymentChange(psbt: String,
                                          recipients: Int,
                                          rebuildWithSilentPaymentChange: @escaping ([[String: Any]]) -> Void) {
        let useAsIs: () -> Void = { [weak self] in
            self?.openVerifier(psbt: psbt)
        }
        
        showActivity("checking for silent payment inputs...", button: createOutlet)
        SilentPaymentSpend.detectInputs(psbt: psbt, passphrase: nil) { owned in
            guard !owned.isEmpty else {
                useAsIs()
                return
            }
            SilentPaymentChange.decode(psbt) { [weak self] tx, _ in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    // No change output (exact amount): nothing to decide.
                    guard let tx = tx, tx.outputs.count > recipients else {
                        useAsIs()
                        return
                    }
                    self.hideActivity()
                    
                    let pinned: [[String: Any]] = tx.inputs.map { ["txid": $0.txid, "vout": $0.vout] }
                    let alert = UIAlertController(
                        title: "Change",
                        message: "This transaction spends silent payment outputs. Send the change to your silent payment address, or to this wallet's normal change address?",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "My silent payment address", style: .default) { _ in
                        rebuildWithSilentPaymentChange(pinned)
                    })
                    alert.addAction(UIAlertAction(title: "Wallet change address", style: .default) { _ in
                        useAsIs()
                    })
                    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    private func createWithSilentPaymentChange(inputs: [[String: Any]], outputs: [[String: Any]]) {
        showActivity("creating psbt with silent payment change...", button: createOutlet)
        SilentPaymentChange.create(inputs: inputs, outputs: outputs) { [weak self] psbt, errorMessage in
            guard let self = self else { return }
            guard let psbt = psbt else {
                self.hideActivity()
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error creating transaction")
                return
            }
            self.openVerifier(psbt: psbt)
        }
    }
    
    @IBAction func pasteAddressAction(_ sender: Any) {
        guard let pasteBoardContents = UIPasteboard.general.string else {
            showAlert(vc: self, title: "", message: "Nothing on your clipboard. You can paste addresses or BIP21 invoices here.")
            return
        }
        DispatchQueue.main.async() { [weak self] in
            guard let self = self else { return }
            
            processBIP21(url: pasteBoardContents)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToScannerToGetAddress":
            guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
            
            vc.isScanningAddress = true
            
            vc.onDoneBlock = { addrss in
                guard let addrss = addrss else { return }
                
                DispatchQueue.main.async { [unowned thisVc = self] in
                    thisVc.processBIP21(url: addrss)
                }
            }
            
        default:
            break
        }
    }
}

// MARK: - Theme

extension CreateRawTxViewController {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .send)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        WalletTheme.styleHeader(view, tint: .send)
    }
}

extension CreateRawTxViewController {
    /// The address info button is an icon: keep it borderless (only the text buttons such as
    /// Paste, Wallet, Batch, Send all and Donate are outlined).
    fileprivate func flattenInfoButtons() {
        var stack: [UIView] = [view]
        while let current = stack.popLast() {
            if let button = current as? UIButton {
                let actions = button.actions(forTarget: self, forControlEvent: .touchUpInside) ?? []
                if actions.contains("showAddressInfoAction:") {
                    WalletTheme.styleIconButton(button, tint: .send)
                }
            } else {
                stack.append(contentsOf: current.subviews)
            }
        }
    }
}

extension CreateRawTxViewController {
    /// "Create transaction": a full-width hero button lined up with the outputs table,
    /// instead of the storyboard's fixed 181 x 38 pill (too narrow for its title).
    fileprivate func configureCreateButton() {
        WalletTheme.styleHero(createOutlet, title: "Create transaction", tint: .send)

        // Drop the storyboard's fixed width / height.
        for constraint in createOutlet.constraints
        where constraint.firstItem === createOutlet && constraint.secondItem == nil
            && (constraint.firstAttribute == .width || constraint.firstAttribute == .height) {
            constraint.isActive = false
        }

        NSLayoutConstraint.activate([
            createOutlet.leadingAnchor.constraint(equalTo: outputsTable.leadingAnchor),
            createOutlet.trailingAnchor.constraint(equalTo: outputsTable.trailingAnchor),
            createOutlet.heightAnchor.constraint(equalToConstant: 52)
        ])
    }
}

// MARK: - Layout: AMOUNT / RECIPIENT / FEE cards

/// The storyboard lays the screen out as ten loose rows, each with its own icon and
/// label. Here they're regrouped (in code, so every outlet, action and the batching table
/// keep working) into three cards:
///
///   > AMOUNT
///     [ amount field                 ]  max
///     ≈ <fiat value of the amount>   (live, reference only)
///     AVAILABLE
///     <balance btc / fiat>
///   > RECIPIENT ………………………………… (i)
///     <address>
///     [PASTE] [WALLET] [+ BATCH] [DONATE]
///   > FEE ………………………………… <n s/vB>
///     ─────────○──────────  (ETA slider)
///     Target: 2 blocks ~20 minutes
///     [ custom sat/vB          ] (x)
///
/// The batching table (hidden until something is added) and the Create button stay
/// below the cards, as before.
extension CreateRawTxViewController {

    private static let cardTag = 0x5E4D
    // Unique tags (small ones like 1 / 2 can collide with storyboard tags).
    private static let captionTag = 0x5E4E
    private static let availableTag = 0x5E4F
    /// Every card caption ("> AMOUNT", "> RECIPIENT", "> FEE") is exactly this.
    private static let captionFont = WalletTheme.mono(11, weight: .bold)
    private static let captionRowHeight: CGFloat = 24

    /// The storyboard's main vertical stack (the one holding the amount field).
    private var mainStack: UIStackView? {
        var view: UIView? = amountInput
        while let current = view {
            if let stack = current as? UIStackView, stack.axis == .vertical, stack.arrangedSubviews.count > 3 {
                return stack
            }
            view = current.superview
        }
        return nil
    }

    /// The top-level row of the main stack that contains `view`.
    private func row(containing view: UIView, in main: UIStackView) -> UIStackView? {
        main.arrangedSubviews.first { view.isDescendant(of: $0) } as? UIStackView
    }

    /// Storyboard buttons, found by the action they trigger.
    private func button(withAction action: String, in root: UIView) -> UIButton? {
        var stack: [UIView] = [root]
        while let current = stack.popLast() {
            if let button = current as? UIButton,
               (button.actions(forTarget: self, forControlEvent: .touchUpInside) ?? []).contains(action) {
                return button
            }
            stack.append(contentsOf: current.subviews)
        }
        return nil
    }

    private func detach(_ view: UIView) {
        (view.superview as? UIStackView)?.removeArrangedSubview(view)
        view.removeFromSuperview()
    }

    fileprivate func groupIntoCards() {
        // The outlets are weak: take strong references first, so views stay alive while
        // they're moved between stacks (their only owner is their superview).
        guard let main = mainStack, main.viewWithTag(Self.cardTag) == nil,
              let amount = amountInput, let address = addressInput, let balance = balanceLabel,
              let feeRate = satPerByteLabel, let target = miningTargetLabel,
              let slider = slider, let customFee = feeRateInputField, let batch = batchOutlet,
              let amountRow = row(containing: amount, in: main),
              let addressRow = row(containing: address, in: main),
              let actionsRow = row(containing: batch, in: main),
              let sliderRow = row(containing: slider, in: main),
              let manualRow = row(containing: customFee, in: main) else { return }
        _ = addressRow

        let infoButton = button(withAction: "showAddressInfoAction:", in: main)
        let order = ["pasteAddressAction:", "sendToWalletAction:", "addToBatchAction:", "donateAction:"]
        let chips = order.compactMap { button(withAction: $0, in: actionsRow) }

        // Pull out what's kept; the old caption labels and icons are dropped.
        [balance, feeRate, target, address].forEach { detach($0) }
        if let infoButton = infoButton { detach(infoButton) }
        for row in [sliderRow, manualRow] {
            // "Set ETA" / "Set manually" labels.
            row.arrangedSubviews.filter { $0 is UILabel }.forEach { detach($0) }
        }
        actionsRow.arrangedSubviews.forEach { detach($0) }
        let originalRows = main.arrangedSubviews
        originalRows.forEach { detach($0) }

        // AMOUNT (the available balance gets its own full-width line under the field)
        let available = UILabel()
        available.text = "AVAILABLE"
        available.tag = Self.availableTag
        available.setContentHuggingPriority(.required, for: .horizontal)
        available.setContentCompressionResistancePriority(.required, for: .horizontal)
        balance.numberOfLines = 0
        balance.setContentCompressionResistancePriority(.required, for: .vertical)
        // "AVAILABLE" on one line, the balance itself on the next.
        let availableRow = UIStackView(arrangedSubviews: [available, balance])
        availableRow.axis = .vertical
        availableRow.alignment = .leading
        availableRow.spacing = 2
        let amountCaption = captionRow("> AMOUNT", trailing: [])

        // RECIPIENT
        address.numberOfLines = 0
        address.lineBreakMode = .byCharWrapping
        address.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        let recipientCaption = captionRow("> RECIPIENT", trailing: infoButton.map { [$0] } ?? [])

        // Chips in a sensible order: Paste, Wallet, Batch, Donate.
        chips.forEach { actionsRow.addArrangedSubview($0) }
        actionsRow.distribution = .fillEqually
        actionsRow.spacing = 6

        // FEE
        feeRate.textAlignment = .right
        let feeCaption = captionRow("> FEE", trailing: [feeRate])
        manualRow.spacing = 8

        // Fiat value of the entered amount (hidden until there's an amount and a rate).
        fiatAmountLabel.isHidden = true
        fiatAmountLabel.numberOfLines = 0
        
        // A little air between the navigation bar's bottom border and the first card.
        if let container = main.superview {
            for constraint in container.constraints where constraint.relation == .equal {
                if constraint.firstItem === main, constraint.firstAttribute == .top {
                    constraint.constant = max(constraint.constant, 12)
                } else if constraint.secondItem === main, constraint.secondAttribute == .top {
                    constraint.constant = min(constraint.constant, -12)
                }
            }
        }
        
        main.spacing = 12
        main.addArrangedSubview(card([amountCaption, amountRow, fiatAmountLabel, availableRow]))
        main.addArrangedSubview(card([recipientCaption, address, actionsRow]))
        main.addArrangedSubview(card([feeCaption, sliderRow, target, manualRow]))
    }

    /// "> CAPTION ……… trailing views"
    private func captionRow(_ title: String, trailing: [UIView]) -> UIStackView {
        let caption = UILabel()
        caption.text = title
        caption.tag = Self.captionTag
        caption.font = Self.captionFont
        caption.textColor = WalletTheme.Tint.send.accent
        caption.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [caption, spacer] + trailing)
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 6
        // Same height for every caption row, whatever sits on the right (the info button,
        // the fee rate, or nothing), so all three headers look identical.
        let height = row.heightAnchor.constraint(equalToConstant: Self.captionRowHeight)
        height.priority = .required
        height.isActive = true
        for view in trailing {
            view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            if let button = view as? UIButton {
                // Fit the icon to the row: no content insets (the storyboard's plain
                // configuration pads it, which clipped the symbol in a 24pt frame) and a
                // symbol sized for the row. Later theme passes only recolour it.
                if var config = button.configuration {
                    config.contentInsets = .zero
                    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)
                    config.title = nil
                    config.attributedTitle = nil
                    button.configuration = config
                }
                button.clipsToBounds = false
                button.widthAnchor.constraint(equalToConstant: Self.captionRowHeight + 4).isActive = true
                button.heightAnchor.constraint(equalToConstant: Self.captionRowHeight).isActive = true
            }
        }
        return row
    }

    /// Bordered card (square corners) holding `rows` (shared WalletTheme card).
    private func card(_ rows: [UIView]) -> UIView {
        let card = WalletTheme.cardView(rows, tint: .send)
        card.tag = Self.cardTag
        return card
    }

    /// Typography / chip styling on top of the theme (runs after WalletTheme.apply).
    fileprivate func styleCards() {
        let tint = WalletTheme.Tint.send
        guard let main = mainStack else { return }

        var stack: [UIView] = [main]
        while let current = stack.popLast() {
            if let label = current as? UILabel {
                switch label.tag {
                case Self.captionTag:   // captions (re-applied after the theme walker)
                    label.font = Self.captionFont
                    label.textColor = tint.accent
                case Self.availableTag: // "AVAILABLE"
                    label.font = WalletTheme.mono(10, weight: .semibold)
                    label.textColor = WalletTheme.dim
                default:
                    break
                }
            }
            stack.append(contentsOf: current.subviews)
        }

        balanceLabel.font = WalletTheme.mono(12)
        balanceLabel.textColor = WalletTheme.text
        balanceLabel.numberOfLines = 0             // wraps instead of clipping
        balanceLabel.lineBreakMode = .byWordWrapping
        balanceLabel.textAlignment = .left

        // The amount is the hero of the screen: large, bold, grouped like balances, with a
        // "BTC" unit tag. Large amounts shrink to fit instead of clipping.
        let amountFont = WalletTheme.mono(30, weight: .bold)
        amountInput.font = amountFont
        amountInput.textColor = tint.accent
        amountInput.keyboardType = .decimalPad
        amountInput.adjustsFontSizeToFitWidth = true
        amountInput.minimumFontSize = 14
        amountInput.attributedPlaceholder = NSAttributedString(string: "0.00 000 000",
                                                               attributes: [.foregroundColor: WalletTheme.dim.withAlphaComponent(0.6),
                                                                            .font: amountFont])
        amountInput.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        amountInput.layer.borderColor = tint.accent.withAlphaComponent(0.7).cgColor
        amountInput.backgroundColor = WalletTheme.bg
        
        let unit = UILabel()
        unit.text = "BTC "
        unit.font = WalletTheme.mono(13, weight: .bold)
        unit.textColor = WalletTheme.dim
        unit.sizeToFit()
        amountInput.rightView = unit
        amountInput.rightViewMode = .always
        
        // Re-group any amount already in the field (e.g. set before the view loaded).
        if let text = amountInput.text, !text.isEmpty {
            amountInput.text = Self.formatAmount(text.condenseWhitespace().replacingOccurrences(of: ",", with: ""))
        }
        
        fiatAmountLabel.font = WalletTheme.mono(14, weight: .semibold)
        fiatAmountLabel.textColor = WalletTheme.text
        updateFiatAmount()

        addressInput.font = WalletTheme.mono(13)
        addressInput.textColor = WalletTheme.text

        satPerByteLabel.font = WalletTheme.mono(13, weight: .semibold)
        satPerByteLabel.textColor = tint.accent
        miningTargetLabel.font = WalletTheme.mono(11)
        miningTargetLabel.textColor = WalletTheme.dim

        feeRateInputField.font = WalletTheme.mono(13)
        feeRateInputField.attributedPlaceholder = NSAttributedString(string: "custom sat/vB (optional)",
                                                                     attributes: [.foregroundColor: WalletTheme.dim,
                                                                                  .font: WalletTheme.mono(13)])

        // Compact chips.
        let chips: [(action: String, title: String, symbol: String)] = [
            ("pasteAddressAction:", "PASTE", "doc.on.clipboard"),
            ("sendToWalletAction:", "WALLET", "wallet.pass"),
            ("addToBatchAction:", "BATCH", "plus.rectangle.on.rectangle"),
            ("donateAction:", "DONATE", "heart")
        ]
        for chip in chips {
            guard let button = button(withAction: chip.action, in: main) else { continue }
            button.configuration = chipConfiguration(title: chip.title, symbol: chip.symbol, tint: tint)
        }

        // MAX: a quiet text link beside the amount, not a full-height button. The storyboard
        // gives it a fixed 100pt width and the row stretches it to the field's height.
        if let maxButton = button(withAction: "sweep:", in: main) {
            maxButton.constraints
                .filter { $0.firstAttribute == .width && $0.secondItem == nil }
                .forEach { $0.isActive = false }
            maxButton.configuration = maxConfiguration()
            maxButton.setContentHuggingPriority(.required, for: .horizontal)
            maxButton.setContentCompressionResistancePriority(.required, for: .horizontal)
            (maxButton.superview as? UIStackView)?.alignment = .center
        }
    }

    private func maxConfiguration() -> UIButton.Configuration {
        var config = UIButton.Configuration.plain()
        config.title = "MAX"
        config.titleLineBreakMode = .byClipping
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 2)
        config.baseForegroundColor = WalletTheme.dim
        config.background.backgroundColor = .clear
        config.background.strokeWidth = 0
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(11, weight: .semibold)
            return attributes
        }
        return config
    }

    /// Shows "≈ <fiat>" for the entered BTC amount (reference only), or hides the line when
    /// there's no amount or no exchange rate.
    func updateFiatAmount() {
        let btc = (amountInput?.text ?? "").condenseWhitespace().doubleValue
        guard btc > 0, let rate = fxRate, rate > 0 else {
            fiatAmountLabel.text = nil
            fiatAmountLabel.isHidden = true
            return
        }
        fiatAmountLabel.text = "≈ " + (btc * rate).fiatString
        fiatAmountLabel.isHidden = false
    }

    private func chipConfiguration(title: String, symbol: String, tint: WalletTheme.Tint) -> UIButton.Configuration {
        WalletTheme.chipConfiguration(title: title,
                                      systemImage: symbol,
                                      tint: tint,
                                      fontSize: 10,
                                      imageSize: 10,
                                      imagePadding: 4,
                                      insets: NSDirectionalEdgeInsets(top: 7, leading: 6, bottom: 7, trailing: 6),
                                      background: WalletTheme.bg,
                                      clipsTitle: true)
    }
}
