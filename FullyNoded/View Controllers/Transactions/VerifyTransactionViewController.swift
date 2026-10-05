//
//  VerifyTransactionViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/4/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class VerifyTransactionViewController: UIViewController, UINavigationControllerDelegate, UITextFieldDelegate, UIDocumentPickerDelegate {
    
    var smartFee = Double()
    var txSize = Int()
    var rejectionMessage = ""
    var txValid: Bool?
    var txFee = Double()
    var fxRate: Double?
    var txid = ""
    var psbtDict: NSDictionary!
    var unsignedPsbt = ""
    var signedRawTx = ""
    var inputArray = [[String:Any]]()
    var inputTableArray = [[String:Any]]()
    var outputArray = [[String:Any]]()
    var index = 0
    var inputTotal = Double()
    var outputTotal = Double()
    var miningFee = ""
    var recipients = [String]()
    var sweeping = Bool()
    var signatures = [[String:String]]()
    var signedTxInputs: [[String: Any]] = []
    var alreadyBroadcast = false
    var confs = 0
    var labelText = "No label added."
    var id: UUID!
    var wallet: Wallet?
    var walletIndex = 0
    var qrCodeStringToExport = ""
    var isUR = false
    var isPlainText = false
    var passphrase: String?
    var initialLoad = true
    
    // Built in code (no storyboard scene); see `buildLayout()`.
    // The rest of the screen lives in extensions: +Analysis, +Signing, +Actions, +Cells.
    let verifyTable = UITableView(frame: .zero, style: .grouped)
    let exportButtonOutlet = UIButton(type: .system)
    let bumpFeeOutlet = UIButton(type: .system)
    let sendOutlet = UIButton(type: .system)

    init() {
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        hidesBottomBarWhenPushed = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        buildLayout()
        
        activeWallet { [weak self] w in
            guard let self = self else { return }
            
            self.wallet = w
        }
        
        configureViews()
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.stylePrimary(sendOutlet, tint: .transaction)
        WalletTheme.apply(to: self, tint: .transaction)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isUR = false
        isPlainText = false
        qrCodeStringToExport = ""
        
        if initialLoad {
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
            initialLoad = false
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        passphrase?.secureWipe()
    }
    
    
    
    func reset() {
        unsignedPsbt = ""
        signedRawTx = ""
        rejectionMessage = ""
        txValid = nil
        txid = ""
        inputArray.removeAll()
        inputTableArray.removeAll()
        outputArray.removeAll()
        index = 0
        inputTotal = 0.0
        outputTotal = 0.0
        miningFee = ""
        recipients.removeAll()
        signatures.removeAll()
        signedTxInputs.removeAll()
        confs = 0
        alreadyBroadcast = false
        labelText = "No label added."
        walletIndex = 0
        qrCodeStringToExport = ""
    }
    
    func processWithBDK(psbt: String) -> ((rawTx: String?, psbt: String?)) {
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
    
    func processPsbt(_ psbt: String) {
        // Check if it can be finalized, if it can finalize and extract it.
        self.showActivity("processing psbt...")
                
        let (rawTx, _) = processWithBDK(psbt: psbt)
        
        guard let rawTx = rawTx else {
            processWithBitcoinCore(psbt: psbt)
            return
        }

        signedRawTx = rawTx
        
        load()
    }
    
    // Use core to populate bip32 derivs and other info needed to finalize as a fallback.
    func processWithBitcoinCore(psbt: String) {
        let param: Wallet_Process_PSBT = .init(["psbt": psbt, "sign": false, "sighashtype": "ALL"])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .walletprocesspsbt(param: param)) { [weak self] (object, errorDescription) in
            guard let self = self else { return }
            
            guard let dict = object as? NSDictionary, let processedPsbt = dict["psbt"] as? String else {
                self.finishActivity()
                showAlert(vc: self, title: "", message: "There was an issue processing your psbt with the active wallet: \(errorDescription ?? "unknown error")")

                return
            }

            // Finalize what Core returned: it may have filled in what BDK needed.
            let (rawTx, _) = processWithBDK(psbt: processedPsbt)
            
            if let rawTx = rawTx {
                signedRawTx = rawTx
                load()
                   
            } else {
                unsignedPsbt = processedPsbt
                load()
            }
        }
    }
    
    func enableExportButton() {
        enableButton(exportButtonOutlet)
    }
    
    func enableBumpFeeButton() {
        enableButton(bumpFeeOutlet)
    }
    
    func enableSendButton() {
        enableButton(sendOutlet)
    }
    
    func disableSendButton() {
        disableButton(sendOutlet)
    }
    
    func disableBumpButton() {
        disableButton(bumpFeeOutlet)
    }
    
    func configureViews() {
        disableBumpButton()
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        if alreadyBroadcast {
            if confs == 0 {
                enableBumpFeeButton()
            }
        } else {
            if signedRawTx != "" {
                enableSendButton()
            }
        }
    }
    
    func enableButton(_ button: UIButton) {
        DispatchQueue.main.async {
            button.isEnabled = true
            button.alpha = 1
        }
    }
    
    func disableButton(_ button: UIButton) {
        DispatchQueue.main.async {
            button.isEnabled = false
            button.alpha = 0.3
        }
    }
    
    
    
    
    
    
    
    @objc func addTransactionAction(_ sender: Any) {
        promptToAddTx()
    }
    
    @objc func tapToAdd(_ sender: UIButton) {
        promptToAddTx()
    }
                        
    
    @objc func sendAction(_ sender: Any) {
        guard !isShowingActivity else { return }
        send()
    }
    
    
    
        






    
    
    
    
    
    
    func updateLabel(_ text: String) {
        showActivity(text)
    }

    /// Ends the screen's activity (nav bar / button spinner) and un-dims the table if a
    /// load had dimmed it.
    func finishActivity() {
        hideActivity()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            UIView.animate(withDuration: 0.2) { self.verifyTable.alpha = 1 }
            self.verifyTable.isUserInteractionEnabled = true
        }
    }
    
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }


    
    
    
    
    
    
    
    
    
    



    
    
    
    
    
    
    
    













    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    





}

