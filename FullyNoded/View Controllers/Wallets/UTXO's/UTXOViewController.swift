//
//  UTXOViewController.swift
//  BitSense
//
//  Created by Peter on 30/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//
//  The wallet's unspent outputs, built in code. Each output is a card with its amount,
//  badges (silent payment, timelock, unconfirmed, dust, reused…), and a callout for the
//  outputs that need explaining: silent payments (found by Fully Noded Server, signed with
//  the spend key plus a tweak) and timelocked outputs (when they unlock). A summary card
//  filters and sorts them, and Select mode spends several outputs at once (coin control).
//

import UIKit
import BitcoinDevKit

// MARK: - What's special about an output

/// Everything the screen tells about one output beyond what listunspent says directly.
struct UTXOTraits {
    /// A silent payment output: held as a bare taproot key (`rawtr()`, how Fully Noded Server
    /// imports them), and verified once "Check SP info" proved it's yours and saved its tweak.
    /// Wallet labels aren't used.
    struct SilentPayment {
        let isVerified: Bool
        /// Paid to a labeled silent payment address (e.g. the change label).
        let isLabeled: Bool
    }

    /// A timelock in the output's descriptor.
    struct Timelock {
        enum Lock {
            /// after(N), N < 500,000,000: block height.
            case height(Int)
            /// after(N), N ≥ 500,000,000: unix time, compared with the median time past.
            case time(Int)
            /// older(N): blocks after the output confirmed.
            case relativeBlocks(Int)
            /// older(N) with the time flag: seconds after the output confirmed.
            case relativeSeconds(Int)
        }

        let lock: Lock
        /// The descriptor has another spending path that doesn't need the lock (e.g. the lock
        /// only guards a recovery key), so the output isn't locked as a whole.
        let isAlternativePath: Bool
    }

    enum ScriptType: String {
        case taproot = "TAPROOT"
        case segwit = "SEGWIT"
        case nestedSegwit = "NESTED SEGWIT"
        case legacy = "LEGACY"
        case segwitScript = "SEGWIT SCRIPT"
        case script = "SCRIPT"
    }

    let silentPayment: SilentPayment?
    let timelock: Timelock?
    let scriptType: ScriptType?
    /// nil: unknown (no descriptor).
    let isChange: Bool?
    let isUnconfirmed: Bool
    /// Core's "safe" flag: unconfirmed outputs from outside keys (or replaceable ones).
    let isUnsafe: Bool
    let isDust: Bool
    let isReused: Bool

    init(_ utxo: UTXO) {
        let desc = utxo.desc ?? ""

        if utxo.spTweakHex != nil || desc.hasPrefix("rawtr(") {
            silentPayment = SilentPayment(isVerified: utxo.spTweakHex != nil, isLabeled: utxo.spLabelTweakHex != nil)
        } else {
            silentPayment = nil
        }

        timelock = Self.timelock(in: desc)
        scriptType = Self.scriptType(desc: desc, scriptPubKey: utxo.scriptPubKey)
        isChange = desc.isEmpty ? nil : desc.contains("/1/")
        isUnconfirmed = (utxo.confirmations ?? 0) == 0
        isUnsafe = (utxo.rawData["safe"] as? Bool) == false
        isDust = utxo.amount <= 0.00010000
        isReused = utxo.reused == true
    }

    private static func timelock(in desc: String) -> Timelock? {
        guard !desc.isEmpty else { return nil }
        // Any branching fragment means the lock may guard only one of several spending paths.
        let branches = ["or_b(", "or_c(", "or_d(", "or_i(", "andor(", "thresh("].contains { desc.contains($0) }
            || (desc.hasPrefix("tr(") && desc.contains(",{"))
        if let n = OnchainUtils.timelockValue(in: desc) {
            return Timelock(lock: n >= 500_000_000 ? .time(n) : .height(n), isAlternativePath: branches)
        }
        if let match = desc.range(of: #"older\((\d+)\)"#, options: .regularExpression),
           let n = Int(desc[match].dropFirst(6).dropLast()) {
            // BIP68: bit 22 selects 512-second units; the low 16 bits hold the value.
            let value = n & 0xFFFF
            let lock: Timelock.Lock = (n & (1 << 22)) != 0 ? .relativeSeconds(value * 512) : .relativeBlocks(value)
            return Timelock(lock: lock, isAlternativePath: branches)
        }
        return nil
    }

    private static func scriptType(desc: String, scriptPubKey: String?) -> ScriptType? {
        let d = desc.lowercased()
        if d.hasPrefix("tr(") || d.hasPrefix("rawtr(") { return .taproot }
        if d.hasPrefix("wpkh(") { return .segwit }
        if d.hasPrefix("sh(wpkh(") { return .nestedSegwit }
        if d.hasPrefix("pkh(") { return .legacy }
        if d.hasPrefix("wsh(") || d.hasPrefix("sh(wsh(") { return .segwitScript }
        if d.hasPrefix("sh(") { return .script }
        guard let spk = scriptPubKey?.lowercased() else { return nil }
        if spk.hasPrefix("5120"), spk.count == 68 { return .taproot }
        if spk.hasPrefix("0014"), spk.count == 44 { return .segwit }
        if spk.hasPrefix("0020"), spk.count == 68 { return .segwitScript }
        if spk.hasPrefix("a914") { return .script }
        if spk.hasPrefix("76a914") { return .legacy }
        return nil
    }
}

/// The chain's tip, for deciding whether timelocks have passed.
struct UTXOChainTip {
    let height: Int
    let medianTime: Int
}

extension UTXOTraits.Timelock {
    /// Where the lock stands: locked (with when it opens), open, or unknown (no chain info).
    enum State {
        case locked(title: String, detail: String)
        case open(title: String, detail: String)
        case unknown(title: String, detail: String)

        var isLocked: Bool { if case .locked = self { return true } else { return false } }
    }

