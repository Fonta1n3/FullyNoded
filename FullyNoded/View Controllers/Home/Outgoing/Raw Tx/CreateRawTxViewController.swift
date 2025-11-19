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
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var address = String()
    var amount = String()
    var outputs:[[String:Any]] = []
    var inputs:[[String:Any]] = []
    var txt = ""
    var utxoTotal: Decimal = 0.0
    let ud = UserDefaults.standard
    var index = 0
    var invoice:[String:Any]?
    var invoiceString = ""
    let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    var balance = ""
    
    
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
    @IBOutlet weak private var addressInput: UITextField!
    @IBOutlet weak private var amountLabel: UILabel!
    @IBOutlet weak private var actionOutlet: UIButton!
    @IBOutlet weak private var scanOutlet: UIButton!
    @IBOutlet weak private var receivingLabel: UILabel!
    @IBOutlet weak private var outputsTable: UITableView!
    @IBOutlet weak private var feeRateInputField: UITextField!
    @IBOutlet weak private var coinSelectionControl: UISegmentedControl!
    
    var spinner = ConnectingView()
    var spendableBalance = Double()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        outputsTable.delegate = self
        feeRateInputField.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        slider.isContinuous = false
        createOutlet.layer.cornerRadius = 8
        createOutlet.clipsToBounds = true
        
        if let fxRate = fxRate {
            balanceLabel.text = balance.doubleValue.btcBalanceWithSpaces + " / " + (fxRate * balance.doubleValue).fiatString
        } else {
            balanceLabel.text = balance.doubleValue.btcBalanceWithSpaces
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
                if wallet["id"] != nil {
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
    
    private func getAddressFromWallet(_ wallet: Wallet) {
        spinner.addConnectingView(vc: self, description: "getting address...")
        
        func getFromFnWallet() {
            let index = Int(wallet.index + 1)
            let param:Derive_Addresses = .init(["descriptor": wallet.receiveDescriptor, "range": [index, index]])
            OnchainUtils.deriveAddresses(param: param) { [weak self] (addresses, message) in
                guard let self = self else { return }
                self.spinner.removeConnectingView()
                guard let addresses = addresses, !addresses.isEmpty else {
                    showAlert(vc: self, title: "There was an issue getting an address from that wallet...", message: message ?? "Unknown error.")
                    return
                }
                self.addAdressNow(address: addresses[0], wallet: wallet)
            }
        }
        getFromFnWallet()
    }
    
    private func addAdressNow(address: String, wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addAddress("\(address)")
            
            OnchainUtils.getAddressInfo(address: address) { (addressInfo, message) in
                guard let addressInfo = addressInfo else { return }
                
                showAlert(vc: self, title: "Address added ✓", message: "Derived from \(wallet.label): \(addressInfo.desc), solvable: \(addressInfo.solvable)")
            }
        }
    }
    
    @IBAction func switchCoinSelectionAction(_ sender: Any) {
        switch coinSelectionControl.selectedSegmentIndex {
        case 0:
            showAlert(vc: self, title: "Standard", message: "This defaults to Bitcoin Core coin selection.")
        case 1:
            showAlert(vc: self, title: "Blind", message: "Blind psbts are designed to be joined with another user before broadcasting. They may be useful to gain a bit more privacy for your day to day transactions.")
        case 2:
            showAlert(vc: self, title: "Coinjoin", message: "Coinjoin psbts are designed to be joined with other users. Export the psbt encrypted to allow others to easily join. Only one input and one output will be added at a time. The amount sent should match the amount of your utxo or this will fail, the easiet way to do this is by tapping the right arrow button on a utxo and then selecting the sweep option.")
        default:
            break
        }
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
            
            addressInput.text = donationAddress
            showAlert(vc: self, title: "Thank you!", message: "Any amount you send to this address will help support Fully Noded and is greatly appreciated. ❤️")
        }
    }
    
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let item = UIPasteboard.general.string else { return }
        
        switch item {
        case _ where item.hasPrefix("1"),
             _ where item.hasPrefix("3"),
             _ where item.hasPrefix("tb1"),
             _ where item.hasPrefix("bc1"),
             _ where item.hasPrefix("2"),
             _ where item.hasPrefix("bcrt"),
             _ where item.hasPrefix("m"),
             _ where item.hasPrefix("n"),
            _ where item.lowercased().hasPrefix("bitcoin:"):
            processBIP21(url: item)
        default:
            showAlert(vc: self, title: "", message: "This button is for pasting bitcoin addresses and bip21 invoices.")
        }
    }
    
    @IBAction func createOnchainAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.rawTxSigned = ""
            self.rawTxUnsigned = ""
            self.amountInput.resignFirstResponder()
            self.addressInput.resignFirstResponder()
        }
        
        guard let addressInput = addressInput.text else {
            showAlert(vc: self, title: "", message: "Enter an address or invoice.")
            return
        }
        
            guard let amount = convertedAmount() else {
                if !self.outputs.isEmpty {
                    tryRaw()
                } else {
                    spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "No amount or address.")
                }
                return
            }
            
            switch coinSelectionControl.selectedSegmentIndex {
            case 0:
                tryRaw()
                
            case 1:
                createBlindNow(amount: amount.doubleValue, recipient: addressInput, strict: false)
                
            case 2:
                createBlindNow(amount: amount.doubleValue, recipient: addressInput, strict: true)
                
            default:
                break
            }
    }
    
    private func createBlindNow(amount: Double, recipient: String, strict: Bool) {
        var type = ""
        
        if strict {
            type = "coinjoin"
        } else {
            type = "blind"
        }
        
        spinner.addConnectingView(vc: self, description: "creating \(type) psbt...")
        
        BlindPsbt.getInputs(amountBtc: amount, recipient: recipient, strict: strict, inputsToJoin: nil) { [weak self] (psbt, error) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            if let error = error {
                showAlert(vc: self, title: "There was an issue creating the \(type) psbt.", message: error)
            } else if let psbt = psbt {
                self.rawTxUnsigned = psbt
                self.showRaw(raw: psbt)
            }
        }
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
                
        outputs.append([address:amount])
        
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
            
            let doubleUtxoValue = (utxoTotal as NSDecimalNumber).doubleValue
            
            if let fxRate = fxRate {
                balanceLabel.text = doubleUtxoValue.btcBalanceWithSpaces + " / " + (fxRate * doubleUtxoValue).fiatString
            } else {
                balanceLabel.text = doubleUtxoValue.btcBalanceWithSpaces
            }
            
            showAlert(vc: self, title: "Coin control ✓", message: "Only the utxo's you have just selected will be used in this transaction. You may send the total balance of the *selected utxo's* by tapping the \"Send all\" button or enter a custom amount as normal.")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        inputs.removeAll()
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
    
    private func sweepSelectedUtxos(_ receivingAddress: String) {
        standardSweep(receivingAddress)
    }
    
    private func standardSweep(_ receivingAddress: String) {
        var paramDict:[String:Any] = [:]
        paramDict["inputs"] = inputs
        paramDict["outputs"] = [[receivingAddress: "\(utxoTotal)"]]
        paramDict["bip32derivs"] = true
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {            
            paramDict["options"] = ["includeWatching": true, "replaceable": true, "fee_rate": feeRate, "subtractFeeFromOutputs": [0], "changeAddress": receivingAddress]
        } else {
            paramDict["options"] = ["includeWatching": true, "replaceable": true, "conf_target": ud.object(forKey: "feeTarget") as? Int ?? 432, "subtractFeeFromOutputs": [0], "changeAddress": receivingAddress]
        }
        
        let param:Wallet_Create_Funded_Psbt = .init(paramDict)
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletcreatefundedpsbt(param: param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                self.spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                return
            }
            
            let param_process:Wallet_Process_PSBT = .init(["psbt": psbt1])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: param_process)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let dict = response as? NSDictionary, let processedPSBT = dict["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                self.sign(psbt: processedPSBT)
            }
        }
    }
    
    private func sweepWallet(_ receivingAddress: String) {
       standardWalletSweep(receivingAddress)
    }
    
    private func standardWalletSweep(_ receivingAddress: String) {
        let param: List_Unspent = .init(["minconf": 0])
        OnchainUtils.listUnspent(param: param) { [weak self] (utxos, message) in
            guard let self = self else { return }
            
            guard let utxos = utxos else {
                self.spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: message ?? "error fetching utxo's")
                return
            }
            
            var inputArray:[[String:Any]] = []
            var amount = Double()
            var spendFromCold = Bool()
            
            for utxo in utxos {
                if !utxo.spendable! {
                    spendFromCold = true
                }
                
                amount += utxo.amount!
                
                guard utxo.confs! > 0 else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "You have unconfirmed utxo's, wait till they get a confirmation before trying to sweep them.")
                    return
                }
                
                inputArray.append(utxo.input)
            }
            
            var paramDict:[String:Any] = [:]
            var options:[String:Any] = [:]
            paramDict["inputs"] = inputArray
            paramDict["outputs"] = [[receivingAddress: "\((rounded(number: amount)))"]]
            paramDict["bip32derivs"] = true
            
            options["includeWatching"] = spendFromCold
            options["replaceable"] = true
            options["subtractFeeFromOutputs"] = [0]
            options["changeAddress"] = receivingAddress
            
            if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                options["fee_rate"] = feeRate
            } else {
                options["conf_target"] = self.ud.object(forKey: "feeTarget") as? Int ?? 432
            }
            
            paramDict["options"] = options
            
            let param:Wallet_Create_Funded_Psbt = .init(paramDict)
                        
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletcreatefundedpsbt(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                let process_param: Wallet_Process_PSBT = .init(["psbt": psbt1])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: process_param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard let dict = response as? NSDictionary, let processedPSBT = dict["psbt"] as? String else {
                        self.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                        return
                    }
                    
                    self.sign(psbt: processedPSBT)
                }
            }
        }
    }
    
    private func sign(psbt: String) {
        Signer.sign(psbt: psbt, passphrase: nil) { [weak self] (psbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            if rawTx != nil {
                self.rawTxSigned = rawTx!
                self.showRaw(raw: rawTx!)
                
            } else if psbt != nil {
                self.rawTxUnsigned = psbt!
                self.showRaw(raw: psbt!)
                
            } else if errorMessage != nil {
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown signing error")
            }
        }
    }
    
    private func sweep() {
        guard let receivingAddress = addressInput.text,
              receivingAddress != "" else {
                  showAlert(vc: self, title: "Add an address first", message: "")
                  return
              }
        
        if inputs.count > 0 {
            spinner.addConnectingView(vc: self, description: "sweeping selected utxo's...")
            sweepSelectedUtxos(receivingAddress)
        } else {
            
            spinner.addConnectingView(vc: self, description: "sweeping wallet...")
            sweepWallet(receivingAddress)
        }
    }
    
    @IBAction func sweep(_ sender: Any) {
        promptToSweep()
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToBroadcaster", sender: self)
        }
    }
    
    @objc func tryRaw() {
        spinner.addConnectingView(vc: self, description: "creating psbt...")
        
        if outputs.count == 0 {
            if let amount = convertedAmount(), self.addressInput.text != "" {
                outputs.append([self.addressInput.text!:amount])
                getRawTx()
                
            } else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "You need to fill out an amount and a recipient")
            }
            
        } else if outputs.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            spinner.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputs.count > 0 {
            getRawTx()
            
        } else {
            spinner.removeConnectingView()
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
            processBIP21(url: addressInput.text!)
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
        NodeLogic.estimateSmartFee { (response, errorMessage) in
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
        let (address, amount, label, message) = AddressParser.parse(url: url)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressInput.resignFirstResponder()
            self.amountInput.resignFirstResponder()
            
            guard let address = address else {
                showAlert(vc: self, title: "Not compatible.", message: "FN does not support Bitpay.")
                return
            }
            
            self.addAddress(address)
            
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
        
        func createNow() {
            CreatePSBT.create(inputs: self.inputs, outputs: self.outputs) { [weak self] (psbt, rawTx, errorMessage) in
                guard let self = self else { return }
                
                self.spinner.removeConnectingView()
                
                if rawTx != nil {
                    self.rawTxSigned = rawTx!
                    self.showRaw(raw: rawTx!)
                
                } else if psbt != nil {
                    self.rawTxUnsigned = psbt!
                    self.showRaw(raw: psbt!)
                                    
                } else {
                    self.outputs.removeAll()
                    DispatchQueue.main.async {
                        self.outputsTable.reloadData()
                    }
                    
                    showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error creating transaction")
                }
            }
        }
        createNow()
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == addressInput {
            if textField.text != "" {
                textField.becomeFirstResponder()
            } else {
                if let string = UIPasteboard.general.string {
                    textField.becomeFirstResponder()
                    textField.text = string
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned vc = self] in
                        textField.resignFirstResponder()
                        vc.processBIP21(url: string)
                    }
                } else {
                    textField.becomeFirstResponder()
                }
            }
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
            
            vc.hasSigned = true
            vc.fxRate = fxRate
            
            if rawTxSigned != "" {
                vc.signedRawTx = rawTxSigned
            } else if rawTxUnsigned != "" {
                vc.unsignedPsbt = rawTxUnsigned
            }
            
            
        default:
            break
        }
    }
}
