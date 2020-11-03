//
//  VerifyTransactionViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/4/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class VerifyTransactionViewController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate {
    
    var smartFee = Double()
    var txSize = Int()
    var rejectionMessage = ""
    var txValid: Bool?
    var memo = ""
    var txFee = Double()
    var fxRate: Double?
    var txid = ""
    var psbtDict:NSDictionary!
    var doneBlock: ((Bool) -> Void)?
    let spinner = ConnectingView()
    var unsignedPsbt = ""
    var signedRawTx = ""
    var outputsString = ""
    var inputArray = [[String:Any]]()
    var inputTableArray = [[String:Any]]()
    var outputArray = [[String:Any]]()
    var index = 0
    var inputTotal = Double()
    var outputTotal = Double()
    var miningFee = ""
    var recipients = [String]()
    var addressToVerify = ""
    var sweeping = Bool()
    var alertStyle = UIAlertController.Style.actionSheet
    var signatures = [[String:String]]()
    var signedTxInputs = NSArray()
    @IBOutlet weak var verifyTable: UITableView!
    @IBOutlet weak var sendButtonOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        verifyTable.delegate = self
        verifyTable.dataSource = self
        
        sendButtonOutlet.clipsToBounds = true
        sendButtonOutlet.layer.cornerRadius = 8
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        if (UIDevice.current.userInterfaceIdiom == .pad) {
          alertStyle = UIAlertController.Style.alert
        }
        
        load()
    }
    
    private func copy(_ text: String) {
        DispatchQueue.main.async {
            UIPasteboard.general.string = text
        }
    }
    
    @IBAction func copyAction(_ sender: Any) {
        if signedRawTx != "" {
            copy(signedRawTx)
        } else {
            copy(unsignedPsbt)
        }
        displayAlert(viewController: self, isError: false, message: "copied to clipboard ✓")
    }
    
    @IBAction func exportAction(_ sender: Any) {
        if signedRawTx != "" {
            exportTxn(txn: signedRawTx)
        } else {
            exportPsbt(psbt: unsignedPsbt)
        }
    }
    
    @IBAction func sendOrExportAction(_ sender: Any) {
        if signedRawTx != "" {
            broadcast()
        } else {
            exportPsbt(psbt: unsignedPsbt)
        }
    }
    
    private func updateLabel(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = text
        }
    }
    
    private func load() {
        spinner.addConnectingView(vc: self, description: "getting exchange rate....")
        
        FiatConverter.sharedInstance.getFxRate { [weak self] exchangeRate in
            guard let self = self else { return }
            
            self.fxRate = exchangeRate
            
            if self.unsignedPsbt == "" {
                self.updateLabel("decoding raw transaction...")
                self.executeNodeCommand(method: .decoderawtransaction, param: "\"\(self.signedRawTx)\"")
            } else {
                self.updateLabel("decoding psbt...")
                let exportImage = UIImage(systemName: "arrowshape.turn.up.right")
                
                DispatchQueue.main.async {
                    self.sendButtonOutlet.setImage(exportImage, for: .normal)
                    self.sendButtonOutlet.setTitle("  Export PSBT", for: .normal)
                }
                
                self.executeNodeCommand(method: .decodepsbt, param: "\"\(self.unsignedPsbt)\"")
            }
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        func send() {
            Reducer.makeCommand(command: .sendrawtransaction, param: param) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let _ = response as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                DispatchQueue.main.async {
                    self.spinner.removeConnectingView()
                    self.navigationItem.title = "Sent ✓"
                    self.sendButtonOutlet.alpha = 0
                    displayAlert(viewController: self, isError: false, message: "Transaction sent ✓")
                }
            }
        }
        
        func decodePsbt() {
            Reducer.makeCommand(command: .decodepsbt, param: param) { [weak self] (object, errorDesc) in
                guard let self = self else { return }
                
                guard let dict = object as? NSDictionary else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorDesc ?? "")
                    return
                }
                
                self.psbtDict = dict
                
                if let inputs = dict["inputs"] as? NSArray, inputs.count > 0 {
                    for input in inputs {
                        if let inputDict = input as? NSDictionary {
                            if let signatures = inputDict["partial_signatures"] as? NSDictionary {
                                for (key, value) in signatures {
                                    self.signatures.append(["\(key)":(value as? String ?? "")])
                                }
                            }
                        }
                    }
                }
                
                if let txDict = dict["tx"] as? NSDictionary {
                    
                    if let size = txDict["vsize"] as? Int {
                        self.txSize = size
                    }
                    
                    if let id = txDict["txid"] as? String {
                        self.txid = id
                    }
                    
                    self.parseTransaction(tx: txDict)
                }
            }
        }
        
        func decodeTx() {
            Reducer.makeCommand(command: .decoderawtransaction, param: param) { [weak self] (object, errorDesc) in
                guard let self = self else { return }
                
                guard let dict = object as? NSDictionary else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorDesc ?? "")
                    return
                }
                
                if let size = dict["vsize"] as? Int {
                    self.txSize = size
                }
                
                if let id = dict["txid"] as? String {
                    self.txid = id
                }
                
                if let inputs = dict["vin"] as? NSArray {
                    self.signedTxInputs = inputs
                }
                
                self.parseTransaction(tx: dict)
            }
        }
        
        switch method {
        case .sendrawtransaction:
            send()
            
        case .decodepsbt:
            decodePsbt()
            
        case .decoderawtransaction:
            decodeTx()
            
        default:
            break
        }
    }
    
    func parseTransaction(tx: NSDictionary) {
        if let inputs = tx["vin"] as? NSArray, let outputs = tx["vout"] as? NSArray {
            parseOutputs(outputs: outputs)
            parseInputs(inputs: inputs, completion: getFirstInputInfo)
        }
    }
    
    func getFirstInputInfo() {
        index = 0
        getInputInfo(index: index)
    }
    
    func getInputInfo(index: Int) {
        let dict = inputArray[index]
        if let txid = dict["txid"] as? String, let vout = dict["vout"] as? Int {
            parsePrevTx(method: .gettransaction, param: "\"\(txid)\", true", vout: vout, txid: txid)
        }
    }
    
    func parseInputs(inputs: NSArray, completion: @escaping () -> Void) {
        for (index, i) in inputs.enumerated() {
            if let input = i as? NSDictionary {
                if let txid = input["txid"] as? String, let vout = input["vout"] as? Int {
                    let dict = ["inputNumber":index + 1, "txid":txid, "vout":vout as Any] as [String : Any]
                    inputArray.append(dict)
                    
                    if index + 1 == inputs.count {
                        completion()
                    }
                }
            }
        }
    }
    
    func parseOutputs(outputs: NSArray) {
        for (i, o) in outputs.enumerated() {
            if let output = o as? NSDictionary {
                if let scriptpubkey = output["scriptPubKey"] as? NSDictionary, let amount = output["value"] as? Double {
                    let addresses = scriptpubkey["addresses"] as? NSArray ?? []
                    let number = i + 1
                    var addressString = ""
                    
                    if addresses.count > 1 {
                        for a in addresses {
                            addressString += a as! String + " "
                        }
                    } else {
                        addressString = addresses[0] as! String
                    }
                    
                    outputTotal += amount
                    var isChange = true
                    
                    for recipient in recipients {
                        if addressString == recipient {
                            isChange = false
                        }
                    }
                    
                    if sweeping {
                        isChange = false
                    }
                    
                    var amountString = amount.avoidNotation
                    
                    if fxRate != nil {
                        amountString += " btc / \(fiatAmount(btc: amount))"
                    }
                    
                    let outputDict:[String:Any] = [
                        "index": number,
                        "amount": amountString,
                        "address": addressString,
                        "isChange": isChange,
                        "isOurs": false,// Hardcode at this stage and update before displaying
                        "isDust": amount < 0.00020000
                    ]
                    
                    outputArray.append(outputDict)
                }
            }
        }
    }
    
    func parsePrevTxOutput(outputs: NSArray, vout: Int) {
        if outputs.count > 0 {
            for o in outputs {
                if let output = o as? NSDictionary {
                    if let n = output["n"] as? Int {
                        if n == vout {
                            //this is our inputs output, we can now get the amount and address for the input (PITA)
                            var addressString = ""
                            
                            if let scriptpubkey = output["scriptPubKey"] as? NSDictionary {
                                if let addresses = scriptpubkey["addresses"] as? NSArray {
                                    if addresses.count > 1 {
                                        for a in addresses {
                                            addressString += a as! String + " "
                                        }
                                        
                                    } else {
                                        addressString = addresses[0] as! String
                                    }
                                }
                            }
                            
                            if let amount = output["value"] as? Double {
                                inputTotal += amount
                                var amountString = amount.avoidNotation
                                
                                if fxRate != nil {
                                    amountString += " btc / \(fiatAmount(btc: amount))"
                                }
                                
                                let inputDict:[String:Any] = [
                                    "index": index + 1,
                                    "amount": amountString,
                                    "address": addressString,
                                    "isOurs": false,// Hardcode at this stage and update before displaying
                                    "isDust": amount < 0.00020000
                                ]
                                
                                inputTableArray.append(inputDict)
                            }
                        }
                    }
                }
            }
        } else {
            let inputDict:[String:Any] = [
                "index": index + 1,
                "amount": "unknown",
                "address": "unknown",
                "isOurs": false,// Hardcode at this stage and update before displaying
                "isDust": true
            ]
            
            inputTableArray.append(inputDict)
        }
        
        if index + 1 < inputArray.count {
            index += 1
            getInputInfo(index: index)
            
        } else if index + 1 == inputArray.count {
            index = 0
            txFee = inputTotal - outputTotal
            let txfeeString = txFee.avoidNotation
            if fxRate != nil {
                self.miningFee = "\(txfeeString) btc / \(fiatAmount(btc: self.txFee))"
            } else {
                self.miningFee = "\(txfeeString) btc / error fetching fx rate"
            }
            verifyInputs()
        }
    }
    
    private func verifyInputs() {
        if index < inputTableArray.count {
            self.updateLabel("verifiying input #\(self.index + 1) out of \(self.inputTableArray.count)")
            
            if let address = inputTableArray[index]["address"] as? String {
                Reducer.makeCommand(command: .getaddressinfo, param: "\"\(address)\"") { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    if let dict = response as? NSDictionary {
                        let solvable = dict["solvable"] as? Bool ?? false
                        let keypath = dict["hdkeypath"] as? String ?? "no key path"
                        let labels = dict["labels"] as? NSArray ?? ["no label"]
                        let desc = dict["desc"] as? String ?? "no descriptor"
                        var isChange = dict["ischange"] as? Bool ?? false
                        let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                        let script = dict["script"] as? String ?? ""
                        let sigsrequired = dict["sigsrequired"] as? Int ?? 0
                        let pubkeys = dict["pubkeys"] as? [String] ?? []
                        var labelsText = ""
                        if labels.count > 0 {
                            for label in labels {
                                if label as? String == "" {
                                    labelsText += "no label "
                                } else {
                                    labelsText += "\(label as? String ?? "") "
                                }
                            }
                        } else {
                            labelsText += "no label "
                        }
                        
                        if desc.contains("/1/") {
                            isChange = true
                        }
                        
                        self.inputTableArray[self.index]["isOurs"] = solvable
                        self.inputTableArray[self.index]["hdKeyPath"] = keypath
                        self.inputTableArray[self.index]["isChange"] = isChange
                        self.inputTableArray[self.index]["label"] = labelsText
                        self.inputTableArray[self.index]["fingerprint"] = fingerprint
                        self.inputTableArray[self.index]["desc"] = desc
                        
                        if script == "multisig" && self.signedRawTx == "" {
                            self.inputTableArray[self.index]["sigsrequired"] = sigsrequired
                            self.inputTableArray[self.index]["pubkeys"] = pubkeys
                            var numberOfSigs = 0
                            
                            // Will only be any for a psbt
                            for (i, sigs) in self.signatures.enumerated() {
                                for (key, _) in sigs {
                                    for pk in pubkeys {
                                        if pk == key {
                                            numberOfSigs += 1
                                        }
                                    }
                                }
                                
                                if i + 1 == self.signatures.count {
                                    self.inputTableArray[self.index]["signatures"] = "\(numberOfSigs) out of \(sigsrequired) signatures"
                                }
                                
                            }
                            
                        } else {
                            // Will only be any for a signed raw transaction
                            if self.signedTxInputs.count > 0 {
                                self.inputTableArray[self.index]["signatures"] = "Unsigned"
                                let input = self.signedTxInputs[self.index] as? NSDictionary ?? [:]
                                let scriptsig = input["scriptSig"] as? NSDictionary ?? [:]
                                let hex = scriptsig["hex"] as? String ?? ""
                                if hex != "" {
                                    self.inputTableArray[self.index]["signatures"] = "Signed"
                                } else {
                                    if let txwitness = input["txinwitness"] as? NSArray {
                                        if txwitness.count > 1 {
                                            self.inputTableArray[self.index]["signatures"] = "Signed"
                                        }
                                    }
                                }
                            }
                        }
                        self.index += 1
                        self.verifyInputs()
                    }
                }
            }
        } else {
            self.index = 0
            verifyOutputs()
        }
    }
    
    private func verifyOutputs() {
        if index < outputArray.count {
            self.updateLabel("verifiying output #\(self.index + 1) out of \(self.outputArray.count)")
            
            if let address = outputArray[index]["address"] as? String {
                Reducer.makeCommand(command: .getaddressinfo, param: "\"\(address)\"") { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    if let dict = response as? NSDictionary {
                        let solvable = dict["solvable"] as? Bool ?? false
                        let keypath = dict["hdkeypath"] as? String ?? "no key path"
                        let labels = dict["labels"] as? NSArray ?? ["no label"]
                        let desc = dict["desc"] as? String ?? "no descriptor"
                        var isChange = dict["ischange"] as? Bool ?? false
                        let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                        var labelsText = ""
                        if labels.count > 0 {
                            for label in labels {
                                if label as? String == "" {
                                    labelsText += "no label "
                                } else {
                                    labelsText += "\(label as? String ?? "") "
                                }
                            }
                        } else {
                            labelsText += "no label "
                        }
                        if desc.contains("/1/") {
                            isChange = true
                        }
                        self.outputArray[self.index]["isOurs"] = solvable
                        self.outputArray[self.index]["hdKeyPath"] = keypath
                        self.outputArray[self.index]["isChange"] = isChange
                        self.outputArray[self.index]["label"] = labelsText
                        self.outputArray[self.index]["fingerprint"] = fingerprint
                        self.outputArray[self.index]["desc"] = desc
                        self.index += 1
                        self.verifyOutputs()
                    }
                }
            }
        } else {
            guard signedRawTx != "" else {
                getFeeRate()
                return
            }
            
            updateLabel("verifying mempool accept...")
            
            Reducer.makeCommand(command: .testmempoolaccept, param: "[\"\(signedRawTx)\"]") { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let arr = response as? NSArray, arr.count > 0,
                    let dict = arr[0] as? NSDictionary,
                    let allowed = dict["allowed"] as? Bool else {
                    self.getFeeRate()
                    return
                }
                
                self.txValid = allowed
                self.rejectionMessage = dict["reject-reason"] as? String ?? ""
                self.getFeeRate()
            }
        }
    }
    
    private func getFeeRate() {
        let target = UserDefaults.standard.object(forKey: "feeTarget") as? Int ?? 432
        
        updateLabel("estimating smart fee...")
        
        Reducer.makeCommand(command: .estimatesmartfee, param: "\(target)") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let feeRate = dict["feerate"] as? Double else {
                self.loadTableData()
                return
            }
            
            let inSatsPerKb = Double(feeRate) * 100000000.0
            self.smartFee = inSatsPerKb / 1000.0
            self.loadTableData()
        }
    }
    
    private func fiatAmount(btc: Double) -> String {
        guard let fxRate = fxRate else { return "error getting fiat rate" }
        let fiat = fxRate * btc
        let roundedFiat = Double(round(100*fiat)/100)
        return "$\(roundedFiat.withCommas())"
    }
    
    func loadTableData() {
        DispatchQueue.main.async { [weak self] in
            self?.verifyTable.reloadData()
        }
        spinner.removeConnectingView()
        
        guard let _ = KeyChain.getData("UnlockPassword") else {
            showAlert(vc: self, title: "You are not using the app securely...", message: "Anyone who gets access to this device will be able to spend your Bitcoin, we urge you to add a lock password via the lock button on the home screen.")
            
            return
        }
    }
    
    func parsePrevTx(method: BTC_CLI_COMMAND, param: String, vout: Int, txid: String) {
        
        func decodeRaw() {
            updateLabel("decoding inputs previous output...")
            Reducer.makeCommand(command: .decoderawtransaction, param: param) { [weak self] (object, errorDescription) in
                guard let self = self else { return }
                
                guard let txDict = object as? NSDictionary, let outputs = txDict["vout"] as? NSArray else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: "Error decoding raw transaction")
                    return
                }
                
                self.parsePrevTxOutput(outputs: outputs, vout: vout)
            }
        }
        
        func getRawTx() {
            updateLabel("fetching inputs previous output...")
            Reducer.makeCommand(command: .gettransaction, param: param) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let dict = response as? NSDictionary, let hex = dict["hex"] as? String else {
                    
                    guard let errorMessage = errorMessage else {
                        self.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: "Error parsing inputs")
                        return
                    }
                    
                    guard errorMessage.contains("Invalid or non-wallet transaction id") else {
                        self.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: "Error parsing inputs: \(errorMessage)")
                        return
                    }
                    
                    let fetcher = GetTx.sharedInstance
                    fetcher.fetch(txid: txid) { [weak self] rawHex in
                        guard let self = self else { return }
                        
                        guard let rawHex = rawHex else {
                            // Esplora must be down, pass an empty array instead
                            self.parsePrevTxOutput(outputs: [], vout: 0)
                            return
                        }
                        
                        self.parsePrevTx(method: .decoderawtransaction, param: "\"\(rawHex)\"", vout: vout, txid: txid)
                    }
                    
                    return
                }
                
                self.parsePrevTx(method: .decoderawtransaction, param: "\"\(hex)\"", vout: vout, txid: txid)
            }
        }
        
        switch method {
        case .decoderawtransaction:
            decodeRaw()
            
        case .gettransaction:
            getRawTx()
            
        default:
            break
        }
        
    }
    
    private func mempoolAcceptCell(_ indexPath: IndexPath) -> UITableViewCell {
        let mempoolAcceptCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        let label = mempoolAcceptCell.viewWithTag(1) as! UILabel
        let imageView = mempoolAcceptCell.viewWithTag(2) as! UIImageView
        let background = mempoolAcceptCell.viewWithTag(3)!
        background.layer.cornerRadius = 5
        imageView.tintColor = .white
        
        if txValid != nil {
            if txValid! {
                label.text = "Mempool acception verified ✓"
                background.backgroundColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.seal")
            } else {
                label.text = "Transaction invalid! Reason: \(rejectionMessage)"
                background.backgroundColor = .systemRed
                imageView.image = UIImage(systemName: "exclamationmark.triangle")
            }
        } else {
            if unsignedPsbt != "" {
                label.text = "Transaction not yet complete! Export the psbt to another signer"
            } else {
                label.text = "This feature requires at least Bitcoin Core 0.20.0"
            }
            
            background.backgroundColor = .darkGray
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        
        mempoolAcceptCell.selectionStyle = .none
        label.textColor = .lightGray
        label.adjustsFontSizeToFitWidth = true
        return mempoolAcceptCell
    }
    
    private func txidCell(_ indexPath: IndexPath) -> UITableViewCell {
        let txidCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        
        let txidLabel = txidCell.viewWithTag(1) as! UILabel
        let imageView = txidCell.viewWithTag(2) as! UIImageView
        let background = txidCell.viewWithTag(3)!
        background.layer.cornerRadius = 5
        background.backgroundColor = .systemBlue
        imageView.tintColor = .white
        imageView.image = UIImage(systemName: "rectangle.and.paperclip")
        txidLabel.text = txid
        txidCell.selectionStyle = .none
        txidLabel.textColor = .lightGray
        txidLabel.adjustsFontSizeToFitWidth = true
        return txidCell
    }
    
    private func inputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let inputCell = verifyTable.dequeueReusableCell(withIdentifier: "inputOutputCell", for: indexPath)
        
        let inputIndexLabel = inputCell.viewWithTag(1) as! UILabel
        let inputAmountLabel = inputCell.viewWithTag(2) as! UILabel
        let inputAddressLabel = inputCell.viewWithTag(3) as! UILabel
        let inputIsOursImage = inputCell.viewWithTag(4) as! UIImageView
        let isChangeImageView = inputCell.viewWithTag(8) as! UIImageView
        let labelLabel = inputCell.viewWithTag(7) as! UILabel
        let pathLabel = inputCell.viewWithTag(5) as! UILabel
        let fingerprintLabel = inputCell.viewWithTag(6) as! UILabel
        let isDustImageView = inputCell.viewWithTag(10) as! UIImageView
        let backgroundView1 = inputCell.viewWithTag(11)!
        let backgroundView2 = inputCell.viewWithTag(12)!
        let backgroundView3 = inputCell.viewWithTag(13)!
        let signaturesLabel = inputCell.viewWithTag(14) as! UILabel
        let descLabel = inputCell.viewWithTag(15) as! UILabel
        backgroundView1.layer.cornerRadius = 5
        backgroundView2.layer.cornerRadius = 5
        backgroundView3.layer.cornerRadius = 5
        isDustImageView.tintColor = .white
        isChangeImageView.tintColor = .white
        inputIsOursImage.tintColor = .white
        
        if indexPath.row < inputTableArray.count {
            let input = inputTableArray[indexPath.row]
            
            let isOurs = input["isOurs"] as? Bool ?? false
            let isChange = input["isChange"] as? Bool ?? false
            let label = input["label"] as? String ?? "no label"
            let fingerprint = input["fingerprint"] as? String ?? "no fingerprint"
            let path = input["hdKeyPath"] as? String ?? "no keypath"
            let isDust = input["isDust"] as? Bool ?? false
            let signatureStatus = input["signatures"] as? String ?? "no signature data"
            let desc = input["desc"] as? String ?? "no descriptor"
            
            labelLabel.text = label
            fingerprintLabel.text = fingerprint
            pathLabel.text = path
            signaturesLabel.text = signatureStatus
            descLabel.text = desc
            
            if isDust {
                isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
                backgroundView3.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark")
                backgroundView3.backgroundColor = .darkGray
            }
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                backgroundView2.backgroundColor = .systemPurple
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                backgroundView2.backgroundColor = .systemBlue
            }
            
            if isOurs {
                backgroundView1.backgroundColor = .systemGreen
                inputIsOursImage.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
            } else {
                backgroundView1.backgroundColor = .systemRed
                inputIsOursImage.image = UIImage(systemName: "person.crop.circle.badge.xmark")
            }
            
            inputIndexLabel.text = "Input #\(input["index"] as! Int)"
            inputAmountLabel.text = "\((input["amount"] as! String))"
            inputAddressLabel.text = (input["address"] as! String)
            inputAddressLabel.adjustsFontSizeToFitWidth = true
            inputCell.selectionStyle = .none
            inputIndexLabel.textColor = .lightGray
            inputAmountLabel.textColor = .lightGray
            inputAddressLabel.textColor = .lightGray
            return inputCell
        } else {
            return inputCell
        }
    }
    
    private func outputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let outputCell = verifyTable.dequeueReusableCell(withIdentifier: "outputCell", for: indexPath)
        
        let inputIndexLabel = outputCell.viewWithTag(1) as! UILabel
        let inputAmountLabel = outputCell.viewWithTag(2) as! UILabel
        let inputAddressLabel = outputCell.viewWithTag(3) as! UILabel
        let inputIsOursImage = outputCell.viewWithTag(4) as! UIImageView
        let isChangeImageView = outputCell.viewWithTag(8) as! UIImageView
        let labelLabel = outputCell.viewWithTag(7) as! UILabel
        let pathLabel = outputCell.viewWithTag(5) as! UILabel
        let fingerprintLabel = outputCell.viewWithTag(6) as! UILabel
        let isDustImageView = outputCell.viewWithTag(10) as! UIImageView
        let backgroundView1 = outputCell.viewWithTag(11)!
        let backgroundView2 = outputCell.viewWithTag(12)!
        let backgroundView3 = outputCell.viewWithTag(13)!
        let descLabel = outputCell.viewWithTag(15) as! UILabel
        backgroundView1.layer.cornerRadius = 5
        backgroundView2.layer.cornerRadius = 5
        backgroundView3.layer.cornerRadius = 5
        isDustImageView.tintColor = .white
        isChangeImageView.tintColor = .white
        inputIsOursImage.tintColor = .white
        
        if indexPath.row < outputArray.count {
            let output = outputArray[indexPath.row]
            
            let isOurs = output["isOurs"] as? Bool ?? false
            let isChange = output["isChange"] as? Bool ?? false
            let label = output["label"] as? String ?? "no label"
            let fingerprint = output["fingerprint"] as? String ?? "no fingerprint"
            let path = output["hdKeyPath"] as? String ?? "no keypath"
            let isDust = output["isDust"] as? Bool ?? false
            let desc = output["desc"] as? String ?? "no descriptor"
            
            labelLabel.text = label
            fingerprintLabel.text = fingerprint
            pathLabel.text = path
            descLabel.text = desc
            
            if isDust {
                isDustImageView.image = UIImage(systemName: "exclamationmark.triangle")
                backgroundView3.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark")
                backgroundView3.backgroundColor = .darkGray
            }
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.2.circlepath")
                backgroundView2.backgroundColor = .systemPurple
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.up.right")
                backgroundView2.backgroundColor = .systemBlue
            }
            
            if isOurs {
                backgroundView1.backgroundColor = .systemGreen
                inputIsOursImage.image = UIImage(systemName: "person.crop.circle.fill.badge.checkmark")
            } else {
                backgroundView1.backgroundColor = .systemRed
                inputIsOursImage.image = UIImage(systemName: "person.crop.circle.badge.xmark")
            }
            
            inputIndexLabel.text = "Output #\(output["index"] as! Int)"
            inputAmountLabel.text = "\((output["amount"] as! String))"
            inputAddressLabel.text = (output["address"] as! String)
            inputAddressLabel.adjustsFontSizeToFitWidth = true
            outputCell.selectionStyle = .none
            inputIndexLabel.textColor = .lightGray
            inputAmountLabel.textColor = .lightGray
            inputAddressLabel.textColor = .lightGray
            return outputCell
        } else {
            return outputCell
        }
    }
    
    private func miningFeeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let miningFeeCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        
        let miningLabel = miningFeeCell.viewWithTag(1) as! UILabel
        let imageView = miningFeeCell.viewWithTag(2) as! UIImageView
        
        let background = miningFeeCell.viewWithTag(3)!
        background.layer.cornerRadius = 5
        imageView.tintColor = .white
        
        if txFee < 0.00050000 {
            background.backgroundColor = .systemGreen
            imageView.image = UIImage(systemName: "checkmark.circle")
        } else {
            background.backgroundColor = .systemRed
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        
        miningLabel.text = miningFee + " / \(satsPerByte()) sats per byte"
        miningFeeCell.selectionStyle = .none
        miningLabel.textColor = .lightGray
        return miningFeeCell
    }
    
    private func etaCell(_ indexPath: IndexPath) -> UITableViewCell {
        let etaCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        
        let etaLabel = etaCell.viewWithTag(1) as! UILabel
        let imageView = etaCell.viewWithTag(2) as! UIImageView
        let background = etaCell.viewWithTag(3)!
        background.layer.cornerRadius = 5
        imageView.tintColor = .white
        
        var feeWarning = ""
        let percentage = (satsPerByte() / smartFee) * 100
        let rounded = Double(round(10*percentage)/10)
        if satsPerByte() > smartFee {
            feeWarning = "The fee paid for this transaction is \(rounded - 100)% greater then your target in terms of sats per byte"
        } else {
            feeWarning = "The fee paid for this transaction is \(100 - rounded)% less then your target fee in terms of sats per byte"
        }
        
        if percentage >= 90 && percentage <= 110 {
            background.backgroundColor = .systemGreen
            imageView.image = UIImage(systemName: "checkmark.circle")
            etaLabel.text = "Fee is on target for a confirmation in approximately \(eta()) or \(feeTarget()) blocks"
        } else {
            if percentage <= 90 {
                background.backgroundColor = .systemRed
                imageView.image = UIImage(systemName: "tortoise")
                etaLabel.text = feeWarning
            } else {
                background.backgroundColor = .systemRed
                imageView.image = UIImage(systemName: "hare")
                etaLabel.text = feeWarning
            }
        }
        
        etaLabel.textColor = .lightGray
        etaCell.selectionStyle = .none
        return etaCell
    }
    
    private func satsPerByte() -> Double {
        let satsPerByte = (txFee * 100000000.0) / Double(txSize)
        return Double(round(10*satsPerByte)/10)
    }
    
    private func feeTarget() -> Int {
        let ud = UserDefaults.standard
        return ud.object(forKey: "feeTarget") as? Int ?? 432
    }
    
    private func eta() -> String {
        var eta = ""
        let seconds = ((feeTarget() * 10) * 60)
        
        if seconds < 86400 {
            
            if seconds < 3600 {
                eta = "\(seconds / 60) minutes"
                
            } else {
                eta = "\(seconds / 3600) hours"
                
            }
            
        } else {
            eta = "\(seconds / 86400) days"
            
        }
        
        let todaysDate = Date()
        let futureDate = Date(timeInterval: Double(seconds), since: todaysDate)
        eta += " on \(formattedDate(date: futureDate))"
        return eta
    }
    
    private func formattedDate(date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = .current
        dateFormatter.dateFormat = "yyyy-MMM-dd hh:mm"
        let strDate = dateFormatter.string(from: date)
        return strDate
    }
    
    private func broadcastPrivately() {
        spinner.addConnectingView(vc: self, description: "broadcasting...")
        
        Broadcaster.sharedInstance.send(rawTx: self.signedRawTx) { [weak self] id in
            guard let self = self else { return }
            
            if id == self.txid {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    self.sendButtonOutlet.alpha = 0
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Success! ✅", message: "Transaction sent.")
                }
            } else {
                self.showError(error: "Error broadcasting privately, try again and use your node instead. Error: \(id ?? "unknown")")
            }
        }
    }
    
    private func broadcastWithMyNode() {
        spinner.addConnectingView(vc: self, description: "broadcasting...")
        
        Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(self.signedRawTx)\"") { [weak self] (response, errorMesage) in
            guard let self = self else { return }
            
            guard let id = response as? String else {
                self.showError(error: "Error broadcasting: \(errorMesage ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                if self.txid == id {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    self.sendButtonOutlet.alpha = 0
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Success! ✅", message: "Transaction sent.")
                } else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Hmmm we got a strange response...", message: id)
                }
            }
        }
    }
    
    private func broadcast() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                self.broadcastPrivately()
            }))
            
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { action in
                self.broadcastWithMyNode()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Uh oh", message: error)
        }
    }
    
    @objc func copyTxid() {
        DispatchQueue.main.async { [unowned vc = self] in
            let pasteBoard = UIPasteboard.general
            pasteBoard.string = vc.txid
            displayAlert(viewController: vc, isError: false, message: "Transaction ID copied to clipboard")
        }
    }
        
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text != "" {
            memo = textField.text!
        }
    }
    
    private func exportPsbt(psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Share as a .psbt file, text or QR?", message: "Sharing as a .psbt file allows you to send the psbt directly to your Coldcard or to Electrum 4.0 for signing", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: ".psbt file", style: .default, handler: { action in
                self.convertPSBTtoData(string: psbt)
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                self.shareText(psbt)
            }))
            
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                self.unsignedPsbt = psbt
                self.exportAsQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func exportAsQR() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToExportPsbtAsQr", sender: self)
        }
    }
    
    private func shareText(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    private func exportTxn(txn: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Export as text or QR?", message: "", preferredStyle: self.alertStyle)
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                self.shareText(txn)
            }))
            
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                self.exportAsQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func convertPSBTtoData(string: String) {
        guard let data = Data(base64Encoded: string), let url = exportPsbtToURL(data: data) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let activityViewController = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            if UIDevice.current.userInterfaceIdiom == .pad {
                activityViewController.popoverPresentationController?.sourceView = self.view
                activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
            }
            
            self.present(activityViewController, animated: true) {}
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToExportPsbtAsQr" {
            
            if let vc = segue.destination as? QRDisplayerViewController {
                
                if unsignedPsbt != "" {
                    vc.psbt = unsignedPsbt
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.headerText = "PSBT"
                    vc.descriptionText = "This psbt still needs more signatures to be complete, you can share it with another signer."
                    
                } else if signedRawTx != "" {
                    vc.text = signedRawTx
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.headerText = "Signed Transaction"
                    vc.descriptionText = "You can save this signed transaction and broadcast it later or share it with someone else."
                    
                }
            }
        }
    }

}