    func state(confirmations: Int?, tip: UTXOChainTip?) -> State {
        let unknownDetail = "Couldn't read the chain's tip, so whether it has passed isn't known."
        switch lock {
        case .height(let n):
            let title = "Timelocked until block \(n.formatted())"
            guard let tip = tip else { return .unknown(title: title, detail: unknownDetail) }
            // Spendable in the block at height n, i.e. once the tip is n - 1 (same rule as the
            // wallet's timelocked balance, which waits for the tip to reach n).
            if n <= tip.height {
                return .open(title: "Timelock passed", detail: "Was locked until block \(n.formatted()). It can be spent now.")
            }
            let blocks = n - tip.height
            return .locked(title: title,
                           detail: "\(blocks.formatted()) block\(blocks == 1 ? "" : "s") to go (about \(Self.duration(TimeInterval(blocks) * 600))). It can't be spent before then.")
        case .time(let t):
            let date = Date(timeIntervalSince1970: TimeInterval(t))
            let title = "Timelocked until \(date.dateDisplay)"
            guard let tip = tip else { return .unknown(title: title, detail: unknownDetail) }
            if t < tip.medianTime {
                return .open(title: "Timelock passed", detail: "Was locked until \(date.dateDisplay). It can be spent now.")
            }
            let remaining = date.timeIntervalSinceNow
            if remaining <= 0 {
                return .locked(title: title, detail: "Unlocks within about an hour: the network's median block time has to pass it first.")
            }
            return .locked(title: title, detail: "Unlocks in about \(Self.duration(remaining)). It can't be spent before then.")
        case .relativeBlocks(let n):
            let title = "Relative timelock: \(n.formatted()) block\(n == 1 ? "" : "s")"
            let confs = confirmations ?? 0
            if confs >= n {
                return .open(title: "Relative timelock passed", detail: "Needed \(n.formatted()) confirmations, has \(confs.formatted()). It can be spent now.")
            }
            let blocks = n - confs
            return .locked(title: title,
                           detail: "Spendable \(n.formatted()) blocks after it confirmed: \(blocks.formatted()) to go (about \(Self.duration(TimeInterval(blocks) * 600))).")
        case .relativeSeconds(let seconds):
            let title = "Relative timelock: \(Self.duration(TimeInterval(seconds)))"
            let confs = confirmations ?? 0
            // Estimated from confirmations (about 10 minutes each); the node enforces the real rule.
            let elapsed = TimeInterval(confs) * 600
            if confs > 0, elapsed >= TimeInterval(seconds) {
                return .open(title: "Relative timelock passed (estimated)", detail: "Needed \(Self.duration(TimeInterval(seconds))) after confirming. It should be spendable now.")
            }
            return .locked(title: title,
                           detail: "Spendable \(Self.duration(TimeInterval(seconds))) after it confirmed: about \(Self.duration(TimeInterval(seconds) - elapsed)) to go.")
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds >= 86_400 * 2 ? [.day, .hour] : (seconds >= 3600 ? [.hour, .minute] : [.minute])
        return formatter.string(from: max(seconds, 60)) ?? "–"
    }
}

/// One row of the list: the output, its traits, and whether it's locked right now.
struct UTXOItem {
    let utxo: UTXO
    let traits: UTXOTraits
    var timelockState: UTXOTraits.Timelock.State?

    /// Can't be spent yet: a timelock that guards every spending path hasn't passed.
    var isTimelocked: Bool {
        guard let timelock = traits.timelock, !timelock.isAlternativePath else { return false }
        return timelockState?.isLocked == true
    }

    init(_ utxo: UTXO, tip: UTXOChainTip?) {
        self.utxo = utxo
        traits = UTXOTraits(utxo)
        timelockState = traits.timelock?.state(confirmations: utxo.confirmations, tip: tip)
    }
}

// MARK: - Screen

class UTXOViewController: UIViewController {

    enum Filter: CaseIterable {
        case all, spendable, silentPayments, timelocked, unconfirmed

        var title: String {
            switch self {
            case .all: return "All"
            case .spendable: return "Spendable"
            case .silentPayments: return "Silent payments"
            case .timelocked: return "Timelocked"
            case .unconfirmed: return "Unconfirmed"
            }
        }

        func matches(_ item: UTXOItem) -> Bool {
            switch self {
            case .all: return true
            case .spendable: return !item.isTimelocked && !item.traits.isUnsafe
            case .silentPayments: return item.traits.silentPayment != nil
            case .timelocked: return item.traits.timelock != nil
            case .unconfirmed: return item.traits.isUnconfirmed
            }
        }
    }

    enum Sort: CaseIterable {
        case newest, oldest, largest, smallest

        var title: String {
            switch self {
            case .newest: return "Newest first"
            case .oldest: return "Oldest first"
            case .largest: return "Largest first"
            case .smallest: return "Smallest first"
            }
        }
    }

    var wallet: Wallet?
    var fxRate: Double?

    private let tint: WalletTheme.Tint = .utxo
    /// Grouped, not inset-grouped: inset-grouped rounds (and clips) every section's first and
    /// last cell, and here every card is its own section. The table is inset 16pt instead.
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refresher = UIRefreshControl()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let selectionBar = UTXOSelectionBar()
    private var selectionBarBottom: NSLayoutConstraint!

    /// Everything listunspent (or the cache) returned for this wallet.
    private var utxos: [UTXO] = []
    private var items: [UTXOItem] = []
    private var tip: UTXOChainTip?
    private var allCachedUtxos: [[String: Any]] = []
    private var filter: Filter = .all
    private var sort: Sort = .newest
    private var isSelecting = false
    private var selected = Set<String>()   // outpoints
    private var lastUpdated: String?
    /// Silent payment tweaks known on this device (saved rows, plus "Check SP info" results), so
    /// a refresh, which replaces this wallet's cached rows, carries them over.
    private var knownTweaks: [String: (tweak: String, label: String?)] = [:]

    private var visibleItems: [UTXOItem] { items.filter { filter.matches($0) } }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "UTXOs"
        WalletTheme.apply(to: self, tint: tint)
        buildLayout()
        updateNavigationItems()
        lastUpdated = displaySavedDate()
        loadCachedUtxos()
    }

    private func buildLayout() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        tableView.register(UTXOSummaryCell.self, forCellReuseIdentifier: UTXOSummaryCell.identifier)
        tableView.register(UTXOCardCell.self, forCellReuseIdentifier: UTXOCardCell.identifier)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "empty")
        WalletTheme.styleTable(tableView)
        refresher.tintColor = tint.accent
        refresher.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.refreshControl = refresher
        view.addSubview(tableView)

