//
//  VerifyTransactionViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/4/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
//import LibWally
//import CoreNFC

class VerifyTransactionViewController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate, UIDocumentPickerDelegate {
    
    //var isChannelFunding = false
    //var voutChannelFunding:Int?
    var smartFee = Double()
    var txSize = Int()
    var rejectionMessage = ""
    var txValid: Bool?
    //var memo = ""
    var txFee = Double()
    var fxRate: Double?
    var txid = ""
    var psbtDict: NSDictionary!
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
    var signatures = [[String:String]]()
    var signedTxInputs: [[String: Any]] = []
    var alreadyBroadcast = false
    var confs = 0
    var labelText = "No label added."
    //var memoText = "no memo added"
    var id: UUID!
    var hasSigned = false
    var isSigning = false
    var wallet:Wallet?
    var bitcoinCoreWallets = [String()]
    var walletIndex = 0
    var qrCodeStringToExport = ""
    var blind = false
    //var processedPsbt:String?
    var isBBQr = false
    var isUR = false
    var isPlainText = false
    //var ndefMessage: NFCNDEFMessage?
    //var readerSession: NFCNDEFReaderSession?
    var exporting = false
    var passphrase: String?
    
    @IBOutlet weak private var verifyTable: UITableView!
    @IBOutlet weak private var exportButtonOutlet: UIButton!
    @IBOutlet weak private var bumpFeeOutlet: UIButton!
    @IBOutlet weak private var signOutlet: UIButton!
    @IBOutlet weak private var sendOutlet: UIButton!
    @IBOutlet weak private var exportBackgroundView: UIView!
    @IBOutlet weak private var bumpFeeBackgroundView: UIView!
    @IBOutlet weak private var signBackgroundView: UIView!
    @IBOutlet weak private var sendBackgroundView: UIView!
    @IBOutlet weak private var buttonsBackgroundView: UIVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        
        verifyTable.delegate = self
        verifyTable.dataSource = self
        verifyTable.layer.cornerRadius = 8
        verifyTable.clipsToBounds = true
        
        func loadNow() {
            activeWallet { [weak self] w in
                guard let self = self else { return }
                
                self.wallet = w
            }
            
            configureViews()
            
            if unsignedPsbt != "" || signedRawTx != "" {
                enableExportButton()
                
                if unsignedPsbt != "" {
                    processPsbt(unsignedPsbt)
                } else {
                    load()
                }
                
            } else {
                promptToAddTx()
            }
        }
                
        loadNow()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isBBQr = false
        isUR = false
        isPlainText = false
        qrCodeStringToExport = ""
        exporting = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        passphrase?.secureWipe()
    }
    
    @IBAction func showRawDataAction(_ sender: Any) {
        if signedRawTx != "" {
            spinner.addConnectingView(vc: self, description: "Decoding raw transaction...")
            
            let p: Decode_Raw_Tx = .init(["hexstring": signedRawTx])
            
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .decoderawtransaction(param: p)) { [weak self] (response, errorDesc) in
                guard let self = self else { return }
                
                spinner.removeConnectingView()
                
                guard let response = response as? [String: Any] else {
                    showAlert(vc: self, title: "", message: errorDesc ?? "No response from decoderawtransaction.")
                    return
                }
                
                showModal(data: response, title: "decoderawtransaction")
            }
        } else if unsignedPsbt != "" {
            spinner.addConnectingView(vc: self, description: "Decoding psbt...")
            
            let p: Decode_Psbt = Decode_Psbt(["psbt": unsignedPsbt])
            
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .decodepsbt(param: p)) { [weak self] (response, errorDesc) in
                guard let self = self else { return }
                
                spinner.removeConnectingView()
                
                guard let response = response as? [String: Any] else {
                    showAlert(vc: self, title: "", message: "No response from decodepsbt.")
                    return
                }
                
                showModal(data: response, title: "decodepsbt")
            }
        } else {
            showAlert(vc: self, title: "", message: "No transaction to decode.")
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let modalVC = TextModalViewController(data: data, viewTitle: title)
            let nav = UINavigationController(rootViewController: modalVC)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            present(nav, animated: true)
        }
    }
    
    private func reset() {
        print("reset")
        self.unsignedPsbt = ""
        self.signedRawTx = ""
        //self.isChannelFunding = false
        //self.voutChannelFunding = nil
        self.rejectionMessage = ""
        self.txValid = nil
        //self.memo = ""
        self.txid = ""
        self.outputsString = ""
        self.inputArray.removeAll()
        self.inputTableArray.removeAll()
        self.outputArray.removeAll()
        self.index = 0
        self.inputTotal = 0.0
        self.outputTotal = 0.0
        self.miningFee = ""
        self.recipients.removeAll()
        self.addressToVerify = ""
        self.signatures.removeAll()
        self.signedTxInputs.removeAll()
        self.confs = 0
        self.alreadyBroadcast = false
        self.labelText = "No label added."
        //self.memoText = "no memo added"
        self.hasSigned = false
        self.isSigning = false
        self.bitcoinCoreWallets.removeAll()
        self.walletIndex = 0
        self.qrCodeStringToExport = ""
        self.blind = false
    }
    
    private func processWithBDK(psbt: String) -> ((rawTx: String?, psbt: String?)) {
        guard let bdkPsbt = try? WalletLogic.BDKPsbt(psbtBase64: psbt) else {
            return (nil, psbt)
        }
        
        let finalized = bdkPsbt.finalize()
        
        guard finalized.couldFinalize else {
            return (nil, psbt)
        }
        
        guard let rawTx = try? finalized.psbt.extractTx() else {
            return (nil, bdkPsbt.serialize())
        }
        
        return (rawTx.description, nil)
    }
    
    private func processPsbt(_ psbt: String) {
        // Check if it can be finalized, if it can finalize and extract it.
        spinner.addConnectingView(vc: self, description: "processing psbt...")
                
        let (rawTx, _) = processWithBDK(psbt: psbt)
        
        guard let rawTx = rawTx else {
            processWithBitcoinCore(psbt: psbt)
            return
        }

        signedRawTx = rawTx
        
        load()
    }
    
    // Use core to populate bip32 derivs and other info needed to finalize as a fallback.
    private func processWithBitcoinCore(psbt: String) {
        let param: Wallet_Process_PSBT = .init(["psbt": psbt, "sign": false, "sighashtype": "ALL"])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: param)) { [weak self] (object, errorDescription) in
            guard let self = self else { return }
            
            guard let dict = object as? NSDictionary, let processedPsbt = dict["psbt"] as? String else {
                showAlert(vc: self, title: "", message: "There was an issue processing your psbt with the active wallet: \(errorDescription ?? "unknown error")")
                
                return
            }
            
            let (rawTx, _) = processWithBDK(psbt: psbt)
            
            if let rawTx = rawTx {
                signedRawTx = rawTx
                load()
                   
            } else {
                unsignedPsbt = processedPsbt
                enableSignAndLoad()
            }
        }
    }
    
    private func enableSignAndLoad() {
        enableSignButton()
        load()
    }
        
    private func enableExportButton() {
        enableView(exportBackgroundView)
        enableButton(exportButtonOutlet)
    }
    
    private func enableBumpFeeButton() {
        enableView(bumpFeeBackgroundView)
        enableButton(bumpFeeOutlet)
    }
    
    private func enableSignButton() {
        enableView(signBackgroundView)
        enableButton(signOutlet)
    }
    
    private func enableSendButton() {
        enableView(sendBackgroundView)
        enableButton(sendOutlet)
    }
    
    private func disableSendButton() {
        disableView(sendBackgroundView)
        disableButton(sendOutlet)
    }
    
    private func disableSignButton() {
        disableView(signBackgroundView)
        disableButton(signOutlet)
    }
    
    private func disableBumpButton() {
        disableButton(bumpFeeOutlet)
        disableView(bumpFeeBackgroundView)
    }
    
//    private func disableExportButton() {
//        disableView(exportBackgroundView)
//        disableButton(exportButtonOutlet)
//    }
    
    private func configureViews() {
        disableSendButton()
        disableBumpButton()
        disableSignButton()
        //disableExportButton()
        
        buttonsBackgroundView.clipsToBounds = true
        buttonsBackgroundView.layer.cornerRadius = 8
        
        roundCorners(exportBackgroundView)
        roundCorners(bumpFeeBackgroundView)
        roundCorners(signBackgroundView)
        roundCorners(sendBackgroundView)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        if alreadyBroadcast {
            if confs == 0 {
                enableBumpFeeButton()
            }
        } else {
            if signedRawTx == "" && unsignedPsbt != "" && !hasSigned {
                enableSignButton()
            } else if signedRawTx != "" {
                enableSendButton()
            }
        }
    }
    
    private func roundCorners(_ view: UIView) {
        DispatchQueue.main.async {
            view.layer.cornerRadius = 8
            view.clipsToBounds = true
            view.layer.borderWidth = 0.5
        }
    }
    
    private func enableButton(_ button: UIButton) {
        DispatchQueue.main.async {
            button.isEnabled = true
            button.alpha = 1
        }
    }
    
    private func disableButton(_ button: UIButton) {
        DispatchQueue.main.async {
            button.isEnabled = false
            button.alpha = 0.3
        }
    }
    
    private func enableView(_ view: UIView) {
        DispatchQueue.main.async {
            view.layer.borderColor = UIColor.lightGray.cgColor
        }
    }
    
    private func disableView(_ view: UIView) {
        DispatchQueue.main.async {
            view.layer.borderColor = UIColor.clear.cgColor
        }
    }
    
    private func copy(_ text: String) {
        DispatchQueue.main.async {
            UIPasteboard.general.string = text
        }
    }
    
    private func promptToAddTx() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Add Transaction",
                                          message: "You can add a transaction in a number of ways.",
                                          preferredStyle: .alert)
            