extension VerifyTransactionViewController: UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 2:
            return inputArray.count
            
        case 3:
            return outputArray.count
            
        case 4, 0, 5, 1:
            return 1
            
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 2, 3:
            return 172
            
        case 0, 1, 4, 5:
            return 50
            
        default:
            return 0
            
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard inputTableArray.count > 0 && outputArray.count > 0 else {
            return UITableViewCell()
        }
        
        tableView.separatorColor = .lightGray
        
        switch indexPath.section {
            
        case 0:
            return mempoolAcceptCell(indexPath)
            
        case 1:
            return txidCell(indexPath)
            
        case 2:
            return inputCell(indexPath)
            
        case 3:
            return outputCell(indexPath)
            
        case 4:
            return miningFeeCell(indexPath)
            
        case 5:
            return etaCell(indexPath)
            
        default:
            return UITableViewCell()
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
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        switch section {
        case 0:
            textLabel.text = "Mempool accept"
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
        case 1:
            textLabel.text = "Transaction ID"
            let copyButton = UIButton()
            let copyImage = UIImage(systemName: "doc.on.doc")!
            copyButton.tintColor = .systemTeal
            copyButton.setImage(copyImage, for: .normal)
            copyButton.addTarget(self, action: #selector(copyTxid), for: .touchUpInside)
            copyButton.frame = CGRect(x: header.frame.maxX - 60, y: 0, width: 50, height: 50)
            copyButton.center.y = textLabel.center.y
            header.addSubview(copyButton)
                            
        case 2:
            textLabel.text = "Inputs"
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                            
        case 3:
            textLabel.text = "Outputs"
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
        case 4:
            textLabel.text = "Mining fee"
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        case 5:
            textLabel.text = "Estimated time to confirm"
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                            
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
}

extension VerifyTransactionViewController: UITableViewDataSource {
    
}
