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
    
    var dataRefresher = UIBarButtonItem()
    private var amountTotal = 0.0
    private let refresher = UIRefreshControl()
    private var unlockedUtxos = [Utxo]()
    private var inputArray: [[String:Any]] = []
    private var selectedUTXOs = [Utxo]()
    //private var spinner = ConnectingView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    private var wallet: Wallet?
    private var psbt: String?
    private var depositAddress: String?
    var fxRate: Double?
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
//        jmMixOutlet.tintColor = .clear
//        jmEarnOutlet.tintColor = .clear
//        jmMixOutlet.isEnabled = false
//        jmEarnOutlet.isEnabled = false
//        jmStatusImageOutlet.alpha = 0
//        jmStatusLabelOutlet.alpha = 0
//        jmActionOutlet.alpha = 0
        
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
        loadUnlockedUtxos()
        //checkForJmWallet()
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
    
    private func lock(_ utxo: Utxo) {
        addNavBarSpinner()
        
        let param = Lock_Unspent(["unlock": false, "transactions": [["txid": utxo.txid,"vout": utxo.vout]]])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .lockunspent(param)) { (response, errorDesc) in
            guard let success = response as? Bool else {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.loadUnlockedUtxos()
                    displayAlert(viewController: self, isError: true, message: errorDesc ?? "unknown error")
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
            self.addNavBarSpinner()
        }
        getUtxosFromBtcRpc()
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
                    //utxoDict["isJoinMarket"] = self.isJmarketWallet
                    
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
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.refresher.endRefreshing()
            self.spinner.stopAnimating()
            self.spinner.alpha = 0
            self.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.loadUnlockedUtxos))
            self.navigationItem.setRightBarButton(self.refreshButton, animated: true)
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
            addNavBarSpinner()
            
            FiatConverter.sharedInstance.getOriginRate(date: dateString) { [weak self] originRate in
                guard let self = self else { return }
                
                guard let originRate = originRate else {
                    removeSpinner()
                    showAlert(vc: self, title: "", message: "There was an issue fetching the historic exchange rate, please let us know about it.")
                    return
                }
                
                CoreDataService.update(id: id, keyToUpdate: "originFxRate", newValue: originRate, entity: .transactions) { [weak self] success in
                    guard let self = self else { return }
                    
                    guard success else {
                        removeSpinner()
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
    
    func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.spinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.spinner.startAnimating()
            self.spinner.alpha = 1
        }
    }
    
    private func updateLabelNow(label: String, address: String) {
        addNavBarSpinner()
        let param: Set_Label_Param = .init(["label":label, "address": address])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .setlabel(param: param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            removeSpinner()
            guard errorDesc == nil else {
                showAlert(vc: self, title: "Error", message: errorDesc!)
                return
            }
            
            loadUnlockedUtxos()
        }
    }
        
    private func promptToEditLabel(_ utxo: Utxo) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let tit = "Edit label?"
            let mess = "Labels are address based and stored by Bitcoin Core. If you reuse addresses this label will apply to multiple utxos."
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: .alert)
            
            let save = UIAlertAction(title: "Save", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                guard let label = (alert.textFields![0] as UITextField).text else { return }
                
                updateLabelNow(label: label, address: utxo.address!)
            }
            
            alert.addTextField { (textField) in
                textField.placeholder = utxo.label ?? ""
            }
            alert.addAction(save)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        let modalVC = TextModalViewController(data: data, viewTitle: title)
        
        let nav = UINavigationController(rootViewController: modalVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        
        present(nav, animated: true)
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
    func getAddressInfo(_ utxo: Utxo) {
        guard let address = utxo.address else {
            showAlert(vc: self, title: "", message: "No address associated with that UTXO.")
            return
        }
        
        let p: Get_Address_Info = .init(["address": address])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard let addressInfo = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: addressInfo, title: "Address Info")
            }
        }
    }
    
    func getTxInfo(_ utxo: Utxo) {
        let p: Get_Tx = .init(["txid": utxo.txid, "verbose": true, "include_watchonly": true])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Transaction Info")
            }
        }
    }
    
    func getDescriptorInfo(_ utxo: Utxo) {
        guard let descriptor = utxo.desc else {
            showAlert(vc: self, title: "", message: "No descriptor associated with this UTXO.")
            return
        }
        let p: Get_Descriptor_Info = .init(["descriptor": descriptor])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getdescriptorinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                showModal(data: response, title: "Descriptor Info")
            }
        }
    }
    
    func didTapToSpendUtxo(_ utxo: Utxo) {
        var utxo = utxo
        utxo.isSelected = true
        
        amountTotal = utxo.amount!
        let input:[String:Any] = ["txid": utxo.txid, "vout": utxo.vout, "sequence": 1]
        inputArray.append(input)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToSendFromUtxos", sender: self)
        }
    }
    
    func copyAddress(_ utxo: Utxo) {
        UIPasteboard.general.string = utxo.address!
        showAlert(vc: self, title: "", message: "Address copied ✓")
    }
    
    func copyTxid(_ utxo: Utxo) {
        UIPasteboard.general.string = utxo.txid
        showAlert(vc: self, title: "", message: "Transaction ID copied ✓")
    }
    
    func copyDesc(_ utxo: Utxo) {
        UIPasteboard.general.string = utxo.desc!
        showAlert(vc: self, title: "", message: "Descriptor copied ✓")
    }
    
    func editLabel(_ utxo: Utxo) {
        promptToEditLabel(utxo)
    }
    
    func didTapToLock(_ utxo: Utxo) {
        lock(utxo)
    }
    
}

// Mark: UITableViewDataSource

extension UTXOViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCell.identifier, for: indexPath) as! UTXOCell
        let utxo = unlockedUtxos[indexPath.section]
        guard let wallet = wallet else { return cell }
        cell.configure(wallet: wallet, utxo: utxo, isLocked: false, fxRate: fxRate, isSats: isSats, isBtc: isBtc, isFiat: isFiat, delegate: self)
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

//extension UTXOViewController: UIPickerViewDataSource {
//    func numberOfComponents(in pickerView: UIPickerView) -> Int {
//        return 2
//    }
//    
//    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
//        switch component {
//        case 0:
//            return months.count
//        case 1:
//            return years.count
//        default:
//            return 0
//        }
//    }
//}

//extension UTXOViewController: UIPickerViewDelegate {
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        var toReturn:String?
//        switch component {
//        case 0:
//            let dict = months[row]
//            for (key, _) in dict {
//                toReturn = key
//            }
//        case 1:
//            toReturn = years[row]
//        default:
//            break
//        }
//        
//        return toReturn
//    }
//    
//    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//        switch component {
//        case 0:
//            let dict = months[row]
//            for (_, value) in dict {
//                month = value
//            }
//        case 1:
//            year = years[row]
//        default:
//            break
//        }
//    }
//}
