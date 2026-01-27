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
    
    private let utxos: [Esplora_Utxo]
    private let watchOnlyBdkWallet: WalletLogic.BDKWallet
    private let signer: SignerStruct?
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
    private let createTxButton = UIButton(type: .system)
    let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double
    
    init(utxos: [Esplora_Utxo], watchOnlyBdkWallet: WalletLogic.BDKWallet, signer: SignerStruct?, network: WalletLogic.BDKNetwork) {
        self.utxos = utxos
        self.watchOnlyBdkWallet = watchOnlyBdkWallet
        self.signer = signer
        self.network = network
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateBalance()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            view.addGestureRecognizer(tapGesture)
            
            // Configure text field to show Done button
        configureDoneButtonOnKeyboard()
        
        // Title
        titleLabel.text = "Sweep Funds"
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
    }

    @objc private func doneButtonTapped() {
        addressTextField.resignFirstResponder()
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
        ConnectingView.shared.show(vc: self, description: "Creating psbt...")
        
        guard let destination = addressTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !destination.isEmpty else {
            ConnectingView.shared.dismiss()
            showAlert(title: "", message: "Destination address not formatted correctly.")
            return
        }
        
        var totalAmount: UInt64 = 0
        
        for utxo in utxos {
            totalAmount += UInt64(utxo.value)
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let psbt = try WalletLogic.shared.createPsbtWithManualInputs(
                    wallet: self.watchOnlyBdkWallet,
                    utxos: self.utxos,
                    outputs: [(address: destination, amount: totalAmount)],
                    network: self.network
                )
                //let psbt = try WalletLogic.shared.createTimelocked
                 
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    ConnectingView.shared.dismiss()
                    
                    guard let psbt = psbt else { return }
                    
                    let reviewVC = PsbtReviewViewController(
                        psbt: psbt,
                        rawTransaction: nil,
                        wallet: watchOnlyBdkWallet,
                        signer: signer, // optional, pass nil if external signer
                        network: network,
                        inputs: utxos,
                        fxRate: fxRate
                    )
                    
                    navigationController?.pushViewController(reviewVC, animated: true)
                }
                
            } catch {
                // Error: dismiss spinner and show alert on main thread
                DispatchQueue.main.async {
                    ConnectingView.shared.dismiss()
                    showAlert(title: "Error", message: error.localizedDescription)
                }
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
