//
//  WalletSwitcherViewController.swift
//  FullyNoded
//
//  Created by Peter on 29/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//
//  Your Fully Noded wallets, built in code: pick the active one, and see what they hold together.
//  The list comes from what's saved (label and descriptor), so it opens at once and picking a
//  wallet never waits on the node. Balances are only fetched when asked (Check balances), then
//  remembered with the time they were checked (WalletBalanceCache), which the wallet screen also
//  keeps fresh for the active wallet.
//

import UIKit

/// The last known balance of each wallet (by node wallet name), with when it was checked.
enum WalletBalanceCache {
    struct Entry {
        let total: Double
        let locked: Double
        let checked: Date
    }

    private static let key = "walletBalanceCache"

    static func entry(for name: String) -> Entry? {
        guard let all = UserDefaults.standard.dictionary(forKey: key),
              let item = all[name] as? [String: Any],
              let total = item["total"] as? Double,
              let checked = item["checked"] as? Double else { return nil }
        return Entry(total: total, locked: item["locked"] as? Double ?? 0, checked: Date(timeIntervalSince1970: checked))
    }

    static func store(name: String, total: Double, locked: Double) {
        var all = UserDefaults.standard.dictionary(forKey: key) ?? [:]
        all[name] = ["total": total, "locked": locked, "checked": Date().timeIntervalSince1970]
        UserDefaults.standard.set(all, forKey: key)
    }

    /// "14:02", "yesterday", "3 days ago".
    static func age(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

final class WalletSwitcherViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    private enum Row {
        case wallet(Wallet)
        case external(Int)
    }

    private let tint: WalletTheme.Tint = .wallet
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private var sections: [(title: String, rows: [Row])] = []
    private var saved: [Wallet] = []
    /// Wallets the node has (nil until it answers, or if it can't be reached).
    private var onNode: Set<String>?
    private var activeName = UserDefaults.standard.string(forKey: "walletName") ?? ""

    // Total balance card.
    private let totalLabel = UILabel()
    private let fiatLabel = UILabel()
    private let checkedLabel = UILabel()
    private let checkButton = UIButton(type: .system)
    private var checking = false

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "Your Wallets"

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 64
        tableView.sectionFooterHeight = 0
        tableView.register(ThemedRowCell.self, forCellReuseIdentifier: ThemedRowCell.reuseId)
        tableView.tableHeaderView = totalCard()
        tableView.tableFooterView = footer()
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        WalletTheme.apply(to: self, tint: tint)
        loadWallets()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Back from a wallet's details (renamed or deleted) or from the external wallets.
        if !saved.isEmpty { loadWallets() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fit(tableView.tableHeaderView) { tableView.tableHeaderView = $0 }
        fit(tableView.tableFooterView) { tableView.tableFooterView = $0 }
    }

    // MARK: - Loading

    /// Saved wallets first (instant), then one listwalletdir call to tell which the node has.
    private func loadWallets() {
        CoreDataService.retrieveEntity(entityName: .wallets) { [weak self] dicts in
            let saved = (dicts ?? []).filter { $0["id"] != nil }.map { Wallet(dictionary: $0) }
                .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.saved = saved
                self.activeName = UserDefaults.standard.string(forKey: "walletName") ?? ""
                self.rebuild()
            }
            OnchainUtils.listWalletDir { (walletDir, _) in
                guard let names = walletDir?.wallets else { return }
                DispatchQueue.main.async {
                    self?.onNode = Set(names)
                    self?.rebuild()
                }
            }
        }
    }

    private var listed: [Wallet] {
        guard let onNode = onNode else { return saved }
        return saved.filter { onNode.contains($0.name) }
    }

    private var external: [Wallet] {
        guard let onNode = onNode else { return [] }
        return saved.filter { !onNode.contains($0.name) }
    }

    private func rebuild() {
        var sections: [(String, [Row])] = []
        if !listed.isEmpty {
            sections.append((onNode == nil ? "> SAVED WALLETS" : "> ON YOUR NODE", listed.map { .wallet($0) }))
        }
        if !external.isEmpty {
            sections.append(("> NOT ON THIS NODE", [.external(external.count)]))
        }
        self.sections = sections.map { (title: $0.0, rows: $0.1) }
        tableView.reloadData()
        updateTotal()
        tableView.backgroundView = saved.isEmpty ? emptyView() : nil
        tableView.tableHeaderView?.isHidden = saved.isEmpty
    }

