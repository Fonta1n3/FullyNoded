//
//  NodelessTransactionAnalyzer.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/29/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit
import BitcoinDevKit  // swift-bdk

class PsbtReviewViewController: UIViewController, UINavigationControllerDelegate {
    
    private let psbt: BitcoinDevKit.Psbt?
    private let rawTransaction: BitcoinDevKit.Transaction?
    private let wallet: BitcoinDevKit.Wallet  // Your watch-only or signing wallet
    private let signer: SignerStruct?  // Optional signer (e.g., from seed)
    private let network: BitcoinDevKit.Network
    private let inputs: [Esplora_Utxo]
    private let fxRate: Double?
    
    // New: for signed transaction
    private var signedRawTx: String?
    private var signedPsbt: String?
    
    // UI Elements
    private let titleLabel = UILabel()
    private let tableView = UITableView()
    private let feeLabel = UILabel()
    private let buttonsStackView = UIStackView()
    
    // Buttons
    private let signButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let broadcastButton = UIButton(type: .system)
    private let dismissButton = UIButton(type: .system)
    
    private var sections: [Section] = []
    
    enum SectionType {
        case inputs
        case outputs
    }
    
    struct Section {
        let type: SectionType
        let items: [TxInOutItem]
    }
    
    struct TxInOutItem {
        let address: String?
        let amountFiat: String?
        let amountBtc: Double
    }
    
    init(psbt: BitcoinDevKit.Psbt?, rawTransaction: BitcoinDevKit.Transaction?, wallet: BitcoinDevKit.Wallet, signer: SignerStruct? = nil, network: BitcoinDevKit.Network, inputs: [Esplora_Utxo], fxRate: Double?) {
        self.psbt = psbt
        self.rawTransaction = rawTransaction
        self.wallet = wallet
        self.signer = signer
        self.network = network
        self.inputs = inputs
        self.fxRate = fxRate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        setupUI()
        
        if let psbt = psbt {
            analyzePsbt(psbt: psbt)
        } else if let tx = rawTransaction {
            analyzeTx(tx: tx)
        }
    }
    
    @objc private func dismissButtonTapped() {
        // Dismiss the view controller (animated)
        //self.dismiss(animated: true, completion: nil)
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Main vertical stack view
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStackView)
        
        // Title
        titleLabel.text = "Review Transaction"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        
        // TableView setup
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ItemCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        tableView.backgroundColor = .clear
        
        // Fee label
        feeLabel.font = UIFont.systemFont(ofSize: 20, weight: .semibold)
        feeLabel.textAlignment = .center
        feeLabel.textColor = .systemRed
        
        // Buttons setup
        setupButtons()
        
        // Bottom buttons stack
        buttonsStackView.axis = .vertical
        buttonsStackView.spacing = 12
        buttonsStackView.addArrangedSubview(signButton)
        buttonsStackView.addArrangedSubview(exportButton)
        buttonsStackView.addArrangedSubview(broadcastButton)
        buttonsStackView.addArrangedSubview(dismissButton)
        broadcastButton.isHidden = true
        
        // Add everything to main stack
        mainStackView.addArrangedSubview(titleLabel)
        mainStackView.addArrangedSubview(tableView)
        mainStackView.addArrangedSubview(feeLabel)
        
        // Spacer to push buttons to bottom
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        mainStackView.addArrangedSubview(spacer)
        
        mainStackView.addArrangedSubview(buttonsStackView)
        
