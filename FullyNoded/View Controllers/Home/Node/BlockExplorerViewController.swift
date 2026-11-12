//
//  BlockExplorerViewController.swift
//  FullyNoded
//
//  A visual block explorer on the active node. Blocks run left to right in ascending order, with
//  the next block being mined at the right end: swipe the strip, or swipe the details below it.
//  Everything comes from the node, so nothing about what you look at leaves it.
//

import UIKit

final class BlockExplorerViewController: UIViewController {
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    private enum Section: Int, CaseIterable { case stats, map, transactions }
    private enum MapState {
        case idle
        case loading
        case loaded([ExplorerMapTx])
        case failed(String)
    }
    private enum DetailState {
        case loading
        case loaded(ExplorerBlockDetail)
        case failed(String)
    }

    private let service = BlockExplorerService()
    private let tint = WalletTheme.Tint.explorer
    private var tip: BlockExplorerService.ChainTip?
    /// The height shown below the strip; `tip.height + 1` is the next block.
    private var selected: Int?
    private var detail = DetailState.loading { didSet { cachedRows = nil } }
    private var mapState = MapState.idle { didSet { cachedRows = nil } }
    /// Sorting a whole block for every row drawn would stutter.
    private var cachedRows: [(txid: String, tx: ExplorerMapTx?)]?
    private var mempool: [String: Any]?
    private var shownTransactions = BlockExplorerViewController.pageSize
    private var pollTimer: Timer?
    private var selectionWork: DispatchWorkItem?
    private var lastBlockTime: Int?
    private var didScrollToTip = false
    private var isPolling = false
    /// A new tip waits on one more call. On a slow link the next poll can see the same tip meanwhile,
    /// and applying it twice would insert the same blocks twice, which the strip can't survive.
    private var isCheckingNewTip = false
    private var wallet: ExplorerWalletActivity?
    private var previousTip: BlockExplorerService.ChainTip?
    private var pace = ExplorerChainSchedule.targetSpacing

    private static let pageSize = 50
    private static let pollInterval: TimeInterval = 12
    private static let itemSize = CGSize(width: 118, height: 158)
    private static let itemSpacing: CGFloat = 14

