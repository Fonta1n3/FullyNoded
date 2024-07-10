//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import Dispatch

class UTXOViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate {
    
    private var pickerView: UIPickerView!
    private var datePickerView: UIVisualEffectView!
    
    private let months = [
        ["January":"01"],
        ["February":"02"],
        ["March":"03"],
        ["April":"04"],
        ["May":"05"],
        ["June":"06"],
        ["July":"07"],
        ["August":"08"],
        ["September":"09"],
        ["October":"10"],
        ["November":"11"],
        ["December":"12"]
    ]
    
    private let years = [
        "2023",
        "2024",
        "2025",
        "2026"
    ]
    
    private var month = ""
    private var year = "2023"
    private var mixdepth = 0
    private var amountTotal = 0.0
    private let refresher = UIRefreshControl()
    private var unlockedUtxos = [Utxo]()
    private var inputArray:[[String:Any]] = []
    private var selectedUTXOs = [Utxo]()
    private var spinner = ConnectingView()
    private var wallet:Wallet?
    private var psbt:String?
    private var depositAddress:String?
    private var isJmarketWallet = false
    private var isJmarket = false
    private var isFidelity = false
    private var jmActive = false
    private var makerRunning = false
    private var takerRunning = false
    private var isDirectSend = false
    var fxRate:Double?
    var isBtc = false
    var isSats = false
    var isFiat = false
    
    @IBOutlet weak private var jmEarnOutlet: UIBarButtonItem!
    @IBOutlet weak private var jmMixOutlet: UIBarButtonItem!
    @IBOutlet weak private var tableView: UITableView!
    @IBOutlet weak private var jmStatusImageOutlet: UIImageView!
    @IBOutlet weak private var jmStatusLabelOutlet: UILabel!
    @IBOutlet weak private var jmActionOutlet: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UINib(nibName: UTXOCell.identifier, bundle: nil), forCellReuseIdentifier: UTXOCell.identifier)
        refresher.tintColor = UIColor.white
        refresher.addTarget(self, action: #selector(loadUnlockedUtxos), for: UIControl.Event.valueChanged)
        tableView.addSubview(refresher)
        jmMixOutlet.tintColor = .clear
        jmEarnOutlet.tintColor = .clear
        jmMixOutlet.isEnabled = false
        jmEarnOutlet.isEnabled = false
        jmStatusImageOutlet.alpha = 0
        jmStatusLabelOutlet.alpha = 0
        jmActionOutlet.alpha = 0
        
        activeWallet { wallet in
            guard let wallet = wallet else {
                return
            }
            
            self.wallet = wallet
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        amountTotal = 0.0
        unlockedUtxos.removeAll()
        selectedUTXOs.removeAll()
        inputArray.removeAll()
        checkForJmWallet()
    }
    
    private func checkForJmWallet() {
        guard let wallet = self.wallet else { return }
        if wallet.isJm {
            self.isJmarketWallet = true
            self.getStatus(wallet)
        } else {
            loadUnlockedUtxos()
        }
    }
    
    private func addSpinny(_ spinny: UIActivityIndicatorView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            spinny.frame = self.jmStatusImageOutlet.frame
            spinny.alpha = 1
            self.view.addSubview(spinny)
            spinny.startAnimating()
        }
    }
    
    private func getStatus(_ wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let spinny = UIActivityIndicatorView()
            self.addSpinny(spinny)
            self.jmStatusLabelOutlet.text = "checking join market status..."
            self.jmStatusLabelOutlet.alpha = 1
            
            JMUtils.session { [weak self] (response, message) in
                guard let self = self else { return }
                guard let status = response else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.jmStatusLabelOutlet.text = "join market inactive"
                        self.jmStatusImageOutlet.tintColor = .systemRed
                        self.hideJmSpinner(spinny: spinny)
                        self.loadUnlockedUtxos()
                        showAlert(vc: self, title: "", message: "Join Market server doesn't seem to be responding, are you sure it is on?")
                    }
                    return
                }
                
                self.jmActive = true
                self.makerRunning = false
                self.takerRunning = false
                
                if status.coinjoin_in_process {
                    self.setTakerRunningUi()
                } else if status.maker_running {
                    self.setMakerRunningUi()
                 } else if !status.maker_running {
                    self.setMakerStoppedUi()
                }
                                
                if !status.session {
                    JMUtils.wallets { (wallets, message) in
                        guard let wallets = wallets, wallets.count > 0 else {
                            self.hideJmSpinner(spinny: spinny)
                            self.addUtxoMixButton()
                            return
                        }
                        
                        var existsOnServer = false
                        
                        for (i, wallet) in wallets.enumerated() {
                            if wallet == self.wallet!.jmWalletName {
                                existsOnServer = true
                            }
                            
                            if i + 1 == wallets.count {
                                if existsOnServer {
                                    JMUtils.unlockWallet(wallet: self.wallet!) { (unlockedWallet, message) in
                                        guard let unlockedWallet = unlockedWallet else {
                                            if let message = message, message.contains("Wallet cannot be created/opened, it is locked") {
                                                self.hideJmSpinner(spinny: spinny)
                                                showAlert(vc: self, title: "Unable to unlock JM wallet.", message: "Deleting .joinmarket/wallets/.\(self.wallet!.jmWalletName).lock file in  on your JM server will fix this.")
                                            } else {
                                                self.hideJmSpinner(spinny: spinny)
                                                showAlert(vc: self, title: "Unable to unlock JM wallet...", message: message ?? "Unknown.")
                                            }
                                            
                                            return
                                        }
                                        
                                        guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                                            self.hideJmSpinner(spinny: spinny)
                                            showAlert(vc: self, title: "", message: "Unable to decrypt your jm auth token.")
                                            return
                                        }
                                        
                                        self.wallet!.token = encryptedToken
                                        self.setMakerStoppedUi()
                                        self.loadUnlockedUtxos()
                                        self.hideJmSpinner(spinny: spinny)
                                    }
                                } else {
                                    self.addUtxoMixButton()
                                    self.hideJmSpinner(spinny: spinny)
                                    self.loadUnlockedUtxos()
                                    
                                }
                            }
                        }
                    }
                } else {
                    self.hideJmSpinner(spinny: spinny)
                    self.loadUnlockedUtxos()
                }
            }
        }
    }
    
