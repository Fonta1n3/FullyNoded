//
//  PeersDetailTableViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/11/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//
//  The node's peers: a summary with the raw getpeerinfo response, a filter, and a row per peer
//  that opens everything known about it (PeerDetailViewController), where it can be banned.
//

import UIKit

class PeersDetailTableViewController: UITableViewController {
    // Pushed full height, without the tab bar.
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    private enum Section: Int, CaseIterable { case summary, peers }
    private enum Filter: Int { case all, outbound, inbound }

    private let tint = WalletTheme.Tint.peers
    private var filter = Filter.all
    private var rows: [PeerInfo] = []
    private var isRefreshing = false

    var peerResponse: GetPeerInfoResponse!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Peers"
        tableView.register(PeerSummaryCell.self, forCellReuseIdentifier: PeerSummaryCell.identifier)
        tableView.register(PeerCell.self, forCellReuseIdentifier: PeerCell.identifier)
        tableView.register(PeerEmptyCell.self, forCellReuseIdentifier: PeerEmptyCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 110
        tableView.separatorStyle = .none
        let refresh = UIRefreshControl()
        refresh.tintColor = tint.accent
        refresh.addTarget(self, action: #selector(refreshTapped), for: .valueChanged)
        refreshControl = refresh
        showRefreshButton()
        WalletTheme.apply(to: self, tint: tint)
        updateRows()
    }

    /// Outbound first (the peers this node chose), then the longest connected.
    private func updateRows() {
        rows = peerResponse.peers
            .filter { peer in
                switch filter {
                case .all: return true
                case .outbound: return !peer.inbound
                case .inbound: return peer.inbound
                }
            }
            .sorted {
                if $0.inbound != $1.inbound { return !$0.inbound }
                return ($0.connectedAt ?? .max) < ($1.connectedAt ?? .max)
            }
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .summary ? 1 : max(rows.count, 1)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if Section(rawValue: indexPath.section) == .summary {
            let cell = tableView.dequeueReusableCell(withIdentifier: PeerSummaryCell.identifier, for: indexPath) as! PeerSummaryCell
            cell.configure(with: peerResponse, filter: filter.rawValue, tint: tint)
            cell.onFilter = { [weak self] index in
                guard let self = self else { return }
                self.filter = Filter(rawValue: index) ?? .all
                self.updateRows()
                self.tableView.reloadSections(IndexSet(integer: Section.peers.rawValue), with: .none)
            }
            cell.onRaw = { [weak self] in
                guard let self = self else { return }
                self.showRawResponse(["peerInfo": self.peerResponse.rawData], title: "getpeerinfo")
            }
            return cell
        }
        guard !rows.isEmpty else {
            let cell = tableView.dequeueReusableCell(withIdentifier: PeerEmptyCell.identifier, for: indexPath) as! PeerEmptyCell
            cell.configure(text: peerResponse.peers.isEmpty ? "No peers connected" : "No peers match this filter")
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: PeerCell.identifier, for: indexPath) as! PeerCell
        cell.configure(with: rows[indexPath.row], tint: tint)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .peers, indexPath.row < rows.count else { return }
        impact()
        let peer = rows[indexPath.row]
        let raw = peerResponse.rawData.first { peer.id != nil && RPCValue.int($0["id"]) == peer.id }
        let vc = PeerDetailViewController(peer: peer, raw: raw)
        vc.onBanned = { [weak self] in self?.refreshTapped() }
        navigationController?.pushViewController(vc, animated: true)
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .summary ? 12 : 10
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        UIView()
    }

    // MARK: - Refresh

    private func showRefreshButton() {
        let button = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refreshTapped))
        button.accessibilityLabel = "Refresh peers"
        navigationItem.rightBarButtonItem = button
    }

    @objc private func refreshTapped() {
        guard !isRefreshing else { return }
        isRefreshing = true
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = tint.accent
        spinner.startAnimating()
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: spinner)

        NodeLogic.sharedInstance.getPeerInfo { [weak self] (response, errorMessage) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isRefreshing = false
                self.refreshControl?.endRefreshing()
                self.showRefreshButton()
                guard let response = response else {
                    showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                    return
                }
                self.peerResponse = response
                self.updateRows()
                self.tableView.reloadData()
            }
        }
    }
}