        selectionBar.translatesAutoresizingMaskIntoConstraints = false
        selectionBar.isHidden = true
        selectionBar.spendButton.addTarget(self, action: #selector(spendSelected), for: .touchUpInside)
        view.addSubview(selectionBar)

        selectionBarBottom = selectionBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            selectionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            selectionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            selectionBarBottom
        ])
    }

    private func updateNavigationItems() {
        let refreshItem: UIBarButtonItem
        if spinner.isAnimating {
            refreshItem = UIBarButtonItem(customView: spinner)
        } else {
            refreshItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh))
        }
        let lockedItem = UIBarButtonItem(image: UIImage(systemName: "lock"), style: .plain, target: self, action: #selector(showLocked))
        lockedItem.accessibilityLabel = "Locked UTXOs"
        let selectItem = UIBarButtonItem(title: isSelecting ? "Cancel" : "Select", style: .plain, target: self, action: #selector(toggleSelecting))
        selectItem.accessibilityHint = "Select several outputs to spend together"
        let items = [refreshItem, lockedItem, selectItem]
        items.forEach { $0.tintColor = tint.accent }
        navigationItem.setRightBarButtonItems(items, animated: false)
    }

    // MARK: Loading

    @objc private func refresh() {
        loadCachedUtxos()
    }

    private func setLoading(_ loading: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if loading {
                self.spinner.color = self.tint.accent
                self.spinner.startAnimating()
            } else {
                self.spinner.stopAnimating()
                self.refresher.endRefreshing()
            }
            self.updateNavigationItems()
        }
    }

    /// Shows this wallet's cached outputs straight away, then fetches fresh ones.
    private func loadCachedUtxos() {
        setLoading(true)
        loadChainTip()

        guard let walletId = wallet?.id else {
            loadUtxos()
            return
        }

        CoreDataService.retrieveEntity(entityName: .utxos) { [weak self] cached in
            guard let self = self else { return }
            self.allCachedUtxos = cached ?? []
            let mine = self.allCachedUtxos.map { UTXO(from: $0) }.filter { $0.walletId == walletId }
            DispatchQueue.main.async {
                for utxo in mine {
                    if let tweak = utxo.spTweakHex {
                        self.knownTweaks[utxo.outpoint] = (tweak, utxo.spLabelTweakHex)
                    }
                }
            }
            if !mine.isEmpty {
                self.show(mine)
            }
            self.loadUtxos()
        }
    }

    private func loadUtxos() {
        let param: List_Unspent = .init(["minconf": 0])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listunspent(param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }

            guard let raw = response as? [[String: Any]] else {
                self.setLoading(false)
                showAlert(vc: self, title: "", message: errorDesc ?? "Unable to fetch utxos from your node.")
                return
            }

            self.saveLastSavedUtxosDate()
            let fresh: [UTXO] = raw.map {
                var utxo = UTXO(from: $0)
                utxo.id = UUID()
                return utxo
            }
            self.show(fresh)

            // Easier and lighter to overwrite all cached utxos for this wallet than to update
            // existing ones and delete spent ones. Runs after `show`, so saved tweaks are kept.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let toCache = self.utxos
                DispatchQueue.global(qos: .background).async { [weak self] in
                    self?.deleteThisWalletsCachedUtxos {
                        self?.cacheUtxos(toCache)
                    }
                }
            }
        }
    }

    /// Height and median time past, so timelocks can be checked.
    private func loadChainTip() {
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblockchaininfo) { [weak self] (response, _) in
            guard let self = self,
                  let info = response as? [String: Any],
                  let height = info["blocks"] as? Int,
                  let medianTime = info["mediantime"] as? Int else { return }
            DispatchQueue.main.async {
                self.tip = UTXOChainTip(height: height, medianTime: medianTime)
                self.rebuildItems()
            }
        }
    }

    private func show(_ utxos: [UTXO]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // listunspent knows nothing about tweaks: put back the ones saved on this device.
            self.utxos = utxos.map { utxo in
                var utxo = utxo
                if utxo.spTweakHex == nil, let known = self.knownTweaks[utxo.outpoint] {
                    utxo.spTweakHex = known.tweak
                    utxo.spLabelTweakHex = known.label
                }
                return utxo
            }
            // Selections of outputs that are gone (spent) are dropped.
            let outpoints = Set(utxos.map { $0.outpoint })
            self.selected.formIntersection(outpoints)
            self.rebuildItems()
        }
    }

    /// Main queue.
    private func rebuildItems() {
        var built = utxos.map { UTXOItem($0, tip: tip) }
        switch sort {
        case .newest: built.sort { ($0.utxo.confirmations ?? 0) < ($1.utxo.confirmations ?? 0) }
        case .oldest: built.sort { ($0.utxo.confirmations ?? 0) > ($1.utxo.confirmations ?? 0) }
        case .largest: built.sort { $0.utxo.amount > $1.utxo.amount }
        case .smallest: built.sort { $0.utxo.amount < $1.utxo.amount }
        }
        items = built
        // A timelock that hasn't passed can't be part of a spend.
        selected = selected.filter { outpoint in !(items.first { $0.utxo.outpoint == outpoint }?.isTimelocked ?? false) }
        tableView.reloadData()
        updateSelectionBar()
    }

    private func deleteThisWalletsCachedUtxos(completion: @escaping () -> Void) {
        guard let walletId = wallet?.id else {
            completion()
            return
        }
        let ids = allCachedUtxos.map { UTXO(from: $0) }.filter { $0.walletId == walletId }.compactMap { $0.id }
        guard !ids.isEmpty else {
            completion()
            return
        }
        let group = DispatchGroup()
        for id in ids {
            group.enter()
            CoreDataService.deleteEntity(id: id, entityName: .utxos) { _ in group.leave() }
        }
        group.notify(queue: .global(qos: .background)) { completion() }
    }

    private func cacheUtxos(_ utxos: [UTXO]) {
        guard let walletId = wallet?.id, !utxos.isEmpty else {
            setLoading(false)
            return
        }
        let group = DispatchGroup()
        for utxo in utxos {
            var dict: [String: Any] = [:]
            dict["walletId"] = walletId
            dict["amount"] = utxo.amount
            dict["address"] = utxo.address ?? ""
            dict["txid"] = utxo.txid
            dict["vout"] = utxo.vout
            dict["label"] = utxo.label ?? ""
            dict["desc"] = utxo.desc ?? ""
            dict["confirmations"] = utxo.confirmations
            dict["solvable"] = utxo.solvable
            dict["spendable"] = utxo.spendable
            dict["lastUpdated"] = Date()
            dict["id"] = utxo.id
            dict["reused"] = utxo.reused
            if let witnessScript = utxo.witnessScript {
                dict["witnessScript"] = witnessScript
            }
            // Silent payment tweaks stay encrypted at rest.
            if let tweak = utxo.spTweakHex.flatMap({ SPHexFN.decode($0) }), let encrypted = Crypto.encrypt(tweak) {
                dict["spTweak"] = encrypted
            }
            if let label = utxo.spLabelTweakHex.flatMap({ SPHexFN.decode($0) }), let encrypted = Crypto.encrypt(label) {
                dict["spLabelTweak"] = encrypted
            }
            group.enter()
            CoreDataService.saveEntity(dict: dict, entityName: .utxos) { _ in group.leave() }
        }
        group.notify(queue: .main) { [weak self] in self?.setLoading(false) }
    }

    func saveLastSavedUtxosDate() {
        UserDefaults.standard.set(Date(), forKey: "lastSavedUtxosDate")
        let display = displaySavedDate()
        DispatchQueue.main.async { [weak self] in
            self?.lastUpdated = display
        }
    }

    func displaySavedDate() -> String? {
        guard let savedDate = UserDefaults.standard.object(forKey: "lastSavedUtxosDate") as? Date else { return nil }
        return savedDate.formattedDate
    }

    // MARK: Selection (coin control)

    @objc private func toggleSelecting() {
        isSelecting.toggle()
        if !isSelecting { selected.removeAll() }
        updateNavigationItems()
        tableView.reloadData()
        updateSelectionBar()
    }

    private func toggleSelection(_ item: UTXOItem) {
        guard !item.isTimelocked else {
            SuccessView.toast("Timelocked: it can't be spent yet", in: self)
            return
        }
        let outpoint = item.utxo.outpoint
        if selected.contains(outpoint) {
            selected.remove(outpoint)
        } else {
            selected.insert(outpoint)
        }
        updateSelectionBar()
    }

    private var selectedItems: [UTXOItem] { items.filter { selected.contains($0.utxo.outpoint) } }

    private func updateSelectionBar() {
        let show = isSelecting
        let chosen = selectedItems
        let total = chosen.reduce(0) { $0 + $1.utxo.amount }
        selectionBar.configure(count: chosen.count, total: total, fxRate: fxRate, tint: tint)
        selectionBar.isHidden = !show
        view.layoutIfNeeded()
        let barHeight = show ? selectionBar.bounds.height : 0
        tableView.contentInset.bottom = barHeight
        tableView.verticalScrollIndicatorInsets.bottom = barHeight
    }

    @objc private func spendSelected() {
        let chosen = selectedItems.map { $0.utxo }
        guard !chosen.isEmpty else { return }
        spend(chosen)
    }

    // MARK: Actions

    private func spend(_ utxos: [UTXO]) {
        guard let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "CreateRawTx") as? CreateRawTxViewController else { return }
        vc.inputs = utxos.map { ["txid": $0.txid, "vout": $0.vout, "sequence": 1] }
        vc.utxoTotal = utxos.reduce(0) { $0 + $1.amount }
        vc.address = ""
        vc.fxRate = fxRate
        vc.utxoToSweep = utxos.count == 1 ? utxos[0] : nil
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func showLocked() {
        guard let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(withIdentifier: "LockedUtxos") as? LockedViewController else { return }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func lock(_ utxo: UTXO) {
        setLoading(true)
        let param = Lock_Unspent(["unlock": false, "transactions": [["txid": utxo.txid, "vout": utxo.vout]]])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .lockunspent(param)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            guard (response as? Bool) == true else {
                self.setLoading(false)
                displayAlert(viewController: self, isError: true, message: errorDesc ?? "The utxo was not locked.")
                return
            }
            let finish = {
                self.loadCachedUtxos()
                showAlert(vc: self, title: "UTXO locked 🔐", message: "Tap the lock button to see your locked utxos and unlock them. If your node restarts, every utxo is unlocked again.")
            }
            guard let id = utxo.id else {
                finish()
                return
            }
            CoreDataService.deleteEntity(id: id, entityName: .utxos) { _ in finish() }
        }
    }

    /// Proves an output is a silent payment to one of your signers (BIP352 scan of its funding
    /// transaction with each signer's scan key) and saves its tweak on this device, so signing
    /// never has to look it up again. `passphrase`: tried before the stored one / none.
    private func checkSilentPayment(_ utxo: UTXO, passphrase: String? = nil) {
        setLoading(true)
        SilentPaymentSpend.scanKeyCandidates(passphrase: passphrase) { [weak self] keys in
            SilentPaymentSpend.match(outpoints: [(txid: utxo.txid, vout: utxo.vout)], keys: keys, firstOnly: true) { [weak self] matches in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.setLoading(false)
                    guard let match = matches.first else {
                        self.silentPaymentNotFound(utxo)
                        return
                    }
                    self.knownTweaks[utxo.outpoint] = (match.output.tweakHex, match.output.labelTweakHex)
                    self.show(self.utxos)
                    self.persistTweak(match.output, for: utxo, retries: 2)
                    SuccessView.show(in: self, title: "Silent payment verified",
                                     subtitle: "Paid to \(match.signerLabel)'s silent payment address. Its tweak is saved on this device, so it signs without being looked up again.")
                }
            }
        }
    }

    /// Writes the tweak to the cached row. The row can be mid-refresh (rows are replaced on
    /// every load), so it retries briefly; the next refresh saves it anyway from `knownTweaks`.
    private func persistTweak(_ output: SilentPaymentSpend.OwnedOutput, for utxo: UTXO, retries: Int) {
        let current = utxos.first { $0.outpoint == utxo.outpoint }
        guard let id = current?.id ?? utxo.id else { return }
        SilentPaymentSpend.saveTweak(output, utxoId: id) { [weak self] saved in
            guard !saved, retries > 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.persistTweak(output, for: utxo, retries: retries - 1)
            }
        }
    }

    private func silentPaymentNotFound(_ utxo: UTXO) {
        let alert = UIAlertController(title: "Not a silent payment to your signers",
                                      message: "None of your signers' silent payment keys produce this output (their stored passphrases and no passphrase were tried). If the signer uses a passphrase that isn't saved, enter it to check again.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Passphrase"
            field.isSecureTextEntry = true
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Check again", style: .default) { [weak self, weak alert] _ in
            let passphrase = alert?.textFields?.first?.text ?? ""
            guard !passphrase.isEmpty else { return }
            self?.checkSilentPayment(utxo, passphrase: passphrase)
        })
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }

    private func promptToEditLabel(_ utxo: UTXO) {
        guard let address = utxo.address else { return }
        let alert = UIAlertController(title: "Edit label?",
                                      message: "Labels are address based and stored by Bitcoin Core. If you reuse addresses this label applies to every utxo on the address.",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.text = utxo.label
            field.placeholder = "Label"
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self = self, let label = alert?.textFields?.first?.text else { return }
            self.setLoading(true)
            let param: Set_Label_Param = .init(["label": label, "address": address])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .setlabel(param: param)) { [weak self] (_, errorDesc) in
                guard let self = self else { return }
                if let errorDesc = errorDesc {
                    self.setLoading(false)
                    showAlert(vc: self, title: "Error", message: errorDesc)
                    return
                }
                self.loadCachedUtxos()
            }
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func copy(_ text: String?, _ what: String) {
        guard let text = text, !text.isEmpty else {
            showAlert(vc: self, title: "", message: "No \(what.lowercased()) for this utxo.")
            return
        }
        UIPasteboard.general.string = text
        SuccessView.toast("\(what) copied", in: self)
    }

    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            let nav = UINavigationController(rootViewController: TextModalViewController(data: data, viewTitle: title))
            nav.modalPresentationStyle = .fullScreen
            self?.present(nav, animated: true)
        }
    }

    /// Runs one RPC and shows its response as JSON.
    private func showRPC(_ method: BTC_CLI_COMMAND, title: String) {
        setLoading(true)
        MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            self.setLoading(false)
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response.")
                return
            }
            self.showModal(data: response, title: title)
        }
    }

    private func menu(for item: UTXOItem) -> UIMenu {
        let utxo = item.utxo
        var copyActions = [
            UIAction(title: "Copy address", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in self?.copy(utxo.address, "Address") },
            UIAction(title: "Copy transaction ID", image: UIImage(systemName: "number")) { [weak self] _ in self?.copy(utxo.txid, "Transaction ID") },
            UIAction(title: "Copy outpoint", image: UIImage(systemName: "link")) { [weak self] _ in self?.copy(utxo.outpoint, "Outpoint") }
        ]
        if utxo.desc != nil {
            copyActions.append(UIAction(title: "Copy descriptor", image: UIImage(systemName: "doc.text")) { [weak self] _ in self?.copy(utxo.desc, "Descriptor") })
        }
        if let parent = utxo.parentDescs?.first {
            copyActions.append(UIAction(title: "Copy parent descriptor", image: UIImage(systemName: "doc.text.fill")) { [weak self] _ in self?.copy(parent, "Parent descriptor") })
        }

        var infoActions: [UIAction] = []
        if let address = utxo.address {
            infoActions.append(UIAction(title: "Address info", image: UIImage(systemName: "info.circle")) { [weak self] _ in
                self?.showRPC(.getaddressinfo(param: .init(["address": address])), title: "Address Info")
            })
        }
        infoActions.append(UIAction(title: "Transaction info", image: UIImage(systemName: "arrow.left.arrow.right")) { [weak self] _ in
            self?.showRPC(.gettransaction(.init(["txid": utxo.txid, "verbose": true, "include_watchonly": true])), title: "Transaction Info")
        })
        if let desc = utxo.desc {
            infoActions.append(UIAction(title: "Descriptor info", image: UIImage(systemName: "doc.text.magnifyingglass")) { [weak self] _ in
                self?.showRPC(.getdescriptorinfo(param: .init(["descriptor": desc])), title: "Descriptor Info")
            })
        }
        if let parent = utxo.parentDescs?.first {
            infoActions.append(UIAction(title: "Parent descriptor info", image: UIImage(systemName: "doc.text.magnifyingglass")) { [weak self] _ in
                self?.showRPC(.getdescriptorinfo(param: .init(["descriptor": parent])), title: "Parent Descriptor Info")
            })
        }
        infoActions.append(UIAction(title: "Raw UTXO", image: UIImage(systemName: "curlybraces")) { [weak self] _ in
            self?.showModal(data: utxo.rawData, title: "Utxo Info")
        })

        var other: [UIMenuElement] = [
            UIAction(title: "Edit label", image: UIImage(systemName: "pencil")) { [weak self] _ in self?.promptToEditLabel(utxo) }
        ]
        if let sp = item.traits.silentPayment {
            other.append(UIAction(title: sp.isVerified ? "Re-check SP info" : "Check SP info", image: UIImage(systemName: "eye.slash")) { [weak self] _ in
                self?.checkSilentPayment(utxo)
            })
        } else {
            // Nodeless sweeps go through BDK, which can't spend a silent payment output.
            if utxo.parentDescs?.isEmpty == false, utxo.address != nil {
                other.append(UIAction(title: "Sweep without node (Nodeless)", image: UIImage(systemName: "antenna.radiowaves.left.and.right.slash")) { [weak self] _ in
                    self?.sweepUtxo(utxo)
                })
            }
        }

        return UIMenu(children: [
            UIMenu(title: "", options: .displayInline, children: copyActions),
            UIMenu(title: "Info", image: UIImage(systemName: "info.circle"), children: infoActions),
            UIMenu(title: "", options: .displayInline, children: other)
        ])
    }

    /// Sweep one output without the node (BDK + Esplora), signed by the matching signer.
    private func sweepUtxo(_ utxo: UTXO) {
        guard let wallet = wallet,
              let parentDesc = utxo.parentDescs?.first,
              let inputAddress = utxo.address,
              let network = WalletLogic.shared.bdkNetwork() else { return }

        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let self = self else { return }
            guard let signers = signers, !signers.isEmpty else {
                showAlert(title: "", message: "No signers present.")
                return
            }

            let fingerprint = Descriptor(parentDesc).fingerprint
            let signer = signers.map { SignerStruct(dictionary: $0) }.first { signer in
                guard signer.words != nil,
                      let encryptedXfp = signer.xfp,
                      let xfp = Crypto.decrypt(encryptedXfp)?.utf8String else { return false }
                return fingerprint.contains(xfp)
            }

            let esploraUtxo = Esplora_Utxo(txid: utxo.txid,
                                           vout: utxo.vout,
                                           value: Int64((utxo.amount * 100_000_000).rounded()),
                                           status: .init(confirmed: true, blockHeight: nil, blockHash: nil, blockTime: nil),
                                           address: inputAddress)
            do {
                let bdkWallet = try WalletLogic.shared.bdkWalletFromDescriptors(recDesc: parentDesc, changeDesc: wallet.changeDescriptor)
                DispatchQueue.main.async {
                    let vc = SweepViewController(utxos: [esploraUtxo], watchOnlyBdkWallet: bdkWallet, signer: signer, network: network)
                    self.navigationController?.pushViewController(vc, animated: true)
                }
            } catch {
                showAlert(title: "Unable to build the wallet", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - Table

extension UTXOViewController: UITableViewDataSource, UITableViewDelegate {

    // One card per section (summary, then each utxo, or the empty row): inside an
    // inset-grouped section UIKit clips the edges where cells meet, which would hide the
    // borders between cards.
    func numberOfSections(in tableView: UITableView) -> Int { 1 + max(visibleItems.count, 1) }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    /// The utxo shown in `section`, if any.
    private func item(inSection section: Int) -> UTXOItem? {
        let visible = visibleItems
        let index = section - 1
        return visible.indices.contains(index) ? visible[index] : nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: UTXOSummaryCell.identifier, for: indexPath) as! UTXOSummaryCell
            let counts = Dictionary(uniqueKeysWithValues: Filter.allCases.map { f in (f, items.filter { f.matches($0) }.count) })
            let sortMenu = UIMenu(children: Sort.allCases.map { option in
                UIAction(title: option.title, state: option == sort ? .on : .off) { [weak self] _ in
                    self?.sort = option
                    self?.rebuildItems()
                }
            })
            cell.configure(items: items, fxRate: fxRate, filter: filter, counts: counts, sortTitle: sort.title,
                           sortMenu: sortMenu, lastUpdated: lastUpdated, tint: tint) { [weak self] newFilter in
                guard let self = self else { return }
                self.filter = newFilter
                self.tableView.reloadData()
            }
            return cell
        }

        guard let item = item(inSection: indexPath.section) else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty", for: indexPath)
            var content = UIListContentConfiguration.cell()
            content.text = items.isEmpty
                ? (spinner.isAnimating ? "Loading utxos…" : "No unspent outputs.")
                : "No utxos match \"\(filter.title)\"."
            content.textProperties.font = WalletTheme.mono(13)
            content.textProperties.color = WalletTheme.dim
            content.textProperties.alignment = .center
            cell.contentConfiguration = content
            cell.selectionStyle = .none
            cell.backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 0)
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: UTXOCardCell.identifier, for: indexPath) as! UTXOCardCell
        cell.configure(item: item,
                       wallet: wallet,
                       fxRate: fxRate,
                       isSelecting: isSelecting,
                       isSelected: selected.contains(item.utxo.outpoint),
                       menu: menu(for: item),
                       tint: tint,
                       onSpend: { [weak self] in self?.spend([item.utxo]) },
                       onLock: { [weak self] in self?.lock(item.utxo) },
                       onCheckSilentPayment: { [weak self] in self?.checkSilentPayment(item.utxo) })
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard isSelecting, let item = item(inSection: indexPath.section) else { return }
        toggleSelection(item)
        UIView.performWithoutAnimation {
            tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 4 }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { .leastNonzeroMagnitude }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }
}