//    private func openClnFromJm(_ utxo: Utxo, address: String) {
//        JMRPC.sharedInstance.command(method: .listutxos(jmWallet: self.wallet!), param: nil) { (response, errorDesc) in
//            
//            func parseresponse(response: Any?, errorDesc: String?) {
//                guard let response = response as? [String:Any], let utxos = response["utxos"] as? [[String:Any]] else {
//                    //completion((nil, nil, "no jm utxos"))
//                    return
//                }
//                
//                guard utxos.count > 0 else {
//                    //completion((nil, nil, "no jm utxos"))
//                    return
//                }
//                
//                func createNow(_ paramDict_: [String:Any], descriptors: [[String:Any]]) {
//                    var processedDesc = descriptors
//                    let gdi:Get_Descriptor_Info = .init(["descriptor":descriptors[0]["desc"] as! String])
//                    
//                    OnchainUtils.getDescriptorInfo(gdi) { (descriptorInfo, mess) in
//                        guard let descriptorInfo = descriptorInfo else {
//                            //completion((nil, nil, mess))
//                            return
//                        }
//                        
//                        processedDesc[0]["desc"] = descriptorInfo.descriptor
//                        
//                        let param:Create_Psbt = .init(paramDict_)
//                        Reducer.sharedInstance.makeCommand(command: .createpsbt(param)) { (response, errorMessage) in
//                            guard let psbt = response as? String else {
//                                var desc = errorMessage ?? "unknown error"
//                                if desc.contains("Unexpected key fee_rate") {
//                                    desc = "In order to set the fee rate manually you must update to Bitcoin Core 0.21."
//                                }
//                                //completion((nil, nil, desc))
//                                return
//                            }
//                            let p: Utxo_Update_Psbt = .init(["psbt": psbt, "descriptors":descriptors])
//                            Reducer.sharedInstance.makeCommand(command: .utxoupdatepsbt(p)) { (response, errorMessag) in
//                                guard let updatedpsbt = response as? String else {
//                                    //completion((nil, nil, errorMessag))
//                                    return
//                                }
//                                print("updatedpsbt: \(updatedpsbt)")
//                                Signer.sign(psbt: updatedpsbt, passphrase: nil) { (psbt, rawTx, errorMessage) in
//                                    //completion((psbt, rawTx, errorMessage))
//                                }
//                            }
//                        }
//                    }
//                }
//                if !utxo.frozen!, utxo.confs! > 0, utxo.tries_remaining! > 0 {
//                    let utxo_string = utxo.utxo!
//                    let txid = utxo_string.split(separator: ":")[0]
//                    let vout = Int(utxo_string.split(separator: ":")[1])!
//                    let inputs = [["txid": txid, "sequence": 1, "vout": vout]]
//                    let btcAmount = utxo.amount
//                    let outputs = [[address:btcAmount]]
//                }
//            }
//            
//            if errorDesc == "Invalid credentials." {
//                JMUtils.unlockWallet(wallet: self.wallet!) { (unlockedWallet, message) in
//                    guard let unlockedWallet = unlockedWallet else {
//                        //completion((nil, nil, "error getting jm utxos: " + (message ?? "unknown")))
//                        return
//                    }
//                    
//                    guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
//                        //completion((nil, nil, "Unable to decrypt your jm auth token."))
//                        return
//                    }
//                    self.wallet!.token = encryptedToken
//                    
//                    JMRPC.sharedInstance.command(method: .listutxos(jmWallet: self.wallet!), param: nil) { (response, errorDesc) in
//                        parseresponse(response: response, errorDesc: errorDesc)
//                    }
//                }
//            } else {
//                parseresponse(response: response, errorDesc: errorDesc)
//            }
//        }
//    }
    
    private func hideJmSpinner(spinny: UIActivityIndicatorView) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            spinny.stopAnimating()
            spinny.alpha = 0
            self.jmStatusImageOutlet.alpha = 1
            
            self.jmMixOutlet.tintColor = .systemTeal
            self.jmEarnOutlet.tintColor = .systemTeal
            self.jmMixOutlet.isEnabled = true
            self.jmEarnOutlet.isEnabled = true
        }
    }
    
    private func setMakerStoppedUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmMixOutlet.tintColor = .systemTeal
            self.jmEarnOutlet.tintColor = .systemTeal
            self.jmMixOutlet.isEnabled = true
            self.jmEarnOutlet.isEnabled = true
            self.jmStatusImageOutlet.tintColor = .systemRed
            self.jmStatusLabelOutlet.text = "maker stopped"
            self.jmActionOutlet.setTitle("start", for: .normal)
            self.makerRunning = false
            self.jmActionOutlet.alpha = 1
        }
    }
    
    private func setMakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabelOutlet.text = "maker running"
            self.jmActionOutlet.alpha = 1
            self.makerRunning = true
            self.jmMixOutlet.tintColor = .clear
            self.jmEarnOutlet.tintColor = .clear
            self.jmMixOutlet.isEnabled = false
            self.jmEarnOutlet.isEnabled = false
        }
    }
    
    private func setTakerRunningUi() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.jmStatusLabelOutlet.text = "taker running"
            self.jmActionOutlet.setTitle("stop", for: .normal)
            self.jmActionOutlet.alpha = 1
            self.jmActionOutlet.isEnabled = true
            self.takerRunning = true
            self.jmMixOutlet.tintColor = .clear
            self.jmEarnOutlet.tintColor = .clear
            self.jmMixOutlet.isEnabled = false
            self.jmEarnOutlet.isEnabled = false
        }
    }
    
    private func addUtxoMixButton() {
        // show mix buttons on utxos to prompt jm wallet creation
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.jmMixOutlet.tintColor = .clear
            self.jmEarnOutlet.tintColor = .clear
            self.jmMixOutlet.isEnabled = false
            self.jmEarnOutlet.isEnabled = false
            self.jmStatusLabelOutlet.text = ""
            self.jmActionOutlet.alpha = 0
            self.jmActionOutlet.isEnabled = false
            self.jmStatusImageOutlet.alpha = 0
            self.isJmarket = false
            self.isJmarketWallet = false
            self.unlockedUtxos.removeAll()
            self.selectedUTXOs.removeAll()
            self.inputArray.removeAll()
            self.loadUnlockedUtxos()
        }
    }
    
    @IBAction func jmActionTapped(_ sender: Any) {
        if makerRunning {
            stopMaker()
        } else if takerRunning {
            stopTaker()
        } else {
            spinner.addConnectingView(vc: self, description: "starting maker bot...")
            startMaker()
        }
    }
    
    private func stopTaker() {
        guard let wallet = wallet else { return }
        
        JMUtils.stopTaker(wallet: wallet) { (response, message) in
            guard message == nil else {
                if message!.contains("Service cannot be stopped as it is not running") {
                    self.getStatus(wallet)
                } else {
                    showAlert(vc: self, title: "There was an issue stopping the taker.", message: message ?? "Unknown.")
                }
                
                return
            }
            
            self.getStatus(wallet)
        }
    }
    
    private func startMaker() {
        guard let wallet = self.wallet else { spinner.removeConnectingView(); return }
        
        JMUtils.startMaker(wallet: wallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            if let message = message {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: message)
                return
            }
            
            guard let response = response else {
                self.spinner.removeConnectingView()
                return
            }
            
            if response.isEmpty, message == nil {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    self.jmStatusImageOutlet.tintColor = .systemGreen
                    self.jmStatusLabelOutlet.text = "maker running"
                    self.jmActionOutlet.setTitle("stop", for: .normal)
                    self.jmActionOutlet.alpha = 1
                    self.makerRunning = true
                    self.jmMixOutlet.tintColor = .clear
                    self.jmEarnOutlet.tintColor = .clear
                    self.jmMixOutlet.isEnabled = false
                    self.jmEarnOutlet.isEnabled = false
                }
            }
            self.spinner.removeConnectingView()
        }
    }
    
    private func stopMaker() {
        guard let wallet = self.wallet else { return }
        
        spinner.addConnectingView(vc: self, description: "stopping maker bot...")
        
        JMUtils.stopMaker(wallet: wallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
                if let message = message, message != "" {
                    
                    if message.contains("Service cannot be stopped as it is not running.") {
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.jmStatusImageOutlet.tintColor = .systemRed
                            self.jmStatusLabelOutlet.text = "maker stopped"
                            self.jmActionOutlet.setTitle("start", for: .normal)
                            self.makerRunning = false
                            self.jmEarnOutlet.tintColor = .systemTeal
                            self.jmMixOutlet.tintColor = .systemTeal
                            self.jmEarnOutlet.isEnabled = true
                            self.jmMixOutlet.isEnabled = true
                        }
                        
                        showAlert(vc: self, title: "Unable to stop maker...", message: "Looks like your maker never actually started, this can happen for a number of reasons.")
                        
                    } else {
                        showAlert(vc: self, title: "", message: message)
                    }
                }
                return
            }
            
            if response.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.jmStatusImageOutlet.tintColor = .systemRed
                    self.jmStatusLabelOutlet.text = "maker stopped"
                    self.jmActionOutlet.setTitle("start", for: .normal)
                    self.makerRunning = false
                    self.jmEarnOutlet.tintColor = .systemTeal
                    self.jmMixOutlet.tintColor = .systemTeal
                    self.jmEarnOutlet.isEnabled = true
                    self.jmMixOutlet.isEnabled = true
                }
            }
            
            if let message = message, message != "" {
                showAlert(vc: self, title: "", message: message)
            }
        }
    }
    
    @IBAction func createFidelityBondAction(_ sender: Any) {
        guard let wallet = wallet, jmActive else { return }
        
        spinner.addConnectingView(vc: self, description: "checking fidelity bond status...")
        
        JMUtils.fidelityStatus(wallet: wallet) { [weak self] (exists, message) in
            guard let self = self else { return }
                        
            guard let exists = exists, exists else {
                guard self.selectedUTXOs.isEmpty else {
                    self.spinner.removeConnectingView()
                    showAlert(
                        vc: self,
                        title: "Fidelity Bond",
                        message: "You can not select specific utxos to spend from in JM, you'll be prmpted to select the mixdepth to spend from. Please deselect the utxos and try again."
                    )
                    return
                }
                self.promptToSelectTimelockDate()
                return
            }
            self.showFidelityBondOptions(wallet)
        }
    }
    
    private func showFidelityBondOptions(_ wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond"
            let mess = ""

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Unfreeze fb", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.unfreezeFb(wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                self.removeSpinner()
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func startMakerNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = "starting maker..."
            self.startMaker()
        }
    }
    
    private func directSend(_ wallet: Wallet) {
        directSendNow()
    }
    
    private func unfreezeFb(_ wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = "unfreezing fb utxo..."
            
            JMUtils.unfreezeFb(wallet: wallet) { (response, message) in
                self.spinner.removeConnectingView()
                
                guard let _ = response else {
                    showAlert(vc: self, title: "There was an issue...", message: message ?? "Unknown issue unfreezing utxo.")
                    return
                }
                
                guard let message = message else {
                    showAlert(vc: self, title: "Utxo unfrozen", message: "You should be able to join or earn with your expired fidelity bond funds now.")
                    return
                }
                
                showAlert(vc: self, title: "Message from JM:", message: message)
            }
        }
    }
    
    private func promptToSelectTimelockDate() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond"
            let mess = "A fidelity bond is a timelocked bitcoin address.  FN can not spend a FB without a connection to your JM server and wallet.\n\nCreating a fidelity bond increases your earning potential. The higher the amount/duration of the bond, the higher the earning potential.\n\nYou will be prompted to select an expiry date for the bond, you will NOT be able to spend these funds until that date."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.selectTimelockDate()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func selectTimelockDate() {
        datePickerView = blurView()
        view.addSubview(datePickerView)
    }
    
    @objc func closeDatePicker() {
        datePickerView.removeFromSuperview()
        getFidelityAddress()
    }
    
    @objc func cancelDatePicker() {
        datePickerView.removeFromSuperview()
    }
    
    private func blurView() -> UIVisualEffectView {
        let effect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(frame: view.frame)
        blurView.effect = effect
        
        pickerView = UIPickerView(frame: .init(x: 0, y: 200, width: self.view.frame.width, height: 300))
        pickerView.delegate = self
        pickerView.dataSource = self
        blurView.contentView.addSubview(pickerView)
        
        let cal = Calendar.current
        var monthInt = cal.component(.month, from: Date())
        if monthInt == 12 {
            monthInt = 1
        } else {
            monthInt += 1
        }
        
        month = String(format: "%02d", monthInt)
        
        pickerView.selectRow(monthInt - 1, inComponent: 0, animated: true)
        
        let label = UILabel()
        label.textColor = .lightGray
        label.frame = CGRect(x: 16, y: pickerView.frame.minY - 40, width: pickerView.frame.width - 32, height: 40)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.text = "⚠️ Select the fidelity bond expiry date. Funds sent to the fidelity bond address will not be spendable until midnight (UTC) on the 1st day of the selected month/year."
        label.sizeToFit()
        blurView.contentView.addSubview(label)
        
        let button = UIButton()
        button.frame = CGRect(x: 0, y: pickerView.frame.maxY + 20, width: view.frame.width, height: 40)
        button.setTitle("Next", for: .normal)
        button.addTarget(self, action: #selector(closeDatePicker), for: .touchUpInside)
        button.showsTouchWhenHighlighted = true
        button.setTitleColor(.systemTeal, for: .normal)
        blurView.contentView.addSubview(button)
        
        let cancel = UIButton()
        cancel.frame = CGRect(x: 0, y: button.frame.maxY + 20, width: view.frame.width, height: 40)
        cancel.setTitle("Cancel", for: .normal)
        cancel.addTarget(self, action: #selector(cancelDatePicker), for: .touchUpInside)
        cancel.showsTouchWhenHighlighted = true
        cancel.setTitleColor(.systemTeal, for: .normal)
        blurView.contentView.addSubview(cancel)
        
        return blurView
    }
        
    private func getFidelityAddress() {
        guard let wallet = wallet else {
            return
        }
        
        spinner.addConnectingView(vc: self, description: "getting timelocked address...")

        let date = "\(year)-\(month)"
        
        JMUtils.fidelityAddress(wallet: wallet, date: date) { [weak self] (address, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let address = address else {
                showAlert(vc: self, title: "Unable to fetch timelocked address...", message: message ?? "Unknown.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let tit = "Fidelity Bond"
                let mess = "This is a timelocked bitcoin address which prevents you from spending the funds until midnight on the 1st of \(date) (UTC).\n\nYou will be presented with the transaction creator as normal with the fidelity bond address automatically entered."

                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                                                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.isFidelity = true
                        self.depositAddress = address
                        self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                    }
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    
    @IBAction func mixAction(_ sender: Any) {
        spinner.addConnectingView(vc: self, description: "checking JM session status...")
        
        JMUtils.session { (response, message) in
            self.spinner.removeConnectingView()
            
            guard let session = response else {
                showAlert(vc: self, title: "Unable to fetch sesssion...", message: message ?? "Unknown error.")
                return
            }
            
            guard !session.coinjoin_in_process else {
                showAlert(vc: self, title: "Coinjoin already in process...", message: "Only one coinjoin session can be active at a time.")
                return
            }
                        
            if self.unlockedUtxos.count > 1 {
                if self.selectedUTXOs.count > 0 {
                    showAlert(vc: self, title: "Coin control not yet supported for JM.", message: "You need to manually freeze your utxos using the JM wallet tool scripts.")
                } else {
                    self.joinNow()
                }
                
            } else {
                self.joinNow()
            }
        }
    }
    
    private func joinNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Join?"
            let mess = "This action will create a coinjoin transaction to the address of your choice.\n\nSpecify the mixdepth (account) you want to join from.\n\nOn the next screen you can select a recipient address and amount as normal. The fees will be determined as per your Join Market config."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "Mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(0)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 1", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(1)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 2", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(2)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 3", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.joinMixdepthNow(3)
            }))
            
            alert.addAction(UIAlertAction(title: "Mixdepth 4", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.joinMixdepthNow(4)
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func joinMixdepthNow(_ mixdepth: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mixdepth = mixdepth
            self.isJmarket = true
            self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
        }
    }
    
    private func directSendNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Direct send?"
            let mess = "This action will direct send from mixdepth 0. Select a recipient and amount as normal."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)

            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.isJmarket = true
                    self.isDirectSend = true
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }))

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
    @IBAction private func lockAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "goToLocked", sender: self)
        }
    }
            
    private func updateSelectedUtxos() {
        selectedUTXOs.removeAll()
        
        for utxo in unlockedUtxos {
            if utxo.isSelected {
                selectedUTXOs.append(utxo)
            }
        }
    }
    
    @IBAction private func createRaw(_ sender: Any) {
        guard let version = UserDefaults.standard.object(forKey: "version") as? Int, version >= 210000 else {
            showAlert(vc: self, title: "Bitcoin Core needs to be updated",
                      message: "Manual utxo selection requires Bitcoin Core 0.21, please update and try again. If you already have 0.21 go to the home screen, refresh and load it completely then try again.")
            
            return
        }
        
        if let w = self.wallet, w.isJm {
            self.isDirectSend = true
            if self.selectedUTXOs.count > 0 {
                showAlert(vc: self, title: "", message: "Utxo selection is not supported by jm wallets. Deselect the utxos and tap the chain button again to create a direct send transaction with joinmarket. You will be prompted to choose which mixdepth to spend from.")
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.updateInputs()
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }
        } else {
            if self.selectedUTXOs.count > 0 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.updateInputs()
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            } else {
                showAlert(vc: self, title: "Select a UTXO first", message: "Just tap a utxo(s) to select it. Then tap the 🔗 to create a transaction with those utxos.")
            }
        }
    }
    
    private func lock(_ utxo: Utxo) {
        spinner.addConnectingView(vc: self, description: "locking...")
        
        let param = Lock_Unspent(["unlock": false, "transactions": [["txid": utxo.txid,"vout": utxo.vout]]])
        
        Reducer.sharedInstance.makeCommand(command: .lockunspent(param)) { (response, errorMessage) in
            guard let success = response as? Bool else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "unknown error")
                }
                
                return
            }
            
            if success {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                }
                
                showAlert(vc: self, title: "UTXO Locked 🔐", message: "You can tap the locked button to see your locked utxo's and unlock them. Be aware if your node reboots all utxo's will be unlocked by default!")
                
            } else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: "utxo was not locked")
                }
            }
        }
    }
    
    private func updateInputs() {
        inputArray.removeAll()
        amountTotal = 0.0
        
        for utxo in selectedUTXOs {
            amountTotal += utxo.amount ?? 0.0
            let input:[String:Any] = ["txid": utxo.txid, "vout": utxo.vout, "sequence": 1]
            inputArray.append(input)
        }
    }
    
    private func finishedLoading() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.updateSelectedUtxos()
            self.tableView.isUserInteractionEnabled = true
            self.tableView.reloadData()
            self.tableView.setContentOffset(.zero, animated: true)
            self.removeSpinner()
        }
    }
    
    @objc private func loadUnlockedUtxos() {
        unlockedUtxos.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.isUserInteractionEnabled = false
            self.addSpinner()
        }
        
        if let w = wallet, w.isJm, let jmwallet = self.wallet {
            // use jm to fetch the utxos for the specific wallet
            getUtxosFromJm(jmwallet: jmwallet)
        } else {
            getUtxosFromBtcRpc()
        }
    }
    
    private func getUtxosFromJm(jmwallet: Wallet) {
        JMRPC.sharedInstance.command(method: .listutxos(jmWallet: jmwallet), param: nil) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            if errorDesc == "Invalid credentials." {
                JMUtils.unlockWallet(wallet: jmwallet) { (unlockedWallet, message) in
                    guard let unlockedWallet = unlockedWallet else {
                        showAlert(vc: self, title: "Join Market message", message: message ?? "unknown error unlocking your jm wallet.")
                        return
                    }
                    
                    guard let encryptedToken = Crypto.encrypt(unlockedWallet.token.utf8) else {
                        showAlert(vc: self, title: "", message: "Unable to decrypt your jm auth token.")
                        return
                    }
                    self.wallet!.token = encryptedToken
                    self.getUtxosFromJm(jmwallet: self.wallet!)
                }
            } else {
                guard let response = response as? [String:Any], let utxos = response["utxos"] as? [[String:Any]] else {
                    self.finishedLoading()
                    return
                }
                
                guard utxos.count > 0 else {
                    self.finishedLoading()
                    return
                }
                
                for (i, utxo) in utxos.enumerated() {
                    var jmUtxoDict = utxo
                    let amountBtc = Utxo(jmUtxoDict).amount!
                    jmUtxoDict["amountSats"] = amountBtc.sats
                    self.unlockedUtxos.append(Utxo(jmUtxoDict))
                    if i + 1 == utxos.count {
                        self.unlockedUtxos = self.unlockedUtxos.sorted {
                            $0.confs ?? 0 < $1.confs ?? 1
                        }
                        self.finishedLoading()
                    }
                }
            }
        }
    }
    
    private func getUtxosFromBtcRpc() {
        let param:List_Unspent = .init(["minconf":0])
        OnchainUtils.listUnspent(param: param) { [weak self] (utxos, message) in
            guard let self = self else { return }
            
            guard let utxos = utxos else {
                self.finishedLoading()
                showAlert(vc: self, title: "Error", message: message ?? "unknown error fecthing your utxos")
                return
            }
            
            guard utxos.count > 0 else {
                self.finishedLoading()
                showAlert(vc: self, title: "No UTXO's", message: "")
                return
            }
            
            DispatchQueue.background(delay: 0.0, completion: {
                for (i, utxo) in utxos.enumerated() {
                    
                    var utxoDict = utxo.dict
                    utxoDict["isJoinMarket"] = self.isJmarketWallet
                    
                    func finish() {
                        self.unlockedUtxos.append(Utxo(utxoDict))
                        
                        if i + 1 == utxos.count {
                            self.unlockedUtxos = self.unlockedUtxos.sorted {
                                $0.confs ?? 0 < $1.confs ?? 1
                            }
                            self.finishedLoading()
                        }
                    }
                    
                    //let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
                    let amountBtc = utxo.amount!
                    utxoDict["amountSats"] = amountBtc.sats
                    finish()
                }
            }
        )}
    }
    
    private func removeSpinner() {
        DispatchQueue.main.async {
            self.refresher.endRefreshing()
            self.spinner.removeConnectingView()
        }
    }
    
    private func addSpinner() {
        DispatchQueue.main.async {
            self.spinner.addConnectingView(vc: self, description: "Getting UTXOs")
        }
    }
    
    private func fetchOriginRate(_ utxo: Utxo) {
        guard let date = utxo.date, let id = utxo.txUUID else {
            showAlert(vc: self, title: "", message: "Date or saved tx UUID missing.")
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        
        let today = dateFormatter.string(from: Date())
        
        if dateString == today {
            showAlert(vc: self, title: "", message: "You need to wait for the transaction to be at least one day old before fetching the historic rate.")
        } else {
            self.spinner.addConnectingView(vc: self, description: "")
            
            FiatConverter.sharedInstance.getOriginRate(date: dateString) { [weak self] originRate in
                guard let self = self else { return }
                
                guard let originRate = originRate else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "There was an issue fetching the historic exchange rate, please let us know about it.")
                    return
                }
                
                CoreDataService.update(id: id, keyToUpdate: "originFxRate", newValue: originRate, entity: .transactions) { [weak self] success in
                    guard let self = self else { return }
                    
                    guard success else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "", message: "There was an issue saving the historic exchange rate, please let us know about it.")
                        return
                    }
                    
                    self.loadUnlockedUtxos()
                }
            }
        }
    }
        
    private func depositNow(_ utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            for (i, unlockedUtxo) in self.unlockedUtxos.enumerated() {
                if unlockedUtxo.id == utxo.id && unlockedUtxo.txid == utxo.txid && unlockedUtxo.vout == utxo.vout {
                    self.unlockedUtxos[i].isSelected = true
                    self.updateSelectedUtxos()
                    self.updateInputs()
                }
                
                if i + 1 == self.unlockedUtxos.count {
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }
        }
    }
    
    private func promptToLockWallets() {
        CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
            guard let wallets = wallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "You have an existing Join Market wallet which is unlocked, you need to lock it before we can create a new one."
                
                let mess = ""
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
                
                JMUtils.wallets { (server_wallets, message) in
                    guard let server_wallets = server_wallets else { return }
                    for server_wallet in server_wallets {
                        DispatchQueue.main.async {
                            alert.addAction(UIAlertAction(title: server_wallet, style: .default, handler: { [weak self] action in
                                guard let self = self else { return }
                                
                                self.spinner.addConnectingView(vc: self, description: "locking wallet...")
                                
                                for fnwallet in wallets {
                                    if fnwallet["id"] != nil {
                                        let str = Wallet(dictionary: fnwallet)
                                        if str.jmWalletName == server_wallet {
                                            JMUtils.lockWallet(wallet: str) { [weak self] (locked, message) in
                                                guard let self = self else { return }
                                                self.spinner.removeConnectingView()
                                                if locked {
                                                    showAlert(vc: self, title: "Wallet locked ✓", message: "Try joining the utxo again.")
                                                } else {
                                                    showAlert(vc: self, title: message ?? "Unknown issue locking that wallet...", message: "FN can only work with one JM wallet at a time, it looks like you need to restart your JM daemon in order to create a new wallet. Restart JM daemon and try again.")
                                                }
                                            }
                                        }
                                    }
                                }
                            }))
                        }
                    }
                }
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
//    private func promptToDepositToWallet(_ utxo: Utxo, _ serverWallets: [String]) {
//        //CoreDataService.retrieveEntity(entityName: .jmWallets) { wallets in
//            //guard let wallets = wallets else { return }
//
//            DispatchQueue.main.async { [weak self] in
//                guard let self = self else { return }
//
//                let tit = "Deposit \(utxo.amount ?? 0.0) utxo to Join Market wallet?"
//
//                let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal."
//
//                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
//
//                CoreDataService.retrieveEntity(entityName: .wallets) { wallets in
//                    guard let wallets = wallets, !wallets.isEmpty else {
//                        return
//                    }
//
//                    for wallet in wallets {
//                        if wallet["id"] != nil {
//                            let str = Wallet(dictionary: wallet)
//                            for serverWallet in serverWallets {
//                                if serverWallet == str.jmWalletName {
//                                    alert.addAction(UIAlertAction(title: str.jmWalletName, style: .default, handler: { [weak self] action in
//                                        guard let self = self else { return }
//
//                                        self.spinner.addConnectingView(vc: self, description: "fetching jm deposit address...")
//                                        self.getJmAddressNow(wallet: str, utxo: utxo)
//                                    }))
//                                }
//                            }
//                        }
//                    }
//                }
//
//                alert.addAction(UIAlertAction(title: "Create new", style: .default, handler: { [weak self] action in
//                    guard let self = self else { return }
//
//                    self.promptToCreateJmWallet(utxo)
//                }))
//
//                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
//                    guard let self = self else { return }
//
//                    self.spinner.removeConnectingView()
//                }))
//
//                alert.popoverPresentationController?.sourceView = self.view
//                self.present(alert, animated: true, completion: nil)
//            }
//        //}
//    }
    
    private func getJmAddressNow(wallet: Wallet, utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Deposit utxo with \(utxo.amount ?? 0.0) btc to Join Market wallet?"
            
            let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining and earning. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal. For best privacy practices send all the btc from this utxo to your JM wallet"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            
            for i in 0...4 {
                alert.addAction(UIAlertAction(title: "Send to mixdepth \(i)", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.spinner.addConnectingView(vc: self, description: "getting JM deposit address...")
                    
                    JMUtils.getAddress(wallet: wallet, mixdepth: i) { (address, message) in
                        self.spinner.removeConnectingView()
                        
                        guard let address = address else {
                            showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                            return
                        }
                        
                        self.depositAddress = address
                        self.depositNow(utxo)
                    }
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    
//    private func createJMWalletNow(_ utxo: Utxo) {
//        self.spinner.addConnectingView(vc: self, description: "creating JM wallet (this can take 30 seconds or so, please be patient)...")
//
//        let currentWallet = self.wallet?.name ?? ""
//
//        JMUtils.createWallet { [weak self] (response, message) in
//            guard let self = self else { return }
//
//            self.spinner.removeConnectingView()
//
//            guard let jmWallet = response else {
//                if let mess = message, mess.contains("Wallet already unlocked.") {
//                    self.promptToLockWallets()
//                } else {
//                    showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
//                }
//
//                return
//            }
//
//            UserDefaults.standard.setValue(currentWallet, forKey: "walletName")
//            self.jmWalletCreated(utxo, jmWallet)
//        }
//    }
    
    
//    private func promptToCreateJmWallet(_ utxo: Utxo) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            let tit = "Create a Join Market wallet?"
//
//            let mess = "In order to join your utxos you need to create a Join Market wallet. This will be like your other Fully Noded wallets with the added ability to instantly join and earn interest on your balance."
//
//            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
//
//            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] action in
//                guard let self = self else { return }
//
//                self.createJMWalletNow(utxo)
//            }))
//
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
//    }
    
//    private func jmWalletCreated(_ utxo: Utxo, _ wallet: Wallet) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            guard let decryptedPassword = Crypto.decrypt(wallet.password!), let password = decryptedPassword.utf8String else { return }
//
//            let tit = "Join Market wallet created ✓"
//            let mess = "The Join Market signer has been encrypted and saved on Fully Noded and your Join Market server ✓\n\n⚠️ Always back up your signers offline on paper or metal to prevent loss of funds! To access the signer go to signers and it will be labeled Join Market."
//
//            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
//
//            alert.addAction(UIAlertAction(title: "Deposit", style: .default, handler: { [weak self] action in
//                guard let self = self else { return }
//
//                self.promptToDeposit(utxo, wallet)
//            }))
//
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
//    }
    
    private func promptToDeposit(_ utxo: Utxo, _ wallet: Wallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Deposit utxo with \(utxo.amount ?? 0.0) btc to Join Market wallet?"
            
            let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining and earning. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal. For best privacy practices send all the btc from this utxo to your JM wallet"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
            
            for i in 0...4 {
                alert.addAction(UIAlertAction(title: "Send to mixdepth \(i)", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.spinner.addConnectingView(vc: self, description: "getting JM deposit address...")
                    
                    JMUtils.getAddress(wallet: wallet, mixdepth: i) { (address, message) in
                        self.spinner.removeConnectingView()
                        
                        guard let address = address else {
                            showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                            return
                        }
                        
                        self.depositAddress = address
                        self.depositNow(utxo)
                    }
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToDonateChange(_ utxo: Utxo) {
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "Donate toxic change?"
                let mess = "Toxic change is best used as a donation to the developer."
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .actionSheet)
                
                alert.addAction(UIAlertAction(title: "Donate", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    guard let donationAddress = Keys.donationAddress() else {
                        return
                    }
                    
                    self.depositAddress = donationAddress
                    self.depositNow(utxo)
                }))
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
    }
                
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
            
        case "goToLocked":
            guard let vc = segue.destination as? LockedViewController else { fallthrough }
            
            vc.fxRate = fxRate
            vc.isFiat = isFiat
            vc.isBtc = isBtc
            vc.isSats = isSats
            
        case "segueToSendFromUtxos":
            guard let vc = segue.destination as? CreateRawTxViewController else { fallthrough }
            
            vc.isFidelity = isFidelity
            vc.isJmarket = isJmarket
            vc.isDirectSend = isDirectSend
            vc.mixdepthToSpendFrom = mixdepth
            vc.jmWallet = wallet
            vc.inputs = inputArray
            vc.utxoTotal = amountTotal
            vc.address = depositAddress ?? ""
            
        case "segueToBroadcasterFromUtxo":
            guard let vc = segue.destination as? VerifyTransactionViewController, let psbt = psbt else { fallthrough }
            
            vc.unsignedPsbt = psbt
            
        default:
            break
        }
    }
}


// MARK: UTXOCellDelegate

extension UTXOViewController: UTXOCellDelegate {
    func didTapToLock(_ utxo: Utxo) {
        lock(utxo)
    }
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        
        cell.configure(
            utxo: utxo,
            isLocked: false,
            fxRate: fxRate,
            isSats: isSats,
            isBtc: isBtc,
            isFiat: isFiat,
            delegate: self
        )
        
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return unlockedUtxos.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
}


// MarK: UITableViewDelegate

extension UTXOViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 5 // Spacing between cells
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! UTXOCell
        let isSelected = unlockedUtxos[indexPath.section].isSelected
        
        if isSelected {
            cell.deselectedAnimation()
        } else {
            cell.selectedAnimation()
        }
        
        unlockedUtxos[indexPath.section].isSelected = !isSelected
        
        updateSelectedUtxos()
        updateInputs()
        
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
}

extension UTXOViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
        case 0:
            return months.count
        case 1:
            return years.count
        default:
            return 0
        }
    }
}

extension UTXOViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        var toReturn:String?
        switch component {
        case 0:
            let dict = months[row]
            for (key, _) in dict {
                toReturn = key
            }
        case 1:
            toReturn = years[row]
        default:
            break
        }
        
        return toReturn
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            let dict = months[row]
            for (_, value) in dict {
                month = value
            }
        case 1:
            year = years[row]
        default:
            break
        }
    }
}
