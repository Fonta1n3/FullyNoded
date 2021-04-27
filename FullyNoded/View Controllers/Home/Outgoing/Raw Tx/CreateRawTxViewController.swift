//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var isFiat = false
    var isBtc = true
    var isSats = false
    var fxRate = Double()
    var spendable = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var address = String()
    var amount = String()
    var outputs = [Any]()
    var inputArray = [Any]()
    var inputsString = ""
    var outputsString = ""
    var txt = ""
    var utxoTotal = 0.0
    let ud = UserDefaults.standard
    var alertStyle = UIAlertController.Style.actionSheet
    
    @IBOutlet weak private var miningTargetLabel: UILabel!
    @IBOutlet weak private var satPerByteLabel: UILabel!
    @IBOutlet weak private var sweepButton: UIStackView!
    @IBOutlet weak private var segmentedControlOutlet: UISegmentedControl!
    @IBOutlet weak private var fiatButtonOutlet: UIButton!
    @IBOutlet weak private var fxRateLabel: UILabel!
    @IBOutlet weak private var denominationImage: UIImageView!
    @IBOutlet weak private var amountIcon: UIView!
    @IBOutlet weak private var addressIcon: UIView!
    @IBOutlet weak private var recipientBackground: UIView!
    @IBOutlet weak private var amountBackground: UIView!
    @IBOutlet weak private var sliderViewBackground: UIView!
    @IBOutlet weak private var feeIconBackground: UIView!
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
    @IBOutlet weak private var addressImageView: UIImageView!
    @IBOutlet weak private var feeRateInputField: UITextField!
    
    
    var spinner = ConnectingView()
    var spendableBalance = Double()
    var outputArray = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        outputsTable.delegate = self
        feeRateInputField.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        addressImageView.alpha = 0
        slider.isContinuous = false
        addTapGesture()
        
        sliderViewBackground.layer.cornerRadius = 8
        sliderViewBackground.layer.borderColor = UIColor.darkGray.cgColor
        sliderViewBackground.layer.borderWidth = 0.5
        
        amountBackground.layer.cornerRadius = 8
        amountBackground.layer.borderColor = UIColor.darkGray.cgColor
        amountBackground.layer.borderWidth = 0.5
        
        recipientBackground.layer.cornerRadius = 8
        recipientBackground.layer.borderColor = UIColor.darkGray.cgColor
        recipientBackground.layer.borderWidth = 0.5
        
        amountIcon.layer.cornerRadius = 5
        feeIconBackground.layer.cornerRadius = 5
        addressIcon.layer.cornerRadius = 5
        
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
        
        if ud.object(forKey: "unit") != nil {
            let unit = ud.object(forKey: "unit") as! String
            var index = 0
            switch unit {
            case "btc":
                index = 0
                isBtc = true
                isFiat = false
                isSats = false
                btcEnabled()
            case "sats":
                index = 1
                isSats = true
                isFiat = false
                isBtc = false
                satsSelected()
            case "fiat":
                index = 2
                isFiat = true
                isBtc = false
                isSats = false
                fiatEnabled()
            default:
                break
            }
            DispatchQueue.main.async { [unowned vc = self] in
                vc.segmentedControlOutlet.selectedSegmentIndex = index
            }
        } else {
            isBtc = true
            isFiat = false
            isSats = false
            btcEnabled()
            DispatchQueue.main.async { [unowned vc = self] in
                vc.segmentedControlOutlet.selectedSegmentIndex = 0
            }
        }
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        
        showFeeSetting()
        slider.addTarget(self, action: #selector(didFinishSliding(_:)), for: .valueChanged)
    }
    
    @IBAction func closeFeeRate(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UserDefaults.standard.removeObject(forKey: "feeRate")
            self.feeRateInputField.text = ""
            self.feeRateInputField.endEditing(true)
        }
    }
    
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let item = UIPasteboard.general.string else { return }
        
        if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") {
            decodeLighnting(invoice: item.replacingOccurrences(of: "lightning:", with: ""))
        } else if item.hasPrefix("bitcoin:") || item.hasPrefix("BITCOIN:") {
            processBIP21(url: item)
        } else {
            switch item {
            case _ where item.hasPrefix("1"),
                 _ where item.hasPrefix("3"),
                 _ where item.hasPrefix("tb1"),
                 _ where item.hasPrefix("bc1"),
                 _ where item.hasPrefix("2"),
                 _ where item.hasPrefix("bcrt"),
                 _ where item.hasPrefix("m"),
                 _ where item.hasPrefix("n"),
                 _ where item.hasPrefix("lntb"):
                processBIP21(url: item)
            default:
                showAlert(vc: self, title: "", message: "This button is for pasting lightning invoices, bitcoin addresses and bip21 invoices")
            }
        }
    }
    
    @IBAction func createOnchainAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.rawTxSigned = ""
            self.rawTxUnsigned = ""
            self.amountInput.resignFirstResponder()
            self.addressInput.resignFirstResponder()
            self.tryRaw()
        }
    }
    
    @IBAction func lightningWithdrawAction(_ sender: Any) {
        guard let item = addressInput.text, item != "" else {
            promptToWithdrawalFromLightning()
            return
        }
        
        if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") {
            decodeLighnting(invoice: item.replacingOccurrences(of: "lightning:", with: ""))
        } else {
            promptToWithdrawalFromLightning()
        }
    }
    
    @IBAction func addToBatchAction(_ sender: Any) {
        guard var amount = amountInput.text, amount != "", let address = addressInput.text, address != "" else {
            
            showAlert(vc: self, title: "", message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
            return
        }
        
        let dblAmount = amount.doubleValue
        
        guard dblAmount > 0.0 else {
            showAlert(vc: self, title: "Amount needs to be greater the 0", message: "")
            return
        }
        
        if isFiat {
            amount = "\(rounded(number: dblAmount / fxRate).avoidNotation)"
        } else if isSats {
            amount = "\(rounded(number: dblAmount / 100000000.0).avoidNotation)"
        }
        
        outputArray.append(["address":addressInput.text!, "amount":amount] as [String : String])
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.outputsTable.alpha = 1
            self.amountInput.text = ""
            self.addressInput.text = ""
            self.outputsTable.reloadData()
        }
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        if inputArray.count > 0 {
            showAlert(vc: self, title: "Coin control ✓", message: "Only the utxo's you have just selected will be used in this transaction. You may sweep the total balance of the selected utxo's by tapping the sweep button or enter a custom amount as normal.")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        outputsString = ""
        outputArray.removeAll()
        inputArray.removeAll()
        inputsString = ""
    }
    
    private func promptToWithdrawalFromLightning() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Withdraw from lightning wallet?", message: "This action will withdraw the amount specified to the given address from your lightning wallet", preferredStyle: self.alertStyle)
            alert.addAction(UIAlertAction(title: "Withdraw now", style: .default, handler: { action in
                self.withdrawLightningSanity()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func withdrawLightningSanity() {
        guard let amountString = amountInput.text, amountString != "", let address = addressInput.text, address != "" else {
            showAlert(vc: self, title: "Oops", message: "Add an amount and address first")
            return
        }
                
        confirmLightningWithdraw(address, amountString.doubleValue)
    }
    
    private func confirmLightningWithdraw(_ address: String, _ amount: Double) {
        var title = ""
        var sats = Int()
        
        let amountString = amountInput.text ?? ""
        let dblAmount = amountString.doubleValue
        
        if isFiat {
            let btcamount = rounded(number: amount / fxRate)
            sats = Int(btcamount * 100000000.0)
            title = "Withdraw $\(dblAmount) USD (\(sats) sats) from lightning wallet to \(address)?"
            
        } else if isSats {
            sats = Int(dblAmount)
            title = "Withdraw \(dblAmount) sats from lightning wallet to \(address)?"
            
        } else {
            sats = Int(amount * 100000000.0)
            title = "Withdraw \(amount.avoidNotation) btc (\(sats) sats) from lightning wallet to \(address)?"
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: title, message: "This action is not reversable!", preferredStyle: self.alertStyle)
            alert.addAction(UIAlertAction(title: "Withdraw now", style: .default, handler: { action in
                self.withdrawLightningNow(address: address, sats: sats)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func withdrawLightningNow(address: String, sats: Int) {
        spinner.addConnectingView(vc: self, description: "withdrawing from lightning wallet...")
        
        let param = "\"\(address)\", \(sats)"
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .withdraw, param: param) { [weak self] (uuid, response, errorDesc) in
            guard commandId == uuid, let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response as? NSDictionary, let _ = dict["txid"] as? String else {
                showAlert(vc: self, title: "Uh oh, somehting is not right", message: errorDesc ?? "unknow error")
                return
            }
            
            showAlert(vc: self, title: "Success ✅", message: "⚡️ Lightning wallet withdraw to \(address) completed ⚡️")
        }
    }
    
    
    @IBAction func fundLightning(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "fetching lightning funding address...")
        
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .newaddr, param: "") { [weak self] (uuid, response, errorDesc) in
            guard commandId == uuid, let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response as? NSDictionary, let address = dict["address"] as? String else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error fetching lightning wallet address")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.addressInput.text = address
                
                showAlert(vc: self, title: "⚡️ Nice! ⚡️", message: "This is an address you can use to fund your lightning node with, its your first step in transacting on the lightning network.")
            }
        }
    }
    
    @IBAction func denominationChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex {
        case 0:
            isFiat = false
            isBtc = true
            isSats = false
            ud.set("btc", forKey: "unit")
            btcEnabled()
        case 1:
            isFiat = false
            isBtc = false
            isSats = true
            ud.set("sats", forKey: "unit")
            satsSelected()
        case 2:
            isFiat = true
            isBtc = false
            isSats = false
            ud.set("fiat", forKey: "unit")
            fiatEnabled()
        default:
            break
        }
    }
    
    private func satsSelected() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.denominationImage.image = UIImage(systemName: "s.circle")
            vc.amountIcon.backgroundColor = .systemPurple
            vc.spinner.removeConnectingView()
        }
    }
    
    private func btcEnabled() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.denominationImage.image = UIImage(systemName: "bitcoinsign.circle")
            vc.amountIcon.backgroundColor = .systemIndigo
            vc.spinner.removeConnectingView()
        }
    }
    
    private func fiatEnabled() {
        spinner.addConnectingView(vc: self, description: "getting fx rate...")
        
        FiatConverter.sharedInstance.getFxRate { [weak self] (fxrate) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let fxrate = fxrate else {
                showAlert(vc: self, title: "Error", message: "Could not get current fx rate")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRate = fxrate
                self.fxRateLabel.text = "$\(fxrate.withCommas()) / btc"
                self.denominationImage.image = UIImage(systemName: "dollarsign.circle")
                self.amountIcon.backgroundColor = .systemBlue
                
                if UserDefaults.standard.object(forKey: "fiatAlert") == nil {
                    showAlert(vc: self, title: "$USD denomination", message: "You may enter an amount denominated in USD, we will calculate the equivalent amount in BTC based on the current exchange rate of $\(fxrate.withCommas())")
                    UserDefaults.standard.set(true, forKey: "fiatAlert")
                }
            }
        }
    }
    
    @IBAction func createPsbt(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreatePsbt", sender: vc)
        }
    }
    
    @IBAction func makeADonationAction(_ sender: Any) {
        if let address = Keys.donationAddress() {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.addressInput.text = address
                vc.addressImageView.image = LifeHash.image(address)
                vc.addressImageView.alpha = 1
                showAlert(vc: vc, title: "Thank you!", message: "A donation address has automatically been added so you may build a transaction which will fund further development of Fully Noded.")
            }
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
        return outputArray.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = view.backgroundColor
        if outputArray.count > 0 {
            if outputArray.count > 1 {
                tableView.separatorColor = .darkGray
                tableView.separatorStyle = .singleLine
            }
            let address = outputArray[indexPath.row]["address"]!
            let amount = outputArray[indexPath.row]["amount"]!
            cell.textLabel?.text = "\n#\(indexPath.row + 1)\n\nSending: \(String(describing: amount))\n\nTo: \(String(describing: address))"
            cell.textLabel?.textColor = .lightGray
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
            
            if self.inputArray.count > 0 {
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
        
        var param = ""
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
            param = "''\(processInputs())'', ''{\"\(receivingAddress)\":\(rounded(number: utxoTotal))}'', 0, ''{\"includeWatching\": \(true), \"replaceable\": true, \"fee_rate\": \(feeRate), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
        } else {
            param = "''\(processInputs())'', ''{\"\(receivingAddress)\":\(rounded(number: utxoTotal))}'', 0, ''{\"includeWatching\": \(true), \"replaceable\": true, \"conf_target\": \(ud.object(forKey: "feeTarget") as? Int ?? 432), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
        }
        
                
        Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                self.spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                return
            }
            
            Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt1)\"") { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let dict = response as? NSDictionary, let processedPSBT = dict["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                Signer.sign(psbt: processedPSBT) { [weak self] (psbt, rawTx, errorMessage) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    
                    guard let rawTx = rawTx else {
                        
                        guard let psbt = psbt else {
                            showAlert(vc: self, title: "Error creating transaction", message: errorMessage ?? "unknown")
                            return
                        }
                        
                        self.rawTxUnsigned = psbt
                        self.showRaw(raw: psbt)
                        
                        return
                    }
                    
                    self.rawTxSigned = rawTx
                    self.showRaw(raw: rawTx)
                }
            }
        }
    }
    
    private func sweepWallet(_ receivingAddress: String) {
        Reducer.makeCommand(command: .listunspent, param: "0") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let resultArray = response as? NSArray else {
                self.spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "error fetching utxo's")
                return
            }
            
            var inputArray = [Any]()
            var inputs = ""
            var amount = Double()
            var spendFromCold = Bool()
            
            for utxo in resultArray {
                let utxoDict = utxo as! NSDictionary
                let confs = utxoDict["confirmations"] as! Int
                let txid = utxoDict["txid"] as! String
                let vout = "\(utxoDict["vout"] as! Int)"
                let spendable = utxoDict["spendable"] as! Bool
                
                if !spendable {
                    spendFromCold = true
                }
                
                amount += utxoDict["amount"] as! Double
                let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                
                guard confs > 0 else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Ooops", message: "You have unconfirmed utxo's, wait till they get a confirmation before trying to sweep them.")
                    return
                }
                
                inputArray.append(input)
            }
            
            inputs = inputArray.description
            inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
            inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
            inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
            inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
            inputs = inputs.replacingOccurrences(of: "\\", with: "")
            
            var param = ""
            
            if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {
                param = "''\(inputs)'', ''{\"\(receivingAddress)\":\(rounded(number: amount))}'', 0, ''{\"includeWatching\": \(spendFromCold), \"replaceable\": true, \"fee_rate\": \(feeRate), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
            } else {
                param = "''\(inputs)'', ''{\"\(receivingAddress)\":\(rounded(number: amount))}'', 0, ''{\"includeWatching\": \(spendFromCold), \"replaceable\": true, \"conf_target\": \(self.ud.object(forKey: "feeTarget") as? Int ?? 432), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
            }
                        
            Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt1)\"") { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard let dict = response as? NSDictionary, let processedPSBT = dict["psbt"] as? String else {
                        self.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                        return
                    }
                    
                    Signer.sign(psbt: processedPSBT) { [weak self] (psbt, rawTx, errorMessage) in
                        guard let self = self else { return }
                        
                        self.spinner.removeConnectingView()
                        
                        if psbt != nil {
                            self.rawTxUnsigned = psbt!
                            self.showRaw(raw: psbt!)
                        } else if rawTx != nil {
                            self.rawTxSigned = rawTx!
                            self.showRaw(raw: rawTx!)
                        } else if errorMessage != nil {
                            showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown signing error")
                        }
                    }
                }
            }
        }
    }
    
    private func sweep() {
        guard let receivingAddress = addressInput.text, receivingAddress != "" else {
            showAlert(vc: self, title: "Add an address first", message: "")
            return
        }
        
        if inputArray.count > 0 {
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
    
    private func processInputs() -> String {
        if inputArray.count > 0 {
            var processed = inputArray.description
            processed = processed.replacingOccurrences(of: "[\"", with: "[")
            processed = processed.replacingOccurrences(of: "\"]", with: "]")
            processed = processed.replacingOccurrences(of: "\"{", with: "{")
            processed = processed.replacingOccurrences(of: "}\"", with: "}")
            return processed.replacingOccurrences(of: "\\", with: "")
        } else {
            return ""
        }
    }
    
    @objc func tryRaw() {
        spinner.addConnectingView(vc: self, description: "creating psbt...")
        
        func convertOutputs() {
            for output in outputArray {
                if let amount = output["amount"] {
                    if let address = output["address"] {
                        if address != "" {
                            outputs.append([address:amount.doubleValue])
                        }
                    }
                }
            }
            
            if inputArray.count > 0 {
                self.inputsString = processInputs()
            }
            
            outputsString = outputs.description
            outputsString = outputsString.replacingOccurrences(of: "[", with: "")
            outputsString = outputsString.replacingOccurrences(of: "]", with: "")
            getRawTx()
        }
        
        if outputArray.count == 0 {
            if self.amountInput.text != "" && self.amountInput.text != "0.0" && self.addressInput.text != "" {
                var amount = amountInput.text ?? ""
                amount = amount.replacingOccurrences(of: ",", with: "")
                let dblAmount = amount.doubleValue
                
                if isFiat {
                    amount = "\(rounded(number: dblAmount / fxRate).avoidNotation)"
                } else if isSats {
                    amount = "\(rounded(number: dblAmount / 100000000).avoidNotation)"
                }
                
                let dict = ["address":addressInput.text!, "amount":amount] as [String : String]
                outputArray.append(dict)
                convertOutputs()
                
            } else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "You need to fill out an amount and a recipient")
            }
            
        } else if outputArray.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            spinner.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputArray.count > 0 {
            convertOutputs()
            
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
    
    func textFieldDidChangeSelection(_ textField: UITextField) {
        guard textField == amountInput, let text = textField.text else { return }
        
        if text.doubleValue > 0.0 {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 0
            }
        } else {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 1
            }
        }
        
        if text == "" {
            DispatchQueue.main.async {
                self.sweepButton.alpha = 1
            }
        }
    }
    
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
    
    private func decodeLighnting(invoice: String) {
        spinner.addConnectingView(vc: self, description: "decoding lightning invoice...")
        
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .decodepay, param: "\"\(invoice)\"") { [weak self] (uuid, response, errorDesc) in
            guard let self = self, commandId == uuid else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response as? NSDictionary else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                return
            }
            
            if let _ = dict["msatoshi"] as? Int {
                self.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: nil)
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    guard let amountText = self.amountInput.text, amountText != "" else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Oops", message: "You need to enter an amount to send for an invoice that does not include one.")
                        return
                    }
                    
                    let dblAmount = amountText.doubleValue
                    
                    guard dblAmount > 0.0 else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Oops", message: "You need to enter an amount to send for an invoice that does not include one.")
                        return
                    }
                    
                    if self.isFiat {
                        let btcamount = rounded(number: dblAmount / self.fxRate)
                        let msats = Int(btcamount * 100000000000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                        
                    } else if self.isSats {
                        let msats = Int(dblAmount * 1000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                        
                    } else {
                        let msats = Int(dblAmount * 100000000000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                        
                    }
                }
            }
        }
    }
    
    private func promptToSendLightningPayment(invoice: String, dict: String, msat: Int?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Pay lightning invoice?", message: dict, preferredStyle: self.alertStyle)
            alert.addAction(UIAlertAction(title: "Pay now", style: .default, handler: { action in
                self.payLightningNow(invoice: invoice, msat: msat)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func payLightningNow(invoice: String, msat: Int?) {
        var params = ""
        
        spinner.addConnectingView(vc: self, description: "paying lightning invoice...")
        
        if msat != nil {
            params = "\"\(invoice)\", \(msat!)"
        } else {
            params = "\"\(invoice)\""
        }
        
        let commandId = UUID()
        
        LightningRPC.command(id: commandId, method: .pay, param: params) { [weak self] (uuid, response, errorDesc) in
            guard let self = self, commandId == uuid else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response as? NSDictionary else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                return
            }
            
            guard let status = dict["status"] as? String, status == "complete" else {
                if let message = dict["message"] as? String {
                    showAlert(vc: self, title: "Message", message: message)
                } else {
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                }
                return
            }
            
            guard let msatInt = dict["msatoshi"] as? Int, let msatSentInt = dict["msatoshi_sent"] as? Int else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error converting amounts")
                return
            }
            
            showAlert(vc: self, title: "Success ✅", message: "Lightning payment completed!\n\nAmount paid \(Double(msatInt) / 1000.0) sats for a fee of \(Double((msatSentInt - msatInt)) / 1000.0) sats")
        }
    }
    
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
            
            self.addressInput.text = address
            
            let lifehash = LifeHash.image(address)
            self.addressImageView.image = lifehash
            self.addressImageView.alpha = 1
            
            if amount != nil || label != nil || message != nil {
                var amountText = "not specified"
                
                if amount != nil {
                    amountText = amount!.avoidNotation
                    self.amountInput.text = amountText
                    self.segmentedControlOutlet.selectedSegmentIndex = 0
                    self.isFiat = false
                    self.isBtc = true
                    self.isSats = false
                    self.ud.set("btc", forKey: "unit")
                    self.btcEnabled()
                }
                
                showAlert(vc: self, title: "BIP21 Invoice\n", message: "Address: \(address)\n\nAmount: \(amountText) btc\n\nLabel: " + (label ?? "no label") + "\n\nMessage: \((message ?? "no message"))")
            }
        }
    }
    
    func getRawTx() {
        CreatePSBT.create(inputs: processInputs(), outputs: outputsString) { [weak self] (psbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            if psbt != nil {
                self.rawTxUnsigned = psbt!
                self.showRaw(raw: psbt!)
                
            } else if rawTx != nil {
                self.rawTxSigned = rawTx!
                self.showRaw(raw: rawTx!)
                
            } else {
                self.outputs.removeAll()
                self.outputsString = ""
                self.outputArray.removeAll()
                
                DispatchQueue.main.async {
                    self.outputsTable.reloadData()
                }
                
                showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error creating transaction")
            }
        }
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
            
            vc.onAddressDoneBlock = { addrss in
                guard let addrss = addrss else { return }
                
                DispatchQueue.main.async { [unowned thisVc = self] in
                    if addrss.hasPrefix("lntb") || addrss.hasPrefix("lightning:") || addrss.hasPrefix("lnbc") || addrss.hasPrefix("lnbcrt") {
                        thisVc.decodeLighnting(invoice: addrss.replacingOccurrences(of: "lightning:", with: ""))
                    } else {
                        thisVc.processBIP21(url: addrss)
                    }
                }
            }
            
        case "segueToBroadcaster":
            guard let vc = segue.destination as? VerifyTransactionViewController else { fallthrough }
            
            vc.hasSigned = true
            
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

//fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
//    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
//}
//
//// Helper function inserted by Swift 4.2 migrator.
//fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
//    return input.rawValue
//}