// MARK: - Small views

/// Monospaced pill: "SILENT PAYMENT", "UNCONFIRMED", …
final class UTXOBadge: UILabel {
    private let insets = UIEdgeInsets(top: 3, left: 7, bottom: 3, right: 7)

    convenience init(_ text: String, color: UIColor, filled: Bool = false) {
        self.init(frame: .zero)
        self.text = text
        font = WalletTheme.mono(10, weight: .bold)
        textColor = filled ? WalletTheme.bg : color
        backgroundColor = filled ? color : color.withAlphaComponent(0.12)
        layer.borderColor = color.withAlphaComponent(0.6).cgColor
        layer.borderWidth = 1
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height + insets.top + insets.bottom)
    }
}

/// Explanation box with a coloured edge: silent payment and timelock details.
final class UTXOCallout: UIView {
    private let edge = UIView()
    private let icon = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        edge.translatesAutoresizingMaskIntoConstraints = false
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentMode = .scaleAspectFit
        titleLabel.font = WalletTheme.mono(12, weight: .bold)
        titleLabel.numberOfLines = 0
        detailLabel.font = WalletTheme.mono(11)
        detailLabel.textColor = WalletTheme.text
        detailLabel.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        text.axis = .vertical
        text.spacing = 3
        text.translatesAutoresizingMaskIntoConstraints = false