//            alert.addAction(UIAlertAction(title: "NFC", style: .default, handler: { [weak self] action in
//                guard let self = self else { return }
//                
//                self.readerSession = NFCNDEFReaderSession(delegate: self, queue: DispatchQueue.main, invalidateAfterFirstRead: false)
//                self.readerSession?.begin()
//            }))
            
            alert.addAction(UIAlertAction(title: "Upload File", style: .default, handler: { action in
                self.presentUploader()
            }))
            
            alert.addAction(UIAlertAction(title: "Paste Text", style: .default, handler: { action in
                self.pasteAction()
            }))
            
            alert.addAction(UIAlertAction(title: "QR Code", style: .default, handler: { action in
                self.scanQr()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func scanQr() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToScanPsbt", sender: self)
        }
    }
    
    private func pasteAction() {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "Not a psbt?", message: "Looks like you do not have valid text on your clipboard")
                return
            }
            
            processPastedString(string)
        } else if let string = UIPasteboard.general.string {
            
           processPastedString(string)
        } else {
            
            showAlert(vc: self, title: "", message: "Not valid text. You can copy and paste the base64 text of a psbt or a signed raw transaction with this button.")
        }
    }
    
    private func processPastedString(_ string: String) {
        let processed = string.condenseWhitespace()
        reset()
        if Keys.validPsbt(processed) {
            enableExportButton()
            processPsbt(processed)
        } else if Keys.validTx(processed) {
            enableExportButton()
            signedRawTx = processed
            load()
        } else if processed.lowercased().hasPrefix("ur:bytes") {
            self.blind = true
            self.parseBlindPsbt(processed)
//        } else if processed.count == 64 {
//            fetchTxFromId(txid: processed)
        } else {
            showAlert(vc: self, title: "Invalid", message: "Whatever you pasted was not a valid psbt, raw transaction or txid.")
        }
    }
    