/// Everything getpeerinfo says about one peer, its raw entry, and banning it.
final class PeerDetailViewController: UIViewController {
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    var onBanned: (() -> Void)?

    private let peer: PeerInfo
    private let raw: [String: Any]?
    private let tint = WalletTheme.Tint.peers

    init(peer: PeerInfo, raw: [String: Any]?) {
        self.peer = peer
        self.raw = raw
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Peer"
        WalletTheme.apply(to: self, tint: tint)
        buildLayout()
    }

    private func buildLayout() {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(headerCard())
        stack.setCustomSpacing(16, after: stack.arrangedSubviews[0])

        let now = Date()
        addSection("CONNECTION", to: stack, rows: [
            ("Direction", peer.inbound ? "Inbound" : "Outbound"),
            ("Type", peer.connectionName),
            ("Network", peer.networkName),
            ("Transport", peer.transportName),
            ("Connected", PeerFormat.ago(peer.connectedAt, now: now)),
            ("Our address", peer.addrBind),
            ("Seen as", peer.addrLocal)
        ])
        addSection("RESPONSIVENESS", to: stack, rows: [
            ("Ping", PeerFormat.ping(peer.ping)),
            ("Best ping", PeerFormat.ping(peer.minPing)),
            ("Waiting", PeerFormat.ping(peer.pingWait)),
            ("Last sent", PeerFormat.ago(peer.lastSend, now: now, zero: "never")),
            ("Last received", PeerFormat.ago(peer.lastReceive, now: now, zero: "never"))
        ])
        addSection("TRAFFIC", to: stack, rows: [
            ("Received", PeerFormat.bytes(peer.bytesReceived)),
            ("Sent", PeerFormat.bytes(peer.bytesSent)),
            ("Last block", PeerFormat.ago(peer.lastBlock, now: now, zero: "never")),
            ("Last tx", PeerFormat.ago(peer.lastTransaction, now: now, zero: "never"))
        ])
        addSection("CHAIN", to: stack, rows: [
            ("Start height", peer.startingHeight.map { $0.withCommas }),
            ("Headers", PeerFormat.height(peer.syncedHeaders)),
            ("Blocks", PeerFormat.height(peer.syncedBlocks))
        ])
        addSection("CAPABILITIES", to: stack, rows: [
            ("Protocol", peer.version > 0 ? "\(peer.version)" : nil),
            ("Services", peer.services.isEmpty ? nil : peer.services.joined(separator: "\n").lowercased()),
            ("Relays txs", PeerFormat.yesNo(peer.relaysTransactions)),
            ("Relays addrs", PeerFormat.yesNo(peer.relaysAddresses)),
            ("Compact to", PeerFormat.yesNo(peer.highBandwidthTo)),
            ("Compact from", PeerFormat.yesNo(peer.highBandwidthFrom)),
            ("Min fee", peer.minFeeFilter.map { "\(($0 * 100_000).avoidNotation) sat/vB" }),
            ("Permissions", peer.permissions.isEmpty ? nil : peer.permissions.joined(separator: ", "))
        ])

        if raw != nil {
            let rawButton = UIButton(type: .system)
            rawButton.configuration = WalletTheme.buttonConfiguration(title: "Raw response", systemImage: "curlybraces", filled: false, tint: tint)
            rawButton.addTarget(self, action: #selector(rawTapped), for: .touchUpInside)
            stack.addArrangedSubview(rawButton)
        }
        stack.addArrangedSubview(banControl())

        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)
        ])
    }

    private func headerCard() -> UIView {
        let name = UILabel()
        name.text = peer.clientName
        name.font = WalletTheme.mono(18, weight: .bold)
        name.textColor = tint.accent
        name.numberOfLines = 0

        let address = UILabel()
        address.text = peer.addr
        address.font = WalletTheme.mono(13)
        address.textColor = WalletTheme.text
        address.numberOfLines = 0
        address.lineBreakMode = .byCharWrapping

        let copy = UIButton(type: .system)
        copy.configuration = WalletTheme.chipConfiguration(title: "Copy address", systemImage: "doc.on.doc", tint: tint, fontSize: 12, imageSize: 11,
                                                           imagePadding: 6, insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        copy.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)

        return WalletTheme.cardView([name, address, PeerBadge.row(for: peer, tint: tint), UIStackView(arrangedSubviews: [copy, UIView()])], tint: tint)
    }

    /// A captioned card of the rows that have a value; nothing at all if none do.
    private func addSection(_ title: String, to stack: UIStackView, rows: [(String, String?)]) {
        let present = rows.compactMap { row in row.1.map { (row.0, $0) } }
        guard !present.isEmpty else { return }
        stack.addArrangedSubview(WalletTheme.caption("> \(title)", tint: tint))
        let card = WalletTheme.cardView(present.map { detailRow($0.0, $0.1) }, tint: tint, spacing: 8)
        stack.addArrangedSubview(card)
        stack.setCustomSpacing(16, after: card)
    }

    private func detailRow(_ title: String, _ value: String) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title.uppercased()
        titleLabel.font = WalletTheme.mono(10, weight: .bold)
        titleLabel.textColor = WalletTheme.dim
        titleLabel.widthAnchor.constraint(equalToConstant: 104).isActive = true
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = WalletTheme.mono(13)
        valueLabel.textColor = WalletTheme.text
        valueLabel.numberOfLines = 0
        valueLabel.lineBreakMode = .byCharWrapping
        let row = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        row.spacing = 10
        row.alignment = .firstBaseline
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(title): \(value)"
        return row
    }

    private func banControl() -> UIView {
        guard !peer.isLocalAddress else {
            let note = UILabel()
            note.text = "This peer connects through a local proxy (usually Tor), so it can't be banned by address: that would ban every peer using the proxy."
            note.font = WalletTheme.mono(11)
            note.textColor = WalletTheme.dim
            note.numberOfLines = 0
            return note
        }
        let ban = UIButton(type: .system)
        ban.configuration = WalletTheme.buttonConfiguration(title: "Ban peer", systemImage: "hand.raised", filled: false, tint: .danger)
        ban.addTarget(self, action: #selector(banTapped), for: .touchUpInside)
        return ban
    }

    // MARK: - Actions

    @objc private func rawTapped() {
        guard let raw = raw else { return }
        showRawResponse(raw, title: "getpeerinfo · \(peer.addr)")
    }

    @objc private func copyAddress() {
        UIPasteboard.general.string = peer.addr
        SuccessView.toast("Address copied", in: self)
    }

    @objc private func banTapped() {
        let host = PeerInfo.host(of: peer.addr)
        let alert = UIAlertController(title: "Ban this peer?",
                                      message: "Your node disconnects \(host) and refuses it for about 100 years. You can remove bans with setban in bitcoin-cli.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Ban", style: .destructive) { [weak self] _ in self?.banNow() })
        present(alert, animated: true)
    }

    private func banNow() {
        showActivity("banning peer...")
        let host = PeerInfo.host(of: peer.addr)
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .setban(Set_Ban(dict: ["subnet": peer.addr]))) { [weak self] (_, errorDesc) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hideActivity()
                if let errorDesc = errorDesc {
                    showAlert(vc: self, title: "Couldn't ban this peer", message: errorDesc)
                    return
                }
                SuccessView.show(in: self, title: "Peer banned", subtitle: host) { [weak self] in
                    guard let self = self else { return }
                    self.navigationController?.popViewController(animated: true)
                    // The node drops the connection just after setban answers.
                    let onBanned = self.onBanned
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { onBanned?() }
                }
            }
        }
    }
}