    private lazy var strip: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = Self.itemSize
        layout.minimumLineSpacing = Self.itemSpacing
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.showsHorizontalScrollIndicator = false
        view.decelerationRate = .fast
        view.clipsToBounds = false
        view.dataSource = self
        view.delegate = self
        view.register(ExplorerBlockCell.self, forCellWithReuseIdentifier: ExplorerBlockCell.identifier)
        view.register(ExplorerPendingCell.self, forCellWithReuseIdentifier: ExplorerPendingCell.identifier)
        view.accessibilityIdentifier = "explorer.strip"
        return view
    }()
    private let table = UITableView(frame: .zero, style: .grouped)
    private let banner = UILabel()
    private let bannerContainer = UIControl()
    private let errorLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Block explorer"
        navigationItem.titleView = makeBrandedTitle()
        // One button that opens into the rest, which leaves the title room to say what app this is.
        var actions = [
            UIAction(title: "Go to block height", image: UIImage(systemName: "number")) { [weak self] _ in self?.jumpTapped() },
            UIAction(title: "Chain dashboard", image: UIImage(systemName: "chart.xyaxis.line")) { [weak self] _ in self?.dashboardTapped() },
            UIAction(title: "Famous blocks and coins", image: UIImage(systemName: "sparkles")) { [weak self] _ in self?.famousTapped() }
        ]
        // Only with an active wallet: there's nothing to skip to otherwise.
        if UserDefaults.standard.string(forKey: "walletName") != nil {
            actions.insert(UIAction(title: "Your coins", image: UIImage(systemName: "bitcoinsign.circle")) { [weak self] _ in self?.coinsTapped() }, at: 0)
        }
        let tools = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: UIMenu(children: actions))
        tools.accessibilityLabel = "Explorer tools"
        navigationItem.rightBarButtonItem = tools
        WalletTheme.apply(to: self, tint: tint)
        buildLayout()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        poll()
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pollTimer?.invalidate()
        pollTimer = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // The first and last blocks can reach the centre.
        let inset = max((strip.bounds.width - Self.itemSize.width) / 2, 0)
        if let layout = strip.collectionViewLayout as? UICollectionViewFlowLayout, layout.sectionInset.left != inset {
            layout.sectionInset = UIEdgeInsets(top: 0, left: inset, bottom: 0, right: inset)
            layout.invalidateLayout()
        }
        if !didScrollToTip, tip != nil, strip.bounds.width > 0 { scrollToSelected(animated: false) }
    }

    private func buildLayout() {
        strip.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(strip)

        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 60
        table.sectionHeaderTopPadding = 0
        table.register(ExplorerStatsCell.self, forCellReuseIdentifier: ExplorerStatsCell.identifier)
        table.register(ExplorerMapCell.self, forCellReuseIdentifier: ExplorerMapCell.identifier)
        table.register(ExplorerTxCell.self, forCellReuseIdentifier: ExplorerTxCell.identifier)
        table.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(table)

        // Swiping the details moves through blocks too: left is forward in time, like the strip.
        for direction in [UISwipeGestureRecognizer.Direction.left, .right] {
            let swipe = UISwipeGestureRecognizer(target: self, action: #selector(detailsSwiped(_:)))
            swipe.direction = direction
            table.addGestureRecognizer(swipe)
        }

        let rule = UIView()
        rule.backgroundColor = tint.line
        rule.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rule)

        banner.font = WalletTheme.mono(13, weight: .bold)
        banner.textColor = WalletTheme.bg
        banner.textAlignment = .center
        banner.numberOfLines = 0
        banner.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.backgroundColor = tint.accent
        bannerContainer.alpha = 0
        bannerContainer.isHidden = true
        bannerContainer.addTarget(self, action: #selector(bannerTapped), for: .touchUpInside)
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.addSubview(banner)
        view.addSubview(bannerContainer)

        errorLabel.font = WalletTheme.mono(13)
        errorLabel.textColor = WalletTheme.pending
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.isHidden = true
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(errorLabel)

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            strip.topAnchor.constraint(equalTo: guide.topAnchor, constant: 14),
            strip.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            strip.heightAnchor.constraint(equalToConstant: Self.itemSize.height),
            rule.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 12),
            rule.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),
            table.topAnchor.constraint(equalTo: rule.bottomAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bannerContainer.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: 8),
            bannerContainer.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16),
            banner.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: 10),
            banner.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -10),
            banner.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: 10),
            banner.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -10),
            errorLabel.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            errorLabel.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32)
        ])
    }

    // MARK: - The chain tip

    private func poll() {
        guard !isPolling else { return }
        isPolling = true
        service.tip { [weak self] result in
            guard let self = self else { return }
            self.isPolling = false
            switch result {
            case .failure(let error):
                // Keep showing what we have; say so only if there's nothing to show.
                if self.tip == nil {
                    self.errorLabel.text = "Can't reach your node.\n\n\(error.message)"
                    self.errorLabel.isHidden = false
                }
            case .success(let new):
                self.errorLabel.isHidden = true
                self.received(new)
                self.refreshTimes()
            }
        }
    }

    /// The blocks' "12m ago" and the next block's ETA update together, so they can't disagree.
    private func refreshTimes() {
        for path in strip.indexPathsForVisibleItems { reconfigure(path) }
        if isPendingSelected { table.reloadData() }
    }

    /// What depends on the tip without being part of the strip's data.
    private func refreshAroundTip() {
        service.walletActivity { [weak self] activity in
            guard let self = self else { return }
            self.wallet = activity
            for path in self.strip.indexPathsForVisibleItems { self.reconfigure(path) }
            self.table.reloadData()
        }
        guard let tip = tip else { return }
        service.schedule(tip: tip) { [weak self] schedule in
            // A sane range: a period's odd start shouldn't make the ETA absurd.
            self?.pace = min(max(schedule.spacing, 300), 1200)
            self?.refreshTimes()
        }
    }

    private func received(_ new: BlockExplorerService.ChainTip) {
        defer { if new != previousTip { previousTip = new; refreshAroundTip() } }
        guard let old = tip else {
            tip = new
            selected = new.height
            strip.reloadData()
            view.setNeedsLayout()
            view.layoutIfNeeded()
            scrollToSelected(animated: false)
            selectionChanged()
            refreshVisibleSummaries()
            return
        }
        guard new != old else { return }
        if new.height > old.height {
            guard !isCheckingNewTip else { return }
            isCheckingNewTip = true
            // Normally just the next block; check the old tip is still on this chain.
            service.blockHash(height: old.height, fresh: true) { [weak self] result in
                guard let self = self else { return }
                self.isCheckingNewTip = false
                guard self.tip == old else { return }
                if case .success(let hash) = result, hash != old.hash {
                    self.reorganized(new, from: old)
                } else {
                    self.blocksMined(new, from: old)
                }
            }
        } else if new.height == old.height && new.hash == old.hash {
            tip = new
        } else {
            reorganized(new, from: old)
        }
    }

    private func blocksMined(_ new: BlockExplorerService.ChainTip, from old: BlockExplorerService.ChainTip) {
        let wasAtTip = selected == old.height
        let wasOnPending = selected == old.height + 1
        tip = new
        let added = (old.height + 1)...new.height
        strip.performBatchUpdates {
            strip.insertItems(at: added.map { IndexPath(item: $0, section: 0) })
        }
        if wasAtTip || wasOnPending {
            selected = wasAtTip ? new.height : new.height + 1
            scrollToSelected(animated: true)
            selectionChanged()
        }
        // The old selection, and the next block's new height.
        for path in strip.indexPathsForVisibleItems { reconfigure(path) }
        refreshVisibleSummaries()
        let count = new.height - old.height
        showBanner(count == 1 ? "⛏ BLOCK \(new.height.withCommas) MINED" : "⛏ \(count) NEW BLOCKS · TIP \(new.height.withCommas)", goToTip: !(wasAtTip || wasOnPending))
        // Once the strip has settled on it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self,
                  let cell = self.strip.cellForItem(at: IndexPath(item: new.height, section: 0)) else {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                return
            }
            self.strip.bringSubviewToFront(cell)
            ExplorerBlockBurst.play(on: cell, color: self.tint.accent)
        }
        // A catch-up after being away isn't news: only blocks arriving one or two at a time.
        if count <= 2 {
            for height in added { checkSoloWin(height) }
        }
    }

    private func checkSoloWin(_ height: Int) {
        service.checkSoloWin(height: height) { [weak self] isSolo, reward in
            guard let self = self, isSolo else { return }
            for path in self.strip.indexPathsForVisibleItems { self.reconfigure(path) }
            let prize = reward.map { value in " · \(ExplorerFormat.btc(value))" + (ExplorerFormat.fiatCompact(btc: value).map { " \($0)" } ?? "") } ?? ""
            self.showBanner("🏆 SOLO MINER WON BLOCK \(height.withCommas)\(prize)", goToTip: true)
            ExplorerBlockBurst.celebrateSoloWin(in: self.view)
        }
    }

    private func reorganized(_ new: BlockExplorerService.ChainTip, from old: BlockExplorerService.ChainTip) {
        // Blocks near the old tip may have changed: forget them and start from the new tip.
        service.forget(from: max(min(new.height, old.height) - 10, 0))
        tip = new
        if let selected = selected, selected > new.height + 1 { self.selected = new.height + 1 }
        strip.reloadData()
        // So its visible cells exist when asked for below.
        strip.layoutIfNeeded()
        scrollToSelected(animated: false)
        selectionChanged()
        refreshVisibleSummaries()
        showBanner("Chain reorganized · tip \(new.height.withCommas)", goToTip: false)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func showBanner(_ text: String, goToTip: Bool) {
        banner.text = goToTip ? text + "  ›" : text
        bannerContainer.isUserInteractionEnabled = goToTip
        bannerContainer.isHidden = false
        UIView.animate(withDuration: 0.25) { self.bannerContainer.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: text)
        let shownText = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self = self, self.banner.text?.hasPrefix(shownText) == true else { return }
            UIView.animate(withDuration: 0.3, animations: { self.bannerContainer.alpha = 0 }) { _ in
                self.bannerContainer.isHidden = true
            }
        }
    }

    @objc private func bannerTapped() {
        guard let tip = tip else { return }
        go(to: tip.height)
    }

    // MARK: - Moving through blocks

    private func scrollToSelected(animated: Bool) {
        guard let selected = selected, strip.bounds.width > 0, strip.numberOfSections > 0,
              selected < strip.numberOfItems(inSection: 0) else { return }
        didScrollToTip = true
        strip.setContentOffset(CGPoint(x: offset(forItem: selected), y: 0), animated: animated)
    }

    private func offset(forItem item: Int) -> CGFloat {
        CGFloat(item) * (Self.itemSize.width + Self.itemSpacing)
    }

    private func item(forOffset x: CGFloat) -> Int {
        let last = (tip?.height ?? 0) + 1
        return min(max(Int((x / (Self.itemSize.width + Self.itemSpacing)).rounded()), 0), last)
    }

    private func go(to height: Int) {
        guard let tip = tip else { return }
        let target = min(max(height, 0), tip.height + 1)
        guard target != selected else { return }
        select(target)
        scrollToSelected(animated: true)
    }

    private func select(_ height: Int) {
        guard height != selected else { return }
        let previous = selected
        selected = height
        UISelectionFeedbackGenerator().selectionChanged()
        var paths = [IndexPath(item: height, section: 0)]
        if let previous = previous { paths.append(IndexPath(item: previous, section: 0)) }
        for path in paths { reconfigure(path) }
        selectionChanged()
    }

    private func reconfigure(_ path: IndexPath) {
        guard let cell = strip.cellForItem(at: path) else { return }
        configure(cell, item: path.item)
    }

    /// The details follow a moment later, so swiping past blocks doesn't load each one.
    private func selectionChanged() {
        selectionWork?.cancel()
        detail = .loading
        mapState = .idle
        mempool = nil
        shownTransactions = Self.pageSize
        table.reloadData()
        table.setContentOffset(.zero, animated: false)
        let work = DispatchWorkItem { [weak self] in self?.loadSelected() }
        selectionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private var isPendingSelected: Bool {
        guard let selected = selected, let tip = tip else { return false }
        return selected == tip.height + 1
    }

    private func loadSelected() {
        guard let height = selected else { return }
        if isPendingSelected {
            service.mempool { [weak self] info in
                guard let self = self, self.isPendingSelected else { return }
                self.mempool = info
                self.table.reloadData()
            }
            if service.isFastConnection { loadMap() }
            return
        }
        service.blockHash(height: height) { [weak self] result in
            guard let self = self, self.selected == height else { return }
            switch result {
            case .failure(let error):
                self.detail = .failed(error.message)
                self.table.reloadData()
            case .success(let hash):
                self.service.detail(hash: hash) { [weak self] result in
                    guard let self = self, self.selected == height else { return }
                    switch result {
                    case .failure(let error):
                        self.detail = .failed(error.message)
                    case .success(let detail):
                        self.detail = .loaded(detail)
                        if let cached = self.service.cachedMap(hash: hash) {
                            self.mapState = .loaded(cached)
                        } else if self.service.isFastConnection {
                            self.loadMap()
                        }
                    }
                    self.table.reloadData()
                }
            }
        }
    }

    private func loadMap() {
        let height = selected
        mapState = .loading
        table.reloadData()
        let finish: (Result<[ExplorerMapTx], ExplorerError>) -> Void = { [weak self] result in
            guard let self = self, self.selected == height else { return }
            switch result {
            case .success(let map): self.mapState = .loaded(map)
            case .failure(let error): self.mapState = .failed(error.message)
            }
            self.table.reloadData()
        }
        if isPendingSelected {
            service.template(completion: finish)
        } else if case .loaded(let detail) = detail {
            service.map(hash: detail.hash, completion: finish)
        }
    }

    private func refreshVisibleSummaries() {
        guard let tip = tip else { return }
        let visible = strip.indexPathsForVisibleItems.map(\.item).filter { $0 <= tip.height }
        // Also a few past each side, so short swipes land on filled blocks.
        let heights = Set(visible.flatMap { [$0 - 2, $0 - 1, $0, $0 + 1, $0 + 2] }).filter { $0 >= 0 && $0 <= tip.height }
        // The queue runs from the end: the one on screen centre comes first.
        let centre = selected ?? tip.height
        let ordered = heights.sorted { abs($0 - centre) > abs($1 - centre) }
        service.requestSummaries(ordered) { [weak self] summary in
            guard let self = self else { return }
            self.reconfigure(IndexPath(item: summary.height, section: 0))
            if summary.height == self.tip?.height {
                self.lastBlockTime = summary.time
                self.reconfigure(IndexPath(item: summary.height + 1, section: 0))
            }
            if summary.height == self.selected { self.table.reloadData() }
        }
        if let time = service.cachedSummary(tip.height)?.time { lastBlockTime = time }
    }

    // MARK: - Actions

    @objc private func detailsSwiped(_ gesture: UISwipeGestureRecognizer) {
        guard let selected = selected else { return }
        go(to: selected + (gesture.direction == .left ? 1 : -1))
    }

    private func dashboardTapped() {
        impact()
        navigationController?.pushViewController(ChainDashboardViewController(), animated: true)
    }

    /// The app's name and logo, small, so a shared screenshot says where it's from.
    private func makeBrandedTitle() -> UIView {
        let logo = UIImageView(image: AppIconSelectorTableViewController.currentIconImage)
        logo.contentMode = .scaleAspectFit
        logo.clipsToBounds = true
        logo.layer.cornerRadius = 5
        logo.widthAnchor.constraint(equalToConstant: 24).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 24).isActive = true
        let name = UILabel()
        name.text = "Block explorer"
        name.font = WalletTheme.mono(14, weight: .semibold)
        name.textColor = tint.accent
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.75
        let brand = UILabel()
        brand.text = "Fully Noded"
        brand.font = WalletTheme.mono(10)
        brand.textColor = WalletTheme.dim
        let text = UIStackView(arrangedSubviews: [name, brand])
        text.axis = .vertical
        let row = UIStackView(arrangedSubviews: [logo, text])
        row.spacing = 6
        row.alignment = .center
        row.isAccessibilityElement = true
        row.accessibilityLabel = "Block explorer, Fully Noded"
        row.accessibilityTraits = .header
        return row
    }

    private func famousTapped() {
        guard let tip = tip else { return }
        impact()
        let famous = ExplorerFamousViewController(service: service, tint: tint, tipHeight: tip.height, isMainnet: tip.chain == "main",
                                                  onBlock: { [weak self] height in self?.go(to: height) })
        presentHalfHeight(UINavigationController(rootViewController: famous))
    }

    private func presentHalfHeight(_ nav: UINavigationController) {
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.largestUndimmedDetentIdentifier = .medium
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    /// Half height, with the strip still live above it, so tapping through blocks shows each one.
    private func coinsTapped() {
        impact()
        let coins = ExplorerCoinsViewController(
            service: service, tint: tint, current: selected,
            pruneHeight: { [weak self] in self?.tip?.pruneHeight },
            onBlock: { [weak self] height in self?.go(to: height) },
            onCoin: { [weak self] coin, height in self?.openCoin(coin, at: height) })
        presentHalfHeight(UINavigationController(rootViewController: coins))
    }

    /// Moves the strip to the coin's block, then opens the transaction that created it.
    private func openCoin(_ coin: ExplorerCoinBlock.Coin, at height: Int) {
        go(to: height)
        func open(_ blockhash: String?) {
            TransactionExplorerViewController.open(txid: coin.txid, blockhash: blockhash, highlightedOutput: coin.vout, service: service, from: self)
        }
        guard coin.confirmations > 0 else {
            open(nil)
            return
        }
        service.blockHash(height: height) { [weak self] result in
            guard self != nil else { return }
            if case .success(let hash) = result { open(hash) } else { open(nil) }
        }
    }

    private func jumpTapped() {
        guard let tip = tip else { return }
        let alert = UIAlertController(title: "Go to block", message: "Height, from 0 to \(tip.height.withCommas).", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .numberPad
            field.placeholder = "\(tip.height)"
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Go", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, let height = Int(text) else { return }
            self?.go(to: min(height, tip.height))
        })
        present(alert, animated: true)
    }

    private func openTransaction(_ txid: String) {
        impact()
        var blockhash: String?
        if case .loaded(let detail) = detail, !isPendingSelected { blockhash = detail.hash }
        TransactionExplorerViewController.open(txid: txid, blockhash: blockhash, service: service, from: self)
    }

    private func showRaw() {
        guard let selected = selected else { return }
        impact()
        let present_: ([String: Any], String) -> Void = { [weak self] data, title in
            let nav = UINavigationController(rootViewController: TextModalViewController(data: data, viewTitle: title))
            nav.modalPresentationStyle = .fullScreen
            self?.present(nav, animated: true)
        }
        if isPendingSelected {
            if let mempool = mempool { present_(mempool, "getmempoolinfo") }
            return
        }
        if case .loaded(let detail) = detail {
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getblock(Get_Block(["blockhash": detail.hash, "verbosity": 1]))) { response, _ in
                DispatchQueue.main.async {
                    if let block = response as? [String: Any] { present_(block, "getblock \(selected)") }
                }
            }
        }
    }

    // MARK: - What the table shows

    /// Transactions in the order listed: by fee rate once the map has them, else the block's own.
    private var transactionRows: [(txid: String, tx: ExplorerMapTx?)] {
        if let cachedRows = cachedRows { return cachedRows }
        var rows: [(txid: String, tx: ExplorerMapTx?)] = []
        if case .loaded(let map) = mapState {
            rows = map.sorted { ($0.feeRate ?? .infinity) > ($1.feeRate ?? .infinity) }.map { ($0.txid, $0) }
        } else if case .loaded(let detail) = detail, !isPendingSelected {
            rows = detail.txids.map { ($0, nil) }
        }
        cachedRows = rows
        return rows
    }

    private func statsRows() -> [(String, String)] {
        guard let selected = selected else { return [] }
        if isPendingSelected {
            var rows: [(String, String)] = [("Height", selected.withCommas)]
            if let time = lastBlockTime {
                rows.append(("Last block", ExplorerFormat.ago(time)))
                rows.append(("ETA", ExplorerFormat.eta(lastBlockTime: time, spacing: pace)))
            }
            if let mempool = mempool {
                if let size = RPCValue.int(mempool["size"]) { rows.append(("Mempool", "\(size.withCommas) txs")) }
                if let bytes = RPCValue.int(mempool["bytes"]) { rows.append(("Mempool size", ExplorerFormat.size(bytes))) }
                if let fee = RPCValue.double(mempool["total_fee"]) { rows.append(("Fees waiting", ExplorerFormat.btcWithFiat(fee))) }
            } else {
                rows.append(("Mempool", "loading…"))
            }
            if case .loaded(let map) = mapState {
                let yours = map.filter { wallet?.txids.contains($0.txid) == true }.count
                if yours > 0 { rows.append(("Your txs", yours.withCommas)) }
                rows.append(("In template", "\(map.count.withCommas) txs"))
                let fees = map.reduce(0.0) { $0 + ($1.feeRate ?? 0) * Double($1.vsize) }
                rows.append(("Template fees", ExplorerFormat.btcWithFiat(fees.rounded() / 100_000_000)))
            }
            return rows
        }
        var rows: [(String, String)] = []
        let summary = service.cachedSummary(selected)
        if let miner = service.cachedMiner(selected) {
            rows.append((miner.isKnown ? "Mined by" : "Coinbase tag", miner.name))
        }
        if case .loaded(let detail) = detail {
            let yours = detail.txids.filter { wallet?.txids.contains($0) == true }.count
            if yours > 0 { rows.append(("Your txs", yours.withCommas)) }
        }
        if case .loaded(let detail) = detail {
            rows.append(("Time", Date(timeIntervalSince1970: TimeInterval(detail.time)).formatted(date: .abbreviated, time: .shortened)))
            rows.append(("Transactions", detail.txids.count.withCommas))
            if let size = detail.size { rows.append(("Size", ExplorerFormat.size(size))) }
            if let weight = detail.weight { rows.append(("Weight", "\(weight.withCommas) WU")) }
        } else if let summary = summary {
            rows.append(("Time", Date(timeIntervalSince1970: TimeInterval(summary.time)).formatted(date: .abbreviated, time: .shortened)))
            rows.append(("Transactions", summary.txCount.withCommas))
        }
        if let reward = summary?.rewardBtc { rows.append(("Reward", ExplorerFormat.btcWithFiat(reward))) }
        if let fees = summary?.totalFeeSats { rows.append(("Fees", ExplorerFormat.btcWithFiat(Double(fees) / 100_000_000))) }
        if let rates = summary?.feeRatePercentiles, rates.count == 5 {
            rows.append(("Median fee", "\(rates[2]) sat/vB"))
            rows.append(("Fee range", "\(rates[0]) – \(rates[4]) sat/vB"))
        }
        if case .loaded(let detail) = detail {
            if let confirmations = detail.confirmations { rows.append(("Confirmations", confirmations.withCommas)) }
            if let difficulty = detail.difficulty { rows.append(("Difficulty", difficulty.withCommas)) }
            if let nonce = detail.nonce { rows.append(("Nonce", "\(nonce)")) }
            rows.append(("Hash", detail.hash))
        }
        return rows
    }

    private var statsNote: String? {
        if case .failed(let message) = detail, !isPendingSelected {
            let lower = message.lowercased()
            if lower.contains("pruned") || lower.contains("not available") {
                return "Your node has pruned this block. Its header is kept, but its transactions are gone from this node."
            }
            return message
        }
        return nil
    }
}