//    private func fetchTxFromId(txid: String) {
//        print("fetchTxFromId")
//    }
    
    private func presentUploader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var documentPicker:UIDocumentPickerViewController!
            
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {        
        guard let text = try? String(contentsOf: urls[0].absoluteURL), Keys.validTx(text) else {
            
            guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
                spinner.removeConnectingView()
                showAlert(vc: self, title: "Invalid File", message: "That is not a recognized format, generally it will be a .psbt or .txn file.")
                return
            }
                        
            if let text = data.utf8String, text.lowercased().hasPrefix("ur:bytes") {
                self.reset()
                self.blind = true
                self.parseBlindPsbt(text)
            } else {
                if Keys.validPsbt(data.base64EncodedString()) {
                    unsignedPsbt = data.base64EncodedString()
                    self.reset()
                    processPsbt(unsignedPsbt)
                } else if let psbtUtf8 = data.utf8String, Keys.validPsbt(psbtUtf8) {
                    unsignedPsbt = psbtUtf8
                    self.reset()
                    processPsbt(psbtUtf8)
                } else {
                    spinner.removeConnectingView()
                    showAlert(vc: self, title: "Invalid format", message: "That is not a valid BIP174 format.")
                }                
            }
            
            return
        }
        
        reset()
        signedRawTx = text.condenseWhitespace()
        load()
    }
    
    @IBAction func addTransactionAction(_ sender: Any) {
        promptToAddTx()
    }
    
    @objc func tapToAdd(_ sender: UIButton) {
        promptToAddTx()
    }
    
    private func promptToExportPsbt() {
        let alert = UIAlertController(title: "Export encrypted?",
                                      message: "You can either export this psbt encrypted or in plain text.",
                                      preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Encrypted", style: .default, handler: { [weak self] action in
            guard let self = self else { return }
            
            guard let data = Data(base64Encoded: self.unsignedPsbt),
                  let encrypted = Crypto.blindPsbt(data),
                  let ur = URHelper.dataToUrBytes(encrypted) else {
                showAlert(vc: self, title: "", message: "Error converting to data or encrypting.")
                return
            }
            
            self.exportPsbt(blindedpsbt: ur.qrString, plainText: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "Unencrypted", style: .default, handler: { [weak self] action in
            guard let self = self else { return }
            
            self.exportPsbt(blindedpsbt: nil, plainText: self.unsignedPsbt)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
        alert.popoverPresentationController?.sourceView = self.view
        self.present(alert, animated: true) {}
    }
                    
    @IBAction func exportAction(_ sender: Any) {
        if self.blind {
            guard let data = Data(base64Encoded: self.unsignedPsbt),
                  let encrypted = Crypto.blindPsbt(data),
                  let ur = URHelper.dataToUrBytes(encrypted) else {
                showAlert(vc: self, title: "", message: "Error converting to data or encrypting.")
                return
            }
            
            self.exportPsbt(blindedpsbt: ur.qrString, plainText: nil)
            
        } else if unsignedPsbt != "" {
            promptToExportPsbt()
        } else if signedRawTx != "" {
            exportTxn(txn: signedRawTx)
        }
    }
    
    @IBAction func sendAction(_ sender: Any) {
        send()
    }
    
    private func send() {
        isSigning = false
        
        if self.signedRawTx != "" {
            broadcast()
        } else {
            showAlert(vc: self, title: "", message: "Transaction not fully signed, you can export it to another signer or sign it if the sign button is enabled.")
        }
    }
    
    @IBAction func bumpFeeAction(_ sender: Any) {
        if confs == 0 && alreadyBroadcast {
            if UserDefaults.standard.object(forKey: "passphrasePrompt") == nil {
                self.bumpFee(nil)
            } else {
                self.setPassphrase { [weak self] passphrase in
                    guard let self = self else { return }
                    self.passphrase = passphrase
                    
                    self.bumpFee(passphrase)
                }
            }
        } else {
            showAlert(vc: self, title: "", message: "You can only bump the fee for transactions that have zero confirmations.")
        }
    }
    
    @IBAction func signAction(_ sender: Any) {
        isSigning = true
        
        spinner.addConnectingView(vc: self, description: "Checking for wallet encryption...")
        
        OnchainUtils.getWalletInfo { [weak self] (walletInfo, message) in
            guard let self = self else { return }
                        
            guard let walletInfo = walletInfo else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error getting wallet info...", message: message ?? "unknown")
                return
            }
            
            guard !walletInfo.locked else {
                self.unlockWallet()
                return
            }
            
            //reset()
            
            if UserDefaults.standard.object(forKey: "passphrasePrompt") == nil {
                self.spinner.removeConnectingView()
                self.signNow(nil)
            } else {
                self.spinner.removeConnectingView()
                self.setPassphrase { [weak self] passphrase in
                    guard let self = self else { return }
                    self.passphrase = passphrase
                    self.signNow(passphrase)
                }
            }
        }
    }
    
    private func setPassphrase(completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Passphrase Prompt"
            let message = "You enabled the passphrase prompt in Security Center, please enter the passphrase you want to use for signing this transaction."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let set = UIAlertAction(title: "Sign now", style: .default) { alertAction in
                completion((alert.textFields![0] as UITextField).text)
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
            }
            
            alert.addAction(set)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { alertAction in }
            alert.addAction(cancel)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func unlockWallet() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let title = "Wallet locked 🔒"
            let message = "Enter your encryption password to unlock it."
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let unlock = UIAlertAction(title: "Unlock", style: .default) { [weak self] alertAction in
                guard let self = self else { return }
                
                let password = (alert.textFields![0] as UITextField).text ?? ""
                
                self.spinner.addConnectingView(vc: self, description: "Unlocking wallet...")
                let param:Wallet_Passphrase = .init(
                    [
                        "passphrase": password,
                        "timeout": 600
                    ]
                )
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletpassphrase(param: param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    
                    guard errorMessage == nil else {
                        self.showError(error: errorMessage ?? "Unknown error unlocking your wallet.")
                        return
                    }
                    
                    showAlert(vc: self, title: "Wallet unlocked ✓", message: "Try signing again.")
                }
            }
            
            alert.addTextField { textField in
                textField.keyboardAppearance = .dark
                textField.isSecureTextEntry = true
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
            }
            
            alert.addAction(unlock)
            
            let cancel = UIAlertAction(title: "Cancel", style: .default) { alertAction in }
            alert.addAction(cancel)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func signNow(_ passphrase: String?) {
        isSigning = true
        spinner.addConnectingView(vc: self, description: "signing...")
        
        //Signer.sign(psbt: self.unsignedPsbt, passphrase: passphrase) { [weak self] (signedPsbt, rawTx, errorMessage) in
        guard let wallet = wallet else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Fully Noded can only sign transactions when using a Fully Noded wallet.")
            return
        }
        
        Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: unsignedPsbt, passphrase: passphrase) { [weak self] (signedPsbt, rawTx, errorMessage) in
            guard let self = self else { return }
            
            print("return from signer")
            
            if let rawTx = rawTx {
                showAlert(vc: self, title: "", message: "Signed successfully ✓")
                self.disableSignButton()
                self.unsignedPsbt = ""
                reset()
                self.signedRawTx = rawTx
                self.enableSendButton()
                //self.enableExportButton()
                self.load()
                
            } else if let signedPsbt = signedPsbt {
                reset()
                self.unsignedPsbt = signedPsbt
                //self.enableExportButton()
                self.load()
                
            } else {
                self.spinner.removeConnectingView()
                
                if let errorMessage = errorMessage {
                    showAlert(vc: self, title: "Error Signing", message: errorMessage)
                }
                
            }
        }
    }
    
    private func saveNewTx(_ txid: String) {
        var transaction = [String:Any]()
        
        self.id = UUID()
        transaction["id"] = self.id
        transaction["label"] = labelText
        transaction["date"] = Date()
        transaction["txid"] = txid
        transaction["fiatCurrency"] = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        if let fx = fxRate {
            transaction["originFxRate"] = fx
        }
        
        CoreDataService.saveEntity(dict: transaction, entityName: .transactions) { _ in }
    }
    
    private func bumpFee(_ passphrase: String?) {
        guard let wallet = wallet else {
            showAlert(vc: self, title: "", message: "Signing transactions only works with Fully Noded wallets.")
            return
        }
        
        spinner.addConnectingView(vc: self, description: "increasing fee...")
        let param_bump_fee: Bump_Fee = .init(["txid":self.txid])
        let param_psbt_bump_fee: PSBT_Bump_Fee = .init(["txid":self.txid])
        let bumpfee: BTC_CLI_COMMAND = .bumpfee(param: param_bump_fee)
        let psbtBumpFee: BTC_CLI_COMMAND = .psbtbumpfee(param: param_psbt_bump_fee)
        var command: BTC_CLI_COMMAND = bumpfee
        
        OnchainUtils.getWalletInfo { [weak self] (walletInfo, message) in
            guard let self = self else { return }
            
            guard let walletInfo = walletInfo else {
                self.showError(error: "Error getting wallet info: \(message ?? "unknown")")
                return
            }
            
            if let privkeysenabled = walletInfo.private_keys_enabled, !privkeysenabled,
                let version = UserDefaults.standard.object(forKey: "version") as? Int,
                version >= 210000 {
                command = psbtBumpFee
            }
            
            MakeRPCCall.sharedInstance.executeRPCCommand(method: command) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let result = response as? NSDictionary,
                        let originalFee = result["origfee"] as? Double,
                        let newFee = result["fee"] as? Double else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "There was an issue increasing the fee.", message: errorMessage ?? "unknown")
                    return
                }
                
                guard let psbt = result["psbt"] as? String else {
                    self.spinner.removeConnectingView()
                    if let txid = result["txid"] as? String {
                        self.saveNewTx(txid)
                        displayAlert(viewController: self, isError: false, message: "fee bumped from \(originalFee.avoidNotation) to \(newFee.avoidNotation)")
                    } else if let errors = result["errors"] as? NSArray {
                        showAlert(vc: self, title: "There was an error increasing the fee.", message: "\(errors)")
                    }
                    return            }
                
                self.signedRawTx = ""
                
                Signer.shared.attemptToSignPsbt(fnWallet: wallet, psbt: psbt, passphrase: passphrase) { [weak self] (signedPsbt, rawTx, errorMessage) in
                    guard let self = self else { return }
                    
                    self.spinner.removeConnectingView()
                    
                    self.disableBumpButton()
                    
                    if rawTx != nil {
                        self.signedRawTx = rawTx!
                        self.enableSendButton()
                        self.disableSignButton()
                        self.load()
                        showAlert(vc: self, title: "Fee increased to \(newFee.avoidNotation)", message: "Tap the send button to broadcast the new transaction.")
                        
                    } else if signedPsbt != nil {
                        self.unsignedPsbt = signedPsbt!
                        self.load()
                        showAlert(vc: self, title: "Fee increased to \(newFee.avoidNotation)", message: "The transaction still needs more signatures before it can be broadcast.")
                        
                    } else {
                        if let errorMessage = errorMessage {
                            showAlert(vc: self, title: "Error Signing", message: errorMessage)
                        }
                    }
                }
            }
        }
    }
    
    private func updateLabel(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.spinner.label.text = text
        }
    }
    
    private func load() {
        spinner.addConnectingView(vc: self, description: "loading...")
        
        inputArray.removeAll()
        inputTableArray.removeAll()
        outputArray.removeAll()
        recipients.removeAll()
        signatures.removeAll()
        outputsString = ""
        
//        FiatConverter.sharedInstance.getFxRate(currency: fiatCurrency) { [weak self] exchangeRate in
//            guard let self = self else { return }
//            
//            self.fxRate = exchangeRate
//        }
        
        if self.unsignedPsbt == "" {
            self.updateLabel("decoding raw transaction...")
            let param:Decode_Raw_Tx = .init(["hexstring":self.signedRawTx])
            self.executeNodeCommand(method: .decoderawtransaction(param: param))
        } else {
            self.updateLabel("decoding psbt...")
            let param:Decode_Psbt = .init(["psbt":self.unsignedPsbt])
            self.executeNodeCommand(method: .decodepsbt(param: param))
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND) {
        
        func send() {
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                
                guard let _ = response as? String else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.disableSendButton()
                    self.spinner.removeConnectingView()
                    self.navigationItem.title = "Sent ✓"
                    displayAlert(viewController: self, isError: false, message: "Transaction sent ✓")
                }
            }
        }
        
        func decodePsbt() {
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (object, errorDesc) in
                guard let self = self else { return }
                
                guard let dict = object as? NSDictionary else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: errorDesc ?? "")
                    return
                }
                
                self.psbtDict = dict
                
                if let inputs = dict["inputs"] as? NSArray, inputs.count > 0 {
                    for (i, input) in inputs.enumerated() {
                        var isSigned = false
                        if let inputDict = input as? NSDictionary {
                            if let signatures = inputDict["partial_signatures"] as? NSDictionary {
                                for (key, value) in signatures {
                                    self.signatures.append(["\(key)":(value as? String ?? "")])
                                }
                            } else if let _ = inputDict["final_scriptwitness"] as? [String] {
                                isSigned = true
                            }
                        }
                        
                        let inputDict:[String:Any] = [
                            "index": i + 1,
                            "amount": "Unknown.",
                            "address": "Unknown.",
                            "isOurs": false,// Hardcode at this stage and update before displaying
                            "isDust": true,
                            "isSigned": isSigned
                        ]
                        
                        self.inputTableArray.append(inputDict)
                    }
                }
                
                if let txDict = dict["tx"] as? NSDictionary {
                    
                    if let size = txDict["vsize"] as? Int {
                        self.txSize = size
                    }
                    
                    if let id = txDict["txid"] as? String {
                        self.txid = id
                        self.loadLabelAndMemo()
                    }
                    
                    self.parseTransaction(tx: txDict)
                }
            }
        }
        
        func decodeTx() {
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (object, errorDesc) in
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
                    self.loadLabelAndMemo()
                }
                
                if let inputs = dict["vin"] as? [[String: Any]] {
                    
                    for (i, _) in inputs.enumerated() {
                        let inputDict:[String:Any] = [
                            "index": i + 1,
                            "amount": "Unknown amount.",
                            "address": "Unknown address.",
                            "isOurs": false,// Hardcode at this stage and update before displaying
                            "isDust": true,
                            "isSigned": false
                        ]
                        
                        self.inputTableArray.append(inputDict)
                    }
                    
                    self.index = 0
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
            if blind {
                CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] utxos in
                    guard let self = self else { return }
                    
                    if let utxos = utxos, utxos.count > 0 {
                        var parseIt = false
                        for (i, utxo) in utxos.enumerated() {
                            let utxoStr = Utxo(utxo)
                            
                            // only parse inputs for utxos we own if dealing with blind psbt
                            if utxoStr.txid == txid, utxoStr.vout == vout, (utxoStr.solvable ?? false) {
                                parseIt = true
                            }
                            
                            if i + 1 == utxos.count && parseIt {
                                let param:Get_Tx = .init(["txid": txid, "verbose": true])
                                self.parsePrevTx(method: .gettransaction(param), vout: vout, txid: txid)
                            } else if i + 1 == utxos.count && !parseIt {
                                
                                if index + 1 < self.inputArray.count {
                                    self.index += 1
                                    self.getInputInfo(index: self.index)
                                } else {
                                    self.parsePrevTxOutput(outputs: [], vout: 0)
                                }
                            }
                        }
                    }
                }
            } else {
                let param:Get_Tx = .init(["txid": txid, "verbose": true])
                parsePrevTx(method: .gettransaction(param), vout: vout, txid: txid)
            }
        } else if dict["txid"] as? String == "coinbase" {
            self.parsePrevTxOutput(outputs: [], vout: 0)
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
                } else if let _ = input["coinbase"] as? String {
                    let dict = ["inputNumber":index + 1, "txid":"coinbase"] as [String : Any]
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
                    
                    if addresses.count > 0 {
                        if addresses.count > 1 {
                            for a in addresses {
                                addressString += a as! String + " "
                            }
                        } else {
                            addressString = addresses[0] as? String ?? ""
                        }
                    } else if let address = scriptpubkey["address"] as? String {
                        addressString = address
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
                                        
                    var amountString = amount.btcBalanceWithSpaces
                    
                    if let fxRate = fxRate {
                        amountString += " / \((fxRate * amount).fiatString)"
                    }
                                        
                    let outputDict:[String:Any] = [
                        "index": number,
                        "amount": amountString,
                        "address": addressString,
                        "isChange": isChange,
                        "isOursBitcoind": false,// Hardcode at this stage and update before displaying
                        "isOursFullyNoded": false,
                        "walletLabel": "",
                        "signable": false,
                        "signerLabel": "",
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
                                } else if let address = scriptpubkey["address"] as? String {
                                    addressString = address
                                }
                            }
                            
                            if let amount = output["value"] as? Double {
                                inputTotal += amount
                                var amountString = amount.btcBalanceWithSpaces
                                
                                if let fxRate = fxRate {
                                    amountString += " / \((fxRate * amount).fiatString)"
                                }
                                
                                self.inputTableArray[index]["amount"] = amountString
                                self.inputTableArray[index]["address"] = addressString
                                self.inputTableArray[index]["isDust"] = amount < 0.00020000
                            }
                        }
                    }
                }
            }
        }
        
        if index + 1 < inputArray.count {
            index += 1
            getInputInfo(index: index)
            
        } else if index + 1 == inputArray.count {
            index = 0
            txFee = inputTotal - outputTotal
            
            if inputTotal > 0.0 {
                let txfeeString = txFee.avoidNotation
                if fxRate != nil {
                    self.miningFee = "\(txfeeString) btc / \(fiatAmount(btc: self.txFee))"
                } else {
                    self.miningFee = "\(txfeeString) btc / error fetching fx rate"
                }
            } else {
                self.miningFee = "No fee data. Your node may be pruned."
            }
            
            verifyInputs()
        }
    }
    
    private func verifyInputs() {
        if index < inputTableArray.count {
            self.updateLabel("verifying input #\(self.index + 1) out of \(self.inputTableArray.count)")
            
            if let address = inputTableArray[index]["address"] as? String, address != "Unknown address.", address != "" {
                
                let param:Get_Address_Info = .init(["address":address])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    guard errorMessage == nil else {
                        self.spinner.removeConnectingView()
                        if errorMessage!.contains("Wallet file not specified (must request wallet RPC through") {
                            showAlert(vc: self, title: "No wallet specified!", message: "Please go to your Active Wallet tab and toggle on a wallet then try this operation again, for certain commands Bitcoin Core needs to know which wallet to talk to.")
                        } else {
                            showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown")
                        }
                        
                        return
                    }
                    
                    guard let dict = response as? NSDictionary else { return }
                    
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
                    
                    isChange = desc.contains("/1/")
                    
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
                            
                            for signedTxInput in signedTxInputs {
                                let scriptsig = signedTxInput["scriptSig"] as? [String: Any] ?? [:]
                                let hex = scriptsig["hex"] as? String ?? ""
                                if hex != "" {
                                    self.inputTableArray[self.index]["signatures"] = "Signatures complete"
                                } else {
                                    if let txwitness = signedTxInput["txinwitness"] as? NSArray {
                                        if txwitness.count > 0 {
                                            self.inputTableArray[self.index]["signatures"] = "Signatures complete"
                                        }
                                    }
                                }
                            }
                        }
                    }
                    self.index += 1
                    self.verifyInputs()
                }
            } else {
                self.index += 1
                self.verifyInputs()
            }
        } else {
            self.index = 0
            verifyOutputs()
        }
    }
    
    private func verifyOutputs() {
        print("verifyOutputs")
        if index < outputArray.count {
            self.updateLabel("verifying output #\(self.index + 1) out of \(self.outputArray.count)")
            
            if let address = outputArray[index]["address"] as? String, address != "" {
                let param:Get_Address_Info = .init(["address":address])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    if let dict = response as? NSDictionary {
                        let solvable = dict["solvable"] as? Bool ?? false
                        var keypath = dict["hdkeypath"] as? String ?? "no key path"
                        let labels = dict["labels"] as? NSArray ?? ["no label"]
                        let desc = dict["desc"] as? String ?? "no descriptor"
                        var isChange = dict["ischange"] as? Bool ?? false
                        let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                        let parentDesc = dict["parent_desc"] as? String ?? ""
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
                        
                        if keypath == "no key path" {
                            let descriptorStr = Descriptor(desc)
                            keypath = descriptorStr.derivation
                        }
                        
                        self.outputArray[self.index]["isOursBitcoind"] = solvable
                        self.outputArray[self.index]["hdKeyPath"] = keypath
                        self.outputArray[self.index]["isChange"] = isChange
                        self.outputArray[self.index]["label"] = labelsText
                        self.outputArray[self.index]["fingerprint"] = fingerprint
                        self.outputArray[self.index]["desc"] = desc
                        //self.outputArray[self.index]["parent_desc"] = parentDesc
                        
                        // Currently only verify address if the node knows about it.. otherwise we have to brute force 200k addresses...
                        // will add a dedicated verify button for unsolvable to cross check against all wallets
                        // also adding a signer verify button to show whether FN is able to sign for the output or not
                        if solvable && self.wallet != nil {
                            // Only do this if we are not using the default wallet.
                            Keys.verifyAddress(parentDesc: parentDesc, passphrase: self.passphrase) { (isOursFullyNoded, walletLabel, signable, signer) in
                                self.outputArray[self.index]["isOursFullyNoded"] = isOursFullyNoded
                                self.outputArray[self.index]["walletLabel"] = walletLabel
                                self.outputArray[self.index]["signable"] = signable
                                self.outputArray[self.index]["signerLabel"] = signer
                                self.index += 1
                                self.verifyOutputs()
                            }
                        } else {
                            self.outputArray[self.index]["isOursFullyNoded"] = false
                            self.outputArray[self.index]["walletLabel"] = ""
                            self.index += 1
                            self.verifyOutputs()
                        }
                    }
                }
            } else {
                self.index += 1
                self.verifyOutputs()
            }
        } else {
            guard signedRawTx != "" else {
                getFeeRate()
                return
            }
            
            if !alreadyBroadcast {
                updateLabel("verifying mempool accept...")
                let param:Test_Mempool_Accept = .init(["rawtxs":[signedRawTx]])
                MakeRPCCall.sharedInstance.executeRPCCommand(method: .testmempoolaccept(param)) { [weak self] (response, errorMessage) in
                    guard let self = self else { return }
                    
                    if let errorMessage = errorMessage {
                        showAlert(vc: self, title: "testmempoolaccept error", message: errorMessage)
                    }
                    
                    guard let arr = response as? NSArray, arr.count > 0,
                        let dict = arr[0] as? NSDictionary,
                        let allowed = dict["allowed"] as? Bool else {
                        self.getFeeRate()
                        return
                    }
                    
                    self.txValid = allowed
                    
                    if allowed {
                        self.enableSendButton()
                        self.disableSignButton()
                    }
                    
                    self.rejectionMessage = dict["reject-reason"] as? String ?? ""
                    self.getFeeRate()
                }
            } else {
                self.getFeeRate()
            }
        }
    }
    
    private func getFeeRate() {
        let target = UserDefaults.standard.object(forKey: "feeTarget") as? Int ?? 432
        
        updateLabel("estimating smart fee...")
        let param:Estimate_Smart_Fee_Param = .init(["conf_target": target])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .estimatesmartfee(param: param)) { [weak self] (response, errorMessage) in
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
        return roundedFiat.fiatString
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
    
    func parsePrevTx(method: BTC_CLI_COMMAND, vout: Int, txid: String) {
        func decodeRaw() {
            updateLabel("decoding inputs previous output...")
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (object, errorDescription) in
                guard let self = self else { return }
                
                guard let txDict = object as? NSDictionary, let outputs = txDict["vout"] as? NSArray else {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: "Error decoding raw transaction")
                    return
                }
                
                self.parsePrevTxOutput(outputs: outputs, vout: vout)
            }
        }
        