        addSubview(edge)
        addSubview(icon)
        addSubview(text)
        NSLayoutConstraint.activate([
            edge.leadingAnchor.constraint(equalTo: leadingAnchor),
            edge.topAnchor.constraint(equalTo: topAnchor),
            edge.bottomAnchor.constraint(equalTo: bottomAnchor),
            edge.widthAnchor.constraint(equalToConstant: 3),
            icon.leadingAnchor.constraint(equalTo: edge.trailingAnchor, constant: 10),
            icon.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            text.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 9),
            text.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon systemName: String, title: String, detail: String, color: UIColor) {
        backgroundColor = color.withAlphaComponent(0.08)
        edge.backgroundColor = color
        icon.image = UIImage(systemName: systemName)
        icon.tintColor = color
        titleLabel.text = title
        titleLabel.textColor = color
        detailLabel.text = detail
    }
}

/// Bottom bar in Select mode: how many outputs, their total, and Spend selected.
final class UTXOSelectionBar: UIView {
    let spendButton = UIButton(type: .system)
    private let summaryLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = WalletTheme.card
        let line = UIView()
        line.backgroundColor = WalletTheme.Tint.utxo.line
        line.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = WalletTheme.mono(12, weight: .semibold)
        summaryLabel.textColor = WalletTheme.text
        summaryLabel.numberOfLines = 2
        summaryLabel.adjustsFontSizeToFitWidth = true
        summaryLabel.minimumScaleFactor = 0.8

