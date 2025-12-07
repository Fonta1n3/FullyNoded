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
        label.numberOfLines = 0 // Allow wrapping if address is long
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let balanceLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let usedLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
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
        button.setTitle("Export", for: .normal)
        button.configuration = .tinted()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Copy", for: .normal)
        button.configuration = .tinted()
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Closures for button actions (user fills these in)
    var checkBalanceAction: (() -> Void)?
    var exportAction: (() -> Void)?
    var copyAction: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Main vertical stack for all content
        let mainStack = UIStackView(arrangedSubviews: [derivationLabel, addressLabel, createInfoStack(), createButtonStack()])
        mainStack.axis = .vertical
        mainStack.spacing = 8
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(mainStack)
        
        // Constraints for the stack
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
        ])
    }
    
    private func createInfoStack() -> UIStackView {
        // Horizontal stack for balance and used
        let infoStack = UIStackView(arrangedSubviews: [balanceLabel, usedLabel])
        infoStack.axis = .horizontal
        infoStack.spacing = 16
        infoStack.distribution = .fillEqually
        return infoStack
    }
    
    private func createButtonStack() -> UIStackView {
        // Horizontal stack for buttons
        let buttonStack = UIStackView(arrangedSubviews: [checkBalanceButton, exportButton, copyButton])
        buttonStack.axis = .horizontal
        buttonStack.spacing = 16
        buttonStack.distribution = .fillEqually
        return buttonStack
    }
    
    private func setupActions() {
        checkBalanceButton.addTarget(self, action: #selector(checkBalanceTapped), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
    }
    
    @objc private func checkBalanceTapped() {
        checkBalanceAction?()
    }
    
    @objc private func exportTapped() {
        exportAction?()
    }
    
    @objc private func copyButtonTapped() {
        copyAction?()
    }
    
    // Function to configure the cell with data (call this in cellForRowAt)
    func configure(with addressStr: AddressStruct) {
        addressLabel.text = addressStr.address.addressExpanded
        balanceLabel.text = "Balance: \(addressStr.balance.btcBalanceWithSpaces) BTC"
        
        if addressStr.used {
            usedLabel.backgroundColor = UIColor.red.withAlphaComponent(0.7)
            usedLabel.textColor = .white
            usedLabel.layer.cornerRadius = 8
            usedLabel.clipsToBounds = true
            usedLabel.alpha = 1
            usedLabel.text = "Used"
        } else {
            usedLabel.alpha = 0
        }
        
        derivationLabel.text = "Derivation: " + addressStr.derivation
    }
}
