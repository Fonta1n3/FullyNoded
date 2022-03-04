//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

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
    private var year = "2022"
    private var mixdepth = 0
    private var amountTotal = 0.0
    private let refresher = UIRefreshControl()
    private var unlockedUtxos = [Utxo]()
    private var inputArray = [String]()
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
    private var jmWallet:JMWallet?
    
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
            self.checkForJmWallet()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        amountTotal = 0.0
        unlockedUtxos.removeAll()
        selectedUTXOs.removeAll()
        inputArray.removeAll()
        loadUnlockedUtxos()
    }
    
    private func checkForJmWallet() {
        guard let wallet = self.wallet else { return }
        
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmwallets in
            guard let jmwallets = jmwallets, !jmwallets.isEmpty else {
                return
            }
            
            for jmwallet in jmwallets {
                let str = JMWallet(jmwallet)
                if str.fnWallet == wallet.name {
                    self.jmWallet = str
                    self.isJmarketWallet = true
                    self.getStatus(str)
                }
            }
        }
    }
    
    private func getStatus(_ jmWallet: JMWallet) {
        let spinny = UIActivityIndicatorView()
        spinny.frame = self.jmStatusImageOutlet.frame
        spinny.alpha = 1
        self.view.addSubview(spinny)
        spinny.startAnimating()
        jmStatusLabelOutlet.text = "checking join market status..."
        jmStatusLabelOutlet.alpha = 1
        
        JMUtils.session { [weak self] (response, message) in
            guard let self = self else { return }
            
            spinny.stopAnimating()
            spinny.alpha = 0
            self.jmStatusImageOutlet.alpha = 1
            
            self.jmMixOutlet.tintColor = .systemTeal
            self.jmEarnOutlet.tintColor = .systemTeal
            self.jmMixOutlet.isEnabled = true
            self.jmEarnOutlet.isEnabled = true
            
            guard let status = response else {
                self.jmStatusLabelOutlet.text = "join market inactive"
                self.jmStatusImageOutlet.tintColor = .systemRed
                return
            }
            
            self.jmActive = true
            
            self.makerRunning = false
                            
            if status.coinjoin_in_process {
                self.jmStatusLabelOutlet.text = "taker running"
                self.jmActionOutlet.setTitle("stop", for: .normal)
                self.jmActionOutlet.alpha = 1
                self.jmActionOutlet.isEnabled = true
                self.takerRunning = true
                self.jmMixOutlet.tintColor = .clear
                self.jmEarnOutlet.tintColor = .clear
                self.jmMixOutlet.isEnabled = false
                self.jmEarnOutlet.isEnabled = false
                
            } else if status.maker_running {
                self.jmStatusLabelOutlet.text = "maker running"
                self.jmActionOutlet.alpha = 1
                self.makerRunning = true
                self.jmMixOutlet.tintColor = .clear
                self.jmEarnOutlet.tintColor = .clear
                self.jmMixOutlet.isEnabled = false
                self.jmEarnOutlet.isEnabled = false
                
            } else if status.session {
                DispatchQueue.main.async {
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
                
            } else {
                self.jmActive = false
                self.jmStatusLabelOutlet.text = "join market connected"
                self.jmEarnOutlet.tintColor = .clear
                self.jmMixOutlet.isEnabled = false
                self.jmMixOutlet.tintColor = .clear
                self.jmEarnOutlet.isEnabled = false
                
                var existsOnServer = false
                
                JMUtils.wallets { (wallets, message) in
                    guard let wallets = wallets else {
                        return
                    }
                    
                    for (i, wallet) in wallets.enumerated() {
                        if wallet == jmWallet.name {
                            existsOnServer = true
                        }
                        
                        if i + 1 == wallets.count {
                            if existsOnServer {
                                JMUtils.unlockWallet(wallet: jmWallet) { (unlockedWallet, message) in
                                    guard let _ = unlockedWallet else {
                                        showAlert(vc: self, title: "Unable to unlock JM wallet...", message: message ?? "Unknown.")
                                        return
                                    }
                                    
                                    CoreDataService.retrieveEntity(entityName: .jmWallets) { jmwallets in
                                        guard let jmwallets = jmwallets, !jmwallets.isEmpty else { return }
                                        
                                        for jmwallet in jmwallets {
                                            let jmwalletstr = JMWallet(jmwallet)
                                            if jmwalletstr.name == jmWallet.name {
                                                self.jmWallet = jmwalletstr
                                                
                                                DispatchQueue.main.async {
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
                                        }
                                    }
                                }
                            } else {
                                // show mix buttons on utxos to prompt jm wallet creation
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
                                
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    
                                    self.unlockedUtxos.removeAll()
                                    self.selectedUTXOs.removeAll()
                                    self.inputArray.removeAll()
                                    self.loadUnlockedUtxos()
                                }
                            }
                        }
                    }
                }
            }
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
        guard let jmWallet = jmWallet else { return }
        
        JMUtils.stopTaker(wallet: jmWallet) { (response, message) in
            guard message == nil else {
                showAlert(vc: self, title: "There was an issue stopping the taker.", message: message ?? "Unknown.")
                return
            }
            
            self.getStatus(jmWallet)
        }
    }
    
    private func startMaker() {
        guard let jmWallet = self.jmWallet else { spinner.removeConnectingView(); return }        
        
        JMUtils.startMaker(wallet: jmWallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
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
        }
    }
    
    private func stopMaker() {
        guard let jmWallet = self.jmWallet else { return }
        
        spinner.addConnectingView(vc: self, description: "stopping maker bot...")
        
        JMUtils.stopMaker(wallet: jmWallet) { [weak self] (response, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
                if let message = message, message != "" {
                    showAlert(vc: self, title: "", message: message)
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
                    
                    self.jmMixOutlet.tintColor = .systemTeal
                    self.jmMixOutlet.isEnabled = true
                }
            }
            
            if let message = message, message != "" {
                showAlert(vc: self, title: "", message: message)
            }
        }
    }
    
    @IBAction func createFidelityBondAction(_ sender: Any) {
        guard let jmWallet = jmWallet, jmActive else { return }
        
        spinner.addConnectingView(vc: self, description: "checking fidelity bond status...")
        
        JMUtils.fidelityStatus(wallet: jmWallet) { [weak self] (exists, message) in
            guard let self = self else { return }
                        
            // MARK: TODO ensure derivation for fidelity bond is always the same
            guard let exists = exists, exists else {
                
                guard !self.selectedUTXOs.isEmpty else {
                    self.spinner.removeConnectingView()
                    
                    showAlert(
                        vc: self,
                        title: "Fidelity Bond",
                        message: "Select the utxos you would like to create your fidelity bond with first. For best privacy practices it is recommended to only select utxos which have been previously mixed to create a fidelity bond and to always sweep the entire balance of the selected utxos."
                    )
                    
                    return
                }
                
                self.promptToSelectTimelockDate()
                
                return
            }
            
            self.showFidelityBondOptions(jmWallet)
        }
    }
    
    private func showFidelityBondOptions(_ wallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let tit = "Fidelity Bond Options"
            let mess = ""

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Unfreeze fb", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.unfreezeFb(wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Direct send mixdepth 0", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                self.directSend(wallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
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
    
    private func directSend(_ wallet: JMWallet) {
        directSendNow()
    }
    
    private func unfreezeFb(_ wallet: JMWallet) {
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
            let mess = "A fidelity bond is a timelocked bitcoin address controlled by your Join market hot wallet. You must ensure your Join Market wallet is backed up as only Join Market can spend these funds.\n\nCreating a fidelity bond increases your earning potential. The higher the amount/duration of the bond, the higher the earning potential.\n\nYou will be prompted to select an expiry date for the bond, you will NOT be able to spend these funds until that date."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

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
        guard let jmWallet = jmWallet else {
            return
        }
        
        spinner.addConnectingView(vc: self, description: "getting timelocked address...")

        let date = "\(year)-\(month)"
        
        JMUtils.fidelityAddress(wallet: jmWallet, date: date) { [weak self] (address, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let address = address else {
                showAlert(vc: self, title: "Unable to fetch timelocked address...", message: message ?? "Unknown.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                let tit = "Fidelity Bond"
                let mess = "This is a timelocked bitcoin address which prevents you from spending the funds until midnight on the 1st of \(date) (UTC).\n\nOnly your Join Market hot wallet will be able to spend from this address!\n\nFully Noded will NOT be able to spend from this address on its own!\n\nYou will be presented with the transaction creator as normal with the fidelity bond address automatically entered."

                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

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
                //self.warnAboutCoinControl()
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
            let mess = "This action will create a coinjoin transaction to the address of your choice. Specify which mixdepth (account) you want to join. The default is the first mixdepth that holds a balance.\n\nOn the next screen you can select a recipient and amount as normal. The fees will be determined as per your Join Market config."

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Default mixdepth \(self.jmWallet!.account)", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                                                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.isJmarket = true
                    self.mixdepth = self.jmWallet!.account
                    self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
                }
            }))
                        
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

            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)

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
    
    
    @IBAction func divideAction(_ sender: Any) {
        guard selectedUTXOs.count > 0 else {
            showAlert(vc: self, title: "Select some utxos first.", message: "")
            return
        }
        
        promptToDivide()
    }
    
    private func promptToDivide() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Divide selected utxos?"
            let mess = "This action will divide the selected utxos into identical amounts. Choose an amount."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            let denomArray = [0.5, 0.05, 0.2, 0.02, 0.1, 0.01, 0.001]
            
            for denom in denomArray {
                alert.addAction(UIAlertAction(title: "\(denom) btc", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.divideNow(denom: denom)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func divideNow(denom: Double) {
        spinner.addConnectingView(vc: self, description: "dividing...")
        updateInputs()
        
        var totalAmount = 0.0
        
        for utxo in selectedUTXOs {
            if let amount = utxo.amount, amount > 0.00000200 {
                totalAmount += amount - 0.00000200
            }
        }
        
        let numberOfOutputs = Int(totalAmount / denom)
        
        let inputs = inputArray.processedInputs
        
        guard let wallet = self.wallet else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "This feature is only available for Fully Noded wallets.")
            return
        }
        
        let startIndex = Int(wallet.index + 1)
        let stopIndex = (startIndex - 1) + numberOfOutputs
        let descriptor = wallet.receiveDescriptor
        
        Reducer.makeCommand(command: .deriveaddresses, param: "\"\(descriptor)\", [\(startIndex),\(stopIndex)]") { (response, errorMessage) in
            guard let addresses = response as? [String] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "addresses not returned...", message: errorMessage ?? "unknown error.")
                return
            }
            
            var outputs = [[String:Any]]()
                        
            for addr in addresses {
                let output:[String:Any] = [addr:denom]
                outputs.append(output)
            }
            
            CreatePSBT.create(inputs: inputs, outputs: outputs.processedOutputs) { (psbt, rawTx, errorMessage) in
                guard let psbt = psbt else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "psbt not returned...", message: errorMessage ?? "unknown error.")
                    return
                }
                
                self.psbt = psbt
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    self.performSegue(withIdentifier: "segueToBroadcasterFromUtxo", sender: self)
                }
            }
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
    
    private func editLabel(_ utxo: Utxo) {
        guard let wallet = self.wallet else { return }
        
        let descStruct = Descriptor(wallet.receiveDescriptor)
        
        guard let address = utxo.address else {
            showAlert(vc: self, title: "Ooops", message: "We do not have an address or info on whether that utxo is watch-only or not.")
            return
        }
        
        let isHot = descStruct.isHot
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Edit utxo label"
            let message = ""
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                guard let textFields = alert.textFields, let label = textFields[0].text else {
                    showAlert(vc: self, title: "Ooops", message: "Something went wrong here, the textfield is not accessible...")
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "updating utxo label")
                
                // need to check if its a native descriptor wallet then add label
                
                if wallet.type == WalletType.descriptor.stringValue {
                    guard let desc = utxo.desc else { return }
                    
                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(label)\"}]"
                    self.importdesc(params: params, utxo: utxo, label: label)
                    
                } else {
                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(address)\" }, \"label\": \"\(label)\", \"timestamp\": \"now\", \"watchonly\": \(!isHot), \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
                    self.importmulti(param: param, utxo: utxo, label: label)
                }
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = "add a label"
                textField.keyboardAppearance = .dark
            }
            
            alert.addAction(save)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func importdesc(params: String, utxo: Utxo, label: String) {
        Reducer.makeCommand(command: .importdescriptors, param: params) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            self.updateLocally(utxo: utxo, label: label)
        }
    }
    
    private func importmulti(param: String, utxo: Utxo, label: String) {
        OnchainUtils.importMulti(param) { (imported, message) in
            if imported {
                self.updateLocally(utxo: utxo, label: label)
            } else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Something went wrong...", message: "error: \(message ?? "unknown error")")
            }
        }
    }
    
    private func updateLocally(utxo: Utxo, label: String) {
        func saved() {
            showAlert(vc: self, title: "Label updated ✅", message: "")
            
            DispatchQueue.main.async { [weak self] in
                self?.loadUnlockedUtxos()
            }
            
            self.spinner.removeConnectingView()
        }
        
        CoreDataService.retrieveEntity(entityName: .utxos) { savedUtxos in
            guard let savedUtxos = savedUtxos, savedUtxos.count > 0 else {
                saved()
                return
            }
            
            for savedUtxo in savedUtxos {
                let savedUtxoStr = Utxo(savedUtxo)
                
                if savedUtxoStr.txid == utxo.txid && savedUtxoStr.vout == utxo.vout {
                    CoreDataService.update(id: savedUtxoStr.id!, keyToUpdate: "label", newValue: label as Any, entity: .utxos) { _ in }
                }
            }
            
            saved()
        }
    }
    
    private func lock(_ utxo: Utxo) {
        spinner.addConnectingView(vc: self, description: "locking...")
        
        let param = "false, [{\"txid\":\"\(utxo.txid)\",\"vout\":\(utxo.vout)}]"
        
        Reducer.makeCommand(command: .lockunspent, param: param) { (response, errorMessage) in
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
        
        for utxo in selectedUTXOs {
            amountTotal += utxo.amount ?? 0.0
            let input = "{\"txid\":\"\(utxo.txid)\",\"vout\": \(utxo.vout),\"sequence\": 1}"
            
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
        
        OnchainUtils.listUnspent(param: "0") { [weak self] (utxos, message) in
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
            
            for (i, utxo) in utxos.enumerated() {
                var dateToSave:Date?
                var txUUID:UUID?
                var capGain:String?
                var originValue:String?
                var amountFiat:String?
                
                var utxoDict = utxo.dict
                utxoDict["isJoinMarket"] = self.isJmarketWallet
                
                func finish() {
                    self.unlockedUtxos.append(Utxo(utxoDict))
                    
                    if i + 1 == utxos.count {
                        self.unlockedUtxos = self.unlockedUtxos.sorted { $0.confs ?? 0 < $1.confs ?? 0 }
                        
                        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] savedUtxos in
                            guard let self = self else { return }
                            
                            guard let savedUtxos = savedUtxos, savedUtxos.count > 0 else {
                                self.finishedLoading()
                                
                                return
                            }
                            
                            for (u, unlockedUtxo) in self.unlockedUtxos.enumerated() {
                                
                                func loopSavedUtxos() {
                                    for (s, savedUtxo) in savedUtxos.enumerated() {
                                        let savedUtxoStr = Utxo(savedUtxo)
                                        
                                        /// We always use the Bitcoin Core address label as the utxo label, when recovering with a new node the user will see the
                                        /// label the user added via Fully Noded. Fully Noded automatically saves the utxo labels.
                                        
                                        if let wallet = self.wallet {
                                            
                                            if savedUtxoStr.txid == unlockedUtxo.txid && savedUtxoStr.vout == unlockedUtxo.vout && wallet.label != savedUtxoStr.label {
                                                self.unlockedUtxos[i].label = savedUtxoStr.label
                                                
//                                                if wallet.type == WalletType.descriptor.stringValue {
//                                                    guard let desc = unlockedUtxo.desc else { return }
//
//                                                    let params = "[{\"desc\": \"\(desc)\", \"active\": false, \"timestamp\": \"now\", \"internal\": false, \"label\": \"\(savedUtxoStr.label ?? "")\"}]"
//
//                                                    Reducer.makeCommand(command: .importdescriptors, param: params) { (_, _) in }
//
//                                                } else {
//                                                    let param = "[{ \"scriptPubKey\": { \"address\": \"\(unlockedUtxo.address!)\" }, \"label\": \"\(savedUtxoStr.label ?? "")\", \"timestamp\": \"now\", \"watchonly\": true, \"keypool\": false, \"internal\": false }], ''{\"rescan\": false}''"
//
//                                                    Reducer.makeCommand(command: .importmulti, param: param) { (_, _) in }
//                                                }
                                            }
                                        }
                                        
                                        if s + 1 == savedUtxos.count && u + 1 == self.unlockedUtxos.count {
                                            self.finishedLoading()
                                        }
                                    }
                                }
                                
                                if unlockedUtxo.label == "" || unlockedUtxo.label == self.wallet?.label {
                                    loopSavedUtxos()
                                } else if u + 1 == self.unlockedUtxos.count {
                                    self.finishedLoading()
                                }
                            }
                        }
                    }
                }
                
                let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
                let amountBtc = utxo.amount!
                utxoDict["amountSats"] = amountBtc.sats
                utxoDict["lifehash"] = LifeHash.image(utxo.address ?? "")
                
                CoreDataService.retrieveEntity(entityName: .transactions) { txs in
                    if let txs = txs, txs.count > 0 {
                        
                        for (i, tx) in txs.enumerated() {
                            let txStruct = TransactionStruct(dictionary: tx)
                            
                            if txStruct.txid == utxo.txid {
                                dateToSave = txStruct.date
                                txUUID = txStruct.id
                                
                                if txStruct.fiatCurrency == currency, let currentFxRate = self.fxRate {
                                    let currentFiatValue = currentFxRate * amountBtc
                                    amountFiat = currentFiatValue.fiatString
                                    
                                    if let originRate = txStruct.fxRate {
                                        let originFiatValue = originRate * amountBtc
                                        var gain = currentFiatValue - originFiatValue
                                        
                                        if originFiatValue > 0 {
                                            originValue = originFiatValue.fiatString
                                            
                                            if gain > 1.0 {
                                                let ratio = gain / originFiatValue
                                                let percentage = Int(ratio * 100.0)
                                                
                                                if percentage > 1 {
                                                    capGain = "gain of \(gain.fiatString) / \(percentage)%"
                                                } else {
                                                    capGain = "gain of \(gain.fiatString)"
                                                }
                                                
                                            } else if gain < 0.0 {
                                                gain = gain * -1.0
                                                let ratio = gain / originFiatValue
                                                let percentage = Int(ratio * 100.0)
                                                
                                                if percentage > 1 {
                                                    capGain = "loss of \(gain.fiatString) / \(percentage)%"
                                                } else {
                                                    capGain = "loss of \(gain.fiatString)"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            if i + 1 == txs.count {
                                utxoDict["capGain"] = capGain
                                utxoDict["originValue"] = originValue
                                utxoDict["date"] = dateToSave
                                utxoDict["txUUID"] = txUUID
                                utxoDict["amountFiat"] = amountFiat
                                finish()
                            }
                        }
                    } else {
                        finish()
                    }
                }
            }
        }
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
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
            guard let jmWallets = jmWallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "You have an existing Join Market wallet which is unlocked, you need to lock it before we can create a new one."
                
                let mess = ""
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                for jmWallet in jmWallets {
                    let str = JMWallet(jmWallet)
                    alert.addAction(UIAlertAction(title: str.name, style: .default, handler: { [weak self] action in
                        guard let self = self else { return }
                        
                        self.spinner.addConnectingView(vc: self, description: "locking wallet...")
                        
                        JMUtils.lockWallet(wallet: str) { [weak self] (locked, message) in
                            guard let self = self else { return }
                            
                            self.spinner.removeConnectingView()
                            
                            if locked {
                                showAlert(vc: self, title: "Wallet locked ✓", message: "Try joining the utxo again.")
                            } else {
                                showAlert(vc: self, title: message ?? "Unknown issue locking that wallet...", message: "FN can only work with one JM wallet at a time, it looks like you need to restart your JM daemon in order to create a new wallet. Restart JM daemon and try again.")
                            }
                        }
                    }))
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func promptToDepositToWallet(_ utxo: Utxo, _ serverWallets: [String]) {
        CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
            guard let jmWallets = jmWallets else { return }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let tit = "Deposit \(utxo.amount ?? 0.0) utxo to Join Market wallet?"
                
                let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal."
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                CoreDataService.retrieveEntity(entityName: .wallets) { fnwallets in
                    guard let fnwallets = fnwallets, !fnwallets.isEmpty else {
                        return
                    }
                    
                    for jmWallet in jmWallets {
                        let str = JMWallet(jmWallet)
                        
                        for serverWallet in serverWallets {
                            if serverWallet == str.name {
                                alert.addAction(UIAlertAction(title: str.name, style: .default, handler: { [weak self] action in
                                    guard let self = self else { return }
                                    
                                    self.spinner.addConnectingView(vc: self, description: "fetching jm deposit address...")
                                    self.getJmAddressNow(jmWallet: str, utxo: utxo)
                                }))
                            }
                        }
                    }
                }
                
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                }))
                
                alert.popoverPresentationController?.sourceView = self.view
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
    
    private func getJmAddressNow(jmWallet: JMWallet, utxo: Utxo) {
        JMUtils.getAddress(wallet: jmWallet) { (address, message) in
            guard let address = address else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                return
            }
            
            self.depositAddress = address
            self.depositNow(utxo)
        }
    }
    
    private func promptToCreateOrRecoverJmWallet(_ utxo: Utxo, _ serverWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Would you like to use an existing JM wallet or create a new one?"
            let mess = ""
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.createJMWalletNow(utxo)
            }))
            
            alert.addAction(UIAlertAction(title: "Use existing JM wallet", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.useExistingJMWallet(utxo, serverWallets)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func useExistingJMWallet(_ utxo: Utxo, _ serverWallets: [String]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Select the JM wallet to use."
            let mess = ""
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            for serverWallet in serverWallets {
                alert.addAction(UIAlertAction(title: serverWallet, style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    self.unlockJMWallet(utxo, serverWallet)
                }))
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func unlockJMWallet(_ utxo: Utxo, _ walletName: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Enter the wallet password to recover it."
            let message = "This is not your passphrase or seed words, this is the Join Market specific password that is used to lock and unlock the wallet."
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            
            let unlock = UIAlertAction(title: "Recover", style: .default) { [weak self] (alertAction) in
                guard let self = self else { return }
                
                guard let textFields = alert.textFields, let password = textFields[0].text else {
                    showAlert(vc: self, title: "", message: "Something went wrong here, the textfield is not accessible...")
                    return
                }
                
                self.spinner.addConnectingView(vc: self, description: "recovering wallet...")
                
                JMUtils.recoverWallet(walletName: walletName, password: password) { [weak self] (saved, message) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                                        
                    guard saved else {
                        showAlert(vc: self, title: "There was an issue recovering that JM wallet.", message: message ?? "Unknown issue.")
                        
                        return
                    }
                    
                    self.checkForJmWallet()
                }
                
            }
            
            alert.addTextField { textField in
                textField.placeholder = "password"
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
            }
            
            alert.addAction(unlock)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            self.present(alert, animated:true, completion: nil)
        }
    }
    
    private func createJMWalletNow(_ utxo: Utxo) {
        self.spinner.addConnectingView(vc: self, description: "creating JM wallet (this can take 30 seconds or so, please be patient)...")
        
        let currentWallet = self.wallet?.name ?? ""
        
        JMUtils.createWallet { [weak self] (response, message) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let jmWallet = response else {
                if let mess = message, mess.contains("Wallet already unlocked.") {
                    self.promptToLockWallets()
                } else {
                    showAlert(vc: self, title: "There was an issue creating your JM wallet.", message: message ?? "Unknown.")
                }
                
                return
            }
            
            UserDefaults.standard.setValue(currentWallet, forKey: "walletName")
            self.jmWalletCreated(utxo, jmWallet)
        }
    }
    
    private func promptToCreateJmWallet(_ utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Create a Join Market wallet?"
            
            let mess = "In order to join your utxos you need to create a Join Market wallet. This will be like your other Fully Noded wallets with the added ability to instantly join and earn interest on your balance."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Create", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.createJMWalletNow(utxo)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func jmWalletCreated(_ utxo: Utxo, _ jmWallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard let decryptedPassword = Crypto.decrypt(jmWallet.password), let password = decryptedPassword.utf8String else { return }
                        
            let tit = "Join Market wallet created successfully ✓"
            let mess = "You must backup the password associated with your Join Market wallet incase you need to recover your wallet with Join Market, failure to do so could result in lost funds:\n\n\(password)\n\nA new Join Marklet signer has been encrypted and saved ✓\n⚠️ MAKE SURE YOU BACK IT UP OFFLINE!\n⚠️ Failure to do so could result in lost funds!"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Deposit", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.promptToDeposit(utxo, jmWallet)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
//    private func walletCreatedSuccess(_ utxo: Utxo, _ jmWallet: JMWallet) {
//        DispatchQueue.main.async { [weak self] in
//            guard let self = self else { return }
//
//            let tit = "Join Market wallet created successfully ✓"
//            let mess = "You may now deposit funds to it."
//
//            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
//
//            alert.addAction(UIAlertAction(title: "Deposit funds", style: .default, handler: { [weak self] action in
//                guard let self = self else { return }
//
//                self.promptToDeposit(utxo, jmWallet)
//            }))
//
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
//            alert.popoverPresentationController?.sourceView = self.view
//            self.present(alert, animated: true, completion: nil)
//        }
//    }
    
    private func promptToDeposit(_ utxo: Utxo, _ jmWallet: JMWallet) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Deposit utxo to Join Market wallet?"
            
            let mess = "Once you deposit the utxo to your Join Market wallet you can begin joining. This action will fetch a deposit address from your Join Market wallet and present the transaction creator as normal."
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.spinner.addConnectingView(vc: self, description: "getting JM deposit address...")
                
                JMUtils.getAddress(wallet: jmWallet) { (address, message) in
                    self.spinner.removeConnectingView()
                    
                    guard let address = address else {
                        showAlert(vc: self, title: "Error getting deposit address...", message: message ?? "Unknown.")
                        return
                    }
                    
                    self.depositAddress = address
                    self.depositNow(utxo)
                }
            }))
            
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
                
                let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
                
                alert.addAction(UIAlertAction(title: "Donate", style: .default, handler: { [weak self] action in
                    guard let self = self else { return }
                    
                    guard let donationAddress = Keys.donationAddress() else {
                        return
                    }
                    
                    self.depositAddress = donationAddress
                    //self.amountTotal = utxo.amount ?? 0.0
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
            vc.mixdepth = mixdepth
            vc.jmWallet = jmWallet
            vc.inputArray = inputArray
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
    
    func didTapToEditLabel(_ utxo: Utxo) {
        editLabel(utxo)
    }
    
    func didTapToFetchOrigin(_ utxo: Utxo) {
        fetchOriginRate(utxo)
    }
    
    func didTapToMix(_ utxo: Utxo) {
        spinner.addConnectingView(vc: self, description: "checking nodes, wallet and utxo...")
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, !nodes.isEmpty else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No nodes", message: "")
                return
            }
            
            var jmNodeActive = false
            var isAny = false
            
            for node in nodes {
                let str = NodeStruct(dictionary: node)
                if str.isJoinMarket {
                    isAny = true
                    if str.isActive {
                        jmNodeActive = true
                    }
                }
            }
            
            guard isAny else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Add a Join Market node first.", message: "")
                return
            }
            
            guard jmNodeActive else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Activate your Join Market node first.", message: "")
                return
            }
            
            CoreDataService.retrieveEntity(entityName: .jmWallets) { jmWallets in
                guard let jmWallets = jmWallets, !jmWallets.isEmpty else {
                    self.promptToCreateJmWallet(utxo)
                    return
                }
                
                JMUtils.wallets { (serverWallets, message) in
                    guard let serverWallets = serverWallets else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "There was an issue connecting to your Join Market server.", message: message ?? "Unknown issue.")
                        return
                    }
                    
                    var existsOnServer = false
                    
                    for (i, jmWallet) in jmWallets.enumerated() {
                        let jmWalletStruct = JMWallet(jmWallet)
                        
                        if jmWalletStruct.fnWallet != "" {
                            for serverWallet in serverWallets {
                                if serverWallet == jmWalletStruct.name {
                                    existsOnServer = true
                                }
                            }
                        }
                        
                        if i + 1 == jmWallets.count {
                            if !serverWallets.isEmpty {
                                if !existsOnServer {
                                    self.promptToCreateOrRecoverJmWallet(utxo, serverWallets)
                                } else {
                                    self.promptToDepositToWallet(utxo, serverWallets)
                                }
                            } else {
                                self.promptToCreateJmWallet(utxo)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func didTapDonateChange(_ utxo: Utxo) {
        promptToDonateChange(utxo)
    }
    
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        
        cell.configure(utxo: utxo, isLocked: false, fxRate: fxRate, isSats: isSats, isBtc: isBtc, isFiat: isFiat, delegate: self)
        
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
