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
    var spendable = Double()
    var rawTx: String?
    var address = String()
    var amount = String()
    var outputs: [[String:Any]] = []
    var inputs: [[String:Any]] = []
    var txt = ""
    var utxoTotal: Double = 0.0
    let ud = UserDefaults.standard
    var index = 0
    var invoice:[String:Any]?
    var invoiceString = ""
    let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    var balance = ""
    var psbt: String?
    var utxoToSweep: UTXO?
    
    
    @IBOutlet weak private var addressInput: UILabel!
    @IBOutlet weak private var createOutlet: UIButton!
    @IBOutlet weak private var balanceLabel: UILabel!
    @IBOutlet weak private var batchOutlet: UIButton!
    @IBOutlet weak private var miningTargetLabel: UILabel!
    @IBOutlet weak private var satPerByteLabel: UILabel!
    @IBOutlet weak private var fiatButtonOutlet: UIButton!
    @IBOutlet weak private var fxRateLabel: UILabel!
    @IBOutlet weak private var denominationImage: UIImageView!
    @IBOutlet weak private var slider: UISlider!
    @IBOutlet weak private var addOutputOutlet: UIBarButtonItem!
    @IBOutlet weak private var playButtonOutlet: UIBarButtonItem!
    @IBOutlet weak private var amountInput: UITextField!
    @IBOutlet weak private var amountLabel: UILabel!
    @IBOutlet weak private var actionOutlet: UIButton!
    @IBOutlet weak private var scanOutlet: UIButton!
    @IBOutlet weak private var receivingLabel: UILabel!
    @IBOutlet weak private var outputsTable: UITableView!
    @IBOutlet weak private var feeRateInputField: UITextField!
    
    let spinner = ConnectingView.shared
    var spendableBalance = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        outputsTable.delegate = self
        feeRateInputField.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        slider.isContinuous = false
        createOutlet.layer.cornerRadius = 8
        createOutlet.clipsToBounds = true
        
        if let fxRate = fxRate {
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
    }
    
    @IBAction func sendToWalletAction(_ sender: Any) {
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
        spinner.show(vc: self, description: "getting address from \(walletToFetchFrom.label)...")
        
        guard let currentActiveWallet = UserDefaults.standard.object(forKey: "walletName") else { return }
        
        // Temporarily set the active wallet to the wallet we are deriving an address from.
        UserDefaults.standard.set(walletToFetchFrom.name, forKey: "walletName")
        
        let addressType = Descriptor(walletToFetchFrom.receiveDescriptor).addressType
        
        let p = Get_New_Address(["address_type": addressType])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            UserDefaults.standard.set(currentActiveWallet, forKey: "walletName")
            spinner.dismiss()
            
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
            showAlert(vc: self, title: "Address added from \(wallet.label) ✓", message: "Tap the info button to get more details.")
        }
    }
    
    @IBAction func showAddressInfoAction(_ sender: Any) {
        guard let address = addressInput.text, address != "", address != "Paste or scan an address or invoice." else {
            showAlert(vc: self, title: "", message: "Not a valid address or invoice.")
            return
        }
        spinner.show(vc: self, description: "")
        OnchainUtils.getAddressInfo(address: address.replacingOccurrences(of: "-", with: "")) { [weak self] (addressInfo, message) in
            guard let self = self else { return }
            
            spinner.dismiss()
            
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.amountInput.resignFirstResponder()
            self.addressInput.resignFirstResponder()
        }
        
        guard let _ = addressInput.text?.replacingOccurrences(of: "-", with: "") else {
            showAlert(vc: self, title: "", message: "Enter an address or invoice.")
            return
        }
        
        guard let _ = convertedAmount() else {
            if !self.outputs.isEmpty {
                tryRaw()
            } else {
                spinner.dismiss()
                showAlert(vc: self, title: "", message: "No amount or address.")
            }
            return
        }
        
        tryRaw()
    }
    
    private func convertedAmount() -> String? {
        guard let amount = amountInput.text, amount != "" else { return nil }
        
        let dblAmount = amount.doubleValue
        
        guard dblAmount > 0.0 else {
            showAlert(vc: self, title: "", message: "Amount needs to be greater than 0.")
            return nil
        }
        
        return "\(dblAmount.avoidNotation)"
    }
    
    @IBAction func addToBatchAction(_ sender: Any) {
        guard let address = addressInput.text, address != "", let amount = convertedAmount() else {
            
            showAlert(vc: self,
                      title: "",
                      message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
            return
        }
        
        outputs.append([address.replacingOccurrences(of: "-", with: ""):amount])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.outputsTable.alpha = 1
            self.amountInput.text = ""
            self.addressInput.text = ""
            self.outputsTable.reloadData()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        if inputs.count > 0 {
            
            if let fxRate = fxRate {
                balanceLabel.text = utxoTotal.btcBalanceWithSpaces + " / " + (fxRate * utxoTotal).fiatString
            } else {
                balanceLabel.text = utxoTotal.btcBalanceWithSpaces
            }
            
            showAlert(vc: self, title: "Coin control ✓", message: "Only the utxo's you have just selected will be used in this transaction. You may send the total balance of the *selected utxo's* by tapping the \"Send all\" button or enter a custom amount as normal.")
        }
    }
    
    @IBAction func createPsbt(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreatePsbt", sender: vc)
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
    
    func updateFeeLabel(label: UILabel, numberOfBlocks: Int) {
        let seconds = ((numberOfBlocks * 10) * 60)
        
        func updateFeeSetting() {
            ud.set(numberOfBlocks, forKey: "feeTarget")
        }
        
        DispatchQueue.main.async {
            if seconds < 86400 {
                //less then a day
                if seconds < 3600 {
                    DispatchQueue.main.async {
                        //less then an hour
                        label.text = "Target: \(numberOfBlocks) blocks ~\(seconds / 60) minutes"
                    }
                } else {
                    DispatchQueue.main.async {
                        //more then an hour
                        label.text = "Target: \(numberOfBlocks) blocks ~\(seconds / 3600) hours"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    //more then a day
                    label.text = "Target: \(numberOfBlocks) blocks ~\(seconds / 86400) days"
                }
            }
            updateFeeSetting()
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
                spinner.dismiss()
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
                    spinner.dismiss()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                goVerifyPsbt(psbt: processedPSBT)
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
                    spinner.dismiss()
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
        
    private func sweepWallet(_ receivingAddress: String) {
        guard inputs.count == 0, utxoToSweep == nil else {
            sweepUtxos(utxosToSweep: [utxoToSweep!], receivingAddress: receivingAddress)
            return
        }
        
        let param: List_Unspent = .init(["minconf": 0])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listunspent(param)) { [weak self] response, errorDesc in
            guard let self else { return }

            guard let response = response as? [[String: Any]] else {
                spinner.dismiss()
                displayAlert(viewController: self, isError: true, message: errorDesc ?? "error fetching utxo's")
                return
            }

            let utxos = [UTXO].from(rawArray: response)
            sweepUtxos(utxosToSweep: utxos, receivingAddress: receivingAddress)
        }
    }
    
    private func goVerifyPsbt(psbt: String) {
        self.psbt = psbt
        showRaw()
    }
    
    private func sweep() {
        guard let receivingAddress = addressInput.text,
              receivingAddress != "" else {
            showAlert(vc: self, title: "Add an address first", message: "")
            return
        }
        spinner.show(vc: self, description: "sweeping wallet...")
        sweepWallet(receivingAddress.replacingOccurrences(of: "-", with: ""))
    }
    
    @IBAction func sweep(_ sender: Any) {
        promptToSweep()
    }
    
    func showRaw() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
        }
    }
    
    @objc func tryRaw() {
        spinner.show(vc: self, description: "creating psbt...")
        
        if outputs.count == 0 {
            if let amount = convertedAmount(), self.addressInput.text != "" {
                outputs.append([self.addressInput.text!.replacingOccurrences(of: "-", with: ""):amount])
                getRawTx()
                
            } else {
                spinner.dismiss()
                showAlert(vc: self, title: "", message: "You need to fill out an amount and a recipient")
            }
            
        } else if outputs.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            spinner.dismiss()
            displayAlert(viewController: self, isError: true, message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputs.count > 0 {
            getRawTx()
            
        } else {
            spinner.dismiss()
            showAlert(vc: self, title: "This is not right...", message: "Please reach out and let us know about this so we can fix it.")
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
        feeRateInputField.resignFirstResponder()
    }
    
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard textField == amountInput, let text = textField.text, string != "" else { return true }
        
        guard text.contains(".") else { return true }
        
        let arr = text.components(separatedBy: ".")
        
        guard arr.count > 0 else { return true }
        
        return arr[1].count < 8
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        
        if textField == addressInput && addressInput.text != "" {
            let address = addressInput.text!
            addressInput.text = address.addressExpanded
            processBIP21(url: address)
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
            
            guard let int = Int(text) else { return }
            
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
            let feeRate = UserDefaults.standard.object(forKey: "feeRate") as! Int
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
                    self.amountInput.text = amountText
                    self.ud.set("btc", forKey: "unit")
                }
                
                showAlert(vc: self, title: "BIP21 Invoice\n", message: "Address: \(address)\n\nAmount: \(amountText) btc\n\nLabel: " + (label ?? "no label") + "\n\nMessage: \((message ?? "no message"))")
            }
        }
    }
    
    func getRawTx() {
        CreatePSBT.create(inputs: self.inputs, outputs: self.outputs) { [weak self] (psbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.dismiss()
            
            if let rawTx = rawTx {
                self.rawTx = rawTx
                self.showRaw()
                
            } else if let psbt = psbt {
                self.psbt = psbt
                self.showRaw()
                
            } else {
                self.outputs.removeAll()
                DispatchQueue.main.async {
                    self.outputsTable.reloadData()
                }
                
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error creating transaction")
            }
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
            
        case "segueToBroadcaster":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.fxRate = fxRate
            
            if let rawTx = rawTx {
                vc.signedRawTx = rawTx
            } else if let psbt = psbt {
                vc.unsignedPsbt = psbt
            }
            outputs.removeAll()
            inputs.removeAll()
            addressInput.text = ""
            amountInput.text = ""
            
        default:
            break
        }
    }
}
