//
//  NodelessTransactionCreator.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/29/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class SweepViewController: UIViewController {

    /// What the swept coins are, and so how the transaction is built and signed.
    enum Source {
        /// Coins of a descriptor wallet: BDK builds the PSBT; the signer (or any stored one) signs.
        case descriptor(wallet: WalletLogic.BDKWallet, signer: SignerStruct?)
        /// Silent payment outputs with their saved tweaks: built here (BDK can't spend a bare
        /// taproot key), signed with the spend key + tweak, finalized locally.
        case silentPayment([SilentPaymentSpend.OwnedOutput])
    }
    
    private let utxos: [Esplora_Utxo]
    private let source: Source
    private let network: WalletLogic.BDKNetwork
    
    // UI Elements
    private let titleLabel = UILabel()
    private let balanceLabel = UILabel()
    private let fiatLabel = UILabel()
    private let destinationLabel = UILabel()
    private let addressTextField = UITextField()
    private let scanButton = UIButton(type: .system)
    private let pasteButton = UIButton(type: .system)
    private let noticeLabel = UILabel()
    private let feeRateLabel = UILabel()
    private let feeRateField = UITextField()
    private let createTxButton = UIButton(type: .system)
    let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double
    
    init(utxos: [Esplora_Utxo], source: Source, network: WalletLogic.BDKNetwork) {
        self.utxos = utxos
        self.source = source
        self.network = network
        super.init(nibName: nil, bundle: nil)
    }

    convenience init(utxos: [Esplora_Utxo], watchOnlyBdkWallet: WalletLogic.BDKWallet, signer: SignerStruct?, network: WalletLogic.BDKNetwork) {
        self.init(utxos: utxos, source: .descriptor(wallet: watchOnlyBdkWallet, signer: signer), network: network)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateBalance()
    }

    /// The fee rate typed in (sat/vB), nil unless it's a number of at least 1.
    private var feeRate: Double? {
        guard let text = feeRateField.text?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."),
              let rate = Double(text), rate >= 1 else { return nil }
        return rate
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            view.addGestureRecognizer(tapGesture)
            
            // Configure text field to show Done button
        configureDoneButtonOnKeyboard()
        
        // Title
        if case .silentPayment = source {
            titleLabel.text = "Sweep Silent Payment"
        } else {
            titleLabel.text = "Sweep Funds"
        }
        titleLabel.font = UIFont.boldSystemFont(ofSize: 28)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // Balance (BTC)
        balanceLabel.font = UIFont.systemFont(ofSize: 36, weight: .semibold)
        balanceLabel.textAlignment = .center
        balanceLabel.textColor = .label
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(balanceLabel)
        
        // Satoshi amount
        fiatLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        fiatLabel.textAlignment = .center
        fiatLabel.textColor = .secondaryLabel
        fiatLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(fiatLabel)
        
        // Destination address label
        destinationLabel.text = "Send to Address"
        destinationLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        destinationLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(destinationLabel)
        
        // Address text field
        addressTextField.placeholder = "bc1..., tb1..., 1..., m..., n..., 2..."
        addressTextField.borderStyle = .roundedRect
        addressTextField.font = UIFont.systemFont(ofSize: 17)
        addressTextField.autocapitalizationType = .none
        addressTextField.autocorrectionType = .no
        addressTextField.keyboardType = .asciiCapable
        addressTextField.clearButtonMode = .whileEditing
        addressTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(addressTextField)
        
        // Scan QR button
        scanButton.setTitle("Scan QR", for: .normal)
        scanButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        scanButton.backgroundColor = .systemBlue
        scanButton.setTitleColor(.white, for: .normal)
        scanButton.layer.cornerRadius = 12
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        scanButton.addTarget(self, action: #selector(scanQRPressed), for: .touchUpInside)
        view.addSubview(scanButton)
        
        // Paste button
        pasteButton.setTitle("Paste", for: .normal)
        pasteButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        pasteButton.backgroundColor = .systemGray
        pasteButton.setTitleColor(.white, for: .normal)
        pasteButton.layer.cornerRadius = 12
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.addTarget(self, action: #selector(pastePressed), for: .touchUpInside)
        view.addSubview(pasteButton)
        
        // Fee rate (sat/vB)
        feeRateLabel.text = "Fee rate (sat/vB)"
        feeRateLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        feeRateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feeRateLabel)

        feeRateField.placeholder = "sat/vB"
        feeRateField.borderStyle = .roundedRect
        feeRateField.font = UIFont.systemFont(ofSize: 17)
        feeRateField.keyboardType = .decimalPad
        feeRateField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(feeRateField)

        // Create Transaction button
        createTxButton.setTitle("Create Transaction", for: .normal)
        createTxButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        createTxButton.backgroundColor = .systemOrange
        createTxButton.setTitleColor(.white, for: .normal)
        createTxButton.layer.cornerRadius = 14
        createTxButton.translatesAutoresizingMaskIntoConstraints = false
        createTxButton.isEnabled = false  // Enable when address is valid
        createTxButton.addTarget(self, action: #selector(createTransactionPressed), for: .touchUpInside)
        view.addSubview(createTxButton)
        
        // Notice label
        noticeLabel.text = "This will present the transaction reviewer where you can review, sign, export and broadcast the transaction."
        noticeLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        noticeLabel.lineBreakMode = .byWordWrapping
        noticeLabel.numberOfLines = 0
        noticeLabel.textColor = .secondaryLabel
        noticeLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(noticeLabel)
        
        setupConstraints()
        
        // Observe text field changes
        addressTextField.addTarget(self, action: #selector(addressTextChanged), for: .editingChanged)
    }
    
    private func configureDoneButtonOnKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
        
        toolbar.items = [flexibleSpace, doneButton]
        toolbar.tintColor = .systemBlue
        
        addressTextField.inputAccessoryView = toolbar
        feeRateField.inputAccessoryView = toolbar
    }

    @objc private func doneButtonTapped() {
        view.endEditing(true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Title
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Balance
            balanceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            balanceLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            balanceLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            balanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Fiat label
            fiatLabel.topAnchor.constraint(equalTo: balanceLabel.bottomAnchor, constant: 8),
            fiatLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Destination label
            destinationLabel.topAnchor.constraint(equalTo: fiatLabel.bottomAnchor, constant: 50),
            destinationLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            destinationLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // Address text field
            addressTextField.topAnchor.constraint(equalTo: destinationLabel.bottomAnchor, constant: 12),
            addressTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            addressTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            addressTextField.heightAnchor.constraint(equalToConstant: 50),
            
            // Scan and Paste buttons
            scanButton.topAnchor.constraint(equalTo: addressTextField.bottomAnchor, constant: 20),
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            scanButton.trailingAnchor.constraint(equalTo: view.centerXAnchor, constant: -10),
            scanButton.heightAnchor.constraint(equalToConstant: 56),
            
            pasteButton.topAnchor.constraint(equalTo: scanButton.topAnchor),
            pasteButton.leadingAnchor.constraint(equalTo: view.centerXAnchor, constant: 10),
            pasteButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            pasteButton.heightAnchor.constraint(equalTo: scanButton.heightAnchor),

            // Fee rate
            feeRateLabel.topAnchor.constraint(equalTo: scanButton.bottomAnchor, constant: 24),
            feeRateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            feeRateField.centerYAnchor.constraint(equalTo: feeRateLabel.centerYAnchor),
            feeRateField.leadingAnchor.constraint(equalTo: feeRateLabel.trailingAnchor, constant: 12),
            feeRateField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            feeRateField.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            feeRateField.heightAnchor.constraint(equalToConstant: 44),
            
            // Create Transaction button (bottom)
            createTxButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            createTxButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            createTxButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            createTxButton.heightAnchor.constraint(equalToConstant: 60),
            
            // Notice label (on top of Create Transaction)
            noticeLabel.topAnchor.constraint(equalTo: createTxButton.topAnchor, constant: -40),
            noticeLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            noticeLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            noticeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30)
        ])
    }
    
    private func updateBalance() {
        let totalSats = utxos.reduce(Int64(0)) { $0 + $1.value }
        let btc = Double(totalSats) / 100_000_000.0
        
        balanceLabel.text = btc.btcBalanceWithSpaces
        if let fxRate = fxRate {
            fiatLabel.text = (btc * fxRate).fiatString
        }
    }
    
    @objc private func scanQRPressed() {
        presentQRScanner(isScanningAddress: true) { qrString in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                addressTextField.text = qrString
                validateAndUpdateCreateButton()
            }
        }
    }
    
    private func presentQRScanner(
        fromSignAndVerify: Bool = false,
        isQuickConnect: Bool = false,
        isScanningAddress: Bool = false,
        completion: @escaping (String) -> Void
    ) {
        let scannerVC = ScanQRViewController()
        
        // Configure based on your use case
        scannerVC.fromSignAndVerify = fromSignAndVerify
        scannerVC.isQuickConnect = isQuickConnect
        scannerVC.isScanningAddress = isScanningAddress
        
        // This is called when scanning completes successfully
        scannerVC.onCompletion = { resultString in
            // Handle the scanned result here (e.g., process PSBT, address, etc.)
            completion(resultString)
        }
        
        // Modal presentation style (full screen on iPhone, sheet on iPad)
        scannerVC.modalPresentationStyle = .fullScreen
        
        // Present it
        self.present(scannerVC, animated: true, completion: nil)
    }
    
    @objc private func pastePressed() {
        if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           !pasted.isEmpty {
            addressTextField.text = pasted
            validateAndUpdateCreateButton()
        } else {
            let alert = UIAlertController(title: "Nothing to Paste", message: "Clipboard is empty or contains invalid text.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func addressTextChanged() {
        validateAndUpdateCreateButton()
    }
    
    private func validateAndUpdateCreateButton() {
        let address = addressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isValid = !address.isEmpty && isABitcoinAddress(address)
        
        createTxButton.isEnabled = isValid
        createTxButton.backgroundColor = isValid ? .systemOrange : .systemGray3
    }
    
    private func isABitcoinAddress(_ string: String) -> Bool {
        do {
            let _ = try WalletLogic.BDKAddress(address: string, network: network)
            return true
        } catch {
            showAlert(title: "", message: "That is not a valid bitcoin address: \(error.localizedDescription)")
            return false
        }
    }
    
    @objc private func createTransactionPressed() {
        guard !isShowingActivity else { return }
        guard let destination = addressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !destination.isEmpty else {
            showAlert(title: "", message: "Destination address not formatted correctly.")
            return
        }
        guard let feeRate = feeRate else {
            showAlert(title: "Fee rate", message: "Enter a fee rate of at least 1 sat/vB.")
            return
        }
        view.endEditing(true)
        showActivity("Creating psbt...", button: createTxButton)

        switch source {
        case .descriptor(let wallet, let signer):
            createDescriptorPsbt(wallet: wallet, signer: signer, destination: destination, feeRate: feeRate)
        case .silentPayment(let outputs):
            createSilentPaymentPsbt(outputs: outputs, destination: destination, feeRate: feeRate)
        }
    }

    /// BDK builds the PSBT from the wallet's descriptor.
    private func createDescriptorPsbt(wallet: WalletLogic.BDKWallet, signer: SignerStruct?, destination: String, feeRate: Double) {
        let totalAmount = utxos.reduce(UInt64(0)) { $0 + UInt64($1.value) }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            do {
                let psbt = try WalletLogic.shared.createPsbtWithManualInputs(
                    wallet: wallet,
                    utxos: self.utxos,
                    outputs: [(address: destination, amount: totalAmount)],
                    feeRate: Float(feeRate),
                    network: self.network
                )
                DispatchQueue.main.async {
                    self.hideActivity()
                    guard let psbt = psbt else { return }
                    self.review(PsbtReviewViewController(psbt: psbt, rawTransaction: nil, wallet: wallet, signer: signer,
                                                         network: self.network, inputs: self.utxos, fxRate: self.fxRate))
                }
            } catch {
                DispatchQueue.main.async {
                    self.hideActivity()
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    /// Silent payment outputs: one Esplora lookup per output (like the BDK path's sync): its
    /// amount and script on chain must match what's cached, and the PSBT is built from the
    /// chain's values, which the BIP341 signature commits to. Already spent shows up as a
    /// broadcast error, so it isn't checked separately.
    private func createSilentPaymentPsbt(outputs: [SilentPaymentSpend.OwnedOutput], destination: String, feeRate: Double) {
        let utxos = utxos
        let network = network
        Task { [weak self] in
            do {
                let destinationScript = try WalletLogic.BDKAddress(address: destination, network: network).scriptPubkey().toBytes()
                var inputs: [SilentPaymentSweep.Input] = []
                for utxo in utxos {
                    guard outputs.contains(where: { $0.txid.lowercased() == utxo.txid.lowercased() && $0.vout == utxo.vout }) else {
                        throw WalletLogic.SPError("No saved silent payment tweak for \(utxo.txid):\(utxo.vout).")
                    }
                    guard let address = utxo.address else {
                        throw WalletLogic.SPError("No address for \(utxo.txid):\(utxo.vout).")
                    }
                    let expectedScript = try WalletLogic.BDKAddress(address: address, network: network).scriptPubkey().toBytes()
                    let onChain = try await EsploraAPI.output(txid: utxo.txid, vout: utxo.vout, network: network)
                    guard SPHexFN.decode(onChain.scriptPubKey) == expectedScript else {
                        throw WalletLogic.SPError("\(utxo.txid):\(utxo.vout) on chain doesn't pay \(address). Refresh your utxos.")
                    }
                    guard onChain.value == utxo.value else {
                        throw WalletLogic.SPError("\(utxo.txid):\(utxo.vout) holds \(onChain.value) sats on chain, not the cached \(utxo.value). Refresh your utxos.")
                    }
                    inputs.append(.init(txid: utxo.txid, vout: utxo.vout, amount: UInt64(onChain.value), scriptPubKey: expectedScript))
                }

                let built = try SilentPaymentSweep.psbt(inputs: inputs, destination: destinationScript, feeRate: feeRate)
                let psbt = try WalletLogic.BDKPsbt(psbtBase64: built.psbt)
                await MainActor.run {
                    guard let self = self else { return }
                    self.hideActivity()
                    self.review(PsbtReviewViewController(psbt: psbt, rawTransaction: nil, wallet: nil, signer: nil,
                                                         network: network, inputs: utxos, fxRate: self.fxRate,
                                                         silentPaymentOutputs: outputs))
                }
            } catch {
                await MainActor.run {
                    self?.hideActivity()
                    showAlert(title: "Error", message: error.localizedDescription)
                }
            }
        }
    }

    private func review(_ reviewVC: PsbtReviewViewController) {
        navigationController?.pushViewController(reviewVC, animated: true)
    }
}

// MARK: - Starting a sweep

/// Picks how a cached utxo is swept without the node: a silent payment output with a saved
/// tweak, or a descriptor wallet coin signed by the stored signer whose fingerprint is in its
/// parent descriptor.
enum NodelessSweep {
    enum SweepError: LocalizedError {
        case unsupported(String)
        var errorDescription: String? {
            switch self { case .unsupported(let message): return message }
        }
    }

    /// Receive / change descriptors for the sweep wallet, from the coin's parent descriptor.
    /// BDK refuses identical ones, so a change coin (`…/1/*`) gets its `/0/*` twin as receive
    /// and a receive coin its `/1/*` twin as change (every key, so multisig works too). A
    /// non-ranged descriptor (e.g. a timelocked address) is paired with the wallet's change.
    /// Checksums are dropped (they change with the descriptor; BDK doesn't need them).
    static func sweepDescriptors(parentDesc: String, wallet: Wallet) -> (receive: String, change: String) {
        let desc = String(parentDesc.split(separator: "#")[0])
        if desc.contains("/1/*") {
            return (desc.replacingOccurrences(of: "/1/*", with: "/0/*"), desc)
        }
        if desc.contains("/0/*") {
            return (desc, desc.replacingOccurrences(of: "/0/*", with: "/1/*"))
        }
        return (desc, wallet.changeDescriptor)
    }

    /// Completion on the main queue.
    static func viewController(for utxo: UTXO, wallet: Wallet, completion: @escaping (Result<UIViewController, Error>) -> Void) {
        let done: (Result<UIViewController, Error>) -> Void = { result in DispatchQueue.main.async { completion(result) } }

        guard let network = WalletLogic.shared.bdkNetwork() else {
            done(.failure(SweepError.unsupported("Unknown network.")))
            return
        }
        guard EsploraAPI.apiBase(network: network) != nil else {
            done(.failure(EsploraAPI.APIError.unsupportedNetwork))
            return
        }
        guard let address = utxo.address else {
            done(.failure(SweepError.unsupported("This utxo has no address.")))
            return
        }
        let esploraUtxo = Esplora_Utxo(txid: utxo.txid,
                                       vout: utxo.vout,
                                       value: Int64((utxo.amount * 100_000_000).rounded()),
                                       status: .init(confirmed: (utxo.confirmations ?? 0) > 0, blockHeight: nil, blockHash: nil, blockTime: nil),
                                       address: address)

        // Silent payment: its saved tweak is all signing needs.
        if let output = utxo.silentPaymentOutput {
            done(.success(SweepViewController(utxos: [esploraUtxo], source: .silentPayment([output]), network: network)))
            return
        }
        if utxo.desc?.hasPrefix("rawtr(") == true {
            done(.failure(SweepError.unsupported("Check SP info on this utxo first: a silent payment can only be swept once its tweak is saved.")))
            return
        }

        guard let parentDesc = utxo.parentDescs?.first else {
            done(.failure(SweepError.unsupported("No descriptor is associated with this utxo.")))
            return
        }
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            let fingerprint = Descriptor(parentDesc).fingerprint
            let signer = (signers ?? []).map { SignerStruct(dictionary: $0) }.first { signer in
                guard signer.words != nil,
                      let encryptedXfp = signer.xfp,
                      let xfp = Crypto.decrypt(encryptedXfp)?.utf8String else { return false }
                return fingerprint.contains(xfp)
            }
            do {
                let pair = sweepDescriptors(parentDesc: parentDesc, wallet: wallet)
                let bdkWallet = try WalletLogic.shared.bdkWalletFromDescriptors(recDesc: pair.receive, changeDesc: pair.change)
                done(.success(SweepViewController(utxos: [esploraUtxo], watchOnlyBdkWallet: bdkWallet, signer: signer, network: network)))
            } catch {
                done(.failure(error))
            }
        }
    }
}

// Helper extension for formatting large numbers
extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        return formatter
    }()
}

extension Numeric {
    func formattedWithSeparator() -> String {
        return Formatter.withSeparator.string(from: self as? NSNumber ?? 0) ?? "\(self)"
    }
}
