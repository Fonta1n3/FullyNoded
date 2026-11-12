//
//  ExplorerCoinsViewController.swift
//  FullyNoded
//
//  The active wallet's coins, by the block each one was created in. A half-height sheet that stays
//  open with the explorer's block strip visible above it: tap a block to skip the strip there, or
//  a coin to trace it.
//

import UIKit

final class ExplorerCoinsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let service: BlockExplorerService
    private let tint: WalletTheme.Tint
    /// The height the strip is showing, to mark it here.
    private var current: Int?
    private let pruneHeight: () -> Int?
    private let onBlock: (Int) -> Void
    private let onCoin: (ExplorerCoinBlock.Coin, Int) -> Void

    private let table = UITableView(frame: .zero, style: .grouped)
    private let messageLabel = UILabel()
    private var blocks: [ExplorerCoinBlock] = []

    init(service: BlockExplorerService, tint: WalletTheme.Tint, current: Int?, pruneHeight: @escaping () -> Int?,
         onBlock: @escaping (Int) -> Void, onCoin: @escaping (ExplorerCoinBlock.Coin, Int) -> Void) {
        self.service = service
        self.tint = tint
        self.current = current
        self.pruneHeight = pruneHeight
        self.onBlock = onBlock
        self.onCoin = onCoin
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your coins"
        WalletTheme.apply(to: self, tint: tint)
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.register(ExplorerCoinCell.self, forCellReuseIdentifier: ExplorerCoinCell.reuseId)
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        messageLabel.font = WalletTheme.mono(13)
        messageLabel.textColor = WalletTheme.dim
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.text = "Loading your coins…"
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.topAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            messageLabel.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        service.walletCoins { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let error):
                self.messageLabel.text = error.message
            case .success(let blocks):
                self.blocks = blocks
                self.messageLabel.isHidden = !blocks.isEmpty
                self.messageLabel.text = "This wallet has no coins yet."
                self.table.reloadData()
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int { blocks.count }

    /// The block, then each coin in it.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { blocks[section].coins.count + 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerCoinCell.reuseId, for: indexPath) as! ExplorerCoinCell
        let block = blocks[indexPath.section]
        if indexPath.row == 0 {
            let count = "\(block.coins.count) coin\(block.coins.count == 1 ? "" : "s")"
            var detail = "\(count) · \(block.totalBtc.btcBalanceWithSpaces) BTC"
            if let fiat = ExplorerFormat.fiatCompact(btc: block.totalBtc) { detail += " \(fiat)" }
            if let confirmations = block.coins.first?.confirmations, confirmations > 0 {
                detail += " · \(confirmations.withCommas) conf\(confirmations == 1 ? "" : "s")"
            }
            let isPruned = block.height.map { $0 < (pruneHeight() ?? 0) } ?? false
            if isPruned { detail += " · PRUNED" }
            let title = block.height.map { "BLOCK \($0.withCommas)" } ?? "UNCONFIRMED"
            cell.configure(title: title, detail: detail, isBlock: true, isCurrent: block.height == current && current != nil, tint: tint)
        } else {
            let coin = block.coins[indexPath.row - 1]
            let shortTxid = "\(coin.txid.prefix(8))…\(coin.txid.suffix(8)):\(coin.vout)"
            let detail = coin.label.map { "\($0) · \(shortTxid)" } ?? shortTxid
            let fiat = ExplorerFormat.fiat(btc: coin.amountBtc).map { "  \($0)" } ?? ""
            cell.configure(title: "\(coin.amountBtc.btcBalanceWithSpaces) BTC\(fiat)", detail: detail, isBlock: false, isCurrent: false, tint: tint)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        impact()
        let block = blocks[indexPath.section]
        // Unconfirmed coins are headed for the next block.
        let height = block.height ?? service.nextBlockHeight
        if indexPath.row == 0 {
            guard let height = height else { return }
            current = block.height
            onBlock(height)
            tableView.reloadData()
        } else if let height = height {
            let coin = block.coins[indexPath.row - 1]
            dismiss(animated: true) { [onCoin] in onCoin(coin, height) }
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { section == 0 ? 8 : 4 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 4 }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

private final class ExplorerCoinCell: UITableViewCell {
    static let reuseId = "ExplorerCoinCell"

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let icon = UIImageView()
    private var leading: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        detailLabel.font = WalletTheme.mono(11)
        detailLabel.textColor = WalletTheme.dim
        detailLabel.numberOfLines = 0
        titleLabel.numberOfLines = 0
        icon.contentMode = .scaleAspectFit
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 2
        let row = UIStackView(arrangedSubviews: [text, icon])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        let leading = row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        self.leading = leading
        NSLayoutConstraint.activate([
            leading,
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, detail: String, isBlock: Bool, isCurrent: Bool, tint: WalletTheme.Tint) {
        titleLabel.text = title
        titleLabel.font = isBlock ? WalletTheme.mono(13, weight: .bold) : WalletTheme.mono(13)
        titleLabel.textColor = isBlock ? tint.accent : WalletTheme.text
        detailLabel.text = detail
        // Coins sit under their block.
        leading?.constant = isBlock ? 16 : 32
        icon.image = UIImage(systemName: isBlock ? (isCurrent ? "checkmark" : "cube") : "chevron.right")
        icon.tintColor = isBlock ? tint.accent : WalletTheme.dim
        accessibilityLabel = "\(title), \(detail)" + (isCurrent ? ", showing" : "")
        accessibilityTraits = .button
        isAccessibilityElement = true
    }
}
