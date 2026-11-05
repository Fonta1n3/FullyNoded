//
//  ImportXpubViewController.swift
//  FullyNoded
//
//  Created by Peter on 9/19/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ImportXpubViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UIGestureRecognizerDelegate {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }
    
    let importOutlet = UIButton(type: .system)
    let labelField = UITextField()
    let descriptorField = UILabel()
    let addressTableView = UITableView(frame: .zero, style: .plain)
    
    var addresses: [String] = []
    var onDoneBlock:(((Bool)) -> Void)?
    var descriptor: Descriptor?

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        
        addressTableView.delegate = self
        addressTableView.dataSource = self
        importOutlet.clipsToBounds = true
        importOutlet.layer.cornerRadius = 8
        labelField.delegate = self
        labelField.spellCheckingType = .no
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        if let desc = descriptor {
            addDescriptorToLabel(desc)
            loadAddresses(desc)
        }
        // Cypherpunk teal look (see WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.stylePrimary(importOutlet, tint: .create)
        WalletTheme.apply(to: self, tint: .create)
    }
    
    private func buildLayout() {
        let scan = UIBarButtonItem(image: UIImage(systemName: "qrcode.viewfinder"), style: .plain,
                                   target: self, action: #selector(scanQrAction(_:)))
        scan.accessibilityLabel = "Scan descriptor"
        navigationItem.rightBarButtonItem = scan

        func caption(_ text: String) -> UILabel {
            let label = UILabel()
            label.text = text
            label.numberOfLines = 0
            label.textColor = .secondaryLabel
            return label
        }
        func spacer() -> UIView {
            let view = UIView()
            view.heightAnchor.constraint(equalToConstant: 12).isActive = true
            return view
        }

        labelField.placeholder = "optional label"
        labelField.font = .systemFont(ofSize: 14)
        labelField.backgroundColor = .secondarySystemFill
        labelField.autocorrectionType = .no
        labelField.spellCheckingType = .no
        labelField.smartDashesType = .no
        labelField.smartQuotesType = .no
        labelField.smartInsertDeleteType = .no
        labelField.keyboardAppearance = .dark
        labelField.heightAnchor.constraint(equalToConstant: 34).isActive = true

        descriptorField.numberOfLines = 0

        addressTableView.register(DerivedAddressCell.self, forCellReuseIdentifier: "addressCell")
        addressTableView.backgroundColor = .clear

        importOutlet.setTitle("Create Wallet", for: .normal)
        importOutlet.backgroundColor = .systemFill
        importOutlet.heightAnchor.constraint(equalToConstant: 43).isActive = true
        importOutlet.addTarget(self, action: #selector(importAction(_:)), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [
            caption("Give your wallet a name:"), labelField, spacer(),
            caption("The descriptor you pasted:"), descriptorField, spacer(),
            caption("First 5 addresses derived from  the descriptor, confirm they are correct:"),
            addressTableView, importOutlet
        ])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        labelField.resignFirstResponder()
    }

    /// Taps on the label field must not trigger the dismiss gesture, otherwise the field
    /// resigns first responder as soon as it gains it and typing goes nowhere.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view else { return true }
        return !touched.isDescendant(of: labelField)
    }
    
    @objc func importAction(_ sender: Any) {
        guard !isShowingActivity else { return }
        guard let desc = self.descriptor else { return }
        
        importDescriptor(desc.string)
    }
    
    @objc func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.showDescriptorScanner()
        }
    }
    
    private func loadAddresses(_ desc: Descriptor) {
        let p = Derive_Addresses(["descriptor": desc.string, "range": [0,4]])
        OnchainUtils.deriveAddresses(param: p) { [weak self] (addresses, message) in
            guard let self = self else { return }
            
            guard let addresses = addresses else { return }
                        
            for address in addresses {
                self.addresses.append(address)
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                addressTableView.reloadData()
            }
        }
    }
        
    private func importDescriptor(_ desc: String) {
        showActivity("importing descriptor wallet, this can take a minute...", button: importOutlet)
        
        let defaultLabel = "Descriptor import"
        
        var label = labelField.text ?? defaultLabel
        
        if label == "" {
            label = defaultLabel
        }
        
        let accountMap = ["descriptor": desc, "blockheight": 0, "watching": [] as [String], "label": label] as [String : Any]
        
        ImportWallet.accountMap(accountMap) { [weak self] (success, errorDescription) in
            guard let self = self else { return }
            
            if success {
                self.doneAlert("Descriptor wallet created", "Tap done to go back and the home screen will refresh, your wallet is rescanning the blockchain, this can take awhile, to monitor rescan progress tap the refresh button on the \"Active Wallet\" tab. You will not see your balances or transaction history until the rescan completes.")
            } else {
                self.hideActivity()
                showAlert(vc: self, title: "", message: errorDescription ?? "unknown error")
            }
        }
    }
    
    private func addDescriptorToLabel(_ descriptor: Descriptor) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            descriptorField.attributedText = descriptorText(descriptor.string)
        }
    }
    
    /// The descriptor, then its checksum (computed here, so it can be compared with the
    /// signer's or wallet's display), with a warning if the checksum written on it disagrees.
    private func descriptorText(_ descriptor: String) -> NSAttributedString {
        let font = descriptorField.font ?? .systemFont(ofSize: 17)
        let color = descriptorField.textColor ?? .label
        let text = NSMutableAttributedString(string: descriptor, attributes: [.font: font, .foregroundColor: color])
        
        guard let checksum = Descriptor.checksum(of: descriptor) else {
            text.append(NSAttributedString(string: "\n\nChecksum: invalid characters in descriptor", attributes: [.font: font, .foregroundColor: UIColor.systemRed]))
            return text
        }
        
        let mono = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .semibold)
        text.append(NSAttributedString(string: "\n\nChecksum: ", attributes: [.font: font, .foregroundColor: UIColor.secondaryLabel]))
        text.append(NSAttributedString(string: checksum, attributes: [.font: mono, .foregroundColor: color]))
        
        if let stated = Descriptor.statedChecksum(of: descriptor), stated != checksum {
            text.append(NSAttributedString(string: "\n⚠️ The descriptor says #\(stated), it should be #\(checksum). It may have been altered or mistyped.", attributes: [.font: font, .foregroundColor: UIColor.systemRed]))
        }
        return text
    }
    
    private func doneAlert(_ title: String, _ message: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
            
            self.hideActivity()
            SuccessView.show(in: self, title: title, subtitle: message) { [weak self] in
                self?.navigationController?.popToRootViewController(animated: true)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return addresses.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "addressCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        // Index as derived (the range starts at 0), matching the wallet's address list.
        label.text = "#\(indexPath.row) " + addresses[indexPath.row].addressExpanded
        return cell
    }
    
    // MARK: - Navigation

    private func showDescriptorScanner() {
        let vc = QRScannerViewController()
        vc.isScanningAddress = true
        vc.onDoneBlock = { [weak self] descriptor in
            guard let self = self else { return }
            
            guard let desc = descriptor else { return }
            
            self.descriptor = Descriptor(desc)
            addDescriptorToLabel(self.descriptor!)
            self.addresses.removeAll()
            self.addressTableView.reloadData()
            loadAddresses(self.descriptor!)
        }
        present(vc, animated: true)
    }
}

/// One derived address (tag 1).
private final class DerivedAddressCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let label = UILabel()
        label.tag = 1
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            label.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Theme

extension ImportXpubViewController {
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: .create)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        WalletTheme.styleHeader(view, tint: .create)
    }
}