private extension UIViewController {
    func showRawResponse(_ data: [String: Any], title: String) {
        impact()
        let nav = UINavigationController(rootViewController: TextModalViewController(data: data, viewTitle: title))
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }
}

private enum PeerFormat {
    static func ping(_ seconds: Double?) -> String? {
        guard let seconds = seconds else { return nil }
        if seconds < 0.001 { return "<1 ms" }
        return seconds < 1 ? "\(Int((seconds * 1000).rounded())) ms" : String(format: "%.2f s", seconds)
    }

    static func bytes(_ count: Int?) -> String? {
        count.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .binary) }
    }

    /// "3h 12m".
    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds < 60 ? [.second] : [.day, .hour, .minute]
        return formatter.string(from: max(seconds, 0)) ?? ""
    }

    /// "3h 12m ago"; `zero` for Core's 0 (never), or nothing without it.
    static func ago(_ time: Int?, now: Date, zero: String? = nil) -> String? {
        guard let time = time else { return nil }
        guard time > 0 else { return zero }
        return duration(now.timeIntervalSince1970 - TimeInterval(time)) + " ago"
    }

    /// Core reports -1 until it knows.
    static func height(_ height: Int?) -> String? {
        guard let height = height else { return nil }
        return height < 0 ? "unknown" : height.withCommas
    }

    static func yesNo(_ value: Bool?) -> String? {
        value.map { $0 ? "Yes" : "No" }
    }
}