        let row = UIStackView(arrangedSubviews: [summaryLabel, spendButton])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        spendButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        spendButton.setContentHuggingPriority(.required, for: .horizontal)

        addSubview(line)
        addSubview(row)
        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: topAnchor),
            line.leadingAnchor.constraint(equalTo: leadingAnchor),
            line.trailingAnchor.constraint(equalTo: trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 1),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(count: Int, total: Double, fxRate: Double?, tint: WalletTheme.Tint) {
        if count == 0 {
            summaryLabel.text = "Tap utxos to select them"
        } else {
            var text = "\(count) selected · \(total.btcBalanceWithSpaces) BTC"
            if let fxRate = fxRate { text += "\n\((total * fxRate).fiatString)" }
            summaryLabel.text = text
        }
        spendButton.configuration = WalletTheme.buttonConfiguration(title: "Spend selected", systemImage: "arrow.up.right", filled: true, tint: tint)
        spendButton.isEnabled = count > 0
        spendButton.alpha = count > 0 ? 1 : 0.4
    }
}

// MARK: - Summary cell

/// Totals, the special outputs at a glance, filter chips and sorting.
final class UTXOSummaryCell: UITableViewCell {
    static let identifier = "UTXOSummaryCell"

    private let caption = WalletTheme.caption("> UNSPENT OUTPUTS", tint: .utxo)
    private let totalLabel = UILabel()
    private let fiatLabel = UILabel()
    private let breakdownStack = UIStackView()
    private let chipsStack = UIStackView()
    private let chipsScroll = UIScrollView()
    private let updatedLabel = UILabel()
    private let sortButton = UIButton(type: .system)
    private var onFilter: ((UTXOViewController.Filter) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        totalLabel.font = WalletTheme.mono(22, weight: .bold)
        totalLabel.textColor = WalletTheme.text
        totalLabel.adjustsFontSizeToFitWidth = true
        totalLabel.minimumScaleFactor = 0.6
        fiatLabel.font = WalletTheme.mono(12)
        fiatLabel.textColor = WalletTheme.dim

        breakdownStack.axis = .vertical
        breakdownStack.spacing = 4

        chipsStack.axis = .horizontal
        chipsStack.spacing = 8
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsScroll.showsHorizontalScrollIndicator = false
        chipsScroll.addSubview(chipsStack)
        chipsScroll.translatesAutoresizingMaskIntoConstraints = false

        updatedLabel.font = WalletTheme.mono(10)
        updatedLabel.textColor = WalletTheme.dim
        updatedLabel.numberOfLines = 0
        sortButton.showsMenuAsPrimaryAction = true
        sortButton.setContentHuggingPriority(.required, for: .horizontal)
        sortButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        let footer = UIStackView(arrangedSubviews: [updatedLabel, sortButton])
        footer.alignment = .center
        footer.spacing = 8

        let stack = UIStackView(arrangedSubviews: [caption, totalLabel, fiatLabel, breakdownStack, chipsScroll, footer])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(2, after: totalLabel)
        stack.setCustomSpacing(12, after: breakdownStack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            chipsStack.topAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.bottomAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.leadingAnchor),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScroll.contentLayoutGuide.trailingAnchor),
            chipsStack.heightAnchor.constraint(equalTo: chipsScroll.frameLayoutGuide.heightAnchor),
            chipsScroll.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(items: [UTXOItem],
                   fxRate: Double?,
                   filter: UTXOViewController.Filter,
                   counts: [UTXOViewController.Filter: Int],
                   sortTitle: String,
                   sortMenu: UIMenu,
                   lastUpdated: String?,
                   tint: WalletTheme.Tint,
                   onFilter: @escaping (UTXOViewController.Filter) -> Void) {
        self.onFilter = onFilter
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 0)
        WalletTheme.squareCorners(self)

        let total = items.reduce(0) { $0 + $1.utxo.amount }
        totalLabel.text = "\(total.btcBalanceWithSpaces) BTC"
        fiatLabel.text = fxRate.map { "\((total * $0).fiatString) · \(items.count) utxo\(items.count == 1 ? "" : "s")" }
            ?? "\(items.count) utxo\(items.count == 1 ? "" : "s")"

        // The outputs that need attention, with their share of the balance.
        breakdownStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        func addLine(_ icon: String, _ title: String, _ matching: [UTXOItem], _ color: UIColor) {
            guard !matching.isEmpty else { return }
            let amount = matching.reduce(0) { $0 + $1.utxo.amount }
            let image = UIImageView(image: UIImage(systemName: icon))
            image.tintColor = color
            image.contentMode = .scaleAspectFit
            image.widthAnchor.constraint(equalToConstant: 16).isActive = true
            let label = UILabel()
            label.font = WalletTheme.mono(11, weight: .semibold)
            label.textColor = color
            label.numberOfLines = 0
            label.text = "\(title): \(amount.btcBalanceWithSpaces) BTC (\(matching.count))"
            let row = UIStackView(arrangedSubviews: [image, label])
            row.spacing = 8
            breakdownStack.addArrangedSubview(row)
        }
        addLine("eye.slash", "Silent payments", items.filter { $0.traits.silentPayment != nil }, UTXOCardCell.silentPaymentColor)
        addLine("hourglass", "Timelocked", items.filter { $0.isTimelocked }, WalletTheme.pending)
        addLine("clock", "Unconfirmed", items.filter { $0.traits.isUnconfirmed }, WalletTheme.pending)
        breakdownStack.isHidden = breakdownStack.arrangedSubviews.isEmpty

        chipsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for option in UTXOViewController.Filter.allCases {
            let count = counts[option] ?? 0
            // Hide empty special filters (but always offer All and Spendable).
            guard option == .all || option == .spendable || count > 0 || option == filter else { continue }
            let chip = UIButton(type: .system)
            var config = WalletTheme.chipConfiguration(title: "\(option.title) \(count)", tint: tint, fontSize: 11, imageSize: 10, imagePadding: 4,
                                                       insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10),
                                                       background: option == filter ? tint.accent : WalletTheme.card)
            config.baseForegroundColor = option == filter ? WalletTheme.bg : tint.accent
            chip.configuration = config
            chip.addAction(UIAction { [weak self] _ in self?.onFilter?(option) }, for: .touchUpInside)
            chipsStack.addArrangedSubview(chip)
        }

        updatedLabel.text = lastUpdated.map { "Updated \($0)" } ?? "Not updated yet"
        sortButton.configuration = WalletTheme.chipConfiguration(title: sortTitle, systemImage: "arrow.up.arrow.down", tint: tint, fontSize: 11, imageSize: 10, imagePadding: 4,
                                                                 insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        sortButton.menu = sortMenu
    }
}

// MARK: - UTXO card cell

final class UTXOCardCell: UITableViewCell {
    static let identifier = "UTXOCardCell"
    /// Silent payments stand out in the signer purple (they're tied to a signer's keys).
    static let silentPaymentColor = SignerTheme.accent

    private let amountLabel = UILabel()
    private let fiatLabel = UILabel()
    private let checkImage = UIImageView()
    private let badgesStack = UIStackView()
    private let badgesScroll = UIScrollView()
    private let silentPaymentCallout = UTXOCallout()
    private let timelockCallout = UTXOCallout()
    private let labelLabel = UILabel()
    private let addressLabel = UILabel()
    private let outpointLabel = UILabel()
    private let confirmationsLabel = UILabel()
    private let ownerLabel = UILabel()
    private let spendButton = UIButton(type: .system)
    private let lockButton = UIButton(type: .system)
    private let moreButton = UIButton(type: .system)
    private let checkSilentPaymentButton = UIButton(type: .system)
    private let actionsRow = UIStackView()
    private var onSpend: (() -> Void)?
    private var onLock: (() -> Void)?
    private var onCheckSilentPayment: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        amountLabel.font = WalletTheme.mono(18, weight: .bold)
        amountLabel.textColor = WalletTheme.text
        amountLabel.adjustsFontSizeToFitWidth = true
        amountLabel.minimumScaleFactor = 0.7
        fiatLabel.font = WalletTheme.mono(11)
        fiatLabel.textColor = WalletTheme.dim
        let amountStack = UIStackView(arrangedSubviews: [amountLabel, fiatLabel])
        amountStack.axis = .vertical
        amountStack.spacing = 2

        checkImage.contentMode = .scaleAspectFit
        checkImage.setContentHuggingPriority(.required, for: .horizontal)
        checkImage.widthAnchor.constraint(equalToConstant: 24).isActive = true
        checkImage.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let topRow = UIStackView(arrangedSubviews: [amountStack, checkImage])
        topRow.alignment = .center
        topRow.spacing = 10

        badgesStack.axis = .horizontal
        badgesStack.spacing = 6
        badgesStack.translatesAutoresizingMaskIntoConstraints = false
        badgesScroll.showsHorizontalScrollIndicator = false
        badgesScroll.addSubview(badgesStack)

        labelLabel.font = WalletTheme.mono(13, weight: .semibold)
        labelLabel.textColor = WalletTheme.text
        labelLabel.numberOfLines = 2
        for label in [addressLabel, outpointLabel, confirmationsLabel, ownerLabel] {
            label.font = WalletTheme.mono(11)
            label.textColor = WalletTheme.dim
            label.lineBreakMode = .byTruncatingMiddle
        }

        for button in [spendButton, lockButton, moreButton] {
            button.setContentHuggingPriority(.required, for: .horizontal)
        }
        spendButton.addAction(UIAction { [weak self] _ in self?.onSpend?() }, for: .touchUpInside)
        lockButton.addAction(UIAction { [weak self] _ in self?.onLock?() }, for: .touchUpInside)
        checkSilentPaymentButton.addAction(UIAction { [weak self] _ in self?.onCheckSilentPayment?() }, for: .touchUpInside)
        checkSilentPaymentButton.accessibilityHint = "Proves it's a silent payment to one of your signers and saves its tweak on this device"
        checkSilentPaymentButton.contentHorizontalAlignment = .leading
        moreButton.showsMenuAsPrimaryAction = true
        moreButton.accessibilityLabel = "More actions"
        lockButton.accessibilityLabel = "Lock this utxo"
        actionsRow.addArrangedSubview(spendButton)
        actionsRow.addArrangedSubview(lockButton)
        actionsRow.addArrangedSubview(UIView())
        actionsRow.addArrangedSubview(moreButton)
        actionsRow.spacing = 8
        actionsRow.alignment = .center

        let details = UIStackView(arrangedSubviews: [addressLabel, outpointLabel, confirmationsLabel, ownerLabel])
        details.axis = .vertical
        details.spacing = 3

