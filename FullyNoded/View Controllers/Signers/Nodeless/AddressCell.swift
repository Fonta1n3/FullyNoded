//
//  AddressCell.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/5/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class BitcoinAddressCell: UITableViewCell {
    
    // Labels for displaying data
    let addressLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 17)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.sizeToFit()
        let padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        label.frame.size.width += padding.left + padding.right
        label.frame.size.height += padding.top + padding.bottom
        return label
    }()
    
    let lastUpdatedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 12, weight: .regular)
        label.textColor = .systemPurple
        label.textAlignment = .center
        label.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.2)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.sizeToFit()
        let padding = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        label.frame.size.width += padding.left + padding.right
        label.frame.size.height += padding.top + padding.bottom
        return label
    }()
    
    let derivationLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 0 // Allow wrapping if address is long
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Buttons with actions
    let checkBalanceButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Check Balance", for: .normal)
        button.configuration = .tinted()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let exportButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("QR", for: .normal)
        button.configuration = .tinted()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Export", for: .normal)
        button.configuration = .tinted()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
//    let sweepButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Send All", for: .normal)
//        button.configuration = .tinted()
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
    
    // Spinner for balance loading
    private let balanceSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()
    
    // Closures for button actions (user fills these in)
    var checkBalanceAction: (() -> Void)?
    var exportAction: (() -> Void)?
    var copyAction: (() -> Void)?
    //var sweepAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        let balanceContainer = UIView()
        balanceContainer.translatesAutoresizingMaskIntoConstraints = false
        
        balanceContainer.addSubview(balanceLabel)
        balanceContainer.addSubview(balanceSpinner)
        
        NSLayoutConstraint.activate([
            balanceLabel.topAnchor.constraint(equalTo: balanceContainer.topAnchor),
            balanceLabel.leadingAnchor.constraint(equalTo: balanceContainer.leadingAnchor),
            balanceLabel.trailingAnchor.constraint(equalTo: balanceContainer.trailingAnchor),
            balanceLabel.bottomAnchor.constraint(equalTo: balanceContainer.bottomAnchor),
            
            balanceSpinner.centerXAnchor.constraint(equalTo: balanceContainer.centerXAnchor),
            balanceSpinner.centerYAnchor.constraint(equalTo: balanceContainer.centerYAnchor)
        ])
        
        let mainStack = UIStackView(arrangedSubviews: [
            derivationLabel,
            addressLabel,
            balanceContainer,  // Uses container instead of direct balanceLabel
            lastUpdatedLabel,
            createButtonStack()
        ])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.alignment = .leading
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
        
        // Make usedLabel compact
        lastUpdatedLabel.setContentHuggingPriority(.required, for: .horizontal)
        lastUpdatedLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    private func createButtonStack() -> UIStackView {
        // Horizontal stack for buttons
        let buttonStack = UIStackView(arrangedSubviews: [checkBalanceButton, exportButton, copyButton/*, sweepButton*/])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        return buttonStack
    }
    
    private func setupActions() {
        checkBalanceButton.addTarget(self, action: #selector(checkBalanceTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        //sweepButton.addTarget(self, action: #selector(sendAllTapped), for: .touchUpInside)
    }
    
    /// Call this when starting balance check
    func showBalanceLoading() {
        balanceLabel.isHidden = true
        balanceSpinner.startAnimating()
        checkBalanceButton.isEnabled = false  // Optional: prevent multiple taps
    }
    
    /// Call this when balance check is complete
    func hideBalanceLoading() {
        balanceSpinner.stopAnimating()
        balanceLabel.isHidden = false
        checkBalanceButton.isEnabled = true
    }
    
    @objc private func checkBalanceTapped() {
        showBalanceLoading()
        checkBalanceAction?()
    }
    
    @objc private func exportTapped() {
        exportAction?()
    }
    
    @objc private func copyButtonTapped() {
        copyAction?()
    }
    
//    @objc private func sendAllTapped() {
//        sweepAction?()
//    }
    
    // Function to configure the cell with data (call this in cellForRowAt)
    func configure(with addressStr: AddressStruct) {
        self.selectionStyle = .none
        addressLabel.text = addressStr.address.addressExpanded
        if let fxRate = UserDefaults.standard.object(forKey: "fxRate") as? Double {
            balanceLabel.text = addressStr.balance.btcBalanceWithSpaces + " btc / " + (addressStr.balance * fxRate).fiatString
        } else {
            balanceLabel.text = addressStr.balance.btcBalanceWithSpaces + " btc"
        }
                
        if let confirmed = addressStr.confirmed {
            if confirmed {
                balanceLabel.textColor = .systemGreen
                balanceLabel.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.2)
            } else {
                balanceLabel.textColor = .systemRed
                balanceLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.2)
            }
        } else {
            balanceLabel.textColor = .secondaryLabel
            balanceLabel.backgroundColor = .clear
        }
        
        if addressStr.utxos.count > 0, let lastUpdated = addressStr.utxos[addressStr.utxos.count - 1].lastUpdated {
            lastUpdatedLabel.text = "Last updated: " + lastUpdated.formattedDate
        } else {
            lastUpdatedLabel.text = ""
        }
        
            
        derivationLabel.text = addressStr.derivation
        hideBalanceLoading()
    }
}