/// Small outlined tag; filled for the peer's direction.
private final class PeerBadge: UILabel {
    init(_ text: String, filled: Bool, tint: WalletTheme.Tint) {
        super.init(frame: .zero)
        self.text = text.uppercased()
        font = WalletTheme.mono(10, weight: .bold)
        textColor = filled ? WalletTheme.bg : tint.accent
        backgroundColor = filled ? tint.accent : .clear
        layer.borderWidth = 1
        layer.borderColor = tint.line.cgColor
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static let padding = UIEdgeInsets(top: 3, left: 6, bottom: 3, right: 6)

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + Self.padding.left + Self.padding.right,
                      height: size.height + Self.padding.top + Self.padding.bottom)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: Self.padding))
    }

    static func row(for peer: PeerInfo, tint: WalletTheme.Tint) -> UIStackView {
        var badges = [PeerBadge(peer.inbound ? "In" : "Out", filled: true, tint: tint),
                      PeerBadge(peer.networkName, filled: false, tint: tint)]
        // Inbound says it all for an inbound peer.
        if !peer.inbound { badges.append(PeerBadge(peer.connectionName, filled: false, tint: tint)) }
        let row = UIStackView(arrangedSubviews: badges + [UIView()])
        row.spacing = 6
        row.alignment = .center
        return row
    }
}

/// Counts, networks, traffic, the filter and the raw response.
private final class PeerSummaryCell: UITableViewCell {
    static let identifier = "PeerSummaryCell"
    var onFilter: ((Int) -> Void)?
    var onRaw: (() -> Void)?