// MARK: - The strip

extension BlockExplorerViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Every block, then the next one.
        tip.map { $0.height + 2 } ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier = indexPath.item == (tip?.height ?? -1) + 1 ? ExplorerPendingCell.identifier : ExplorerBlockCell.identifier
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath)
        configure(cell, item: indexPath.item)
        return cell
    }

    fileprivate func configure(_ cell: UICollectionViewCell, item: Int) {
        let isSelected = item == selected
        if let cell = cell as? ExplorerPendingCell {
            cell.configure(height: item, lastBlockTime: lastBlockTime, spacing: pace, hasYourTx: wallet?.hasUnconfirmed == true,
                           selected: isSelected, accent: tint.accent)
        } else if let cell = cell as? ExplorerBlockCell {
            let pruneHeight = tip?.pruneHeight
            cell.configure(height: item, summary: service.cachedSummary(item), selected: isSelected, accent: tint.accent,
                           miner: service.cachedMiner(item)?.name,
                           isYours: wallet?.heights.contains(item) == true,
                           isSolo: service.isCachedSolo(item),
                           isPruned: pruneHeight.map { item < $0 } ?? false)
        }
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? ExplorerPendingCell)?.startAnimating()
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        (cell as? ExplorerPendingCell)?.stopAnimating()
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        go(to: indexPath.item)
    }

    /// Snaps so one block sits in the centre.
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard scrollView === strip else { return }
        targetContentOffset.pointee.x = offset(forItem: item(forOffset: targetContentOffset.pointee.x))
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === strip, tip != nil, scrollView.isDragging || scrollView.isDecelerating else { return }
        select(item(forOffset: scrollView.contentOffset.x))
        refreshVisibleSummaries()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView === strip else { return }
        refreshVisibleSummaries()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === strip else { return }
        refreshVisibleSummaries()
    }
}

