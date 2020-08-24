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
    var stringToExport = ""
    var spendable = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    var stringURL = String()
    var address = String()
    var amount = String()
    var outputs = [Any]()
    var outputsString = ""
    let ud = UserDefaults.standard
    
    
    @IBOutlet weak var segmentedControlOutlet: UISegmentedControl!
    @IBOutlet weak var fiatButtonOutlet: UIButton!
    @IBOutlet weak var fxRateLabel: UILabel!
    @IBOutlet weak var denominationImage: UIImageView!
    @IBOutlet weak var amountIcon: UIView!
    @IBOutlet weak var addressIcon: UIView!
    @IBOutlet weak var recipientBackground: UIView!
    @IBOutlet weak var amountBackground: UIView!
    @IBOutlet weak var sliderViewBackground: UIView!
    @IBOutlet weak var feeIconBackground: UIView!
    @IBOutlet weak var miningTargetLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var addOutputOutlet: UIBarButtonItem!
    @IBOutlet weak var playButtonOutlet: UIBarButtonItem!
    @IBOutlet var amountInput: UITextField!
    @IBOutlet var addressInput: UITextField!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var actionOutlet: UIButton!
    @IBOutlet var scanOutlet: UIButton!
    @IBOutlet var receivingLabel: UILabel!
    @IBOutlet var outputsTable: UITableView!
    
    var spinner = ConnectingView()
    var spendableBalance = Double()
    var outputArray = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        outputsTable.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
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
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if let item = UIPasteboard.general.string {
            if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") {
                decodeLighnting(invoice: item.replacingOccurrences(of: "lightning:", with: ""))
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        outputsString = ""
        outputArray.removeAll()
    }
    
    @IBAction func withdrawalFromLightningAction(_ sender: Any) {
        if addressInput.text != "" {
            let item = addressInput.text!
            if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") {
                decodeLighnting(invoice: item.replacingOccurrences(of: "lightning:", with: ""))
            } else {
                promptToWithdrawalFromLightning()
            }
        } else {
            promptToWithdrawalFromLightning()
        }
    }
    
    private func promptToWithdrawalFromLightning() {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Withdraw from lightning wallet?", message: "This action will withdraw the amount specified to the given address from your lightning wallet", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Withdraw now", style: .default, handler: { action in
                vc.withdrawLightningSanity()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func withdrawLightningSanity() {
        if amountInput.text != "" {
            if let dbl = Double(amountInput.text!) {
                if addressInput.text != "" {
                    confirmLightningWithdraw(address: addressInput.text!, amount: dbl)
                } else {
                    showAlert(vc: self, title: "Oops", message: "You need to enter a destination address to withdraw funds to.")
                }
            } else {
                showAlert(vc: self, title: "Oops", message: "Invalid amount")
            }
        } else {
            showAlert(vc: self, title: "Oops", message: "Add an amount first")
        }
    }
    
    private func confirmLightningWithdraw(address: String, amount: Double) {
        var title = ""
        var sats = Int()
        if isFiat {
            if let dblAmount = Double(amountInput.text!) {
                let btcamount = rounded(number: amount / fxRate)
                sats = Int(btcamount * 100000000.0)
                title = "Withdraw $\(dblAmount) USD (\(sats) sats) from lightning wallet to \(address)?"
            }
        } else if isSats {
            if let dblAmount = Double(amountInput.text!) {
                sats = Int(dblAmount)
                title = "Withdraw \(dblAmount) sats from lightning wallet to \(address)?"
            }
        } else {
            sats = Int(amount * 100000000.0)
            title = "Withdraw \(amount.avoidNotation) btc (\(sats) sats) from lightning wallet to \(address)?"
        }
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: title, message: "This action is not reversable!", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Withdraw now", style: .default, handler: { action in
                vc.withdrawLightningNow(address: address, sats: sats)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
    
    private func withdrawLightningNow(address: String, sats: Int) {
        spinner.addConnectingView(vc: self, description: "withdrawing from lightning wallet...")
        let param = "\"\(address)\", \(sats)"
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .withdraw, param: param) { [weak self] (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    if let _ = dict["txid"] as? String {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Success ✅", message: "⚡️ Lightning wallet withdraw to \(address) completed ⚡️")
                    } else if let message = dict["message"] as? String {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Uh oh, somehting is not right", message: message)
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Uh oh, somehting is not right", message: errorDesc ?? "unknow error")
                }
            }
        }
    }
    
    
    @IBAction func fundLightning(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "fetching lightning funding address...")
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .newaddr, param: "") { [weak self] (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    if let address = dict["address"] as? String {
                        DispatchQueue.main.async { [weak self] in
                            if self != nil {
                                self!.addressInput.text = address
                                self?.spinner.removeConnectingView()
                                showAlert(vc: self, title: "⚡️ Nice! ⚡️", message: "This is an address you can use to fund your lightning node with, its your first step in transacting on the lightning network.")
                            }
                        }
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error fetching lightning wallet address")
                }
            }
        }
    }
    
    
    @IBAction func denominationChanged(_ sender: UISegmentedControl) {
        switch sender.selectedSegmentIndex
        {
        case 0:
            print("btc selected")
            isFiat = false
            isBtc = true
            isSats = false
            ud.set("btc", forKey: "unit")
            btcEnabled()
        case 1:
            print("sats selected")
            isFiat = false
            isBtc = false
            isSats = true
            ud.set("sats", forKey: "unit")
            satsSelected()
        case 2:
            print("fiat selected")
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
        let fx = FiatConverter.sharedInstance
        fx.getFxRate { [weak self] (fxrate) in
            if fxrate != nil {
                if self != nil {
                    DispatchQueue.main.async { [weak self] in
                        if self != nil {
                            self!.fxRate = fxrate!
                            self!.fxRateLabel.text = "$\(fxrate!.withCommas()) / btc"
                            self!.denominationImage.image = UIImage(systemName: "dollarsign.circle")
                            self!.amountIcon.backgroundColor = .systemBlue
                            self!.spinner.removeConnectingView()
                            showAlert(vc: self, title: "Fiat denomination", message: "You may enter an amount denominated in USD, we will calculate the equivalent amount in btc based on the current exchange rate of $\(fxrate!.withCommas()) / btc, always confirm the amounts before broadcasting by tapping the \"verify\" button.\n\nBitcoin's exchange rate can be volatile so always double check the amounts using the \"verify\" tool when the broadcaster presents itself.")
                        }
                    }
                }
            } else {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: "Could not get current fx rate")
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
                showAlert(vc: vc, title: "Thank you!", message: "A donation address has automatically been added so you may build a transaction which will fund further development of Fully Noded.")
            }
        }
    }
    
    @IBAction func scanNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerToGetAddress", sender: vc)
        }
    }
    
    @IBAction func addOutput(_ sender: Any) {
        if amountInput.text != "" && addressInput.text != "" && amountInput.text != "0.0" {
            var amount = amountInput.text!
            if let dblAmount = Double(amountInput.text!) {
                if isFiat {
                    amount = "\(rounded(number: dblAmount / fxRate))"
                } else if isSats {
                    amount = "\(rounded(number: dblAmount / 100000000.0))"
                }
            }
            let dict = ["address":addressInput.text!, "amount":amount] as [String : String]
            outputArray.append(dict)
            DispatchQueue.main.async { [unowned vc = self] in
                vc.outputsTable.alpha = 1
                vc.amountInput.text = ""
                vc.addressInput.text = ""
                vc.outputsTable.reloadData()
            }
        } else {
            displayAlert(viewController: self, isError: true, message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
        }
    }
    
    @objc func setFee(_ sender: UISlider) {
        let numberOfBlocks = Int(sender.value) * -1
        updateFeeLabel(label: miningTargetLabel, numberOfBlocks: numberOfBlocks)
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
                        label.text = "Confirmation target \(numberOfBlocks) blocks (\(seconds / 60) minutes)"
                    }
                } else {
                    DispatchQueue.main.async {
                        //more then an hour
                        label.text = "Confirmation target \(numberOfBlocks) blocks (\(seconds / 3600) hours)"
                    }
                }
            } else {
                DispatchQueue.main.async {
                    //more then a day
                    label.text = "Confirmation target \(numberOfBlocks) blocks (\(seconds / 86400) days)"
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
    
    @IBAction func sweep(_ sender: Any) {
        if addressInput.text != "" {
            spinner.addConnectingView(vc: self, description: "sweeping...")
            let receivingAddress = addressInput.text!
            Reducer.makeCommand(command: .listunspent, param: "0") { [weak self] (response, errorMessage) in
                if let resultArray = response as? NSArray {
                    var inputArray = [Any]()
                    var inputs = ""
                    var amount = Double()
                    var spendFromCold = Bool()
                    
                    for utxo in resultArray {
                        let utxoDict = utxo as! NSDictionary
                        let txid = utxoDict["txid"] as! String
                        let vout = "\(utxoDict["vout"] as! Int)"
                        let spendable = utxoDict["spendable"] as! Bool
                        if !spendable {
                            spendFromCold = true
                        }
                        amount += utxoDict["amount"] as! Double
                        let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                        inputArray.append(input)
                    }
                    
                    inputs = inputArray.description
                    inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
                    inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
                    inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
                    inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
                    inputs = inputs.replacingOccurrences(of: "\\", with: "")
                    
                    let ud = UserDefaults.standard
                    let param = "''\(inputs)'', ''{\"\(receivingAddress)\":\(rounded(number: amount))}'', 0, ''{\"includeWatching\": \(spendFromCold), \"replaceable\": true, \"conf_target\": \(ud.object(forKey: "feeTarget") as! Int), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
                    Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
                        if let result = response as? NSDictionary {
                            let psbt1 = result["psbt"] as! String
                            Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt1)\"") { [weak self] (response, errorMessage) in
                                if let dict = response as? NSDictionary {
                                    if let processedPSBT = dict["psbt"] as? String {
                                        Signer.sign(psbt: processedPSBT) { [weak self] (psbt, rawTx, errorMessage) in
                                            if self != nil {
                                                self?.spinner.removeConnectingView()
                                                if psbt != nil {
                                                    self!.rawTxUnsigned = psbt!
                                                    self!.showRaw(raw: psbt!)
                                                } else if rawTx != nil {
                                                    self!.rawTxSigned = rawTx!
                                                    self!.showRaw(raw: rawTx!)
                                                } else if errorMessage != nil {
                                                    showAlert(vc: self, title: "Error", message: errorMessage!)
                                                }
                                            }
                                        }
                                    }
                                } else {
                                    self?.spinner.removeConnectingView()
                                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                                }
                            }
                        } else {
                            self?.spinner.removeConnectingView()
                            displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                        }
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToBroadcaster", sender: vc)
        }
    }
    
    @IBAction func tryRawNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.rawTxSigned = ""
            vc.rawTxUnsigned = ""
            vc.amountInput.resignFirstResponder()
            vc.addressInput.resignFirstResponder()
            vc.tryRaw()
        }
    }
    
    @objc func tryRaw() {
        spinner.addConnectingView(vc: self, description: "creating psbt...")
        
        func convertOutputs() {
            for output in outputArray {
                if let amount = output["amount"] {
                    if let address = output["address"] {
                        if address != "" {
                            let dbl = Double(amount)!
                            let out = [address:dbl]
                            outputs.append(out)
                        }
                    }
                }
            }
            
            outputsString = outputs.description
            outputsString = outputsString.replacingOccurrences(of: "[", with: "")
            outputsString = outputsString.replacingOccurrences(of: "]", with: "")
            getRawTx()
        }
        
        if outputArray.count == 0 {
            if self.amountInput.text != "" && self.amountInput.text != "0.0" && self.addressInput.text != "" {
                var amount = amountInput.text!
                if let dblAmount = Double(amountInput.text!) {
                    if isFiat {
                        amount = "\(rounded(number: dblAmount / fxRate))"
                    } else if isSats {
                        amount = "\(rounded(number: dblAmount / 100000000))"
                    }
                }
                let dict = ["address":addressInput.text!, "amount":amount] as [String : String]
                outputArray.append(dict)
                convertOutputs()
            } else {
                spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: "You need to fill out an amount and a recipient")
            }
            
        } else if outputArray.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            spinner.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputArray.count > 0 {
            convertOutputs()
            
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
    }
        
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.text?.contains("."))! {
           let decimalCount = (textField.text?.components(separatedBy: ".")[1])?.count
            if decimalCount! <= 7 {
            } else {
                DispatchQueue.main.async {
                    displayAlert(viewController: self, isError: true, message: "Only 8 decimal places allowed")
                    self.amountInput.text = ""
                }
            }
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        if textField == addressInput && addressInput.text != "" {
            processBIP21(url: addressInput.text!)
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
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    if let _ = dict["msatoshi"] as? Int {
                        if self != nil {
                            self!.spinner.removeConnectingView()
                            self!.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: nil)
                        }
                    } else {
                        DispatchQueue.main.async { [weak self] in
                            self?.spinner.removeConnectingView()
                            if self?.amountInput.text != "" {
                                if self != nil {
                                    if let dblAmount = Double(self!.amountInput.text!) {
                                        if dblAmount > 0.0 {
                                            if self!.isFiat {
                                                let btcamount = rounded(number: dblAmount / self!.fxRate)
                                                let msats = Int(btcamount * 100000000000.0)
                                                self!.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                                            } else if self!.isSats {
                                                let msats = Int(dblAmount * 1000.0)
                                                self!.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                                            } else {
                                                let msats = Int(dblAmount * 100000000000.0)
                                                self!.promptToSendLightningPayment(invoice: invoice, dict: "\(dict)", msat: msats)
                                            }
                                        } else {
                                            self?.spinner.removeConnectingView()
                                            showAlert(vc: self, title: "Oops", message: "You need to enter an amount to send for an invoice that does not include one.")
                                        }
                                    } else {
                                        self?.spinner.removeConnectingView()
                                        showAlert(vc: self, title: "Oops", message: "You need to enter an amount to send for an invoice that does not include one.")
                                    }
                                }
                            } else {
                                self?.spinner.removeConnectingView()
                                showAlert(vc: self, title: "Oops", message: "You need to enter an amount to send for an invoice that does not include one.")
                            }
                        }
                    }
                } else {
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                }
            }
        }
    }
    
    private func promptToSendLightningPayment(invoice: String, dict: String, msat: Int?) {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Pay lightning invoice?", message: dict, preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Pay now", style: .default, handler: { action in
                vc.payLightningNow(invoice: invoice, msat: msat)
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
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
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    self?.spinner.removeConnectingView()
                    if let message = dict["message"] as? String {
                        showAlert(vc: self, title: "Message", message: message)
                    } else if let status = dict["status"] as? String {
                        if status == "complete" {
                            let msatoshi = Double(dict["msatoshi"] as! Int)
                            let msatoshi_sent = Double(dict["msatoshi_sent"] as! Int)
                            showAlert(vc: self, title: "Success ✅", message: "Lightning payment completed!\n\nAmount paid \(msatoshi / 1000.0) sats for a fee of \(Double((msatoshi_sent - msatoshi)) / 1000.0) sats")
                        }
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                }
            }
        }
    }
    
    func processBIP21(url: String) {
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        if !errorBool {
            address = addressParser.parseAddress(url: url).address
            amount = "\(addressParser.parseAddress(url: url).amount)"
            DispatchQueue.main.async { [unowned vc = self] in
                vc.addressInput.resignFirstResponder()
                vc.amountInput.resignFirstResponder()
                DispatchQueue.main.async { [unowned vc = self] in
                    if vc.amount != "" && vc.amount != "0.0" {
                        vc.amountInput.text = vc.amount
                    }
                    vc.addressInput.text = vc.address
                }
            }
        } else {
            displayAlert(viewController: self, isError: true, message: errorDescription)
        }
    }
    
    func getRawTx() {
        CreatePSBT.create(outputs: outputsString) { [weak self] (psbt, rawTx, errorMessage) in
            self?.spinner.removeConnectingView()
            if psbt != nil {
                self?.rawTxUnsigned = psbt!
                self?.showRaw(raw: psbt!)
            } else if rawTx != nil {
                self?.rawTxSigned = rawTx!
                self?.showRaw(raw: rawTx!)
            } else if errorMessage != nil {
                showAlert(vc: self, title: "Error", message: errorMessage!)
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
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { addrss in
                    if addrss != nil {
                        DispatchQueue.main.async { [unowned thisVc = self] in
                            if addrss!.hasPrefix("lntb") || addrss!.hasPrefix("lightning:") || addrss!.hasPrefix("lnbc") || addrss!.hasPrefix("lnbcrt") {
                                thisVc.decodeLighnting(invoice: addrss!.replacingOccurrences(of: "lightning:", with: ""))
                            } else {
                                thisVc.processBIP21(url: addrss!)
                            }
                        }
                    }
                }
            }
        case "segueToBroadcaster":
            if let vc = segue.destination as? SignerViewController {
                if rawTxSigned != "" {
                    vc.txn = rawTxSigned
                    vc.broadcast = true
                } else if rawTxUnsigned != "" {
                    vc.psbt = rawTxUnsigned
                    vc.export = true
                }
            }
        default:
            break
        }
    }
}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



