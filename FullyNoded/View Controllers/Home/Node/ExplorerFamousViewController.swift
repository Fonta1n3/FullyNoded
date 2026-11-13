//
//  ExplorerFamousViewController.swift
//  FullyNoded
//
//  The fun part of the chain: coins people have heard of and blocks worth visiting. Half height,
//  with the block strip still live above it. Balances come from scanning your node's whole UTXO
//  set, which works on a pruned node but takes a minute or so, so each one is on request.
//

import UIKit

final class ExplorerFamousViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private enum Section: Int, CaseIterable {
        case coins, blocks
    }

    private let service: BlockExplorerService
    private let tint: WalletTheme.Tint
    private let tipHeight: Int
    private let isMainnet: Bool
    private let onBlock: (Int) -> Void
    private let table = UITableView(frame: .zero, style: .grouped)

    /// By coin title. A node scans one at a time, so only one is ever running.
    private var results: [String: String] = [:]
    private var scanning: String?

    init(service: BlockExplorerService, tint: WalletTheme.Tint, tipHeight: Int, isMainnet: Bool, onBlock: @escaping (Int) -> Void) {
        self.service = service
        self.tint = tint
        self.tipHeight = tipHeight
        self.isMainnet = isMainnet
        self.onBlock = onBlock
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var blocks: [ExplorerFamous.Block] { ExplorerFamous.blocks.filter { $0.height <= tipHeight && (isMainnet || $0.height == 0) } }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Famous"
        WalletTheme.apply(to: self, tint: tint)
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 70
        table.register(ExplorerFamousCell.self, forCellReuseIdentifier: ExplorerFamousCell.reuseId)
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    // Did, not will: starting to drag the sheet down and letting go doesn't close it.
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Nobody's waiting for it any more, and the node has better things to do.
        if scanning != nil {
            service.call(.scantxoutset(Scan_Tx_Out(["action": "abort"]))) { _, _ in }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .coins: return isMainnet ? ExplorerFamous.coins.count : 1
        default: return blocks.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerFamousCell.reuseId, for: indexPath) as! ExplorerFamousCell
        switch Section(rawValue: indexPath.section) {
        case .coins:
            guard isMainnet else {
                cell.configure(title: "Mainnet only", detail: "These coins are on Bitcoin's main network, and this node is on another.", status: nil, icon: nil, tint: tint)
                cell.accessibilityTraits = .staticText
                return cell
            }
            let coin = ExplorerFamous.coins[indexPath.row]
            let status: String
            if scanning == coin.title {
                status = "Scanning your node's UTXO set, about a minute…"
            } else if let result = results[coin.title] {
                status = result
            } else if coin.isLarge && !service.isFastConnection {
                status = "Too many coins to fetch over Tor."
            } else {
                status = "Tap to check the balance"
            }
            cell.configure(title: coin.title, detail: coin.detail, status: status, icon: scanning == coin.title ? "hourglass" : "magnifyingglass", tint: tint)
        default:
            let block = blocks[indexPath.row]
            cell.configure(title: "\(block.height.withCommas) · \(block.title)", detail: block.detail, status: nil, icon: "cube", tint: tint)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .coins:
            guard isMainnet else { return }
            scan(ExplorerFamous.coins[indexPath.row])
        default:
            impact()
            onBlock(blocks[indexPath.row].height)
        }
    }

    private func scan(_ coin: ExplorerFamous.Coin) {
        guard scanning == nil, results[coin.title] == nil, !coin.isLarge || service.isFastConnection else { return }
        impact()
        scanning = coin.title
        table.reloadData()
        service.call(.scantxoutset(Scan_Tx_Out(["action": "start", "scanobjects": [coin.descriptor]]))) { [weak self] response, error in
            guard let self = self else { return }
            self.scanning = nil
            if let scan = (response as? [String: Any]).flatMap({ ExplorerFamous.ScanResult(response: $0) }) {
                self.results[coin.title] = scan.summary + (ExplorerFormat.fiat(btc: scan.btc).map { "\n\($0) today" } ?? "")
            } else {
                // Not remembered, so it can be tried again.
                showAlert(vc: self, title: "Couldn't check that", message: error ?? "Your node didn't answer.")
            }
            self.table.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let title = Section(rawValue: section) == .coins ? "> FAMOUS COINS" : "> FAMOUS BLOCKS"
        let caption = WalletTheme.caption(title, tint: tint)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 34 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 1 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

private final class ExplorerFamousCell: UITableViewCell {
    static let reuseId = "ExplorerFamousCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let statusLabel = UILabel()
    private let iconView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        titleLabel.font = WalletTheme.mono(13, weight: .bold)
        titleLabel.numberOfLines = 0
        detailLabel.font = WalletTheme.mono(11)
        detailLabel.textColor = WalletTheme.dim
        detailLabel.numberOfLines = 0
        statusLabel.font = WalletTheme.mono(12, weight: .semibold)
        statusLabel.textColor = WalletTheme.text
        statusLabel.numberOfLines = 0
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel, statusLabel])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [text, iconView])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String, status: String?, icon: String?, tint: WalletTheme.Tint) {
        titleLabel.text = title
        titleLabel.textColor = tint.accent
        detailLabel.text = detail
        statusLabel.text = status
        statusLabel.isHidden = status == nil
        iconView.image = icon.flatMap { UIImage(systemName: $0) }
        iconView.isHidden = icon == nil
        iconView.tintColor = tint.accent
        accessibilityLabel = [title, detail, status].compactMap { $0 }.joined(separator: ". ")
        accessibilityTraits = .button
    }
}