//        func checkEsplora(txid: String) {
//            guard let useEsplora = UserDefaults.standard.object(forKey: "useEsplora") as? Bool, useEsplora else {
//                if UserDefaults.standard.object(forKey: "useEsplora") == nil && UserDefaults.standard.object(forKey: "useEsploraAlert") == nil {
//                    showAlert(vc: self, title: "Unable to fetch input.", message: "Pruned nodes can not lookup input details for inputs that are associated with transactions which are not owned by the active wallet. In order to see inputs in detail you can enable Esplora (Blockstream's block explorer) over Tor in \"Settings\".")
//
//                    UserDefaults.standard.setValue(true, forKey: "useEsploraAlert")
//                }
//
//                self.parsePrevTxOutput(outputs: [], vout: 0)
//                return
//            }
//
//            self.updateLabel("fetching inputs previous output with Esplora...")
//
//            let fetcher = GetTx.sharedInstance
//            fetcher.fetch(txid: txid) { [weak self] rawHex in
//                guard let self = self else { return }
//
//                guard let rawHex = rawHex else {
//                    // Esplora must be down, pass an empty array instead
//                    self.parsePrevTxOutput(outputs: [], vout: 0)
//                    return
//                }
//                let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":rawHex])
//                self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
//            }
//            return
//        }
        
        func getRawTx() {
            updateLabel("fetching inputs previous output...")
            MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                guard let response = response as? [String:Any] else {
                    self.parsePrevTxOutput(outputs: [], vout: 0)
                    return
                }
                
                guard let hex = response["hex"] as? String else {
                    guard let errorMessage = errorMessage else { return }
                    
                    guard errorMessage.contains("No such mempool transaction") else {
                        self.spinner.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: "Error parsing inputs: \(errorMessage)")
                        return
                    }
                    
                    let param_get_tx:Get_Tx = .init(["txid":txid, "verbose": true])
                    MakeRPCCall.sharedInstance.executeRPCCommand(method: .gettransaction(param_get_tx)) { (response, errorMessage) in
                        guard let dict = response as? NSDictionary, let hexToParse = dict["hex"] as? String else {
//                            guard let useEsplora = UserDefaults.standard.object(forKey: "useEsplora") as? Bool, useEsplora else {
//                                if UserDefaults.standard.object(forKey: "useEsplora") == nil && UserDefaults.standard.object(forKey: "useEsploraAlert") == nil {
//                                    showAlert(vc: self, title: "Unable to fetch input.", message: "Pruned nodes can not lookup input details for inputs that are associated with transactions which are not owned by the active wallet. In order to see inputs in detail you can enable Esplora (Blockstream's block explorer) over Tor in \"Settings\".")
//
//                                    UserDefaults.standard.setValue(true, forKey: "useEsploraAlert")
//                                }
//
//                                self.parsePrevTxOutput(outputs: [], vout: 0)
//                                return
//                            }
//
//                            self.updateLabel("fetching inputs previous output with Esplora...")
//
//                            let fetcher = GetTx.sharedInstance
//                            fetcher.fetch(txid: txid) { [weak self] rawHex in
//                                guard let self = self else { return }
//
//                                guard let rawHex = rawHex else {
//                                    // Esplora must be down, pass an empty array instead
//                                    self.parsePrevTxOutput(outputs: [], vout: 0)
//                                    return
//                                }
//                                let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":rawHex])
//                                self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
//                            }
//                            return
                            //checkEsplora(txid: txid)
                            self.parsePrevTxOutput(outputs: [], vout: 0)
                            return
                        }
                        
                        let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":hexToParse])
                        self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
                    }
                    
                    return
                }
                let param_decode_raw:Decode_Raw_Tx = .init(["hexstring":hex])
                self.parsePrevTx(method: .decoderawtransaction(param: param_decode_raw), vout: vout, txid: txid)
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
    
    private func defaultCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = verifyTable.dequeueReusableCell(withIdentifier: "defaultCell", for: indexPath)
        configureCell(cell)
        
        let addButton = cell.viewWithTag(2) as! UIButton
        addButton.addTarget(self, action: #selector(tapToAdd(_:)), for: .touchUpInside)
        
        return cell
    }
    
    private func confsCell(_ indexPath: IndexPath) -> UITableViewCell {
        let confsCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(confsCell)
        
        let label = confsCell.viewWithTag(1) as! UILabel
        let imageView = confsCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        label.text = "\(confs) confirmations"
        label.textColor = .label
        
        if confs > 0 {
            imageView.tintColor = .systemGreen
            imageView.image = UIImage(systemName: "checkmark.seal")
        } else {
            imageView.tintColor = .systemRed
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        return confsCell
    }
    
    private func mempoolAcceptCell(_ indexPath: IndexPath) -> UITableViewCell {
        let mempoolAcceptCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(mempoolAcceptCell)
        
        let label = mempoolAcceptCell.viewWithTag(1) as! UILabel
        let imageView = mempoolAcceptCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        
        if txValid != nil {
            if txValid! {
                label.text = "Mempool acception verified ✓"
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.seal")
            } else {
                label.text = "Transaction invalid! Reason: \(rejectionMessage)."
                imageView.tintColor = .systemRed
                imageView.image = UIImage(systemName: "exclamationmark.triangle")
            }
        } else {
            if unsignedPsbt != "" {
                label.text = "Transaction incomplete."
            } else {
                if signedRawTx != "" {
                    label.text = "Transaction complete."
                } else {
                    let version = UserDefaults.standard.object(forKey: "version") as? String ?? "0.20"
                    
                    if version.contains("0.1") {
                        label.text = "This feature requires at least Bitcoin Core 0.20.0"
                    } else {
                        label.text = "There was an issue verifying your tx with mempoolaccept."
                    }
                }
            }
            
            imageView.tintColor = .systemOrange
            imageView.image = UIImage(systemName: "exclamationmark.triangle")
        }
        
        mempoolAcceptCell.selectionStyle = .none
        label.textColor = .label
        label.adjustsFontSizeToFitWidth = true
        return mempoolAcceptCell
    }
    
    private func txidCell(_ indexPath: IndexPath) -> UITableViewCell {
        let txidCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        configureCell(txidCell)
        
        let txidLabel = txidCell.viewWithTag(1) as! UILabel
        let imageView = txidCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .tintColor
        imageView.image = UIImage(systemName: "rectangle.and.paperclip")
        txidLabel.text = txid
        txidCell.selectionStyle = .none
        txidLabel.textColor = .label
        txidLabel.adjustsFontSizeToFitWidth = true
        return txidCell
    }
    
    private func inputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let inputCell = verifyTable.dequeueReusableCell(withIdentifier: "inputCell", for: indexPath)
        configureCell(inputCell)
        
        let inputIndexLabel = inputCell.viewWithTag(1) as! UILabel
        let inputAmountLabel = inputCell.viewWithTag(2) as! UILabel
        let inputAddressLabel = inputCell.viewWithTag(3) as! UILabel
        let inputIsOursImage = inputCell.viewWithTag(4) as! UIImageView
        let inputIsOursLabel = inputCell.viewWithTag(5) as! UILabel
        let inputTypeLabel = inputCell.viewWithTag(6) as! UILabel
        let utxoLabel = inputCell.viewWithTag(7) as! UILabel
        let isChangeImageView = inputCell.viewWithTag(8) as! UIImageView
        let isDustImageView = inputCell.viewWithTag(10) as! UIImageView
        let signaturesLabel = inputCell.viewWithTag(14) as! UILabel
        let descTextView = inputCell.viewWithTag(15) as! UITextView
        let sigsImageView = inputCell.viewWithTag(17) as! UIImageView
        let copyAddressButton = inputCell.viewWithTag(18) as! UIButton
        let copyDescButton = inputCell.viewWithTag(19) as! UIButton
        let addressQrButton = inputCell.viewWithTag(20) as! UIButton
        let getAddressInfoButton = inputCell.viewWithTag(21) as! UIButton

        isDustImageView.tintColor = .tintColor
        isChangeImageView.tintColor = .tintColor
        inputIsOursImage.tintColor = .tintColor
        sigsImageView.tintColor = .tintColor
        descTextView.clipsToBounds = true
        descTextView.layer.cornerRadius = 8
        descTextView.layer.borderWidth = 0.5
        descTextView.layer.borderColor = UIColor.darkGray.cgColor
        utxoLabel.textColor = .label
        descTextView.textColor = .label
        inputAddressLabel.textColor = .label
        
        if indexPath.row < inputTableArray.count {
            let input = inputTableArray[indexPath.row]
            
            let isOurs = input["isOurs"] as? Bool ?? false
            let isChange = input["isChange"] as? Bool ?? false
            let label = input["label"] as? String ?? "No label."
            let isDust = input["isDust"] as? Bool ?? false
            let signatureStatus = input["signatures"] as? String ?? "No signature data."
            let desc = input["desc"] as? String ?? "No descriptor."
            let inputAddress = input["address"] as! String
            let hasSigned = input["isSigned"] as! Bool
            
            utxoLabel.text = label
            descTextView.text = desc
            sigsImageView.image = UIImage(systemName: "signature")
            
            inputIndexLabel.text = "Input #\(input["index"] as! Int)"
            inputAmountLabel.text = "\((input["amount"] as! String))"
            inputAddressLabel.text = inputAddress.addressExpanded
            
            copyAddressButton.restorationIdentifier = inputAddress
            copyDescButton.restorationIdentifier = desc
            addressQrButton.restorationIdentifier = inputAddress
            getAddressInfoButton.restorationIdentifier = inputAddress
            
            
            copyAddressButton.addTarget(self, action: #selector(copyAddress(_:)), for: .touchUpInside)
            copyDescButton.addTarget(self, action: #selector(copyDesc(_:)), for: .touchUpInside)
            addressQrButton.addTarget(self, action: #selector(showAddressQr(_:)), for: .touchUpInside)
            getAddressInfoButton.addTarget(self, action: #selector(showAddressInfo(_:)), for: .touchUpInside)
            
            signaturesLabel.text = signatureStatus
            
            if signatureStatus == "Signatures complete" || hasSigned {
                //sigsBackgroundView.backgroundColor = .systemGreen
                signaturesLabel.text = "Signatures complete."
                sigsImageView.tintColor = .green
            } else if self.signatures.count > 0 {
                //sigsBackgroundView.backgroundColor = .systemOrange
                signaturesLabel.text = "Signed."
                sigsImageView.tintColor = .systemGreen
            } else {
                //sigsBackgroundView.backgroundColor = .systemRed
                sigsImageView.tintColor = .systemOrange
            }
            
            if isDust {
                isDustImageView.image = UIImage(systemName: "exclamationmark.circle")
                isDustImageView.tintColor = .systemRed
                //backgroundView3.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark.circle")
                isDustImageView.tintColor = .tintColor
                //backgroundView3.backgroundColor = .systemGreen
            }
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
               // backgroundView2.backgroundColor = .systemPurple
                isChangeImageView.tintColor = .systemPurple
                inputTypeLabel.text = "Change input"
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.down.left")
                //backgroundView2.backgroundColor = .systemBlue
                isChangeImageView.tintColor = .tintColor
                inputTypeLabel.text = "Receive input"
            }
            
            if isOurs {
                //backgroundView1.backgroundColor = .systemGreen
                inputIsOursImage.image = UIImage(systemName: "checkmark.circle")
                inputIsOursImage.tintColor = .tintColor
                
                if let walletLabel = wallet?.label {
                    inputIsOursLabel.text = "Owned by \(walletLabel)."
                } else {
                    inputIsOursLabel.text = "Owned by the Active Wallet."
                }
                
            } else {
                inputTypeLabel.text = "Unknown type."
                //backgroundView2.backgroundColor = .systemGray
                //backgroundView1.backgroundColor = .systemGray
                inputIsOursImage.image = UIImage(systemName: "questionmark.circle")
                isChangeImageView.image = UIImage(systemName: "questionmark.circle")
                inputIsOursImage.tintColor = .systemRed
                isChangeImageView.tintColor = .systemRed
                
                if let walletLabel = wallet?.label {
                    inputIsOursLabel.text = "Not owned by \(walletLabel)."
                    
                } else {
                    inputIsOursLabel.text = "Not owned by the Active Wallet."
                }
            }
        }
        
        return inputCell
    }
    
    private func outputCell(_ indexPath: IndexPath) -> UITableViewCell {
        let outputCell = verifyTable.dequeueReusableCell(withIdentifier: "outputCell", for: indexPath)
        configureCell(outputCell)
        
        let outputIndexLabel = outputCell.viewWithTag(1) as! UILabel
        let outputAmountLabel = outputCell.viewWithTag(2) as! UILabel
        let outputAddressLabel = outputCell.viewWithTag(3) as! UILabel
        let outputIsOursImage = outputCell.viewWithTag(4) as! UIImageView
        let verifiedByFnImageView = outputCell.viewWithTag(6) as! UIImageView
        let labelLabel = outputCell.viewWithTag(7) as! UILabel
        let isChangeImageView = outputCell.viewWithTag(8) as! UIImageView
        let verifiedByFnLabel = outputCell.viewWithTag(9) as! UILabel
        let isDustImageView = outputCell.viewWithTag(10) as! UIImageView
        let descTextView = outputCell.viewWithTag(15) as! UITextView
        let signableImageView = outputCell.viewWithTag(17) as! UIImageView
        let signerLabel = outputCell.viewWithTag(18) as! UILabel
        let verifiedByNodeLabel = outputCell.viewWithTag(19) as! UILabel
        let addressTypeLabel = outputCell.viewWithTag(20) as! UILabel
        let copyAddressButton = outputCell.viewWithTag(21) as! UIButton
        let copyDescriptorButton = outputCell.viewWithTag(22) as! UIButton
        let verifyOwnerButton = outputCell.viewWithTag(23) as! UIButton
        let addressQrButton = outputCell.viewWithTag(24) as! UIButton
        let getAddressInfoButton = outputCell.viewWithTag(25) as! UIButton

        descTextView.layer.cornerRadius = 8
        descTextView.layer.borderWidth = 0.5
        descTextView.layer.borderColor = UIColor.darkGray.cgColor
        
        signableImageView.tintColor = .tintColor
        isDustImageView.tintColor = .tintColor
        isChangeImageView.tintColor = .tintColor
        outputIsOursImage.tintColor = .tintColor
        verifiedByFnImageView.tintColor = .tintColor
        
        outputAddressLabel.textColor = .label
                        
        if indexPath.row < outputArray.count {
            let output = outputArray[indexPath.row]
            
            let outputAddress = output["address"] as? String ?? ""
            let signable = output["signable"] as? Bool ?? false
            let signer =  output["signerLabel"] as? String ?? ""
            let walletLabel = output["walletLabel"] as? String ?? ""
            let isOursFullyNoded = output["isOursFullyNoded"] as? Bool ?? false
            let isOursBitcoind = output["isOursBitcoind"] as? Bool ?? false
            let isChange = output["isChange"] as? Bool ?? false
            let label = output["label"] as? String ?? "no label"
            let isDust = output["isDust"] as? Bool ?? false
            let desc = output["desc"] as? String ?? "no descriptor"
            
            labelLabel.text = label
            descTextView.text = desc
            
            outputIndexLabel.text = "Output #\(output["index"] as! Int)"
            outputAmountLabel.text = "\((output["amount"] as! String))"
            outputAddressLabel.text = outputAddress.addressExpanded
            
            copyAddressButton.restorationIdentifier = outputAddress
            verifyOwnerButton.restorationIdentifier = outputAddress + " " + "\(indexPath.row)"
            copyDescriptorButton.restorationIdentifier = desc
            addressQrButton.restorationIdentifier = outputAddress
            getAddressInfoButton.restorationIdentifier = outputAddress
            
            copyAddressButton.addTarget(self, action: #selector(copyAddress(_:)), for: .touchUpInside)
            copyDescriptorButton.addTarget(self, action: #selector(copyDesc(_:)), for: .touchUpInside)
            verifyOwnerButton.addTarget(self, action: #selector(verifyOwner(_:)), for: .touchUpInside)
            addressQrButton.addTarget(self, action: #selector(showAddressQr(_:)), for: .touchUpInside)
            getAddressInfoButton.addTarget(self, action: #selector(showAddressInfo(_:)), for: .touchUpInside)
            
            if isOursFullyNoded {
                verifiedByFnLabel.text = "Owned by \(walletLabel)."
                verifiedByFnImageView.image = UIImage(systemName: "checkmark.circle")
                verifiedByFnImageView.tintColor = .systemGreen
                //verifiedByFnBackgroundView.backgroundColor = .systemGreen
            } else {
                verifyOwnerButton.alpha = 1
                verifiedByFnLabel.text = "Not verified by Fully Noded."
                verifiedByFnImageView.image = UIImage(systemName: "questionmark.circle")
                verifiedByFnImageView.tintColor = .systemRed
                //verifiedByFnBackgroundView.backgroundColor = .systemGray
            }
            
            if signable {
                signableImageView.image = UIImage(systemName: "signature")
                //signableBackgroundView.backgroundColor = .systemGreen
                signerLabel.text = "Signable by \(signer)"
                signableImageView.tintColor = .systemGreen
            } else {
                signableImageView.image = UIImage(systemName: "signature")
                //signableBackgroundView.backgroundColor = .systemRed
                signerLabel.text = "Unable to determine."
                signableImageView.tintColor = .systemOrange
            }
            
            if isDust {
                isDustImageView.image = UIImage(systemName: "exclamationmark.circle")
                isDustImageView.tintColor = .systemRed
                //backgroundView3.backgroundColor = .systemRed
            } else {
                isDustImageView.image = UIImage(systemName: "checkmark.circle")
                isDustImageView.tintColor = .tintColor
                //backgroundView3.backgroundColor = .systemGreen
            }
            
            if isChange {
                isChangeImageView.image = UIImage(systemName: "arrow.triangle.2.circlepath")
                isChangeImageView.tintColor = .systemPurple
                addressTypeLabel.text = "Change address."
            } else {
                isChangeImageView.image = UIImage(systemName: "arrow.up.right")
                isChangeImageView.tintColor = .tintColor
                addressTypeLabel.text = "Receive address."
            }
            
            var activeWalletLabel = "Bitcoin Core"
            
            if self.wallet != nil {
                activeWalletLabel = self.wallet!.label
            }
            
            if isOursBitcoind {
                verifyOwnerButton.alpha = 0
                verifiedByNodeLabel.text = "Owned by Bitcoin Core."
                outputIsOursImage.tintColor = .systemGreen
                outputIsOursImage.image = UIImage(systemName: "checkmark.circle")
                
                if self.wallet != nil {
                    let ds = Descriptor(self.wallet!.receiveDescriptor)
                    if ds.isHot {
                        signableImageView.image = UIImage(systemName: "checkmark.square")
                        signableImageView.tintColor = .systemGreen
                        signerLabel.text = "Bitcoin Core hot wallet."
                    }
                }
                
            } else {
                verifyOwnerButton.alpha = 1
                verifiedByNodeLabel.text = "Not owned by \(activeWalletLabel)."
                outputIsOursImage.tintColor = .systemOrange
                outputIsOursImage.image = UIImage(systemName: "questionmark.circle")
                
                isChangeImageView.image = UIImage(systemName: "questionmark.circle")
                isChangeImageView.tintColor = .systemOrange
                addressTypeLabel.text = "Address type unknown."
            }
        }
        
        return outputCell
    }
    
    private func miningFeeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let miningFeeCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        miningFeeCell.selectionStyle = .none
        configureCell(miningFeeCell)
        
        let miningLabel = miningFeeCell.viewWithTag(1) as! UILabel
        miningLabel.textColor = .label
        
        let imageView = miningFeeCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .white
        
        if inputTotal > 0.0 {
            if txFee < 0.0 {
                imageView.tintColor = .systemOrange
                imageView.image = UIImage(systemName: "questionmark.circle")
                miningLabel.text = "Can not determine fee for inputs which don't belong to us."
                
            } else if txFee < 0.00050000 {
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.circle")
                miningLabel.text = miningFee + " / \(satsPerByte()) sats per byte"
                
            } else {
                imageView.tintColor = .systemRed
                imageView.image = UIImage(systemName: "exclamationmark.triangle")
                miningLabel.text = miningFee + " / \(satsPerByte()) sats per byte"
            }
        } else {
            imageView.tintColor = .systemOrange
            imageView.image = UIImage(systemName: "questionmark.circle")
            miningLabel.text = miningFee
        }
        
        return miningFeeCell
    }
    
    private func etaCell(_ indexPath: IndexPath) -> UITableViewCell {
        let etaCell = verifyTable.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
        etaCell.selectionStyle = .none
        configureCell(etaCell)
        
        let etaLabel = etaCell.viewWithTag(1) as! UILabel
        etaLabel.textColor = .label
        
        let imageView = etaCell.viewWithTag(2) as! UIImageView
        imageView.tintColor = .white
        
        var feeWarning = ""
        
        if txFee > 0.0 {
            let percentage = (satsPerByte() / smartFee) * 100
            let rounded = Double(round(10*percentage)/10)
            
            if satsPerByte() > smartFee, rounded.isFinite {
                feeWarning = "The fee paid for this transaction is \(Int(rounded - 100))% greater then your target."
            } else if rounded.isFinite {
                feeWarning = "The fee paid for this transaction is \(Int(100 - rounded))% less then your target."
            } else {
                feeWarning = "Unable to determine fee difference."
            }
            
            if percentage >= 90 && percentage <= 110 {
                imageView.tintColor = .systemGreen
                imageView.image = UIImage(systemName: "checkmark.circle")
                etaLabel.text = "Fee is on target for a confirmation in approximately \(eta()) or \(feeTarget()) blocks."
            } else {
                if percentage <= 90 {
                    imageView.tintColor = .systemRed
                    imageView.image = UIImage(systemName: "tortoise")
                    etaLabel.text = feeWarning
                } else {
                    imageView.tintColor = .systemRed
                    imageView.image = UIImage(systemName: "hare")
                    etaLabel.text = feeWarning
                }
            }
        } else {
            imageView.image = UIImage(systemName: "questionmark.circle")
            imageView.tintColor = .systemOrange
            etaLabel.text = "No fee data."
        }
        
        return etaCell
    }
    
    private func transactionLabelCell(_ indexPath: IndexPath) -> UITableViewCell {
        let labelCell = verifyTable.dequeueReusableCell(withIdentifier: "memoLabelCell", for: indexPath)
        configureCell(labelCell)
        let label = labelCell.viewWithTag(1) as! UILabel
        let button = labelCell.viewWithTag(2) as! UIButton
        button.addTarget(self, action: #selector(updateLabelMemoAction), for: .touchUpInside)
        //button.showsTouchWhenHighlighted = true
        label.text = labelText
        label.textColor = .label
        return labelCell
    }
    
    @objc func verifyOwner(_ sender: UIButton) {
        guard let id = sender.restorationIdentifier else { return }
        let arr = id.split(separator: " ")
        let address = "\(arr[0])"
        guard let index = Int(arr[1]) else { return }
                
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Verify Owner",
                                          message: "This address does not belong to the current Active Wallet, you can run this check to see if any of your other wallets are the owner.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Verify Owner", style: .default, handler: { action in
                self.spinner.addConnectingView(vc: self, description: "checking other FN wallets...")
                self.getBitcoinCoreWallets(address, index)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func checkEachWallet(_ address: String, _ walletsToCheck: [String], _ int: Int) {
        var updatedOutput = outputArray[int]
        
        func resetActiveWallet() {
            UserDefaults.standard.set(self.wallet!.name, forKey: "walletName")
        }
        
        if walletIndex < walletsToCheck.count {
            let wallet = walletsToCheck[walletIndex]
            UserDefaults.standard.set(wallet, forKey: "walletName")
            let param:Get_Address_Info = .init(["address":address])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { resetActiveWallet(); return }
                
                if let dict = response as? NSDictionary, let solvable = dict["solvable"] as? Bool, solvable {
                    let keypath = dict["hdkeypath"] as? String ?? "no key path"
                    let labels = dict["labels"] as? NSArray ?? ["no label"]
                    let desc = dict["desc"] as? String ?? "no descriptor"
                    var isChange = dict["ischange"] as? Bool ?? false
                    let fingerprint = dict["hdmasterfingerprint"] as? String ?? "no fingerprint"
                    let parentDesc = dict["parent_desc"] as? String ?? ""
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
                    updatedOutput["isOursBitcoind"] = solvable
                    updatedOutput["hdKeyPath"] = keypath
                    updatedOutput["isChange"] = isChange
                    updatedOutput["label"] = labelsText
                    updatedOutput["fingerprint"] = fingerprint
                    updatedOutput["desc"] = desc
                    
                    // Currently only verify address if the node knows about it.. otherwise we have to brute force 200k addresses...
                    // will add a dedicated verify button for unsolvable to cross check against all wallets
                    // also adding a signer verify button to show whether FN is able to sign for the output or not
                    
                    Keys.verifyAddress(parentDesc: parentDesc, passphrase: self.passphrase) { (isOursFullyNoded, walletLabel, signable, signer) in
                        updatedOutput["isOursFullyNoded"] = isOursFullyNoded
                        updatedOutput["walletLabel"] = walletLabel
                        updatedOutput["signable"] = signable
                        updatedOutput["signerLabel"] = signer
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            resetActiveWallet()
                            self.outputArray[int] = updatedOutput
                            self.verifyTable.reloadData()
                            self.spinner.removeConnectingView()
                            showAlert(vc: self, title: "", message: "Owned by \(walletLabel ?? "Bitcoin Core") ✓")
                        }
                        
                        return
                    }
                } else {
                    self.walletIndex += 1
                    self.checkEachWallet(address, walletsToCheck, int)
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                resetActiveWallet()
                self.verifyTable.reloadData()
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: "Address not owned by any of the FN Wallets associated with this node.")
            }
        }
    }
    
    private func getFullyNodedWallets(_ address: String,_ int: Int) {
        var walletsToCheck = [String]()
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            
            guard let wallets = wallets, wallets.count > 0, let activeWallet = self.wallet else { return }
            
            for (i, wallet) in wallets.enumerated() {
                if wallet["id"] != nil {
                    let walletStruct = Wallet(dictionary: wallet)
                    
                    if activeWallet.id != walletStruct.id {
                        for (b, bitcoinCoreWallet) in self.bitcoinCoreWallets.enumerated() {
                            if bitcoinCoreWallet == walletStruct.name {
                                walletsToCheck.append(walletStruct.name)
                            }
                            if b + 1 == self.bitcoinCoreWallets.count {
                                if i + 1 == wallets.count {
                                    self.checkEachWallet(address, walletsToCheck, int)
                                }
                            }
                        }
                    } else if i + 1 == wallets.count {
                        self.checkEachWallet(address, walletsToCheck, int)
                    }
                }
            }
        }
    }
    
    func getBitcoinCoreWallets(_ address: String, _ int: Int) {
        bitcoinCoreWallets.removeAll()
        OnchainUtils.listWalletDir { [weak self] (walletDir, message) in
            guard let self = self else { return }
            
            guard let walletDir = walletDir else {
                DispatchQueue.main.async {
                    self.spinner.removeConnectingView()
                    displayAlert(viewController: self, isError: true, message: "error getting wallets: \(message ?? "")")
                }
                return
            }
            
            self.parseWallets(walletDir.wallets, address, int)
        }
    }
    
    private func parseWallets(_ wallets: [String], _ address: String, _ int: Int) {
        guard !wallets.isEmpty else { return }
        
        for (i, walletName) in wallets.enumerated() {
            bitcoinCoreWallets.append(walletName)
            
            if i + 1 == wallets.count {
                getFullyNodedWallets(address, int)
            }
        }
    }
    
    @objc func copyAddress(_ sender: UIButton) {
        UIPasteboard.general.string = sender.restorationIdentifier
        
        showAlert(vc: self, title: "", message: "Address copied ✓")
    }
    
    @objc func showAddressQr(_ sender: UIButton) {
        guard let address = sender.restorationIdentifier else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.qrCodeStringToExport = address
            self.performSegue(withIdentifier: "segueToShowAddressQR", sender: self)
        }
    }
    
    @objc func showAddressInfo(_ sender: UIButton) {
        spinner.addConnectingView(vc: self, description: "getting address info...")
        guard let address = sender.restorationIdentifier else { return }
        
        let p = Get_Address_Info(["address": address])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            spinner.removeConnectingView()
            
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "Unable to get address info.")
                return
            }
            
            self.showModal(data: response, title: "getaddressinfo")
        }
    }
    
    @objc func copyDesc(_ sender: UIButton) {
        UIPasteboard.general.string = sender.restorationIdentifier
        
        showAlert(vc: self, title: "", message: "Descriptor copied ✓")
    }
    
    private func loadLabelAndMemo() {
        CoreDataService.retrieveEntity(entityName: .transactions) { [weak self] transactions in
            guard let self = self else { return }
            
            guard let transactions = transactions, transactions.count > 0 else {
                self.saveNewTx(self.txid)
                return
            }
            
            var alreadySaved = false
            
            for (i, transaction) in transactions.enumerated() {
                let txStruct = TransactionStruct(dictionary: transaction)
                if txStruct.txid == self.txid {
                    alreadySaved = true
                    self.id = txStruct.id!
                    self.labelText = txStruct.label
                    //self.memoText = txStruct.memo
                }
                
                if i + 1 == transactions.count && !alreadySaved {
                    self.saveNewTx(self.txid)
                }
            }
        }
    }
    
    @objc func updateLabelMemoAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToTxLabelMemo", sender: self)
        }
    }
    
    private func configureView(_ view: UIView) {
        view.clipsToBounds = true
        view.layer.cornerRadius = 8
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 0.5
    }
    
    private func configureCell(_ cell: UITableViewCell) {
        cell.selectionStyle = .none
        configureView(cell)
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
                    self.disableSendButton()
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "", message: "Transaction sent ✓")
                }
            } else {
                self.showError(error: "Error broadcasting privately, try again and use your node instead. Error: \(id ?? "unknown")")
            }
        }
    }
    
    private func broadcastWithMyNode() {
        spinner.addConnectingView(vc: self, description: "broadcasting...")
        let paramDict:[String:Any] = ["hexstring":self.signedRawTx]
        let param:Send_Raw_Transaction = .init(paramDict)
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .sendrawtransaction(param)) { [weak self] (response, errorMesage) in
            guard let self = self else { return }
            
            guard let id = response as? String else {
                self.showError(error: "Error broadcasting: \(errorMesage ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                if self.txid == id {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    self.disableSendButton()
                    self.spinner.removeConnectingView()
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        let alert = UIAlertController(title: "Transaction sent ✓",
                                                      message: "",
                                                      preferredStyle: .alert)
                        
                        alert.addAction(UIAlertAction(title: "Done", style: .default, handler: { [weak self] action in
                            self?.navigationController?.popToRootViewController(animated: true)
                        }))

                        alert.popoverPresentationController?.sourceView = self.view
                        self.present(alert, animated: true) {}
                    }
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
            
            let alert = UIAlertController(title: "Broadcast transaction?",
                                          message: "You can broadcast with your node or via Blockstreams Esplora onion. Broadcasting with Esplora is more private.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Via my node", style: .default, handler: { action in
                self.broadcastWithMyNode()
            }))
            
            alert.addAction(UIAlertAction(title: "Via Esplora (Tor)", style: .default, handler: { action in
                self.broadcastPrivately()
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
    
    //Need to export either as blinded or plain text.
    private func exportPsbt(blindedpsbt: String?, plainText: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                        
            var tit = ""
            var itemToExport = ""
            
            if let blinded = blindedpsbt {
                tit = "⚠️ This psbt will only be readable by Fully Noded!"
                itemToExport = blinded
            } else if let plain = plainText {
                itemToExport = plain
            }
            
            let alert = UIAlertController(title: tit, message: "Share?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "File", style: .default, handler: { action in
                self.convertPSBTtoData(string: itemToExport)
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                self.shareText(itemToExport)
            }))
            
            alert.addAction(UIAlertAction(title: "UR QR", style: .default, handler: { action in
                self.qrCodeStringToExport = itemToExport
                self.isBBQr = false
                self.isUR = true
                self.isPlainText = false
                self.exportAsQR()
            }))
            
            alert.addAction(UIAlertAction(title: "BBQr", style: .default, handler: { action in
                self.isBBQr = true
                self.isUR = true
                self.isPlainText = false
                self.qrCodeStringToExport = itemToExport
                self.exportAsQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Plain Text QR", style: .default, handler: { action in
                self.isBBQr = false
                self.isUR = false
                self.isPlainText = true
                self.qrCodeStringToExport = itemToExport
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
            #if !os(macOS)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                }
                
                self.present(activityViewController, animated: true) {}
            }
            
            #else
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                UIPasteboard.general.string = text
                showAlert(vc: self, title: "Transaction copied to clipboard ✓", message: "")
            }
            
            #endif
    }
    
    private func exportTxn(txn: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Export as text or QR?", message: "", preferredStyle: .alert)
            
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
        if string.hasPrefix("UR:BYTES") {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let ur = URHelper.ur(string) else { return }
                
                let data = ur.qrData
                
                var label = self.labelText
                
                if label == "" {
                    label = "FullyNoded"
                }
                            
                let fileManager = FileManager.default
                let fileURL = fileManager.temporaryDirectory.appendingPathComponent("\(label).blindedPsbt")
                
                try? data.write(to: fileURL)
                
                var controller: UIDocumentPickerViewController!
                            
                if #available(iOS 14.0, *) {
                    controller = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                } else {
                    controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                }
                
                self.present(controller, animated: true)
            }
            
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self, let data = Data(base64Encoded: string) else { return }
                
                var label = self.labelText
                
                if label == "" {
                    label = "FullyNoded"
                }
                            
                let fileManager = FileManager.default
                let fileURL = fileManager.temporaryDirectory.appendingPathComponent("\(label).psbt")
                
                try? data.write(to: fileURL)
                
                var controller: UIDocumentPickerViewController!
                            
                if #available(iOS 14.0, *) {
                    controller = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
                } else {
                    controller = UIDocumentPickerViewController(url: fileURL, in: .exportToService)
                }
                
                self.present(controller, animated: true)
            }
        }
    }
    
    private func prompToAddBlindPsbt(_ blindPsbt: Data) {
        func loadNormally() {
            guard let decryptedPsbt = Crypto.decryptPsbt(blindPsbt) else {
                showAlert(vc: self, title: "", message: "Error decrypting psbt.")
                return
            }
            
            self.isSigning = false
            self.unsignedPsbt = decryptedPsbt.base64EncodedString()
            processPsbt(unsignedPsbt)
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Add inputs and outputs to the psbt?",
                                          message: "Fully Noded will add inputs and outputs from your active wallet to this transaction. Everyones inputs and outputs will be shuffled. This helps to break common heuristics companies may use to track your utxos and/or payments.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Join", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.spinner.label.text = "adding our inputs and outputs..."
                self.addBlindPsbt(blindPsbt)
            }))
            
            alert.addAction(UIAlertAction(title: "Not now", style: .default, handler: { action in
                loadNormally()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in
                loadNormally()
            }))
            
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
        
    private func parseBlindPsbt(_ blindPsbt: String) {
        spinner.addConnectingView(vc: self, description: "")
        
        guard let ur = URHelper.ur(blindPsbt), let encryptedData = URHelper.bytesToData(ur) else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "", message: "Error converting blind psbt to data.")
            return
        }
        
        prompToAddBlindPsbt(encryptedData)
    }
    
    private func addBlindPsbt(_ blindPsbt: Data) {
        BlindPsbt.parseBlindPsbt(blindPsbt) { [weak self] (joinedPsbt, error) in
            guard let self = self else { return }
                        
            guard let joinedPsbt = joinedPsbt else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error getting joined psbt.", message: "\(error ?? "unknown error")")
                return
            }
            
            self.processPsbt(joinedPsbt)
        }
    }
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToShowAddressQR" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = self.qrCodeStringToExport
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                vc.headerText = "Address"
                vc.descriptionText = self.qrCodeStringToExport
            }
        }
        
        if segue.identifier == "segueToExportPsbtAsQr" {            
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.isBbqr = self.isBBQr
                vc.isUR = self.isUR
                
                if self.qrCodeStringToExport != "" {
                    vc.psbt = self.qrCodeStringToExport
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    
                    if self.qrCodeStringToExport.hasPrefix("UR:BYTES") {
                        vc.headerText = "Encrypted PSBT"
                        vc.descriptionText = "Pass this psbt to your signer or to others to create a collaborative batch transaction."
                    } else {
                        if isBBQr {
                            vc.headerText = "PSBT BBQr"
                        } else if isUR {
                            vc.headerText = "PSBT UR QR"
                        } else if isPlainText {
                            vc.headerText = "PSBT Plain Text"
                        }
                        vc.descriptionText = "This psbt still needs more signatures to be complete, you can share it with another signer."
                    }
                } else if signedRawTx != "" {
                    vc.txn = signedRawTx
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                    vc.headerText = "Signed Transaction"
                    vc.descriptionText = "You can save this signed transaction and broadcast it later or share it with someone else."
                }
            }
        }
        
        if segue.identifier == "segueToTxLabelMemo" {
            if let vc = segue.destination as? TransactionLabelMemoViewController {
                vc.txid = self.txid
                vc.labelText = labelText
                //vc.memoText = memoText
                
                vc.doneBlock = { result in
                    self.labelText = result
                    
                    DispatchQueue.main.async {
                        self.verifyTable.reloadSections(IndexSet(arrayLiteral: 0), with: .none)
                        showAlert(vc: self, title: "", message: "Transaction updated ✓")
                    }
                }
            }
        }
        
        if segue.identifier == "segueToScanPsbt" {
            if #available(macCatalyst 14.0, *) {
                guard let vc = segue.destination as? QRScannerViewController else { return }
                
                vc.fromSignAndVerify = true
                
                vc.onDoneBlock = { [weak self] tx in
                    guard let self = self, let tx = tx else {
                        return }
                    
                    self.reset()
                    
                    if Keys.validPsbt(tx) {
                        self.processPsbt(tx)
                    } else if Keys.validTx(tx) {
                        self.signedRawTx = tx
                        self.load()
                    } else if tx.uppercased().hasPrefix("UR:BYTES") {
                        guard let ur = URHelper.ur(tx) else {
                            showAlert(vc: self, title: "", message: "Unable to convert ur string to ur.")
                            return
                        }
                        
                        guard let psbt = URHelper.bytesToData(ur) else {
                            self.blind = true
                            self.parseBlindPsbt(tx)
                            
                            return
                        }
                        
                        
                        self.processPsbt(psbt.base64EncodedString())
                        
                    } else if tx.uppercased().hasPrefix("UR:CRYPTO-PSBT") {
                        guard let ur = URHelper.ur(tx) else {
                            showAlert(vc: self, title: "", message: "Unable to convert ur string to ur.")
                            return
                        }
                        
                        guard let psbt = URHelper.psbtUrToBase64Text(ur) else {
                            showAlert(vc: self, title: "", message: "Unable to convert ur to psbt.")
                            return
                        }
                        
                       self.processPsbt(psbt)
                    }
                }
            }
        }
    }
}