// MARK: - The details

extension BlockExplorerViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        selected == nil ? 0 : Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .stats: return 1
        case .map: return (statsNote == nil) ? 1 : 0
        case .transactions:
            let total = transactionRows.count
            return min(total, shownTransactions) + (total > shownTransactions ? 1 : 0)
        case nil: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .stats:
            let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerStatsCell.identifier, for: indexPath) as! ExplorerStatsCell
            var title = isPendingSelected ? "NEXT BLOCK" : "BLOCK \((selected ?? 0).withCommas)"
            if isPendingSelected, case .loaded = mapState { title += " · YOUR NODE'S TEMPLATE" }
            let showRawButton: Bool
            if isPendingSelected { showRawButton = mempool != nil } else if case .loaded = detail { showRawButton = true } else { showRawButton = false }
            cell.configure(title: title, rows: statsRows(), note: statsNote, showRaw: showRawButton, tint: tint)
            cell.onRaw = { [weak self] in self?.showRaw() }
            return cell
        case .map:
            let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerMapCell.identifier, for: indexPath) as! ExplorerMapCell
            cell.configure(state: mapCellState(), yours: wallet?.txids ?? [], tint: tint)
            cell.onLoad = { [weak self] in self?.loadMap() }
            cell.onSelect = { [weak self] tx in self?.openTransaction(tx.txid) }
            return cell
        default:
            let rows = transactionRows
            let cell = tableView.dequeueReusableCell(withIdentifier: ExplorerTxCell.identifier, for: indexPath) as! ExplorerTxCell
            if indexPath.row < min(rows.count, shownTransactions) {
                let row = rows[indexPath.row]
                cell.configure(txid: row.txid, tx: row.tx, index: indexPath.row, isYours: wallet?.txids.contains(row.txid) == true, tint: tint)
            } else {
                cell.configureMore(remaining: rows.count - shownTransactions, tint: tint)
            }
            return cell
        }
    }

    private func mapCellState() -> ExplorerMapCell.State {
        switch mapState {
        case .loaded(let map): return .map(map)
        case .loading: return .loading
        case .failed(let message): return .failed(message)
        case .idle:
            if case .loaded(let detail) = detail, !isPendingSelected {
                // getblock with every transaction is about six times the block's size as JSON.
                return .offer(detail.size.map { "Load the block map (about \(ExplorerFormat.size($0 * 6)))" } ?? "Load the block map")
            }
            if isPendingSelected { return .offer("Load your node's template") }
            return .waiting
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard Section(rawValue: indexPath.section) == .transactions else { return }
        let rows = transactionRows
        if indexPath.row < min(rows.count, shownTransactions) {
            openTransaction(rows[indexPath.row].txid)
        } else {
            shownTransactions += Self.pageSize
            tableView.reloadData()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard Section(rawValue: section) == .transactions, !transactionRows.isEmpty else { return UIView() }
        let header = UIView()
        var title = "> TRANSACTIONS · \(transactionRows.count.withCommas)"
        if case .loaded = mapState { title += " · BY FEE RATE" }
        let caption = WalletTheme.caption(title, tint: tint)
        caption.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(caption)
        NSLayoutConstraint.activate([
            caption.leadingAnchor.constraint(equalTo: header.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            caption.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -6)
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .stats: return 10
        case .map: return 8
        case .transactions: return transactionRows.isEmpty ? 0.01 : 32
        }
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        Section(rawValue: section) == .transactions ? 30 : 0.01
    }
}

// MARK: - Cells

private final class ExplorerStatsCell: UITableViewCell {
    static let identifier = "ExplorerStatsCell"
    var onRaw: (() -> Void)?
    private let stack = UIStackView()
    private let raw = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        stack.axis = .vertical
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        raw.addTarget(self, action: #selector(rawTapped), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, rows: [(String, String)], note: String?, showRaw: Bool, tint: WalletTheme.Tint) {
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let heading = UILabel()
        heading.text = title
        heading.font = WalletTheme.mono(15, weight: .bold)
        heading.textColor = tint.accent
        heading.numberOfLines = 0
        stack.addArrangedSubview(heading)
        // By character: the hash is one long word.
        for (name, value) in rows { stack.addArrangedSubview(WalletTheme.infoRow(name, value, wrapByCharacter: true)) }
        if let note = note {
            let label = UILabel()
            label.text = note
            label.font = WalletTheme.mono(12)
            label.textColor = WalletTheme.pending
            label.numberOfLines = 0
            stack.addArrangedSubview(label)
        }
        if showRaw {
            raw.configuration = WalletTheme.chipConfiguration(title: "Raw response", systemImage: "curlybraces", tint: tint, fontSize: 12, imageSize: 11, imagePadding: 6,
                                                              insets: NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
            stack.addArrangedSubview(UIStackView(arrangedSubviews: [raw, UIView()]))
        }
    }

    @objc private func rawTapped() { onRaw?() }
}

private final class ExplorerMapCell: UITableViewCell {
    static let identifier = "ExplorerMapCell"
    enum State {
        case waiting
        case offer(String)
        case loading
        case failed(String)
        case map([ExplorerMapTx])
    }

    var onLoad: (() -> Void)?
    var onSelect: ((ExplorerMapTx) -> Void)?
    private let stack = UIStackView()
    private let mapView = ExplorerBlockMapView()
    private let button = UIButton(type: .system)
    private let label = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let legend = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        label.font = WalletTheme.mono(12)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
        label.textAlignment = .center
        button.addTarget(self, action: #selector(loadTapped), for: .touchUpInside)
        mapView.onSelect = { [weak self] tx in self?.onSelect?(tx) }
        mapView.heightAnchor.constraint(equalTo: mapView.widthAnchor, multiplier: 0.8).isActive = true
        legend.spacing = 2
        legend.distribution = .fillEqually
        for (_, title, color) in ExplorerFeeColor.buckets {
            let swatch = UILabel()
            swatch.text = title
            swatch.font = WalletTheme.mono(9, weight: .bold)
            swatch.textAlignment = .center
            swatch.textColor = WalletTheme.bg
            swatch.backgroundColor = color
            legend.addArrangedSubview(swatch)
        }
        legend.isAccessibilityElement = true
        legend.accessibilityLabel = "Fee rate legend, sat per virtual byte"
        for view in [label, button, spinner, mapView, legend] as [UIView] { stack.addArrangedSubview(view) }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -28)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(state: State, yours: Set<String>, tint: WalletTheme.Tint) {
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        spinner.color = tint.accent
        label.isHidden = true
        button.isHidden = true
        spinner.isHidden = true
        spinner.stopAnimating()
        mapView.isHidden = true
        legend.isHidden = true
        switch state {
        case .waiting:
            spinner.isHidden = false
            spinner.startAnimating()
        case .offer(let title):
            button.configuration = WalletTheme.buttonConfiguration(title: title, systemImage: "square.grid.3x3.fill", filled: false, tint: tint)
            button.isHidden = false
            label.text = "Shows every transaction by size and fee rate. Over Tor this can take a minute or more."
            label.isHidden = false
        case .loading:
            spinner.isHidden = false
            spinner.startAnimating()
            label.text = "Loading every transaction from your node…"
            label.isHidden = false
        case .failed(let message):
            label.text = message
            label.textColor = WalletTheme.pending
            label.isHidden = false
            button.configuration = WalletTheme.buttonConfiguration(title: "Try again", systemImage: "arrow.clockwise", filled: false, tint: tint)
            button.isHidden = false
            return
        case .map(let map):
            mapView.configure(map, yours: yours, yoursColor: tint.accent)
            mapView.isHidden = false
            legend.isHidden = false
        }
        label.textColor = WalletTheme.dim
    }

    @objc private func loadTapped() { onLoad?() }
}

private final class ExplorerTxCell: UITableViewCell {
    static let identifier = "ExplorerTxCell"
    private let swatch = UIView()
    private let txidLabel = UILabel()
    private let infoLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        automaticallyUpdatesBackgroundConfiguration = false
        swatch.widthAnchor.constraint(equalToConstant: 6).isActive = true
        txidLabel.font = WalletTheme.mono(12)
        txidLabel.textColor = WalletTheme.text
        txidLabel.numberOfLines = 0
        txidLabel.lineBreakMode = .byCharWrapping
        infoLabel.font = WalletTheme.mono(11, weight: .semibold)
        infoLabel.textColor = WalletTheme.dim
        let column = UIStackView(arrangedSubviews: [txidLabel, infoLabel])
        column.axis = .vertical
        column.spacing = 3
        let row = UIStackView(arrangedSubviews: [swatch, column])
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 9),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -9),
            row.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor, constant: 26),
            row.trailingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.trailingAnchor, constant: -26)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(txid: String, tx: ExplorerMapTx?, index: Int, isYours: Bool, tint: WalletTheme.Tint) {
        defer {
            if isYours {
                swatch.backgroundColor = tint.accent
                infoLabel.text = "YOUR TX" + (infoLabel.isHidden ? "" : " · " + (infoLabel.text ?? ""))
                infoLabel.textColor = tint.accent
                infoLabel.isHidden = false
                accessibilityLabel = "Your transaction \(txid). \(infoLabel.text ?? "")"
            } else {
                infoLabel.textColor = WalletTheme.dim
            }
        }
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        txidLabel.text = txid
        txidLabel.textColor = WalletTheme.text
        txidLabel.textAlignment = .natural
        swatch.isHidden = false
        swatch.backgroundColor = tx.map { $0.isCoinbase ? WalletTheme.text : ExplorerFeeColor.color($0.feeRate) } ?? tint.line
        if let tx = tx {
            let size = "\(tx.vsize.withCommas) vB" + (tx.size.map { " · " + ExplorerFormat.megabytes($0) } ?? "")
            infoLabel.text = (tx.isCoinbase ? "Coinbase · " : (tx.feeRate.map(ExplorerFormat.feeRate) ?? "fee unknown") + " · ") + size
                + (tx.category.map { "\n" + $0.uppercased() } ?? "")
            infoLabel.numberOfLines = 0
            infoLabel.isHidden = false
        } else if index == 0 {
            infoLabel.text = "Coinbase"
            infoLabel.isHidden = false
        } else {
            infoLabel.isHidden = true
        }
        accessibilityLabel = "Transaction \(txid). \(infoLabel.isHidden ? "" : (infoLabel.text ?? ""))"
    }

    func configureMore(remaining: Int, tint: WalletTheme.Tint) {
        backgroundConfiguration = WalletTheme.cardConfiguration(tint: tint, horizontalInset: 16)
        swatch.isHidden = true
        infoLabel.isHidden = true
        txidLabel.text = "Show more · \(remaining.withCommas) left"
        txidLabel.textColor = tint.accent
        txidLabel.textAlignment = .center
        accessibilityLabel = txidLabel.text
    }
}