// MARK: - Layout (programmatic)

extension VerifyTransactionViewController {

    /// Table, bottom action bar and navigation items (formerly the storyboard scene).
    func buildLayout() {
        title = "Transaction Detail"
        view.backgroundColor = WalletTheme.bg

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: UIImage(systemName: "plus"), style: .plain, target: self, action: #selector(addTransactionAction(_:))),
            UIBarButtonItem(image: UIImage(systemName: "info.circle"), style: .plain, target: self, action: #selector(showRawDataAction(_:)))
        ]

        verifyTable.translatesAutoresizingMaskIntoConstraints = false
        verifyTable.delegate = self
        verifyTable.dataSource = self
        verifyTable.rowHeight = UITableView.automaticDimension
        verifyTable.estimatedRowHeight = 120
        verifyTable.sectionFooterHeight = 0
        verifyTable.keyboardDismissMode = .onDrag
        verifyTable.register(VerifyInputCell.self, forCellReuseIdentifier: VerifyInputCell.reuseId)
        verifyTable.register(VerifyOutputCell.self, forCellReuseIdentifier: VerifyOutputCell.reuseId)
        verifyTable.register(VerifyStatusCell.self, forCellReuseIdentifier: VerifyStatusCell.reuseId)
        verifyTable.register(VerifyMemoCell.self, forCellReuseIdentifier: VerifyMemoCell.reuseId)
        verifyTable.register(VerifyAddCell.self, forCellReuseIdentifier: VerifyAddCell.reuseId)

        configureActionButton(exportButtonOutlet, title: "export", systemImage: "square.and.arrow.up", action: #selector(exportAction(_:)))
        configureActionButton(bumpFeeOutlet, title: "bump fee", systemImage: "arrow.up.forward", action: #selector(bumpFeeAction(_:)))
        configureActionButton(sendOutlet, title: "send", systemImage: "paperplane", action: #selector(sendAction(_:)))

        let buttons = UIStackView(arrangedSubviews: [exportButtonOutlet, bumpFeeOutlet, sendOutlet])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually
        buttons.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(verifyTable)
        view.addSubview(buttons)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            verifyTable.topAnchor.constraint(equalTo: guide.topAnchor),
            verifyTable.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            verifyTable.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            buttons.topAnchor.constraint(equalTo: verifyTable.bottomAnchor, constant: 8),
            buttons.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            buttons.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            buttons.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -8),
            buttons.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    func configureActionButton(_ button: UIButton, title: String, systemImage: String, action: Selector) {
        button.configuration = WalletTheme.buttonConfiguration(title: title, systemImage: systemImage, filled: false, tint: .transaction)
        button.addTarget(self, action: action, for: .touchUpInside)
    }
}
