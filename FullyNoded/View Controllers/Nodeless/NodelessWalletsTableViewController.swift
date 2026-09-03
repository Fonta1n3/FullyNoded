//
//  NodelessWalletsTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/23/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import UIKit

class NodelessWalletsTableViewController: UITableViewController {
    
    var wallets: [Wallet] = []
    var wallet: Wallet?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.register(WalletCell.self, forCellReuseIdentifier: WalletCell.reuseIdentifier)
        setupTableHeader()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.wallets.removeAll()
        
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] wallets in
            guard let self = self else { return }
            guard let wallets = wallets else { return }
            self.wallets = wallets.compactMap { Wallet(dictionary: $0) }
            
            CoreDataService.retrieveEntity(entityName: .timelocks) { [weak self] timelocks in
                guard let timelocks = timelocks, timelocks.count > 0 else {
                    self?.reloadData()
                    return
                }
                
                for timelock in timelocks {
                    let timelockStr = Timelock(dictionary: timelock)
                    let dummyWallet = Wallet(dictionary: [
                        "receiveDescriptor": timelockStr.descriptor,
                        "label": "Timelock",
                        "id": timelockStr.id,
                    ])
                    
                    self?.wallets.append(dummyWallet)
                }
                self?.reloadData()
            }
        }
    }
    
    private func reloadData() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return wallets.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: WalletCell.reuseIdentifier, for: indexPath) as! WalletCell
        let wallet = wallets[indexPath.row]
        cell.configure(with: wallet)
        cell.onTapped = { [weak self] in
            self?.wallet = wallet
            self?.goToNodeless()
        }
        return cell
    }
    
    private func goToNodeless() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueFromWalletsToNodeless", sender: self)
        }
    }
    
    private func setupTableHeader() {
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.text = "These are all the wallets you have ever created or imported with Fully Noded. You can go nodeless to send and receive bitcoin from each wallet without a connection to your node."
        titleLabel.numberOfLines = 0
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        titleLabel.textColor = .systemGreen       // cypherpunk green
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -12)
        ])
        
        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        
        let height = headerView.systemLayoutSizeFitting(
            CGSize(width: tableView.bounds.width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        
        headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: height)
        tableView.tableHeaderView = headerView
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let vc = segue.destination as? NodelessTableViewController else { return }
        guard let wallet = wallet else { return }
        vc.primaryDescriptor = wallet.receiveDescriptor
        vc.changeDescriptor = wallet.changeDescriptor
        vc.walletName = wallet.label
    }
}


class WalletCell: UITableViewCell {
    static let reuseIdentifier = "WalletCell"
    var onTapped: (() -> Void)?
        
