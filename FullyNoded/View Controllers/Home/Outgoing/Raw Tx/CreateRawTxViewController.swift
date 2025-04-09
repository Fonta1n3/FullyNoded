//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Denton LLC. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    var isJmarket = false
    var isDirectSend = false
    var mixdepthToSpendFrom = 0
    var jmWallet:Wallet?
    var isFiat = false
    var isBtc = true
    var isSats = false
    var fxRate:Double?
    var spendable = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var address = String()
    var amount = String()
    var outputs:[[String:Any]] = []
    var inputs:[[String:Any]] = []
    var txt = ""
    var utxoTotal = 0.0
    let ud = UserDefaults.standard
    var index = 0
    var invoice:[String:Any]?
    var invoiceString = ""
    let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
    var isFidelity = false
    var balance = ""
    
    
    @IBOutlet weak private var balanceLabel: UILabel!
    @IBOutlet weak private var batchOutlet: UIButton!
    @IBOutlet weak private var lightningWithdrawOutlet: UIButton!
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
    @IBOutlet weak var coinSelectionControl: UISegmentedControl!
    
    var spinner = ConnectingView()
    var spendableBalance = Double()
    //var outputArray = [[String:String]]()
    
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
        balanceLabel.text = "Available: \(balance)"
        addTapGesture()
        
        sliderViewBackground.layer.cornerRadius = 8
        sliderViewBackground.layer.borderColor = UIColor.darkGray.cgColor
        sliderViewBackground.layer.borderWidth = 0.5
        sliderViewBackground.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        amountBackground.layer.cornerRadius = 8
        amountBackground.layer.borderColor = UIColor.darkGray.cgColor
        amountBackground.layer.borderWidth = 0.5
        amountBackground.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        recipientBackground.layer.cornerRadius = 8
        recipientBackground.layer.borderColor = UIColor.darkGray.cgColor
        recipientBackground.layer.borderWidth = 0.5
        recipientBackground.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
        amountIcon.layer.cornerRadius = 5
        feeIconBackground.layer.cornerRadius = 5
        addressIcon.layer.cornerRadius = 5
        
        addressImageView.layer.magnificationFilter = .nearest
        
        slider.addTarget(self, action: #selector(setFee), for: .allEvents)
        slider.maximumValue = 2 * -1
        slider.minimumValue = 432 * -1
        
        segmentedControlOutlet.setTitle(fiatCurrency.lowercased(), forSegmentAt: 2)
        
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
    
    private func getAddressFromJm(wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            let title = "Select a mixdepth to deposit to."
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 0, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 1, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 2, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.getJmAddressFromMixDepth(mixDepth: 3, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.getJmAddressFromMixDepth(mixDepth: 4, wallet: wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getJmAddressFromMixDepth(mixDepth: Int, wallet: Wallet) {
        spinner.addConnectingView(vc: self, description: "getting address from jm...")
        
        JMRPC.sharedInstance.command(method: .getaddress(jmWallet: wallet, mixdepth: mixDepth), param: nil) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            self.spinner.removeConnectingView()
            guard let response = response as? [String:Any],
            let address = response["address"] as? String else {
                showAlert(vc: self, title: "", message: errorDesc ?? "unknown error getting jm address.")
                return
            }

            self.addAdressNow(address: address, wallet: wallet)
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
        
        if wallet.isJm {
            self.getAddressFromJm(wallet: wallet)
        } else {
            getFromFnWallet()
        }
        
//        guard let jmWallet = jmWallet else {
//
//            return
//        }
//
//        if jmWallet.fnWallet == wallet.name {
//
//
//        } else {
//            getFromFnWallet()
//        }
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
    
    private func chooseMixdepthToSpendFrom() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            let title = "Select a mixdepth to spend from."
            
            let alert = UIAlertController(title: title, message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.directSend(mixdepth: 0)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.directSend(mixdepth: 1)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.directSend(mixdepth: 2)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.directSend(mixdepth: 3)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.directSend(mixdepth: 4)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction func switchCoinSelectionAction(_ sender: Any) {
        switch coinSelectionControl.selectedSegmentIndex {
        case 0:
            showAlert(vc: self, title: "Standard", message: "This defaults to Bitcoin Core coin selection.")
        case 1:
            showAlert(vc: self, title: "Blind", message: "Blind psbts are designed to be joined with another user before broadcasting. They may be useful to gain a bit more privacy for your day to day transactions.")
        case 2:
            showAlert(vc: self, title: "Coinjoin", message: "Coinjoin psbts are designed to be joined with other users. Export the psbt encrypted to allow others to easily join. Only one input and one output will be added at a time. The amount sent should match the amount of your utxo or this will fail.")
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
    
    
    @IBAction func pasteAction(_ sender: Any) {
        guard let item = UIPasteboard.general.string else { return }
        
        if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") || item.hasPrefix("lno") {
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
        }
        
        guard let addressInput = addressInput.text else {
            showAlert(vc: self, title: "", message: "Enter an address or invoice.")
            return
        }
        
        let lc = addressInput.lowercased()
        
        if lc.hasPrefix("lntb") || lc.hasPrefix("lightning:") || lc.hasPrefix("lnbc") || lc.hasPrefix("lnbcrt") || lc.hasPrefix("lno") {
            decodeLighnting(invoice: addressInput.lowercased().replacingOccurrences(of: "lightning:", with: ""))
        } else {
            
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
                if isDirectSend {
                    self.chooseMixdepthToSpendFrom()
                    
                } else if isJmarket {
                    guard let jmWallet = jmWallet else { return }
                    promptToCoinjoinWithJM(jmWallet: jmWallet, recipient: addressInput, amount: amount)
                } else {
                    tryRaw()
                }
                
            case 1:
                self.createBlindNow(amount: amount.doubleValue, recipient: addressInput, strict: false)
                
            case 2:
                self.createBlindNow(amount: amount.doubleValue, recipient: addressInput, strict: true)
                
            default:
                break
            }
        }
    }
    
    private func promptToCoinjoinWithJM(jmWallet: Wallet, recipient: String, amount: String) {
        let counter = Int.random(in: 5...15)
        let sats = Int(Double(amount)! * 100000000.0)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Start coinjoin?", message: "You will *not* be prompted with the transaction verifier when using Join Market to create coinjoins!\n\nMake sure you are happy with the following as there is no going back:\n\nsats: \(sats)\naddress: \(recipient)\nfrom mixdepth: \(self.mixdepthToSpendFrom)\ncounterparties: \(counter)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Start Coinjoin", style: .default, handler: { action in
                JMUtils.coinjoin(wallet: jmWallet,
                                 amount_sats: sats,
                                 mixdepth: self.mixdepthToSpendFrom,
                                 counterparties: counter,
                                 address: recipient) { [weak self] (response, message) in
                    
                    guard let self = self else { return }
                    
                    self.handleJMResponse(response, message)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDirectSendWithJM(jmWallet: Wallet, recipient: String, amount: Int, mixdepth: Int) {
        //let counter = Int.random(in: 5...15)
        //let sats = Int(Double(amount)! * 100000000.0)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let alert = UIAlertController(title: "Direct send with Join Market?", message: "You will *not* be prompted with the transaction verifier when using Join Market to direct send!\n\nMake sure you are happy with the following as there is no going back:\n\nsats: \(amount)\naddress: \(recipient)\nfrom mixdepth: \(mixdepth)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Direct send", style: .default, handler: { action in
                JMUtils.directSend(wallet: jmWallet, address: recipient, amount: amount, mixdepth: mixdepth) { [weak self] (jmTx, message) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    
                    guard let jmTx = jmTx, let txid = jmTx.txid else {
                        showAlert(vc: self, title: "No transaction info received...", message: "Message: \(message ?? "unknown")")
                        return
                    }
                    
                    func done() {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }

                            let alert = UIAlertController(title: "Sent ✓", message: "joinmarket direct send sent.", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }

                                    self.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = self.view
                            self.present(alert, animated: true, completion: nil)
                        }
                    }
                    
                    FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
                        guard let self = self else { return }
                        
                        var dict:[String:Any] = ["txid": txid,
                                                 "id": UUID(),
                                                 "memo": "JM Direct Send",
                                                 "date": Date(),
                                                 "label": "JM Direct Send",
                                                 "fiatCurrency": self.fiatCurrency]
                        
                        self.spinner.removeConnectingView()
                        
                        guard let originRate = fxRate else {
                            CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in
                                done()
                            }
                            
                            return
                        }
                        
                        dict["originFxRate"] = originRate
                        
                        CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in
                            done()
                        }
                    }
                    
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func directSend(mixdepth: Int) {
        guard let jmWallet = jmWallet else { print("no jm wallet."); return }
        self.spinner.addConnectingView(vc: self, description: "direct sending with JM...")
        
        var sats = 0
        
        if amount == "0" {
            if amount == "0" {
                sats = 0
            }
        } else {
            guard let amount = convertedAmount() else { print("cant convert amoount"); return }
            let dblAmount = amount.doubleValue
            sats = Int(dblAmount * 100000000.0)
        }
        
        promptToDirectSendWithJM(jmWallet: jmWallet, recipient: self.addressInput.text!, amount: sats, mixdepth: mixdepth)
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
    
    @IBAction func lightningWithdrawAction(_ sender: Any) {
        guard let item = addressInput.text, item != "" else {
            showAlert(vc: self, title: "", message: "Add a recipient address first.")
            return
        }
        
        if item.hasPrefix("lntb") || item.hasPrefix("lightning:") || item.hasPrefix("lnbc") || item.hasPrefix("lnbcrt") || item.hasPrefix("lno") {
            decodeLighnting(invoice: item.replacingOccurrences(of: "lightning:", with: ""))
        } else {
            promptWithdrawalLightning(item)
        }
    }
    
    private func convertedAmount() -> String? {
        guard let amount = amountInput.text, amount != "" else { return nil }
        
        let dblAmount = amount.doubleValue
        
        guard dblAmount > 0.0 else {
            showAlert(vc: self, title: "", message: "Amount needs to be greater than 0.")
            return nil
        }
        
        if isFiat {
            guard let fxRate = fxRate else { return nil }
            
            return "\(rounded(number: dblAmount / fxRate).avoidNotation)"
        } else if isSats {
            return "\(rounded(number: dblAmount / 100000000.0).avoidNotation)"
        } else if isBtc {
            return "\(dblAmount.avoidNotation)"
        } else {
            return nil
        }
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
            if !isJmarket && !isFidelity {
                showAlert(vc: self, title: "Coin control ✓", message: "Only the utxo's you have just selected will be used in this transaction. You may send the total balance of the *selected utxo's* by tapping the \"⚠️ send all\" button or enter a custom amount as normal.")
            }
        }
        
        if isJmarket && !isFidelity {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.sliderViewBackground.alpha = 0
                self.lightningWithdrawOutlet.alpha = 0
                self.batchOutlet.removeFromSuperview()
                self.coinSelectionControl.alpha = 0
                    
                if self.isJmarket {
                    let title = "Join Market Transaction"
                    let mess = "Add a recipient address for your coinjoined funds. To remix select the Join Market wallet as the recipient."
                    let alert = UIAlertController(title: title, message: mess, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in }))
                    alert.popoverPresentationController?.sourceView = self.view
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
        if isFidelity {
            showAlert(vc: self, title: "Fidelity Bond", message: "⚠️ This is a timelocked address.\n\nFor best privacy practices it is recommended to use the \"Send all\" button to sweep the selected utxo(s) when creating a fidelity bond.\n\n⚠️ WARNING: You should send coins to this address only once. Only single biggest value UTXO will be announced as a fidelity bond. Sending coins to this address multiple times will not increase fidelity bond value. ⚠️ WARNING: Only send coins here which are from coinjoins or otherwise not linked to your identity.")
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        //outputsString = ""
        //outputArray.removeAll()
        inputs.removeAll()
        //inputsString = ""
        isJmarket = false
        isFidelity = false
    }
        
    private func promptWithdrawalLightning(_ recipient: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var title = "Withdraw from lightning wallet?"
            var mess = "This action will withdraw the amount specified to the given address from your lightning wallet"
            
            if self.amountInput.text == "" || self.amountInput.text == "0" || self.amountInput.text == "0.0" {
                title = "Withdraw ALL onchain funds from your ⚡️ wallet?\n"
                mess = "This action will withdraw the TOTAL available onchain amount from your lightning internal onchain wallet to:\n\n\(recipient)"
            }
            
            let alert = UIAlertController(title: title, message: mess, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Withdraw now", style: .default, handler: { action in
                self.withdrawLightningSanity()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func withdrawLightningSanity() {
        guard let amountString = amountInput.text, let address = addressInput.text, address != "" else {
            showAlert(vc: self, title: "Oops", message: "Add an address first.")// add option to withdraw to onchain wallet too
            return
        }
                
        confirmLightningWithdraw(address, amountString.doubleValue)
    }
    
    private func confirmLightningWithdraw(_ address: String, _ amount: Double) {
        var title = ""
        var sats = Int()
        
        let amountString = amountInput.text ?? ""
        let dblAmount = amountString.doubleValue
        
        if amount > 0.0 {
            if isFiat {
                guard let fxRate = fxRate else { return }
                let btcamount = rounded(number: amount / fxRate)
                sats = Int(btcamount * 100000000.0)
                title = "Withdraw $\(dblAmount) \(fiatCurrency) (\(sats) sats) from lightning wallet to \(address)?"
                
            } else if isSats {
                sats = Int(dblAmount)
                title = "Withdraw \(dblAmount) sats from lightning wallet to \(address)?"
                
            } else {
                sats = Int(amount * 100000000.0)
                title = "Withdraw \(amount.avoidNotation) btc (\(sats) sats) from lightning wallet to \(address)?"
            }
        } else {
            sats = 0
            title = "Sweep ALL funds from onchain lightning wallet?"
        }
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: title, message: "This action is not reversable!", preferredStyle: .alert)
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
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.withdrawFromCL(address: address, sats: sats)
                
                return
            }
            
            self.withdrawFromLND(address: address, sats: sats)
        }
    }
    
    private func withdrawFromLND(address: String, sats: Int) {
        let param:[String:Any] = ["addr": address,
                                  "amount": "\(sats)",
                                  "spend_unconfirmed": true,
                                  "send_all": !(sats > 0)]
        
        LndRpc.sharedInstance.command(.sendcoins, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response, let _ = dict["txid"] as? String else {
                showAlert(vc: self, title: "Uh oh, somehting is not right", message: error ?? "unknow error")
                return
            }
            
            showAlert(vc: self, title: "Success ✓", message: "Lightning wallet withdraw to\n\n\(address)\n\ncompleted ⚡️")
        }
    }
    
    private func withdrawFromCL(address: String, sats: Int) {
        var param:[String:Any] = ["destination":address, "satoshi":sats]
        if sats == 0 {
            param["satoshi"] = "all"
        }
        let commandId = UUID()
        //destination satoshi [feerate] [minconf] [utxos]
        LightningRPC.sharedInstance.command(id: commandId, method: .withdraw, param: param) { [weak self] (uuid, response, errorDesc) in
            guard commandId == uuid, let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let dict = response as? NSDictionary, let _ = dict["txid"] as? String else {
                showAlert(vc: self, title: "Uh oh, somehting is not right", message: errorDesc ?? "unknow error")
                return
            }
            
            showAlert(vc: self, title: "Success ✓", message: "Lightning wallet withdraw to\n\n\(address)\n\ncompleted ⚡️")
        }
    }
    
    
    @IBAction func fundLightning(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "Fetching lightning funding address...")
        
        isLndNode(completion: { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.getCLAddress()
                
                return
            }
            
            self.getLndAddress()
        })
    }
    
    private func getLndAddress() {
        LndRpc.sharedInstance.command(.getnewaddress, nil, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let dict = response, let address = dict["addr"] as? String else {
                spinner.removeConnectingView()
                if let error = error {
                    showAlert(vc: self, title: "", message: error)
                } else {
                    showAlert(vc: self, title: "", message: "No address returned.")
                }
                
                return
            }
            
            self.showFundingAddr(address)
        }
    }
    
    private func getCLAddress() {
        let commandId = UUID()
        LightningRPC.sharedInstance.command(id: commandId, method: .newaddr, param: nil) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
                        
            guard let dict = response as? NSDictionary, let address = dict["bech32"] as? String else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error fetching lightning wallet address")
                return
            }
            
            self.showFundingAddr(address)
        }
    }
    
    private func showFundingAddr(_ addr: String) {
        spinner.removeConnectingView()
        
        addAddress(addr)
        
        showAlert(
            vc: self,
            title: "⚡️ Lightning deposit address\n",
            message: "This is an address controlled by your Lightning node's internal onchain wallet. You can use it to fund your lightning node to open channels.\n\nTo fund channels directly from your active Fully Noded wallet you can navigate home > tap the ⚡️ button > Channels > + (c-lightning only)."
        )
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
                self.fxRateLabel.text = fxrate.exchangeRate
                switch self.fiatCurrency {
                case "USD":
                    self.denominationImage.image = UIImage(systemName: "dollarsign.circle")
                case "GBP":
                    self.denominationImage.image = UIImage(systemName: "sterlingsign.circle")
                case "EUR":
                    self.denominationImage.image = UIImage(systemName: "eurosign.circle")
                default:
                    break
                }
                
                self.amountIcon.backgroundColor = .systemBlue
                
                if UserDefaults.standard.object(forKey: "fiatAlert") == nil {
                    showAlert(vc: self, title: "\(self.fiatCurrency) denomination", message: "You may enter an amount denominated in \(self.fiatCurrency), we will calculate the equivalent amount in BTC based on the current exchange rate of \(fxrate.exchangeRate)")
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
    
    private func addAddress(_ address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.addressInput.text = address
            self.addressImageView.image = LifeHash.image(address)
            self.addressImageView.alpha = 1
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
        if isJmarket {
            //sweepToMix(receivingAddress)
            showAlert(vc: self, title: "Join Market does not support utxo selection...", message: "You really shouldn't even see this error.")
        } else {
            standardSweep(receivingAddress)
        }
    }
    
    private func standardSweep(_ receivingAddress: String) {
        var paramDict:[String:Any] = [:]
        paramDict["inputs"] = inputs
        paramDict["outputs"] = [[receivingAddress: "\(rounded(number: utxoTotal))"]]
        paramDict["bip32derivs"] = true
        
        if let feeRate = UserDefaults.standard.object(forKey: "feeRate") as? Int {            
            paramDict["options"] = ["includeWatching": true, "replaceable": true, "fee_rate": feeRate, "subtractFeeFromOutputs": [0], "changeAddress": receivingAddress]
        } else {
            paramDict["options"] = ["includeWatching": true, "replaceable": true, "conf_target": ud.object(forKey: "feeTarget") as? Int ?? 432, "subtractFeeFromOutputs": [0], "changeAddress": receivingAddress]
        }
        
        let param:Wallet_Create_Funded_Psbt = .init(paramDict)
        Reducer.sharedInstance.makeCommand(command: .walletcreatefundedpsbt(param: param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                self.spinner.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                return
            }
            
            let param_process:Wallet_Process_PSBT = .init(["psbt": psbt1])
            Reducer.sharedInstance.makeCommand(command: .walletprocesspsbt(param: param_process)) { [weak self] (response, errorMessage) in
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
    
    private func sweepToMix(_ recipient: String) {
        guard let jmWallet = jmWallet else { return }
        
        let counter = Int.random(in: 6...15)
        
        JMUtils.coinjoin(wallet: jmWallet,
                         amount_sats: 0,
                         mixdepth: self.mixdepthToSpendFrom,
                         counterparties: counter,
                         address: recipient) { [weak self] (response, message) in

            guard let self = self else { return }

            self.handleJMResponse(response, message)
        }
    }
    
    private func handleJMResponse(_ response: [String:Any]?, _ message: String?) {
        self.spinner.removeConnectingView()

        var tit = ""
        var mess = ""

        if message == "Service already started." {
            tit = "JM Service already running."
            mess = "You need to quit the current service or restart the jmwalletd.py script."
        }

        if let response = response {
            if response.isEmpty {
                tit = "JM Transaction initiated ✓"
                mess = "You can monitor its status by refreshing the transaction history. JM transactions may fail at which point you can try again by tapping the join button on the utxo."
            } else {
                tit = "JM response"
                mess = "\(response)"
            }
            
        } else if let message = message, message != "" {
            tit = "JM message:"
            mess = message

        } else {
            tit = "No response.."
            mess = "Usually after a succesful taker order JM replies with an empty response, this time we got nothing at all."
        }
        

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func sweepWallet(_ receivingAddress: String) {
        if isFidelity {
            self.amount = "0"
            self.chooseMixdepthToSpendFrom()
            
        } else if isJmarket {
            sweepToMix(receivingAddress)
        } else {
            activeWallet { wallet in
                if let wallet = wallet, wallet.isJm {
                    self.jmWallet = wallet
                    self.amount = "0"
                    self.chooseMixdepthToSpendFrom()
                } else {
                    self.standardWalletSweep(receivingAddress)
                }
            }
        }
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
                        
            Reducer.sharedInstance.makeCommand(command: .walletcreatefundedpsbt(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let result = response as? NSDictionary, let psbt1 = result["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                let process_param: Wallet_Process_PSBT = .init(["psbt": psbt1])
                Reducer.sharedInstance.makeCommand(command: .walletprocesspsbt(param: process_param)) { [weak self] (response, errorMessage) in
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
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.decodeFromCL(invoice)
                return
            }
            
            self.decodeFromLND(invoice)
        }
    }
    
    private func decodeFromLND(_ invoice: String) {
        LndRpc.sharedInstance.command(.decodepayreq, nil, invoice, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let dict = response else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "unknown error")
                return
            }
            
            if let numSatoshis = dict["num_satoshis"] as? String, numSatoshis != "0" {
                self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: nil)
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    guard let amountText = self.amountInput.text, amountText != "" else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
                        return
                    }
                    
                    let dblAmount = amountText.doubleValue
                    
                    guard dblAmount > 0.0 else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
                        return
                    }
                    
                    if self.isFiat {
                        guard let fxRate = self.fxRate else { return }
                        let btcamount = rounded(number: dblAmount / fxRate)
                        let msats = Int(btcamount * 100000000000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)
                        
                    } else if self.isSats {
                        let msats = Int(dblAmount * 1000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)
                        
                    } else {
                        let msats = Int(dblAmount * 100000000000.0)
                        self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)
                        
                    }
                }
            }
        }
    }
    
    private func parseOffer(offer: String, amountMsat: Int?) {
        var param:[String:Any] = ["offer": offer]
        // fetchinvoice offer [amount_msat] [quantity] [recurrence_counter] [recurrence_start] [recurrence_label] [timeout] [payer_note]
        if let amountMsat = amountMsat {
            param["amount_msat"] = amountMsat
            self.fetchInvoice(param: param)
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                guard let amountText = self.amountInput.text, amountText != "" else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
                    return
                }

                guard let msats = self.getMsatAmount(amountText: amountText) else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "There was an issue converting the amount to msats.")
                    return
                }

                param["amount_msat"] = msats
                self.fetchInvoice(param: param)
            }
        }
    }
    
    private func fetchInvoice(param: [String:Any]) {
        let commandId = UUID()
        var paramToUse:[String:Any] = param
        
        LightningRPC.sharedInstance.command(id: commandId, method: .fetchinvoice, param: param) { [weak self] (id, response, errorDesc) in
            guard let self = self else { return }

            guard let response = response as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue fetching the invoice.", message: errorDesc ?? "Unknown error.")
                return
            }
            guard let invoice = response["invoice"] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue fetching the invoice.", message: "No invoice returned from fetchinvoice.")
                return
            }
            
            paramToUse["num_msat"] = param["amount_msat"]

            self.promptToSendLightningPayment(invoice: invoice, dict: param, msat: nil)
        }
    }
    
    private func decodeFromCL(_ invoice: String) {
        let commandId = UUID()
        if invoice.hasPrefix("lno") {
            LightningRPC.sharedInstance.command(id: commandId, method: .decode, param: [invoice]) { [weak self] (id, response, errorDesc) in
                guard let self = self else { return }

                guard let response = response as? [String:Any],
                        let type = response["type"] as? String else {
                    self.spinner.removeConnectingView()
                    return
                }
                switch type {
                case "bolt12 offer":
                    // offer_amount_msat is a string
                    if let msatAmount = response["offer_amount_msat"] as? Int {
                        self.parseOffer(offer: invoice, amountMsat: msatAmount)
                    } else if var msatAmount = response["offer_amount_msat"] as? String {
                        msatAmount = msatAmount.replacingOccurrences(of: "msat", with: "")
                        guard let msatAmountInt = Int(msatAmount) else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "", message: "Unable to convert Core Lightning msat string to int.")
                            return
                        }
                        
                        self.parseOffer(offer: invoice, amountMsat: msatAmountInt)
                    }
                    
                default:
                    break
                }
            }
        } else {
            LightningRPC.sharedInstance.command(id: commandId, method: .decodepay, param: ["bolt11": invoice]) { [weak self] (uuid, response, errorDesc) in
                guard let self = self, commandId == uuid else { return }
                
                self.spinner.removeConnectingView()
                
                guard let dict = response as? [String:Any] else {
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error")
                    return
                }
                
                if let _ = dict["msatoshi"] as? Int {
                    self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: nil)
                    
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        guard let amountText = self.amountInput.text, amountText != "" else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
                            return
                        }
                        
                        guard let msats = self.getMsatAmount(amountText: amountText) else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "", message: "There was an issue converting the amount to msats.")
                            return
                        }
                        
                        self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)
                        
                        let dblAmount = amountText.doubleValue

                        guard dblAmount > 0.0 else {
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
                            return
                        }

                        if self.isFiat {
                            guard let fxRate = self.fxRate else { return }
                            let btcamount = rounded(number: dblAmount / fxRate)
                            let msats = Int(btcamount * 100000000000.0)


                        } else if self.isSats {
                            let msats = Int(dblAmount * 1000.0)
                            self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)

                        } else {
                            let msats = Int(dblAmount * 100000000000.0)
                            self.promptToSendLightningPayment(invoice: invoice, dict: dict, msat: msats)

                        }
                    }
                }
            }
       }
    }
    
    private func getMsatAmount(amountText: String) -> Int? {
        let dblAmount = amountText.doubleValue
        
        guard dblAmount > 0.0 else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "No amount specified.", message: "You need to enter an amount to send for an invoice that does not include one.")
            return nil
        }
        
        if self.isFiat {
            guard let fxRate = self.fxRate else { return nil }
            let btcamount = rounded(number: dblAmount / fxRate)
            return Int(btcamount * 100000000000.0)
            
        } else if self.isSats {
            return Int(dblAmount * 1000.0)
            
        } else {
            return Int(dblAmount * 100000000000.0)
        }
    }
    
    private func promptToSendLightningPayment(invoice: String, dict: [String:Any], msat: Int?) {
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.fxRate = fxRate
                self.invoice = dict
                if let msat = msat {
                    self.invoice!["userSpecifiedAmount"] = "\(msat)"
                }
                self.invoiceString = invoice
                self.performSegue(withIdentifier: "segueToLightningConf", sender: self)
            }
        }
    }
    
    private func payLightningNow(invoice: String, msat: Int?, dict: [String:Any]) {
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.payFromCL(invoice: invoice, msat: msat, dict: dict)
                return
            }
            
            self.payFromLNDViaRoutes(invoice: invoice, msat: msat, dict: dict)
        }
    }
    
    private func payFromLNDViaRoutes(invoice: String, msat: Int?, dict: [String:Any]) {
        var amount = dict["num_satoshis"] as? String ?? "0"
        if let msat = msat {
            amount = "\(Int(Double(msat) / 1000.0))"
        }
        let destination = dict["destination"] as? String ?? ""
        let paymentHash = dict["payment_hash"] as? String ?? ""
        let paymentHashData = Data(hexString: paymentHash)!.base64EncodedString()
        let ext = "\(destination)/\(amount)"
        let query:[String:Any] = ["fee_limit.percent":"1"]
        
        LndRpc.sharedInstance.command(.queryroutes, nil, ext, query) { [weak self] (response, error) in
            guard let self = self else { return }

            guard let routes = response?["routes"] as? NSArray, routes.count > 0 else {
                self.index = 0
                self.payInvoiceLND(invoice: invoice, sats: Int(amount)!, dict: dict)
                return
            }

            let lnrpcRouteToTry = routes[self.index]

            let param:[String:Any] = ["route": lnrpcRouteToTry, "payment_hash": paymentHashData]
            
            LndRpc.sharedInstance.command(.routepayment, param, nil, nil) { [weak self] (response, error) in
                guard let self = self else { return }

                guard let response = response else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "There was an issue...", message: error ?? "Unknown error.")
                    return
                }

                if let payment_error = response["payment_error"] as? String, payment_error != "" {
                    if routes.count < self.index {
                        self.index += 1
                        self.payFromLNDViaRoutes(invoice: invoice, msat: msat, dict: dict)
                    } else {
                        self.index = 0
                        self.payInvoiceLND(invoice: invoice, sats: Int(amount)!, dict: dict)
                    }
                } else if let _ = response["payment_preimage"] as? String {
                    let route = response["payment_route"] as! [String:Any]
                    let feesSat = (route["total_fees_msat"] as! String).msatToSat
                    self.saveTx(memo: dict["description"] as? String ?? "no memo", hash: dict["payment_hash"] as! String, sats: Int(amount)!, fee: feesSat)
                }
            }
        }
    }
    
    private func payInvoiceLND(invoice: String, sats: Int, dict: [String:Any]) {
        let param:[String:Any] = ["payment_request":invoice,"fee_limit":["percent":"1"], "allow_self_payment":true, "amt": "\(sats)"]
        
        LndRpc.sharedInstance.command(.payinvoice, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }

            guard let response = response else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue...", message: error ?? "Unknown error.")
                return
            }
            
            if let payment_error = response["payment_error"] as? String, payment_error != "" {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Payment Error", message: payment_error)
            } else if let _ = response["payment_preimage"] as? String {
                
                let route = response["payment_route"] as! [String:Any]
                let feesSat = (route["total_fees_msat"] as! String).msatToSat
                
                self.saveTx(memo: dict["description"] as? String ?? "no memo", hash: dict["payment_hash"] as! String, sats: sats, fee: feesSat)
            } else if let message = response["message"] as? String {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "There was an issue...", message: message)
            }
        }
    }
    
    private func saveTx(memo: String, hash: String, sats: Int, fee: Double?) {
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self else { return }
            
            var dict:[String:Any] = ["txid": hash,
                                     "id": UUID(),
                                     "memo": memo,
                                     "date": Date(),
                                     "label": "Fully Noded ⚡️ payment",
                                     "fiatCurrency": self.fiatCurrency]
            
            self.spinner.removeConnectingView()
            
            guard let originRate = fxRate else {
                CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                
                showAlert(vc: self, title: "Lightning payment sent ⚡️", message: "\n\(sats) sats sent.\n\nFor a fee of \(fee!.avoidNotation).")
                return
            }
            
            dict["originFxRate"] = originRate
            
            let tit = "Lightning payment sent ⚡️"
            
            let mess = "\n\(sats) sats / \((sats.satsToBtcDouble * originRate).fiatString) sent.\n\nFor a fee of \(fee!.avoidNotation) sats / \((fee!.satsToBtcDouble * originRate).fiatString)."
            
            showAlert(vc: self, title: tit, message: mess)
            
            CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
        }
    }
    
    private func payFromCL(invoice: String, msat: Int?, dict: [String:Any]) {
        //bolt11 [msatoshi] [label] [riskfactor] [maxfeepercent] [retry_for] [maxdelay] [exemptfee] [localinvreqid] [exclude] [maxfee] [description]
        var param:[String:Any] = [:]
        param["invoice"] = invoice
        if let msat = msat {
            param["msatoshi"] = msat
        }
        
        let memo = dict["description"] as? String ?? "no memo added"
        param["label"] = memo
        let payment_hash = dict["payment_hash"] as? String ?? ""
        
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .pay, param: param) { [weak self] (uuid, response, errorDesc) in
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
            
            let fee = Double((msatSentInt - msatInt)) / 1000.0
            
            self.saveTx(memo: memo, hash: payment_hash, sats: Int(Double(msatSentInt) / 1000.0), fee: fee)            
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
            
            self.addAddress(address)
            
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
        
        activeWallet { wallet in
            guard let wallet = wallet else {
                createNow()
                return
            }
            
            if wallet.isJm {
                self.jmWallet = wallet
                self.chooseMixdepthToSpendFrom()
            } else {
                createNow()
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
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
                
                vc.isScanningAddress = true
                
                vc.onDoneBlock = { addrss in
                    guard let addrss = addrss else { return }
                    
                    DispatchQueue.main.async { [unowned thisVc = self] in
                        let potentialLightning = addrss.lowercased()
                        if potentialLightning.hasPrefix("lntb") || potentialLightning.hasPrefix("lightning:") || potentialLightning.hasPrefix("lnbc") || potentialLightning.hasPrefix("lnbcrt"), potentialLightning.hasPrefix("lno") {
                            thisVc.decodeLighnting(invoice: potentialLightning.replacingOccurrences(of: "lightning:", with: ""))
                        } else {
                            thisVc.processBIP21(url: addrss)
                        }
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
            
        case "segueToLightningConf":
            guard let vc = segue.destination as? ConfirmLightningPaymentViewController else { fallthrough }
            
            vc.fxRate = self.fxRate
            vc.invoice = self.invoice
            self.spinner.removeConnectingView()
            
            vc.doneBlock = { [weak self] confirmed in
                guard let self = self else { return }
                
                if confirmed {
                    self.spinner.addConnectingView(vc: self, description: "paying lightning invoice...")
                    
                    if let userSpecifiedAmount = self.invoice!["userSpecifiedAmount"] as? String {
                        self.payLightningNow(invoice: self.invoiceString, msat: Int(userSpecifiedAmount)!, dict: self.invoice!)
                    } else {
                        self.payLightningNow(invoice: self.invoiceString, msat: nil, dict: self.invoice!)
                    }
                    
                } else {
                    self.invoice = nil
                    self.invoiceString = ""
                }
            }
            
        default:
            break
        }
    }
}