    // MARK: - Balances

    /// Fetches each listed wallet's balance by name (never changing the active wallet), updating
    /// its row and the total as each answer arrives.
    @objc private func checkBalances() {
        guard !checking, !listed.isEmpty else { return }
        impact()
        checking = true
        let wallets = listed
        var done = 0
        var failed = 0
        updateCheckButton(progress: (0, wallets.count))
        let group = DispatchGroup()
        for wallet in wallets {
            group.enter()
            OnchainUtils.getBalanceBreakdown(walletName: wallet.name) { [weak self] (total, locked, _) in
                DispatchQueue.main.async {
                    defer { group.leave() }
                    done += 1
                    if let total = total {
                        WalletBalanceCache.store(name: wallet.name, total: total, locked: locked)
                    } else {
                        failed += 1
                    }
                    guard let self = self else { return }
                    self.updateCheckButton(progress: (done, wallets.count))
                    self.reloadRow(of: wallet)
                    self.updateTotal()
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.checking = false
            self.updateCheckButton(progress: nil)
            self.updateTotal()
            if failed > 0 {
                showAlert(vc: self, title: "Some balances didn't load",
                          message: "\(failed) of \(wallets.count) wallets didn't answer (they may not be loaded on your node). Their last known balance is shown.",
                          kind: .notice)
            }
        }
    }

    private func reloadRow(of wallet: Wallet) {
        for (s, section) in sections.enumerated() {
            for (r, row) in section.rows.enumerated() {
                if case .wallet(let w) = row, w.id == wallet.id {
                    tableView.reloadRows(at: [IndexPath(row: r, section: s)], with: .none)
                }
            }
        }
    }

    /// The total of the last known balances; "—" until one has been checked.
    private func updateTotal() {
        let entries = listed.compactMap { WalletBalanceCache.entry(for: $0.name) }
        guard !entries.isEmpty else {
            totalLabel.text = "—"
            fiatLabel.text = "Balances aren't loaded until you ask."
            checkedLabel.text = "\(listed.count) wallet\(listed.count == 1 ? "" : "s")"
            updateCheckButton(progress: nil)
            return
        }
        let total = entries.reduce(0) { $0 + $1.total }
        let locked = entries.reduce(0) { $0 + $1.locked }
        totalLabel.text = "\(total.avoidNotation) btc"
        if let rate = UserDefaults.standard.object(forKey: "fxRate") as? Double {
            fiatLabel.text = (total * rate).fiatString + (locked > 0 ? " · \(locked.avoidNotation) btc timelocked" : "")
        } else {
            fiatLabel.text = locked > 0 ? "\(locked.avoidNotation) btc timelocked" : ""
        }
        let oldest = entries.map(\.checked).min()!
        let missing = listed.count - entries.count
        checkedLabel.text = "\(entries.count) of \(listed.count) wallet\(listed.count == 1 ? "" : "s") · as of \(WalletBalanceCache.age(oldest))"
            + (missing > 0 ? " · \(missing) not checked" : "")
        updateCheckButton(progress: nil)
    }

    private func updateCheckButton(progress: (Int, Int)?) {
        let title: String
        if let (done, count) = progress {
            title = "Checking \(done) of \(count)…"
        } else {
            title = listed.contains(where: { WalletBalanceCache.entry(for: $0.name) != nil }) ? "Refresh balances" : "Check balances"
        }
        checkButton.configuration = WalletTheme.buttonConfiguration(title: title, systemImage: "arrow.clockwise", filled: false, tint: tint)
        checkButton.isEnabled = progress == nil && !listed.isEmpty
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ThemedRowCell.reuseId, for: indexPath) as! ThemedRowCell
        switch sections[indexPath.section].rows[indexPath.row] {
        case .wallet(let wallet):
            let descriptor = Descriptor(wallet.receiveDescriptor)
            let active = wallet.name == activeName
            var lines = [Self.summary(of: descriptor)]
            if let balance = WalletBalanceCache.entry(for: wallet.name) {
                lines.append("\(balance.total.avoidNotation) btc · \(WalletBalanceCache.age(balance.checked))")
            }
            cell.configure(icon: descriptor.isMulti ? "person.2" : "square.stack.3d.up",
                           title: wallet.label,
                           subtitle: lines.joined(separator: "\n"),
                           value: active ? "ACTIVE" : nil,
                           tint: tint,
                           trailingSymbol: active ? "checkmark.circle.fill" : "circle",
                           trailingHighlighted: active)
        case .external(let count):
            cell.configure(icon: "externaldrive.badge.questionmark",
                           title: "\(count) wallet\(count == 1 ? "" : "s") not on this node",
                           subtitle: "Saved in Fully Noded but missing from this node: recover or delete them",
                           tint: tint)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let caption = WalletTheme.caption(sections[section].title, tint: tint)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 2),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        40
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        WalletTheme.styleCell(cell, in: tableView, tint: tint)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section].rows[indexPath.row] {
        case .wallet(let wallet):
            select(wallet)
        case .external:
            impact()
            let vc = ExternalFNWalletsViewController()
            vc.externalWallets = external
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .wallet(let wallet) = sections[indexPath.section].rows[indexPath.row] else { return nil }
        let details = UIContextualAction(style: .normal, title: "Details") { [weak self] _, _, done in
            self?.showDetails(wallet)
            done(true)
        }
        details.backgroundColor = tint.accent.withAlphaComponent(0.5)
        return UISwipeActionsConfiguration(actions: [details])
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard case .wallet(let wallet) = sections[indexPath.section].rows[indexPath.row] else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            var actions = [UIAction(title: "Details", image: UIImage(systemName: "info.circle")) { _ in self?.showDetails(wallet) }]
            if wallet.name != self?.activeName {
                actions.insert(UIAction(title: "Make active", image: UIImage(systemName: "checkmark.circle")) { _ in self?.select(wallet) }, at: 0)
            }
            return UIMenu(children: actions)
        }
    }

