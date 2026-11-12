//
//  TransactionExplorerViewController.swift
//  FullyNoded
//
//  One transaction: where its money came from and went. Tap an input to go back to the output it
//  spends; tap an output to see whether it has been spent.
//
//  Going back works without txindex: each input's prevout names the block it was created in.
//  Going forward is limited by the node: Core can say an output is spent, and name a spender in
//  the mempool, but keeps no index of which block spent it.
//

import UIKit

final class TransactionExplorerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    private enum Section: Int, CaseIterable { case inputs, outputs }

    private let service: BlockExplorerService
    private let tx: ExplorerTx
    private let raw: [String: Any]
    /// The output a trace arrived at, flashed when the screen opens.
    private let highlightedOutput: Int?
    private let embeddedStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()
    private var embeddedData: [ExplorerEmbeddedData] = []
    private var isEmbeddedDecoded = false
    private let categoryStack = UIStackView()
    private var walletCategory: ExplorerTxCategory?
    private static let maxEmbeddedShown = 20
    private let tint = WalletTheme.Tint.explorer
    private let table = UITableView(frame: .zero, style: .grouped)
    private var statuses: [Int: BlockExplorerService.OutputStatus] = [:]
    private var loadingStatuses = Set<Int>()
    private var didFlash = false

    init(service: BlockExplorerService, tx: ExplorerTx, raw: [String: Any], highlightedOutput: Int? = nil) {
        self.service = service
        self.tx = tx
        self.raw = raw
        self.highlightedOutput = highlightedOutput
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Loads the transaction, then opens it, so a trace that can't continue (a pruned block, say)
    /// leaves you where you were with the reason.
    static func open(txid: String, blockhash: String?, highlightedOutput: Int? = nil, service: BlockExplorerService, from vc: UIViewController) {
        vc.showActivity("loading transaction...")
        service.transaction(txid: txid, blockhash: blockhash) { [weak vc] result in
            guard let vc = vc else { return }
            vc.hideActivity()
            switch result {
            case .success(let (tx, raw)):
                let detail = TransactionExplorerViewController(service: service, tx: tx, raw: raw, highlightedOutput: highlightedOutput)
                vc.navigationController?.pushViewController(detail, animated: true)
            case .failure(let error):
                showAlert(vc: vc, title: "Can't open this transaction", message: friendly(error.message))
            }
        }
    }

    private static func friendly(_ message: String) -> String {
        let lower = message.lowercased()
        if lower.contains("not available") || lower.contains("pruned") {
            return "Your node has pruned the block holding it, so its details are gone from this node."
        }
        if lower.contains("no such") || lower.contains("txindex") {
            return "Your node can't find it. Without txindex, a confirmed transaction can only be opened from its block."
        }
        return message
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transaction"
        let rawItem = UIBarButtonItem(image: UIImage(systemName: "curlybraces"), style: .plain, target: self, action: #selector(rawTapped))
        rawItem.accessibilityLabel = "Raw response"
        navigationItem.rightBarButtonItem = rawItem
        WalletTheme.apply(to: self, tint: tint)

        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 80
        table.sectionHeaderTopPadding = 0
        table.register(ExplorerEndpointCell.self, forCellReuseIdentifier: ExplorerEndpointCell.identifier)
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        table.tableHeaderView = makeHeader()
        showCategories()
        findEmbeddedData()
        loadWalletCategory()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Header views don't size themselves.
        if let header = table.tableHeaderView {
            let size = header.systemLayoutSizeFitting(CGSize(width: table.bounds.width, height: 0),
                                                      withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
            if header.frame.height != size.height {
                header.frame.size.height = size.height
                table.tableHeaderView = header
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let output = highlightedOutput, !didFlash,
              let row = tx.outputs.firstIndex(where: { $0.n == output }) else { return }
        didFlash = true
        let path = IndexPath(row: row, section: Section.outputs.rawValue)
        table.scrollToRow(at: path, at: .middle, animated: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            (self?.table.cellForRow(at: path) as? ExplorerEndpointCell)?.flash()
        }
    }

    // MARK: - Header

    private func makeHeader() -> UIView {
        let container = UIView()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.safeAreaLayoutGuide.trailingAnchor, constant: -16)
        ])

        let txid = UILabel()
        txid.text = tx.txid
        txid.font = WalletTheme.mono(13, weight: .semibold)
        txid.textColor = WalletTheme.text
        txid.numberOfLines = 0
        txid.lineBreakMode = .byCharWrapping

        let status = UILabel()
        status.font = WalletTheme.mono(12, weight: .bold)
        status.numberOfLines = 0
        if tx.confirmations > 0 {
            status.text = "✓ \(tx.confirmations.withCommas) confirmation\(tx.confirmations == 1 ? "" : "s")" + (tx.blocktime.map { " · \(ExplorerFormat.ago($0))" } ?? "")
            status.textColor = tint.accent
        } else {
            status.text = "In the mempool · waiting to be mined"
            status.textColor = WalletTheme.pending
        }

        let flow = ExplorerFlowView()
        flow.configure(tx, tint: tint)
        flow.heightAnchor.constraint(equalToConstant: 150).isActive = true
        flow.onSelect = { [weak self] side in self?.flowTapped(side) }

        let copy = UIButton(type: .system)
        copy.configuration = WalletTheme.chipConfiguration(title: "Copy txid", systemImage: "doc.on.doc", tint: tint, fontSize: 12, imageSize: 11,
                                                           imagePadding: 6, insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        copy.addTarget(self, action: #selector(copyTxid), for: .touchUpInside)

        categoryStack.axis = .vertical
        categoryStack.spacing = 8
        categoryStack.isHidden = true
        stack.addArrangedSubview(WalletTheme.cardView([txid, status, categoryStack, UIStackView(arrangedSubviews: [copy, UIView()])], tint: tint))
        stack.addArrangedSubview(embeddedStack)
        stack.addArrangedSubview(WalletTheme.caption("> FLOW", tint: tint))
        stack.addArrangedSubview(WalletTheme.cardView([flow], tint: tint))
        stack.addArrangedSubview(WalletTheme.caption("> DETAILS", tint: tint))
        stack.addArrangedSubview(WalletTheme.cardView(detailRows(), tint: tint, spacing: 8))
        return container
    }

    private func detailRows() -> [UIView] {
        var rows: [(String, String)] = [("Sent", ExplorerFormat.btcWithFiat(tx.totalOutBtc))]
        if tx.isCoinbase {
            rows.append(("Type", "Coinbase: new coins and the block's fees"))
        } else if let fee = tx.feeBtc {
            rows.append(("Fee", ExplorerFormat.btcWithFiat(fee)))
            if let rate = tx.feeRate { rows.append(("Fee rate", ExplorerFormat.feeRate(rate))) }
        }
        if let size = tx.size { rows.append(("Size", ExplorerFormat.megabytes(size))) }
        if let vsize = tx.vsize { rows.append(("Virtual size", "\(vsize.withCommas) vB" + (tx.weight.map { " · \($0.withCommas) WU" } ?? ""))) }
        if tx.confirmations == 0 { rows.append(("Replaceable", tx.signalsRBF ? "Yes (RBF)" : "No signal")) }
        if let version = tx.version { rows.append(("Version", "\(version)")) }
        if let locktime = tx.locktime, locktime > 0 { rows.append(("Locktime", locktime.withCommas)) }
        return rows.map { detailRow($0, $1) }
    }

    private func detailRow(_ title: String, _ value: String) -> UIView { WalletTheme.infoRow(title, value, titleWidth: 92) }

    // MARK: - Embedded data

    /// Inscriptions can be megabytes, so this reads them away from the main thread.
    private func findEmbeddedData() {
        let raw = self.raw
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = ExplorerEmbeddedData.decode(raw: raw)
            DispatchQueue.main.async {
                guard let self = self, !found.isEmpty else { return }
                self.embeddedData = found
                self.showEmbeddedOffer()
                self.showCategories()
            }
        }
    }

    // MARK: - Categories

    private func showCategories() {
        // Counted from the tip, since a transaction reply doesn't give a height.
        let height = service.nextBlockHeight.map { $0 - tx.confirmations }
        var categories = ExplorerTxCategory.all(tx: tx, embedded: embeddedData, height: height)
        if let wallet = walletCategory { categories.insert(wallet, at: 0) }
        categoryStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for category in categories {
            let name = UILabel()
            name.text = category.name.uppercased()
            name.font = WalletTheme.mono(11, weight: .bold)
            name.textColor = tint.accent
            name.numberOfLines = 0
            let detail = UILabel()
            detail.text = category.detail
            detail.font = WalletTheme.mono(11)
            detail.textColor = WalletTheme.dim
            detail.numberOfLines = 0
            let row = UIStackView(arrangedSubviews: [name, detail])
            row.axis = .vertical
            row.spacing = 2
            row.isAccessibilityElement = true
            row.accessibilityLabel = "\(category.name). \(category.detail)"
            categoryStack.addArrangedSubview(row)
        }
        categoryStack.isHidden = categories.isEmpty
        view.setNeedsLayout()
    }

    /// The active wallet can say for certain what only it knows: that it was on both sides.
    private func loadWalletCategory() {
        guard UserDefaults.standard.string(forKey: "walletName") != nil else { return }
        service.call(.gettransaction(Get_Tx(["txid": tx.txid]))) { [weak self] response, _ in
            guard let self = self, let wallet = response as? [String: Any],
                  WalletSelfTransfer.matches(walletTransaction: wallet) else { return }
            self.walletCategory = ExplorerTxCategory(name: WalletSelfTransfer.title, detail: WalletSelfTransfer.detail)
            self.showCategories()
        }
    }

    /// What's there, by name. Its contents are from strangers, so showing them is a choice.
    private func showEmbeddedOffer() {
        var names: [String] = []
        for item in embeddedData where !names.contains(item.name) { names.append(item.name) }
        let summary = UILabel()
        summary.text = names.prefix(4).joined(separator: " · ") + (names.count > 4 ? " · …" : "")
        summary.font = WalletTheme.mono(13)
        summary.textColor = WalletTheme.text
        summary.numberOfLines = 0
        let decode = UIButton(type: .system)
        decode.configuration = WalletTheme.chipConfiguration(title: "Decode", systemImage: "text.magnifyingglass", tint: tint, fontSize: 12, imageSize: 11,
                                                             imagePadding: 6, insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        decode.addAction(UIAction { [weak self] _ in self?.showEmbeddedDecoded() }, for: .touchUpInside)
        setEmbedded([summary, UIStackView(arrangedSubviews: [decode, UIView()])])
    }

    private func showEmbeddedDecoded() {
        impact()
        isEmbeddedDecoded = true
        var views: [UIView] = []
        for item in embeddedData.prefix(Self.maxEmbeddedShown) {
            let title = UILabel()
            switch item.location {
            case .output(let n): title.text = "OUTPUT #\(n) · \(item.name)"
            case .input(let n): title.text = "INPUT #\(n) · \(item.name)"
            }
            title.font = WalletTheme.mono(12, weight: .bold)
            title.textColor = tint.accent
            title.numberOfLines = 0
            views.append(title)
            views += item.details.map { detailRow($0.title, $0.value) }
        }
        if embeddedData.count > Self.maxEmbeddedShown {
            views.append(detailRow("More", "\(embeddedData.count - Self.maxEmbeddedShown) more items"))
        }
        let note = UILabel()
        note.text = "Format match only: this doesn't check validity under the protocol's own rules."
        note.font = WalletTheme.mono(10)
        note.textColor = WalletTheme.dim
        note.numberOfLines = 0
        views.append(note)
        setEmbedded(views)
        table.reloadData()
    }

    private func setEmbedded(_ views: [UIView]) {
        embeddedStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        embeddedStack.addArrangedSubview(WalletTheme.caption("> EMBEDDED DATA", tint: tint))
        embeddedStack.addArrangedSubview(WalletTheme.cardView(views, tint: tint, spacing: 8))
        view.setNeedsLayout()
    }

    // MARK: - Table

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Section(rawValue: section) == .inputs ? tx.inputs.count : tx.outputs.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        let isInputs = Section(rawValue: section) == .inputs
        let caption = WalletTheme.caption(isInputs ? "> INPUTS · \(tx.inputs.count.withCommas)" : "> OUTPUTS · \(tx.outputs.count.withCommas)", tint: tint)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 32 }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 4 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerEndpointCell.identifier, for: indexPath) as! ExplorerEndpointCell
        if Section(rawValue: indexPath.section) == .inputs {
            let input = tx.inputs[indexPath.row]
            if input.coinbase {
                cell.configure(index: indexPath.row, value: "New coins", address: "Coinbase: no previous output", note: nil, noteColor: nil, tracable: false, tint: tint)
            } else {
                let source = "from \(input.txid ?? "?"):\(input.vout ?? 0)"
                let address = input.address ?? (input.valueBtc == nil ? "Spent output details unavailable" : ExplorerTx.scriptName(input.scriptType))
                cell.configure(index: indexPath.row,
                               value: input.valueBtc.map(ExplorerFormat.btcWithFiat) ?? "Amount unknown",
                               address: address,
                               note: source + (input.sourceHeight.map { "\nblock \($0.withCommas)" } ?? ""),
                               noteColor: WalletTheme.dim, tracable: true, tint: tint)
            }
        } else {
            let output = tx.outputs[indexPath.row]
            let status = statusText(output.n)
            cell.configure(index: output.n, value: ExplorerFormat.btcWithFiat(output.valueBtc),
                           address: output.address ?? embeddedName(output: output.n) ?? ExplorerTx.scriptName(output.scriptType),
                           note: status.text, noteColor: status.color, tracable: statusIsTracable(output.n), tint: tint)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .outputs else { return }
        loadStatus(tx.outputs[indexPath.row].n, row: indexPath.row)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if Section(rawValue: indexPath.section) == .inputs {
            traceInput(indexPath.row)
        } else {
            outputTapped(tx.outputs[indexPath.row].n)
        }
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let isInputs = Section(rawValue: indexPath.section) == .inputs
        let address = isInputs ? tx.inputs[indexPath.row].address : tx.outputs[indexPath.row].address
        guard let address = address else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            UIMenu(children: [UIAction(title: "Copy address", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                UIPasteboard.general.string = address
                if let self = self { SuccessView.toast("Address copied", in: self) }
            }])
        }
    }

    // MARK: - Output status

    /// OP_RETURN outputs can never be spent, so gettxout's "not found" doesn't mean spent.
    /// Once decoded, an output with no address can say what it holds.
    private func embeddedName(output n: Int) -> String? {
        guard isEmbeddedDecoded else { return nil }
        return embeddedData.first { $0.location == .output(n) }?.name
    }

    private func isUnspendable(_ n: Int) -> Bool {
        tx.outputs.first { $0.n == n }?.scriptType == "nulldata"
    }

    private func statusText(_ n: Int) -> (text: String, color: UIColor) {
        if isUnspendable(n) { return ("Data only: can never be spent", WalletTheme.dim) }
        switch statuses[n] {
        case .unspent: return ("● Unspent", tint.accent)
        case .spentInMempool: return ("→ Being spent, in the mempool. Tap to follow", WalletTheme.pending)
        case .spent: return ("Spent in a block", WalletTheme.dim)
        case nil: return ("Checking…", WalletTheme.dim)
        }
    }

    private func statusIsTracable(_ n: Int) -> Bool {
        if case .spentInMempool = statuses[n] { return true }
        return false
    }

    private func loadStatus(_ n: Int, row: Int) {
        guard !isUnspendable(n), statuses[n] == nil, !loadingStatuses.contains(n) else { return }
        loadingStatuses.insert(n)
        service.outputStatus(txid: tx.txid, n: n) { [weak self] result in
            guard let self = self else { return }
            self.loadingStatuses.remove(n)
            guard case .success(let status) = result else { return }
            self.statuses[n] = status
            self.table.reloadRows(at: [IndexPath(row: row, section: Section.outputs.rawValue)], with: .none)
        }
    }

    // MARK: - Tracing

    private func flowTapped(_ side: ExplorerFlowView.Side) {
        switch side {
        case .input(let index):
            traceInput(index)
        case .output(let index):
            table.scrollToRow(at: IndexPath(row: index, section: Section.outputs.rawValue), at: .middle, animated: true)
        }
    }

    private func traceInput(_ index: Int) {
        let input = tx.inputs[index]
        guard !input.coinbase, let txid = input.txid else {
            showAlert(vc: self, title: "This is where these coins began", message: "A coinbase input spends nothing: it creates the block's reward.", kind: .notice)
            return
        }
        impact()
        guard let height = input.sourceHeight, height > 0 else {
            // No height: its parent is in the mempool, or the node predates prevout data.
            Self.open(txid: txid, blockhash: nil, highlightedOutput: input.vout, service: service, from: self)
            return
        }
        showActivity("finding block \(height.withCommas)...")
        service.blockHash(height: height) { [weak self] result in
            guard let self = self else { return }
            self.hideActivity()
            switch result {
            case .success(let hash):
                Self.open(txid: txid, blockhash: hash, highlightedOutput: input.vout, service: self.service, from: self)
            case .failure(let error):
                showAlert(vc: self, title: "Can't follow this input", message: error.message)
            }
        }
    }

    private func outputTapped(_ n: Int) {
        if isUnspendable(n) {
            showAlert(vc: self, title: "Data only", message: "An OP_RETURN output holds data, not spendable coins, so the trail ends here.", kind: .notice)
            return
        }
        switch statuses[n] {
        case .spentInMempool(let spender):
            impact()
            Self.open(txid: spender, blockhash: nil, service: service, from: self)
        case .unspent:
            showAlert(vc: self, title: "Unspent", message: "This output hasn't been spent. There's nothing further to follow yet.", kind: .notice)
        case .spent:
            showAlert(vc: self, title: "Spent in a block",
                      message: "Your node knows this output was spent, but Bitcoin Core keeps no index of which transaction spent it, so the trail can't be followed forward from here.",
                      kind: .notice)
        case nil:
            break
        }
    }

    // MARK: - Actions

    @objc private func rawTapped() {
        impact()
        let nav = UINavigationController(rootViewController: TextModalViewController(data: raw, viewTitle: "getrawtransaction"))
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    @objc private func copyTxid() {
        UIPasteboard.general.string = tx.txid
        SuccessView.toast("Txid copied", in: self)
    }
}

/// One input or output: index, amount, whole address, then where it came from or its status.
private final class ExplorerEndpointCell: UITableViewCell {
    static let identifier = "ExplorerEndpointCell"
    private let indexLabel = UILabel()
    private let valueLabel = UILabel()
    private let addressLabel = UILabel()
    private let noteLabel = UILabel()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
    private let flashView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        automaticallyUpdatesBackgroundConfiguration = false
        indexLabel.font = WalletTheme.mono(11, weight: .bold)
        indexLabel.textColor = WalletTheme.dim
        indexLabel.widthAnchor.constraint(equalToConstant: 36).isActive = true
        valueLabel.font = WalletTheme.mono(14, weight: .semibold)
        valueLabel.textColor = WalletTheme.text
        valueLabel.numberOfLines = 0
        addressLabel.font = WalletTheme.mono(12)
        addressLabel.textColor = WalletTheme.text
        addressLabel.numberOfLines = 0
        addressLabel.lineBreakMode = .byCharWrapping
        noteLabel.font = WalletTheme.mono(11)
        noteLabel.numberOfLines = 0
        noteLabel.lineBreakMode = .byCharWrapping
        chevron.tintColor = WalletTheme.dim
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        chevron.setContentCompressionResistancePriority(.required, for: .horizontal)

        let column = UIStackView(arrangedSubviews: [valueLabel, addressLabel, noteLabel])
        column.axis = .vertical
        column.spacing = 4
        let row = UIStackView(arrangedSubviews: [indexLabel, column, chevron])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        flashView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(flashView)
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            flashView.topAnchor.constraint(equalTo: contentView.topAnchor),
            flashView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            flashView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            flashView.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 26),
            row.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -26)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(index: Int, value: String, address: String, note: String?, noteColor: UIColor?, tracable: Bool, tint: WalletTheme.Tint) {
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        flashView.backgroundColor = tint.accent.withAlphaComponent(0.35)
        indexLabel.text = "#\(index)"
        valueLabel.text = value
        addressLabel.text = address
        noteLabel.text = note
        noteLabel.textColor = noteColor ?? WalletTheme.dim
        noteLabel.isHidden = note == nil
        chevron.alpha = tracable ? 1 : 0
        accessibilityLabel = "Number \(index), \(value), \(address). \(note ?? "")"
    }

    func flash() {
        flashView.alpha = 1
        UIView.animate(withDuration: 1.2, delay: 0.2, options: [.curveEaseOut]) { self.flashView.alpha = 0 }
    }
}