extension VerifyTransactionViewController: UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        if unsignedPsbt == "" && signedRawTx == "" {
            return 1
        } else {
            return 7
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if unsignedPsbt == "" && signedRawTx == "" {
            return 1
        } else {
            switch section {
            case 3:
                return inputArray.count
                
            case 4:
                return outputArray.count
                
            case 0, 1, 5, 2, 6:
                return 1
                
            default:
                return 0
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 3:
            return 441
            
        case 4:
            return 522
        
//        case 1:
//            return 150
            
        case 0, 1:
            return 50
            
        case 2, 5, 6:
            return 80
            
        default:
            return 0
            
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard inputTableArray.count > 0 && outputArray.count > 0 else {
            return defaultCell(indexPath)
        }
        
        tableView.separatorColor = .none
        
        switch indexPath.section {
            
        case 0:
            return transactionLabelCell(indexPath)
            
        case 1:
            if !alreadyBroadcast {
                return mempoolAcceptCell(indexPath)
            } else {
                return confsCell(indexPath)
            }
            
        case 2:
            return txidCell(indexPath)
            
        case 3:
            return inputCell(indexPath)
            
        case 4:
            return outputCell(indexPath)
            
        case 5:
            return miningFeeCell(indexPath)
            
        case 6:
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
        textLabel.textColor = .secondaryLabel
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        if unsignedPsbt == "" && signedRawTx == "" {
            textLabel.text = ""
        } else {
            switch section {
            case 0:
                textLabel.text = "Label"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
//            case 1:
//                textLabel.text = "Memo"
//                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 1:
                if !alreadyBroadcast {
                    textLabel.text = "Mempool accept"
                } else {
                    textLabel.text = "Confirmations"
                }
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 2:
                textLabel.text = "Transaction ID"
                let copyButton = UIButton()
                let copyImage = UIImage(systemName: "doc.on.doc")!
                copyButton.tintColor = .systemBlue
                copyButton.setImage(copyImage, for: .normal)
                copyButton.addTarget(self, action: #selector(copyTxid), for: .touchUpInside)
                copyButton.frame = CGRect(x: header.frame.maxX - 70, y: 0, width: 50, height: 50)
                copyButton.center.y = textLabel.center.y
                header.addSubview(copyButton)
                                
            case 3:
                textLabel.text = "Inputs"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                                
            case 4:
                textLabel.text = "Outputs"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                
            case 5:
                textLabel.text = "Mining fee"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
            
            case 6:
                textLabel.text = "Estimated time to confirm"
                textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
                                
            default:
                break
            }
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
}

extension VerifyTransactionViewController: UITableViewDataSource {}
