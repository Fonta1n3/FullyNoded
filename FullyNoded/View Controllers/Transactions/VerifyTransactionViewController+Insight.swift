//
//  VerifyTransactionViewController+Insight.swift
//  FullyNoded
//
//  A card at the top of the screen: the transaction's flow, will this unconfirmed transaction confirm (and, if the node
//  has dropped it, a way to abandon it), or what a PSBT needs next. Extra information only: if the
//  node can't answer, there's no card and the screen works as it always did.
//

import UIKit

/// A small titled card for the top of a table.
final class WalletInsightCard: UIView {
    private let stack = UIStackView()
    private let privacyStack = UIStackView()
    private let selfTransferStack = UIStackView()
    private let flowStack = UIStackView()
    private var privacyRating: TransactionPrivacyRating?
    private var isPrivacyExpanded = false
    /// Its height changed, so the table needs telling.
    var onResize: (() -> Void)?
    private let tint: WalletTheme.Tint

    init(tint: WalletTheme.Tint) {
        self.tint = tint
        super.init(frame: .zero)
        let card = UIView()
        card.backgroundColor = WalletTheme.card
        card.layer.borderWidth = 1
        card.layer.borderColor = tint.line.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        stack.axis = .vertical
        stack.spacing = 6
        stack.isHidden = true
        privacyStack.axis = .vertical
        privacyStack.spacing = 6
        privacyStack.isHidden = true
        selfTransferStack.axis = .vertical
        selfTransferStack.spacing = 6
        selfTransferStack.isHidden = true
        flowStack.axis = .vertical
        flowStack.spacing = 6
        flowStack.isHidden = true
        let column = UIStackView(arrangedSubviews: [flowStack, selfTransferStack, stack, privacyStack])
        column.axis = .vertical
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(column)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            column.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            column.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            column.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The same picture as the block explorer's: where the money goes, and what it costs.
    func update(flowInputs inputs: [Double?], outputs: [Double], fee: Double?, onSelect: @escaping (ExplorerFlowView.Side) -> Void) {
        flowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        flowStack.isHidden = false
        let title = UILabel()
        title.text = "> FLOW"
        title.font = WalletTheme.mono(11, weight: .bold)
        title.textColor = tint.accent
        let flow = ExplorerFlowView()
        flow.configure(inputs: inputs, outputs: outputs, fee: fee, tint: .explorer)
        flow.heightAnchor.constraint(equalToConstant: 110).isActive = true
        flow.onSelect = onSelect
        flowStack.addArrangedSubview(title)
        flowStack.addArrangedSubview(flow)
    }

    func showSelfTransfer() {
        guard selfTransferStack.isHidden else { return }
        selfTransferStack.isHidden = false
        let title = UILabel()
        title.text = "> " + WalletSelfTransfer.title.uppercased()
        title.font = WalletTheme.mono(11, weight: .bold)
        title.textColor = tint.accent
        let detail = UILabel()
        detail.text = WalletSelfTransfer.detail
        detail.font = WalletTheme.mono(12)
        detail.textColor = WalletTheme.text
        detail.numberOfLines = 0
        selfTransferStack.addArrangedSubview(title)
        selfTransferStack.addArrangedSubview(detail)
    }

    /// The grade always shows. Its reasons open on a tap: on a small phone they'd otherwise push
    /// the Sign buttons off the screen.
    func update(privacy rating: TransactionPrivacyRating) {
        privacyRating = rating
        renderPrivacy()
    }

    private func renderPrivacy() {
        guard let rating = privacyRating else { return }
        privacyStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        privacyStack.isHidden = false
        let color: UIColor
        switch rating.grade {
        case .good: color = tint.accent
        case .fair: color = WalletTheme.pending
        case .poor: color = WalletTheme.danger
        }
        let toggle = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.contentInsets = .zero
        config.imagePlacement = .trailing
        config.imagePadding = 6
        config.image = UIImage(systemName: isPrivacyExpanded ? "chevron.up" : "chevron.down",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold))
        config.baseForegroundColor = color
        config.attributedTitle = AttributedString("> PRIVACY · \(rating.grade.rawValue) · \(rating.score)/100",
                                                  attributes: AttributeContainer([.font: WalletTheme.mono(11, weight: .bold), .foregroundColor: color]))
        toggle.configuration = config
        toggle.contentHorizontalAlignment = .leading
        toggle.accessibilityHint = isPrivacyExpanded ? "Hides the reasons" : "Shows the reasons"
        toggle.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.isPrivacyExpanded.toggle()
            self.renderPrivacy()
            self.onResize?()
        }, for: .touchUpInside)
        privacyStack.addArrangedSubview(toggle)
        guard isPrivacyExpanded else { return }
        for finding in rating.findings {
            let label = UILabel()
            label.text = (finding.isGood ? "+ " : "- ") + finding.text
            label.font = WalletTheme.mono(12)
            label.textColor = finding.isGood ? WalletTheme.dim : WalletTheme.text
            label.numberOfLines = 0
            privacyStack.addArrangedSubview(label)
        }
        let note = UILabel()
        note.text = "Based on common on-chain assumptions. How you broadcast matters too."
        note.font = WalletTheme.mono(10)
        note.textColor = WalletTheme.dim
        note.numberOfLines = 0
        privacyStack.addArrangedSubview(note)
    }

    func update(title: String, lines: [String], actionTitle: String? = nil, action: (() -> Void)? = nil) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.isHidden = false
        let titleLabel = UILabel()
        titleLabel.text = "> " + title.uppercased()
        titleLabel.font = WalletTheme.mono(11, weight: .bold)
        titleLabel.textColor = tint.accent
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)
        for line in lines {
            let label = UILabel()
            label.text = line
            label.font = WalletTheme.mono(12)
            label.textColor = WalletTheme.text
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }
        if let actionTitle = actionTitle, let action = action {
            let button = UIButton(type: .system)
            button.configuration = WalletTheme.buttonConfiguration(title: actionTitle, systemImage: "xmark.circle", filled: false, tint: tint)
            button.addAction(UIAction { _ in action() }, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
    }
}