    private let walletLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        return label
    }()
    
    private let networkLabel: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
    
    private let statusBadge: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
    
    private let expiryBadge: UIButton = {
        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        config.cornerStyle = .medium
        
        let button = UIButton(configuration: config)
        button.isUserInteractionEnabled = false
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
        
    private let typeLabel = makeDetailLabel(color: .secondaryLabel)
    private let formatLabel = makeDetailLabel(color: .secondaryLabel)
    private let policyLabel = makeDetailLabel(color: .secondaryLabel)
    private let fingerprintLabel = makeDetailLabel(color: .secondaryLabel, allowsWrapping: true)
    private let derivationLabel = makeDetailLabel(color: .secondaryLabel)
        
    private let receiveTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .systemCyan
        label.text = "RECEIVE DESCRIPTOR"
        return label
    }()
    
    private let receiveCopyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.tintColor = .systemCyan
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
    
    private let descriptorLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = .systemCyan
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private let statusStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let detailsStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 3
        stack.alignment = .leading
        return stack
    }()
    
    private let receiveHeaderStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        return stack
    }()
    
    private let infoStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 7
        stack.alignment = .leading
        return stack
    }()
    
    private let nodelessButton: UIButton = {
        var config = UIButton.Configuration.tinted()
        config.title = "Go Nodeless"
        config.baseForegroundColor = .tintColor
        config.baseBackgroundColor = UIColor.tintColor.withAlphaComponent(0.50)
        config.cornerStyle = .medium
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 17, weight: .regular)
            return outgoing
        }
        
        let button = UIButton(configuration: config)
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        return button
    }()
        
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemGroupedBackground
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
                        
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        
        // Card background
        let cardView = UIView()
        cardView.backgroundColor = .secondarySystemGroupedBackground
        cardView.layer.cornerRadius = 12
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        
        // Build stacks
        statusStack.addArrangedSubview(statusBadge)
        statusStack.addArrangedSubview(networkLabel)
        statusStack.addArrangedSubview(expiryBadge)
        
        detailsStack.addArrangedSubview(typeLabel)
        detailsStack.addArrangedSubview(formatLabel)
        detailsStack.addArrangedSubview(policyLabel)
        detailsStack.addArrangedSubview(fingerprintLabel)
        detailsStack.addArrangedSubview(derivationLabel)
        
        receiveHeaderStack.addArrangedSubview(receiveTitleLabel)
        receiveHeaderStack.addArrangedSubview(receiveCopyButton)
        receiveHeaderStack.addArrangedSubview(UIView())
        
        // Main vertical stack – everything full width
        infoStack.addArrangedSubview(walletLabel)
        infoStack.addArrangedSubview(statusStack)
        infoStack.addArrangedSubview(detailsStack)
        infoStack.addArrangedSubview(receiveHeaderStack)
        infoStack.addArrangedSubview(descriptorLabel)
        
        cardView.addSubview(infoStack)
        cardView.addSubview(nodelessButton)
        
        cardView.translatesAutoresizingMaskIntoConstraints = false
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        nodelessButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Card with spacing between cells
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Info stack fills the entire card
            infoStack.topAnchor.constraint(equalTo: cardView.layoutMarginsGuide.topAnchor),
            infoStack.bottomAnchor.constraint(equalTo: cardView.layoutMarginsGuide.bottomAnchor),
            infoStack.leadingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.leadingAnchor),
            infoStack.trailingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.trailingAnchor),
            
            // Only the wallet name leaves room for the button
            walletLabel.trailingAnchor.constraint(lessThanOrEqualTo: nodelessButton.leadingAnchor, constant: -12),
            
            // Nodeless button – forced to top right
            nodelessButton.topAnchor.constraint(equalTo: cardView.layoutMarginsGuide.topAnchor),
            nodelessButton.trailingAnchor.constraint(equalTo: cardView.layoutMarginsGuide.trailingAnchor),
            
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        
        nodelessButton.addTarget(self, action: #selector(goNodeless), for: .touchUpInside)
        receiveCopyButton.addTarget(self, action: #selector(copyReceiveDescriptor), for: .touchUpInside)
    }
    
    // MARK: - Configure
    
    func configure(with wallet: Wallet) {
        walletLabel.text = wallet.label
        descriptorLabel.text = wallet.receiveDescriptor
        
        let parsed = Descriptor(wallet.receiveDescriptor)
                
        if parsed.isMulti {
            policyLabel.text = "POLICY  \(parsed.mOfNType)"
        } else {
            policyLabel.text = "POLICY  Single Sig"
        }
        
        if parsed.isTimelocked {
            var expiryConfig = expiryBadge.configuration ?? .plain()
            expiryConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .systemFont(ofSize: 11, weight: .bold)
                return outgoing
            }
            expiryConfig.title = "Timelocked until \(parsed.expiry)"
            expiryConfig.baseForegroundColor = .systemPink
            expiryConfig.background.backgroundColor = UIColor.systemPink.withAlphaComponent(0.18)
            expiryBadge.configuration = expiryConfig
            expiryBadge.alpha = 1
            //nodelessButton.alpha = 0
        } else {
            //nodelessButton.alpha = 1
            expiryBadge.alpha = 0
        }
        
        fingerprintLabel.text = "FINGERPRINT  \(parsed.fingerprint)"
        derivationLabel.text = "DERIVATION  \(parsed.derivation)"
        
        // Hot / Watch-only badge
        var config = statusBadge.configuration ?? .plain()
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 11, weight: .bold)
            return outgoing
        }

        if parsed.isHot {
            config.title = "HOT"
            config.baseForegroundColor = .systemRed
            config.background.backgroundColor = UIColor.systemRed.withAlphaComponent(0.18)
        } else {
            config.title = "WATCH-ONLY"
            config.baseForegroundColor = .systemBlue
            config.background.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
        }

        statusBadge.configuration = config
        
        switch parsed.format {
        case "P2TR": typeLabel.text = "TAPROOT"
        case "P2WSH", "P2WPKH": typeLabel.text = "NATIVE SEGWIT"
        case "P2SH-P2WPKH", "P2SH-P2WSH": typeLabel.text = "NESTED SEGWIT"
        case "P2PK": typeLabel.text = "PUBLIC KEY"
        case "P2PKH", "P2SH": typeLabel.text = "LEGACY"
        default:
            break
        }
        
        typeLabel.text? += " - \(parsed.format)"
        
        var networkConfig = networkLabel.configuration ?? .plain()
        networkConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 11, weight: .bold)
            return outgoing
        }

        switch parsed.chain {
        case "Mainnet":
            networkConfig.title = "MAINNET"
            networkConfig.baseForegroundColor = .systemOrange
            networkConfig.background.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
        case "Testnet":
            networkConfig.title = "TESTNET"
            networkConfig.baseForegroundColor = .systemGreen
            networkConfig.background.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.18)
        case "Signet":
            networkConfig.title = "SIGNET"
            networkConfig.baseForegroundColor = .systemPurple
            networkConfig.background.backgroundColor = UIColor.systemPurple.withAlphaComponent(0.18)
        case "Regtest":
            networkConfig.title = "REGTEST"
            networkConfig.baseForegroundColor = .systemBlue
            networkConfig.background.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
        default:
            networkConfig.title = parsed.chain.uppercased()
            networkConfig.baseForegroundColor = .systemGray
            networkConfig.background.backgroundColor = UIColor.systemGray.withAlphaComponent(0.18)
        }

        networkLabel.configuration = networkConfig
        
        
    }
        
    @objc private func goNodeless() {
        onTapped?()
    }
    
    @objc private func copyReceiveDescriptor() {
        UIPasteboard.general.string = descriptorLabel.text
        showAlert(title: "Copied ✓", message: "")
    }
    
    // MARK: - Helpers
    
    private static func makeDetailLabel(color: UIColor, allowsWrapping: Bool = false) -> UILabel {
        let label = UILabel()
        label.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
        label.textColor = color
        label.numberOfLines = allowsWrapping ? 0 : 1
        label.lineBreakMode = allowsWrapping ? .byWordWrapping : .byTruncatingTail
        return label
    }
}