    private let countStack = UIStackView()
    private let detailLabel = UILabel()
    private let filterControl = UISegmentedControl(items: ["All", "Outbound", "Inbound"])
    private let rawButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        countStack.distribution = .fillEqually
        detailLabel.font = WalletTheme.mono(12)
        detailLabel.textColor = WalletTheme.text
        detailLabel.numberOfLines = 0
        filterControl.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        rawButton.addTarget(self, action: #selector(rawTapped), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [countStack, detailLabel, filterControl, rawButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with response: GetPeerInfoResponse, filter: Int, tint: WalletTheme.Tint) {
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        WalletTheme.style(filterControl, tint: tint)
        filterControl.selectedSegmentIndex = filter
        rawButton.configuration = WalletTheme.buttonConfiguration(title: "Raw response", systemImage: "curlybraces", filled: false, tint: tint)

        countStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (value, caption) in [(response.peers.count, "PEERS"), (response.outgoingCount, "OUTBOUND"), (response.incomingCount, "INBOUND")] {
            let number = UILabel()
            number.text = "\(value)"
            number.font = WalletTheme.mono(24, weight: .bold)
            number.textColor = tint.accent
            let label = UILabel()
            label.text = caption
            label.font = WalletTheme.mono(10, weight: .bold)
            label.textColor = WalletTheme.dim
            let column = UIStackView(arrangedSubviews: [number, label])
            column.axis = .vertical
            column.spacing = 2
            column.isAccessibilityElement = true
            column.accessibilityLabel = "\(value) \(caption.lowercased())"
            countStack.addArrangedSubview(column)
        }

        var networks: [String: Int] = [:]
        response.peers.forEach { networks[$0.networkName, default: 0] += 1 }
        var lines = [networks.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { "\($0.key) \($0.value)" }.joined(separator: " · ")]
        if !response.peers.isEmpty {
            let received = response.peers.reduce(0) { $0 + ($1.bytesReceived ?? 0) }
            let sent = response.peers.reduce(0) { $0 + ($1.bytesSent ?? 0) }
            lines.append("↓ \(PeerFormat.bytes(received) ?? "")  ↑ \(PeerFormat.bytes(sent) ?? "")")
        }
        detailLabel.text = lines.filter { !$0.isEmpty }.joined(separator: "\n")
        detailLabel.isHidden = response.peers.isEmpty
    }

    @objc private func filterChanged() {
        onFilter?(filterControl.selectedSegmentIndex)
    }

    @objc private func rawTapped() {
        onRaw?()
    }
}

private final class PeerCell: UITableViewCell {
    static let identifier = "PeerCell"

    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let statsLabel = UILabel()
    private let badgeHolder = UIStackView()
    private var tintValue = WalletTheme.Tint.peers

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        automaticallyUpdatesBackgroundConfiguration = false
        accessoryType = .none
        nameLabel.font = WalletTheme.mono(15, weight: .semibold)
        nameLabel.textColor = WalletTheme.text
        nameLabel.numberOfLines = 0
        addressLabel.font = WalletTheme.mono(12)
        addressLabel.textColor = WalletTheme.dim
        addressLabel.numberOfLines = 0
        addressLabel.lineBreakMode = .byCharWrapping
        statsLabel.font = WalletTheme.mono(11)
        statsLabel.textColor = WalletTheme.dim
        statsLabel.numberOfLines = 0

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        chevron.tintColor = WalletTheme.dim
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let column = UIStackView(arrangedSubviews: [nameLabel, addressLabel, badgeHolder, statsLabel])
        column.axis = .vertical
        column.spacing = 6
        let row = UIStackView(arrangedSubviews: [column, chevron])
        row.spacing = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            row.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with peer: PeerInfo, tint: WalletTheme.Tint) {
        tintValue = tint
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        nameLabel.text = peer.clientName
        addressLabel.text = peer.addr

        badgeHolder.arrangedSubviews.forEach { $0.removeFromSuperview() }
        badgeHolder.addArrangedSubview(PeerBadge.row(for: peer, tint: tint))

        var stats: [String] = []
        if let ping = PeerFormat.ping(peer.ping) { stats.append(ping) }
        if let received = PeerFormat.bytes(peer.bytesReceived), let sent = PeerFormat.bytes(peer.bytesSent) {
            stats.append("↓ \(received) ↑ \(sent)")
        }
        if let connected = peer.connectedAt, connected > 0 {
            stats.append(PeerFormat.duration(Date().timeIntervalSince1970 - TimeInterval(connected)))
        }
        statsLabel.text = stats.joined(separator: " · ")
        statsLabel.isHidden = stats.isEmpty

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(peer.clientName), \(peer.inbound ? "inbound" : "outbound") \(peer.networkName), \(peer.addr)"
    }

    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tintValue, highlighted: highlighted, horizontalInset: 16)
    }
}

private final class PeerEmptyCell: UITableViewCell {
    static let identifier = "PeerEmptyCell"
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        label.font = WalletTheme.mono(13)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        label.text = text
    }
}