extension VerifyTransactionViewController {

    func loadInsight() {
        // The payjoin banner has the top of the screen while one is under way.
        guard payjoin == nil, payjoinBanner == nil else { return }
        showFlow()
        loadPrivacyRating()
        loadSelfTransfer()
        if alreadyBroadcast, confs == 0, !txid.isEmpty {
            loadConfirmationInsight(txid: txid)
        } else if !alreadyBroadcast, !unsignedPsbt.isEmpty {
            loadPsbtInsight(psbt: unsignedPsbt)
        }
    }

    func clearInsight() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let card = self.insightCard else { return }
            self.insightCard = nil
            if self.verifyTable.tableHeaderView === card { self.verifyTable.tableHeaderView = nil }
        }
    }

    private func headerCard() -> WalletInsightCard {
        let card = insightCard ?? WalletInsightCard(tint: .transaction)
        insightCard = card
        card.onResize = { [weak self] in self?.sizeTableHeader(force: true) }
        return card
    }

    // MARK: - Flow

    private func showFlow() {
        let outputs = outputArray.compactMap { $0["amountBtc"] as? Double }
        guard !inputTableArray.isEmpty, !outputs.isEmpty, outputs.count == outputArray.count else { return }
        let inputs = inputTableArray.map { $0["amountBtc"] as? Double }
        let known = inputs.compactMap { $0 }
        // Only from the amounts in the picture, so the ribbons add up.
        let fee = known.count == inputs.count ? ((known.reduce(0, +) - outputs.reduce(0, +)) * 100_000_000).rounded() / 100_000_000 : nil
        headerCard().update(flowInputs: inputs, outputs: outputs, fee: fee) { [weak self] side in
            guard let self = self else { return }
            let path: IndexPath
            switch side {
            case .input(let index): path = IndexPath(row: index, section: 3)
            case .output(let index): path = IndexPath(row: index, section: 4)
            }
            guard path.section < self.verifyTable.numberOfSections, path.row < self.verifyTable.numberOfRows(inSection: path.section) else { return }
            impact()
            self.verifyTable.scrollToRow(at: path, at: .middle, animated: true)
        }
        verifyTable.tableHeaderView = insightCard
        sizeTableHeader(force: true)
    }

    // MARK: - Self transfer

    private func loadSelfTransfer() {
        // The wallet's record is the better answer, when it has one.
        if alreadyBroadcast, !txid.isEmpty {
            let currentTxid = txid
            rpc(.gettransaction(Get_Tx(["txid": currentTxid]))) { [weak self] response, _ in
                guard let self = self, self.txid == currentTxid,
                      let wallet = response as? [String: Any], WalletSelfTransfer.matches(walletTransaction: wallet) else { return }
                self.showSelfTransfer()
            }
        } else if WalletSelfTransfer.matches(inputs: inputTableArray, outputs: outputArray) {
            showSelfTransfer()
        }
    }

    private func showSelfTransfer() {
        guard payjoinBanner == nil else { return }
        headerCard().showSelfTransfer()
        verifyTable.tableHeaderView = insightCard
        sizeTableHeader(force: true)
    }

    // MARK: - Privacy

    private func loadPrivacyRating() {
        // A prevout the wallet can't see reads "Unknown address.": not an address.
        let inputs = inputTableArray.compactMap { $0["address"] as? String }.filter { !$0.isEmpty && !$0.hasPrefix("Unknown") }
        // Only when every input's address is known: a rating of part of it would mislead.
        guard !inputs.isEmpty, inputs.count == inputTableArray.count else { return }
        let outputs: [(address: String, amountBtc: Double)] = outputArray.compactMap { output in
            guard let address = output["address"] as? String, let amount = output["amountBtc"] as? Double else { return nil }
            return (address, amount)
        }
        guard !outputs.isEmpty, outputs.count == outputArray.count else { return }
        let currentTxid = txid
        let wasPayjoin = payjoinUsed
        func show(_ reused: Set<String>) {
            guard txid == currentTxid, payjoinBanner == nil else { return }
            headerCard().update(privacy: TransactionPrivacyRating(inputs: inputs, outputs: outputs, reusedOutputs: reused, isPayjoin: wasPayjoin))
            verifyTable.tableHeaderView = insightCard
            sizeTableHeader(force: true)
        }
        // The wallet knows which of its own addresses have received before. Once broadcast, this
        // transaction counts too, so one earlier payment is then two.
        let minimum = alreadyBroadcast ? 2 : 1
        rpc(.listreceivedbyaddress(List_Received_By_Address())) { response, _ in
            let rows = response as? [[String: Any]] ?? []
            let reused = rows.filter { ($0["txids"] as? [Any])?.count ?? 0 >= minimum }.compactMap { $0["address"] as? String }
            show(Set(reused))
        }
    }

    private func showInsight(title: String, lines: [String], actionTitle: String? = nil, action: (() -> Void)? = nil) {
        guard payjoinBanner == nil else { return }
        let card = headerCard()
        card.update(title: title, lines: lines, actionTitle: actionTitle, action: action)
        verifyTable.tableHeaderView = card
        sizeTableHeader(force: true)
    }

    /// Completes on the main queue.
    private func rpc(_ method: BTC_CLI_COMMAND, completion: @escaping (Any?, String?) -> Void) {
        insightService.call(method, completion: completion)
    }

    // MARK: - PSBT

    private func loadPsbtInsight(psbt: String) {
        rpc(.analyzepsbt(param: Analyze_PSBT(["psbt": psbt]))) { [weak self] response, _ in
            guard let self = self, self.unsignedPsbt == psbt, !self.alreadyBroadcast,
                  let next = (response as? [String: Any]).flatMap({ PSBTNextStep(response: $0) }) else { return }
            var lines = [next.step]
            if next.missingSignatures > 0 {
                lines.append("Missing \(next.missingSignatures) signature\(next.missingSignatures == 1 ? "" : "s").")
            }
            self.showInsight(title: "Next step", lines: lines)
        }
    }

    // MARK: - Will it confirm?

    private func loadConfirmationInsight(txid: String) {
        rpc(.gettransaction(Get_Tx(["txid": txid]))) { [weak self] response, _ in
            guard let self = self, self.txid == txid else { return }
            let wallet = response as? [String: Any]
            // It may have confirmed since the wallet's list was loaded.
            if (RPCValue.int(wallet?["confirmations"]) ?? 0) > 0 { return }
            if wallet?["abandoned"] as? Bool == true {
                self.showAbandoned()
                return
            }
            self.rpc(.getmempoolentry(Get_Mempool_Entry(txid: txid))) { [weak self] entry, error in
                guard let self = self, self.txid == txid else { return }
                if let entry = entry as? [String: Any], let position = MempoolPosition(entry: entry) {
                    self.loadOutlook(position, txid: txid)
                } else if error?.lowercased().contains("not in mempool") == true {
                    self.showDropped(txid: txid, isWalletTransaction: wallet != nil)
                }
            }
        }
    }

    private func loadOutlook(_ position: MempoolPosition, txid: String) {
        var estimates: [Int: Double] = [:]
        var inTemplate = false
        let group = DispatchGroup()
        for target in [1, 6, 144] {
            group.enter()
            rpc(.estimatesmartfee(param: Estimate_Smart_Fee_Param(["conf_target": target]))) { response, _ in
                if let rate = RPCValue.double((response as? [String: Any])?["feerate"]) {
                    estimates[target] = rate * 100_000
                }
                group.leave()
            }
        }
        // Several megabytes, so not over Tor: the estimates alone answer well enough there.
        if insightService.isFastConnection {
            group.enter()
            insightService.template { result in
                if case .success(let map) = result { inTemplate = map.contains { $0.txid == txid } }
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.txid == txid else { return }
            var lines = [MempoolPosition.describe(position.outlook(estimates: estimates, inTemplate: inTemplate)),
                         "Effective rate: " + ExplorerFormat.feeRate(position.effectiveRate)]
            if position.unconfirmedParents > 0 {
                lines.append("Waiting on \(position.unconfirmedParents) unconfirmed parent\(position.unconfirmedParents == 1 ? "" : "s").")
            }
            if position.unconfirmedChildren > 0 {
                lines.append("\(position.unconfirmedChildren) unconfirmed transaction\(position.unconfirmedChildren == 1 ? " spends" : "s spend") its outputs.")
            }
            self.showInsight(title: "Will it confirm?", lines: lines)
        }
    }

    // MARK: - Dropped

    private func showDropped(txid: String, isWalletTransaction: Bool) {
        let lines = ["Your node doesn't have this transaction in its mempool, so it may never confirm unless it's broadcast again."]
        guard isWalletTransaction else {
            showInsight(title: "Not in your mempool", lines: lines)
            return
        }
        showInsight(title: "Not in your mempool", lines: lines, actionTitle: "Abandon transaction") { [weak self] in
            self?.promptToAbandon(txid: txid)
        }
    }

    private func promptToAbandon(txid: String) {
        let alert = UIAlertController(
            title: "Abandon this transaction?",
            message: "Your wallet will stop counting it and can spend its coins again.\n\nThis doesn't cancel it. If another node still has it, it can still confirm, unless you spend those coins in a new transaction first.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Abandon", style: .destructive) { [weak self] _ in self?.abandon(txid: txid) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func abandon(txid: String) {
        rpc(.abandontransaction(Abandon_Transaction(txid: txid))) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                showAlert(vc: self, title: "Couldn't abandon it", message: error)
                return
            }
            self.showAbandoned()
            NotificationCenter.default.post(name: .refreshWallet, object: nil)
        }
    }

    private func showAbandoned() {
        showInsight(title: "Abandoned", lines: ["Your wallet no longer counts this transaction and can spend its coins again. It can still confirm if another node has it."])
    }
}