    // MARK: - Actions

    /// Makes `wallet` active, then returns to the wallet screen (which refreshes with it).
    private func select(_ wallet: Wallet) {
        guard wallet.name != activeName else {
            navigationController?.popViewController(animated: true)
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
        activeName = wallet.name
        UserDefaults.standard.set(wallet.name, forKey: "walletName")
        tableView.reloadData()
        NotificationCenter.default.post(name: .refreshWallet, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }

    private func showDetails(_ wallet: Wallet) {
        let vc = WalletDetailViewController()
        vc.walletId = wallet.id
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - Views

    /// "Taproot · single-sig · Mainnet", from the saved descriptor.
    private static func summary(of descriptor: Descriptor) -> String {
        let kind = descriptor.isMulti ? descriptor.mOfNType : "single-sig"
        return [descriptor.scriptType, kind, descriptor.chain].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func totalCard() -> UIView {
        totalLabel.font = WalletTheme.mono(26, weight: .bold)
        totalLabel.textColor = tint.accent
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.6
        fiatLabel.font = WalletTheme.mono(12, weight: .semibold)
        fiatLabel.textColor = WalletTheme.text
        fiatLabel.numberOfLines = 0
        checkedLabel.font = WalletTheme.mono(10)
        checkedLabel.textColor = WalletTheme.dim
        checkedLabel.numberOfLines = 0
        checkButton.addTarget(self, action: #selector(checkBalances), for: .touchUpInside)
        updateCheckButton(progress: nil)

        let card = WalletTheme.cardView([WalletTheme.caption("> TOTAL BALANCE", tint: tint), totalLabel, fiatLabel, checkedLabel, checkButton],
                                        tint: tint, spacing: 8, background: tint.accent.withAlphaComponent(0.05))
        card.layer.borderColor = tint.accent.withAlphaComponent(0.6).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4)
        ])
        return container
    }

    private func footer() -> UIView {
        let label = UILabel()
        label.text = "Tap a wallet to make it active. Swipe or long-press it for its details."
        label.font = WalletTheme.mono(10)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -24),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -24)
        ])
        return container
    }

    private func emptyView() -> UIView {
        let label = UILabel()
        label.text = "No Fully Noded wallets yet.\nCreate or import one with the + on the wallet screen."
        label.font = WalletTheme.mono(12)
        label.textColor = WalletTheme.dim
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    /// Table header / footer views size to their content at the table's width.
    private func fit(_ view: UIView?, set: (UIView) -> Void) {
        guard let view = view, tableView.bounds.width > 0 else { return }
        let height = view.systemLayoutSizeFitting(CGSize(width: tableView.bounds.width, height: 0),
                                                  withHorizontalFittingPriority: .required,
                                                  verticalFittingPriority: .fittingSizeLevel).height
        guard abs(view.frame.height - height) > 0.5 || view.frame.width != tableView.bounds.width else { return }
        view.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: height)
        set(view)
    }
}