        let stack = UIStackView(arrangedSubviews: [topRow, badgesScroll, silentPaymentCallout, checkSilentPaymentButton, timelockCallout, labelLabel, details, actionsRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            badgesStack.topAnchor.constraint(equalTo: badgesScroll.contentLayoutGuide.topAnchor),
            badgesStack.bottomAnchor.constraint(equalTo: badgesScroll.contentLayoutGuide.bottomAnchor),
            badgesStack.leadingAnchor.constraint(equalTo: badgesScroll.contentLayoutGuide.leadingAnchor),
            badgesStack.trailingAnchor.constraint(equalTo: badgesScroll.contentLayoutGuide.trailingAnchor),
            badgesStack.heightAnchor.constraint(equalTo: badgesScroll.frameLayoutGuide.heightAnchor),
            badgesScroll.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: UTXOItem,
                   wallet: Wallet?,
                   fxRate: Double?,
                   isSelecting: Bool,
                   isSelected: Bool,
                   menu: UIMenu,
                   tint: WalletTheme.Tint,
                   onSpend: @escaping () -> Void,
                   onLock: @escaping () -> Void,
                   onCheckSilentPayment: @escaping () -> Void) {
        self.onSpend = onSpend
        self.onLock = onLock
        self.onCheckSilentPayment = onCheckSilentPayment
        let utxo = item.utxo
        let traits = item.traits
        let sp = traits.silentPayment

        // Card: purple edge for silent payments, highlighted when selected, dimmed when it
        // can't be selected.
        var background = WalletTheme.cardConfiguration(tint: tint, highlighted: isSelected, horizontalInset: 0)
        if sp != nil, !isSelected {
            background.strokeColor = Self.silentPaymentColor.withAlphaComponent(0.6)
        }
        backgroundConfiguration = background
        WalletTheme.squareCorners(self)
        contentView.alpha = (isSelecting && item.isTimelocked) ? 0.5 : 1

        amountLabel.text = "\(utxo.amount.btcBalanceWithSpaces) BTC"
        fiatLabel.text = fxRate.map { (utxo.amount * $0).fiatString }
        fiatLabel.isHidden = fxRate == nil

        checkImage.isHidden = !isSelecting
        checkImage.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        checkImage.tintColor = isSelected ? tint.accent : WalletTheme.dim

        // Badges, most important first.
        badgesStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var badges: [UTXOBadge] = []
        if let sp = sp {
            badges.append(sp.isVerified
                          ? UTXOBadge("SILENT PAYMENT", color: Self.silentPaymentColor, filled: true)
                          : UTXOBadge("SP? UNVERIFIED", color: Self.silentPaymentColor))
        }
        if let state = item.timelockState {
            switch state {
            case .locked: badges.append(UTXOBadge(item.isTimelocked ? "TIMELOCKED" : "TIMELOCKED PATH", color: WalletTheme.pending, filled: item.isTimelocked))
            case .open: badges.append(UTXOBadge("TIMELOCK PASSED", color: tint.accent))
            case .unknown: badges.append(UTXOBadge("TIMELOCK", color: WalletTheme.pending))
            }
        }
        if traits.isUnconfirmed { badges.append(UTXOBadge("UNCONFIRMED", color: WalletTheme.pending)) }
        if traits.isUnsafe { badges.append(UTXOBadge("UNSAFE", color: WalletTheme.danger)) }
        if traits.isDust { badges.append(UTXOBadge("DUST", color: WalletTheme.danger)) }
        if traits.isReused { badges.append(UTXOBadge("REUSED ADDRESS", color: WalletTheme.pending)) }
        if traits.isChange == true, sp == nil { badges.append(UTXOBadge("CHANGE", color: WalletTheme.dim)) }
        if let type = traits.scriptType { badges.append(UTXOBadge(type.rawValue, color: WalletTheme.dim)) }
        badges.forEach { badgesStack.addArrangedSubview($0) }
        badgesScroll.isHidden = badges.isEmpty
        badgesScroll.contentOffset = .zero

        // Silent payment callout, and the check button until it's verified.
        if let sp = sp {
            if sp.isVerified {
                silentPaymentCallout.configure(icon: "checkmark.seal",
                                               title: "Silent payment · verified",
                                               detail: "Proven yours by the BIP352 scan" + (sp.isLabeled ? ", paid to a labeled silent payment address (e.g. your change label)" : "") + ". Its tweak is saved on this device, so Fully Noded signs it with your spend key plus that tweak without looking anything up.",
                                               color: Self.silentPaymentColor)
            } else {
                silentPaymentCallout.configure(icon: "eye.slash",
                                               title: "Possible silent payment",
                                               detail: "A bare taproot key (rawtr), which is how Fully Noded Server imports silent payments. Check it to prove it's yours and save its tweak on this device.",
                                               color: Self.silentPaymentColor)
            }
            silentPaymentCallout.isHidden = false
        } else {
            silentPaymentCallout.isHidden = true
        }
        let showCheck = sp != nil && sp?.isVerified == false && !isSelecting
        checkSilentPaymentButton.isHidden = !showCheck
        if showCheck {
            var config = WalletTheme.chipConfiguration(title: "Check SP info", systemImage: "eye.slash", tint: tint, fontSize: 12, imageSize: 11, imagePadding: 5,
                                                       insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            config.baseForegroundColor = Self.silentPaymentColor
            config.background.strokeColor = Self.silentPaymentColor.withAlphaComponent(0.6)
            checkSilentPaymentButton.configuration = config
        }

        // Timelock callout.
        if let state = item.timelockState, let timelock = traits.timelock {
            let alternative = timelock.isAlternativePath
                ? " This lock only guards one spending path (e.g. a recovery key); the other path isn't locked."
                : ""
            switch state {
            case .locked(let title, let detail):
                timelockCallout.configure(icon: "hourglass", title: title, detail: detail + alternative, color: WalletTheme.pending)
            case .open(let title, let detail):
                timelockCallout.configure(icon: "lock.open", title: title, detail: detail + alternative, color: tint.accent)
            case .unknown(let title, let detail):
                timelockCallout.configure(icon: "hourglass", title: title, detail: detail + alternative, color: WalletTheme.pending)
            }
            timelockCallout.isHidden = false
        } else {
            timelockCallout.isHidden = true
        }

        // Label (display only). Fully Noded Server's machine label ("sp scan=… t=…") isn't
        // shown as if it were yours.
        var label = utxo.label ?? ""
        if label.hasPrefix("sp scan=") { label = "" }
        labelLabel.text = label.isEmpty ? "No label" : label
        labelLabel.textColor = label.isEmpty ? WalletTheme.dim : WalletTheme.text

        addressLabel.text = utxo.address.map { "address  \($0)" } ?? "address  unknown"
        outpointLabel.text = "outpoint \(utxo.outpoint)"
        if let confs = utxo.confirmations {
            confirmationsLabel.text = "confs    \(confs.formatted())"
            confirmationsLabel.textColor = confs == 0 ? WalletTheme.pending : WalletTheme.dim
        } else {
            confirmationsLabel.text = "confs    ?"
            confirmationsLabel.textColor = WalletTheme.dim
        }
        let walletLabel = wallet?.label ?? (UserDefaults.standard.string(forKey: "walletName") ?? "this wallet")
        if utxo.solvable == false {
            ownerLabel.text = "owner    not solvable by \(walletLabel)"
            ownerLabel.textColor = WalletTheme.danger
        } else {
            ownerLabel.text = "owner    \(walletLabel)"
            ownerLabel.textColor = WalletTheme.dim
        }

        // Actions: hidden while selecting (tap the card instead).
        actionsRow.isHidden = isSelecting
        var spendConfig = WalletTheme.chipConfiguration(title: item.isTimelocked ? "Locked" : "Spend",
                                                        systemImage: item.isTimelocked ? "hourglass" : "arrow.up.right",
                                                        tint: tint, fontSize: 12, imageSize: 11, imagePadding: 5,
                                                        insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        if item.isTimelocked { spendConfig.baseForegroundColor = WalletTheme.pending }
        spendButton.configuration = spendConfig
        spendButton.isEnabled = !item.isTimelocked
        spendButton.accessibilityHint = item.isTimelocked ? "Timelocked: it can't be spent yet" : "Spend this utxo"
        lockButton.configuration = WalletTheme.chipConfiguration(title: "Lock", systemImage: "lock", tint: tint, fontSize: 12, imageSize: 11, imagePadding: 5,
                                                                 insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        moreButton.configuration = WalletTheme.chipConfiguration(title: "", systemImage: "ellipsis", tint: tint, fontSize: 12, imageSize: 13, imagePadding: 0,
                                                                 insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        moreButton.menu = menu

        accessibilityElements = nil
    }
}