        // Constraints for main stack
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        
        // Make tableView expand to fill available space
        tableView.setContentHuggingPriority(.defaultLow, for: .vertical)
    }
        
    private func setupButtons() {
        // Sign Button
        signButton.setTitle("Sign Transaction", for: .normal)
        signButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        signButton.backgroundColor = .systemGreen
        signButton.setTitleColor(.white, for: .normal)
        signButton.layer.cornerRadius = 12
        signButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        signButton.addTarget(self, action: #selector(signButtonTapped), for: .touchUpInside)
        
        // Export PSBT
        exportButton.setTitle("Export PSBT", for: .normal)
        exportButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        exportButton.backgroundColor = .systemBlue
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 12
        exportButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        exportButton.addTarget(self, action: #selector(exportPsbtTapped), for: .touchUpInside)
        
        // Broadcast
        broadcastButton.setTitle("Broadcast Transaction", for: .normal)
        broadcastButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 17)
        broadcastButton.backgroundColor = .systemPurple
        broadcastButton.setTitleColor(.white, for: .normal)
        broadcastButton.layer.cornerRadius = 12
        broadcastButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
        broadcastButton.addTarget(self, action: #selector(broadcastTapped), for: .touchUpInside)
        
        // Dismiss
        dismissButton.setTitle("Done", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.backgroundColor = .systemGray
        dismissButton.layer.cornerRadius = 12
        dismissButton.titleLabel?.font = .boldSystemFont(ofSize: 17)
        dismissButton.addTarget(self, action: #selector(dismissButtonTapped), for: .touchUpInside)
        dismissButton.heightAnchor.constraint(equalToConstant: 60).isActive = true
    }
    
    private func analyzeTx(tx: Transaction) {
        do {
            self.signedRawTx = tx.serialize().hex
            self.signButton.isHidden = true
            self.broadcastButton.isHidden = false
            self.exportButton.isHidden = true
            var inputItems: [TxInOutItem] = []
            var outputItems: [TxInOutItem] = []
            
            // Inputs
            for input in inputs {
                var fiatAmount: String?
                let amountBtc = (input.value.doubleValue / 100000000.0)
                if let fxRate = fxRate {
                    fiatAmount = (amountBtc * fxRate).fiatString
                }
                inputItems.append(TxInOutItem(address: input.address, amountFiat: fiatAmount, amountBtc: amountBtc))
            }
            
            // Outputs
            for output in tx.output() {
                let address = try Address.fromScript(script: output.scriptPubkey, network: network).description
                let amountBtc = output.value.toBtc()
                var fiatAmount: String?
                if let fxRate = fxRate {
                    fiatAmount = (amountBtc * fxRate).fiatString
                }
                outputItems.append(TxInOutItem(address: address, amountFiat: fiatAmount, amountBtc: amountBtc))
            }
            
            sections = [
                Section(type: .inputs, items: inputItems),
                Section(type: .outputs, items: outputItems)
            ]
            
            // Update fee label
//            let btcFee = Double(fee) / 100_000_000.0
//            if let fxRate = fxRate {
//                let fiatAmount = (btcFee * fxRate).fiatString
//                feeLabel.text = "Fee: \(btcFee.btcBalanceWithSpaces) / \(fiatAmount)"
//            } else {
//                feeLabel.text = "Fee: \(btcFee.btcBalanceWithSpaces)"
//            }
            
            
            tableView.reloadData()
        } catch {
            showAlert(title: "Failed analyzing", message: error.localizedDescription)
        }
        
    }
    
    private func analyzePsbt(psbt: Psbt) {
        do {
            let tx = try psbt.extractTx()  // Final tx if fully signed, otherwise underlying tx
            let fee = try psbt.fee()
            
            var inputItems: [TxInOutItem] = []
            var outputItems: [TxInOutItem] = []
            
            // Inputs
            for input in inputs {
                var fiatAmount: String?
                let amountBtc = (input.value.doubleValue / 100000000.0)
                if let fxRate = fxRate {
                    fiatAmount = (amountBtc * fxRate).fiatString
                }
                inputItems.append(TxInOutItem(address: input.address, amountFiat: fiatAmount, amountBtc: amountBtc))
            }
            
            // Outputs
            for output in tx.output() {
                let address = try Address.fromScript(script: output.scriptPubkey, network: network).description
                let amountBtc = output.value.toBtc()
                var fiatAmount: String?
                if let fxRate = fxRate {
                    fiatAmount = (amountBtc * fxRate).fiatString
                }
                outputItems.append(TxInOutItem(address: address, amountFiat: fiatAmount, amountBtc: amountBtc))
            }
            
            sections = [
                Section(type: .inputs, items: inputItems),
                Section(type: .outputs, items: outputItems)
            ]
            
            // Update fee label
            let btcFee = Double(fee) / 100_000_000.0
            if let fxRate = fxRate {
                let fiatAmount = (btcFee * fxRate).fiatString
                feeLabel.text = "Fee: \(btcFee.btcBalanceWithSpaces) / \(fiatAmount)"
            } else {
                feeLabel.text = "Fee: \(btcFee.btcBalanceWithSpaces)"
            }
            
            
            tableView.reloadData()
        } catch {
            showAlert(title: "Failed analyzing", message: error.localizedDescription)
        }
    }
    
    @objc private func exportPsbtTapped() {
        showQr()
    }
    
    func showQr() {
        promptQRDisplayFormat { format in
            var isBBQr = false
            var isUr = false
            
            switch format {
            case .bbqr:
                isBBQr = true
            case .ur:
                isUr = true
            case .plain:
                isUr = false
                isBBQr = false
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                var transactionToExport = ""
                var headerText = ""
                var descriptionText = ""
                
                if let signedRawTx = signedRawTx {
                    transactionToExport = signedRawTx
                    headerText = "Signed Transaction"
                    descriptionText = "Share or scan to broadcast elsewhere"
                } else if let signedPsbt = signedPsbt {
                    transactionToExport = signedPsbt
                    headerText = "Signed PSBT (needs more sigs)"
                    descriptionText = "Share or scan to sign elsewhere"
                } else if let psbt = psbt {
                    transactionToExport = psbt.serialize()
                    headerText = "Unsigned PSBT"
                    descriptionText = "Share or scan to sign elsewhere"
                }
                
                
                let qrVC = QRViewController(
                    text: transactionToExport,
                    headerText: headerText,
                    descriptionText: descriptionText,
                    headerIcon: UIImage(systemName: "qrcode"),
                    isBbqr: isBBQr,
                    isUR: isUr
                )

                // Optional: Wrap in navigation controller for better UX
                let nav = UINavigationController(rootViewController: qrVC)
                nav.modalPresentationStyle = .pageSheet // or .fullScreen

                present(nav, animated: true)
            }
        }
    }
    
    func promptQRDisplayFormat(
        title: String = "QR Code Format",
        message: String = "Choose how to display the QR code:",
        completion: ((QRDisplayFormat) -> Void)? = nil
    ) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        
        // UR Option (animated multi-part if large)
        alert.addAction(UIAlertAction(title: "UR", style: .default) { _ in
            completion?(.ur)
        })
        
        // BBQr Option (animated split parts)
        alert.addAction(UIAlertAction(title: "BBQr", style: .default) { _ in
            completion?(.bbqr)
        })
        
        // Plain Text Option (static single QR)
        alert.addAction(UIAlertAction(title: "Plain Text (Static QR)", style: .default) { _ in
            completion?(.plain)
        })
        
        // Cancel
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad support
        if let popover = alert.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX,
                                        y: self.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        self.present(alert, animated: true)
    }

    enum QRDisplayFormat {
        case ur
        case bbqr
        case plain
    }
        
    @objc private func broadcastTapped() {
        guard let rawTx = signedRawTx else {
            showAlert(title: "", message: "No signed transaction.")
            return
        }
        
        ConnectingView.shared.show(vc: self, description: "Broadcasting...")
        
        Task {
            let result = try await Broadcaster.sharedInstance.broadcastRawTransaction(rawTx: rawTx, network: network)
            ConnectingView.shared.dismiss()
            switch result {
            case .success(let txid):
                saveNewUtxo(txid: txid)
                deleteCachedUtxo()
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.showTransactionSuccessAnimation(title: "Transaction broadcast successfully!", subtitle: "TxID: \(txid)")
                    self.broadcastButton.isHidden = true
                }
            case .failure(let msg):
                showAlert(title: "", message: "Broadcast failed: \(msg)")
            }
        }
    }
    
    private func deleteCachedUtxo() {        
        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] savedUtxos in
            guard let self = self else { return }
            guard let savedUtxos = savedUtxos else { return }
            for savedUtxo in savedUtxos {
                let utxo = UTXO(from: savedUtxo)
                for input in inputs {
                    if utxo.address == input.address, utxo.txid == input.txid, utxo.vout == input.vout {
                        guard let id = utxo.id else { return }
                        CoreDataService.deleteEntity(id: id, entityName: .utxos) { deleted in
                            guard deleted else {
                                showAlert(title: "", message: "Cached utxo was not deleted...")
                                return
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Save it incase it was a self transfer.
    private func saveNewUtxo(txid: String) {
        do {
            guard let signedTx = self.signedRawTx else { return }
            guard let bytes = Data(hexString: signedTx) else { return }
            guard let tx = try? Transaction(transactionBytes: bytes) else { return }
            
            for (i, output) in tx.output().enumerated() {
                let address = try Address.fromScript(script: output.scriptPubkey, network: network).description
                
                let utxoDict: [String: Any] = [
                    "txid": txid,
                    "walletId": UUID(),
                    "vout": Int64(i),
                    "address": address,
                    "amount": output.value.toBtc(),
                    "confirmations": 0,
                    "lastUpdated": Date(),
                    "id": UUID()
                ]
                
                CoreDataService.saveEntity(dict: utxoDict, entityName: .utxos) { saved in
                    guard saved else {
                        showAlert(title: "", message: "New utxo was not saved to cache...")
                        return
                    }
                }
            }
        } catch {
            showAlert(title: "", message: "Unable to save new utxo: \(error.localizedDescription)")
        }
    }
    
    @objc private func signButtonTapped() {
        let alert = UIAlertController(
            title: "Passphrase (Optional)",
            message: "Enter your BIP39 passphrase if your wallet uses one.\nLeave blank if none.",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.placeholder = "Passphrase"
            textField.isSecureTextEntry = true  // Hide characters
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
            // User cancelled
        }
        
        let signAction = UIAlertAction(title: "Sign", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            let passphrase = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Now proceed with signing using the optional passphrase
            self.performSigning(with: passphrase)
        }
        
        alert.addAction(cancelAction)
        alert.addAction(signAction)
        
        // Make "Sign" the preferred action (bold on iPad, highlighted)
        alert.preferredAction = signAction
        
        present(alert, animated: true)
    }

    private func performSigning(with passphrase: String) {
        // Show loading spinner
        ConnectingView.shared.show(vc: self, description: "Signing transaction...")
        
        // Run signing on background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let walletDict: [String: Any] = [
                "receiveDescriptor": wallet.publicDescriptor(keychain: .external),
                "changeDescriptor": wallet.publicDescriptor(keychain: .internal),
                "blockheight": 0,
                "label": "",
                "name": "",
                "id": UUID()
            ]
            
            let fnWallet = Wallet(dictionary: walletDict)
            
            if let signer = signer {
                attemptToSign(signers: [signer], passphrase: passphrase, fnWallet: fnWallet)
            } else {
                CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
                    guard let self = self else { return }
                    
                    guard let signers = signers else {
                        ConnectingView.shared.dismiss()
                        showAlert(title: "", message: "No signers to sign with...")
                        return
                    }
                    
                    guard !signers.isEmpty else {
                        ConnectingView.shared.dismiss()
                        showAlert(title: "", message: "No signers to sign with...")
                        return
                    }
                                        
                    var signerStructs: [SignerStruct] = []
                    for signer in signers {
                        let signerStr = SignerStruct(dictionary: signer)
                        signerStructs.append(signerStr)
                    }
                    
                    attemptToSign(signers: signerStructs, passphrase: passphrase, fnWallet: fnWallet)
                }
            }
        }
    }
    
    private func attemptToSign(signers: [SignerStruct], passphrase: String?, fnWallet: Wallet) {
        guard let psbt = psbt else {
            ConnectingView.shared.dismiss()
            showAlert(title: "", message: "No psbt to sign...")
            return
        }
        
        Signer.shared.sign(fnWallet: fnWallet, psbt: psbt.serialize(), passphrase: passphrase, signers: signers, network: network) { (signedPsbt, rawTx, errorMessage) in
            ConnectingView.shared.dismiss()
            
            if let rawTx = rawTx {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.signedRawTx = rawTx
                    self.broadcastButton.isHidden = false
                    self.signButton.isHidden = true
                    self.exportButton.setTitle("Export Signed Transaction", for: .normal)
                    self.showTransactionSuccessAnimation(title: "Transaction signed!", subtitle: "Ready to broadcast")
                }
            } else if let signedPsbt = signedPsbt {
                guard let signedBdkPsbt = try? Psbt(psbtBase64: signedPsbt) else { return }
                
                
                var hasSigs = false
                for input in signedBdkPsbt.input() {
                    if input.partialSigs.count > 0 {
                        hasSigs = true
                    }
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    if hasSigs {
                        self.signedPsbt = signedPsbt
                        self.showTransactionSuccessAnimation(title: "Transaction partially signed!", subtitle: "Ready to export to another signer")
                    } else {
                        showAlert(title: "Psbt is unsigned", message: "Sign it with another signer.")
                    }
                }
                
            } else {
                showAlert(vc: self, title: "Error Signing", message: errorMessage ?? "Unknown error.")
            }
        }
    }
    
    private func showTransactionSuccessAnimation(title: String, subtitle: String) {
        // Background overlay
        let overlay = UIView()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)
        
        // Success container
        let successView = UIView()
        successView.backgroundColor = .systemBackground
        successView.layer.cornerRadius = 20
        successView.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(successView)
        
        // Checkmark
        let checkmarkImageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        checkmarkImageView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: config)
        checkmarkImageView.tintColor = .systemGreen
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        successView.addSubview(checkmarkImageView)
        
        // Title label
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
        titleLabel.textAlignment = .center
        titleLabel.textColor = .label
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        successView.addSubview(titleLabel)
        
        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 18)
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        successView.addSubview(subtitleLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            successView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            successView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            successView.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 40),
            successView.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -40),
            successView.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            
            checkmarkImageView.topAnchor.constraint(equalTo: successView.topAnchor, constant: 40),
            checkmarkImageView.centerXAnchor.constraint(equalTo: successView.centerXAnchor),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 120),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 120),
            
            titleLabel.topAnchor.constraint(equalTo: checkmarkImageView.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: successView.leadingAnchor, constant: 30),
            titleLabel.trailingAnchor.constraint(equalTo: successView.trailingAnchor, constant: -30),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: successView.bottomAnchor, constant: -40)
        ])
        
        // Animation sequence
        successView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        successView.alpha = 0
        
        checkmarkImageView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: []) {
            successView.transform = .identity
            successView.alpha = 1
            checkmarkImageView.transform = .identity
        }
        
        // Pulse effect on checkmark
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.15
        pulse.duration = 0.4
        pulse.autoreverses = true
        checkmarkImageView.layer.add(pulse, forKey: "pulse")
        
        // Auto-dismiss after 2.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UIView.animate(withDuration: 0.4, animations: {
                overlay.alpha = 0
            }) { _ in
                overlay.removeFromSuperview()
            }
        }
        
        // Optional: Haptic feedback
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.success)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension PsbtReviewViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].type == .inputs ? "Inputs" : "Outputs"
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        
        let btc = item.amountBtc.btcBalanceWithSpaces
        
        var config = UIListContentConfiguration.subtitleCell()  // Better for two lines
        config.text = item.address?.addressExpanded ?? "Unknown Address"
        config.textProperties.font = UIFont.systemFont(ofSize: 17)
        config.textProperties.numberOfLines = 2  // Allow wrapping long addresses
        
        if let fiatAmount = item.amountFiat {
            config.secondaryText = btc + " / " + fiatAmount
        }
        
//        if sections[indexPath.section].type == .outputs && item.isChange {
//            config.secondaryText! += " (change)"
//        }
        
        config.secondaryTextProperties.font = UIFont.systemFont(ofSize: 16)
        config.secondaryTextProperties.color = .secondaryLabel
        config.secondaryTextProperties.numberOfLines = 1
        
        // Highlight change outputs
//        if sections[indexPath.section].type == .outputs && item.isChange {
//            config.textProperties.color = .systemGreen
//        }
        
        cell.contentConfiguration = config
        cell.backgroundColor = .secondarySystemBackground
        cell.selectionStyle = .none
        
        return cell
    }

}

