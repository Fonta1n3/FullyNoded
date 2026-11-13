//
//  ChainDashboardViewController.swift
//  FullyNoded
//
//  The chain as your node sees it: the difficulty period and halving, what fee gets you in, recent
//  trends, the node's own health, and which peers bring it blocks. Each card loads by itself, so a
//  slow answer over Tor doesn't hold up the others, and a call this node can't answer just leaves
//  its row out.
//

import UIKit

final class ChainDashboardViewController: UIViewController {
    override var hidesBottomBarWhenPushed: Bool { get { true } set {} }

    private let service = BlockExplorerService()
    private let tint = WalletTheme.Tint.dashboard
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let scheduleCard = DashboardCard(title: "RETARGET & HALVING")
    private let feeCard = DashboardCard(title: "FEE LADDER")
    private let pulseCard = DashboardCard(title: "NETWORK PULSE")
    private let healthCard = DashboardCard(title: "CHAIN HEALTH")
    private let peerCard = DashboardCard(title: "PEER RACE")
    private var peers: GetPeerInfoResponse?
    private var estimates: [Int: Double] = [:]
    private var mempoolMinimum: Double?
    private var templateLowest: Double?
    private var isLoadingTemplate = false
    private var templateFailed = false
    private var feeHistory: [ExplorerBlockSummary] = []
    private var isLoading = false

    /// Confirmation targets: blocks, and what to call them.
    private static let feeTargets: [(blocks: Int, name: String)] = [(1, "Next block"), (3, "30 min"), (6, "1 hour"), (144, "1 day")]
    private static let hashratePoints = 14
    private static let hashrateWindow = 144
    private static let feePoints = 24

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Chain dashboard"
        WalletTheme.apply(to: self, tint: tint)

        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        view.addSubview(scroll)
        let refresh = UIRefreshControl()
        refresh.tintColor = tint.accent
        refresh.addTarget(self, action: #selector(reload), for: .valueChanged)
        scroll.refreshControl = refresh

        for card in [scheduleCard, feeCard, pulseCard, healthCard, peerCard] {
            stack.addArrangedSubview(WalletTheme.caption("> \(card.title)", tint: tint))
            stack.addArrangedSubview(card)
            stack.setCustomSpacing(16, after: card)
        }
        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -16)
        ])
        reload()
    }

    @objc private func reload() {
        guard !isLoading else { return }
        isLoading = true
        estimates = [:]
        templateLowest = nil
        templateFailed = false
        renderFees()
        service.tip { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false
            self.scroll.refreshControl?.endRefreshing()
            switch result {
            case .failure(let error):
                self.scheduleCard.setNote("Can't reach your node. \(error.message)")
            case .success(let tip):
                self.loadSchedule(tip)
                self.loadFees()
                self.loadPulse(tip)
                self.loadHealth(tip)
                self.loadPeers()
            }
        }
    }

    // MARK: - Retarget & halving

    private func loadSchedule(_ tip: BlockExplorerService.ChainTip) {
        service.schedule(tip: tip) { [weak self] schedule in self?.renderSchedule(schedule) }
    }

    private func renderSchedule(_ schedule: ExplorerChainSchedule) {
        var views: [UIView] = []
        let spacing = min(max(schedule.spacing, 300), 1200)
        if let retarget = schedule.retarget {
            let progress = UIProgressView(progressViewStyle: .bar)
            progress.progress = Float(retarget.blocksDone) / Float(ExplorerChainSchedule.retargetInterval)
            progress.progressTintColor = tint.accent
            progress.trackTintColor = WalletTheme.line.withAlphaComponent(0.25)
            progress.isAccessibilityElement = true
            progress.accessibilityLabel = "\(retarget.blocksDone) of \(ExplorerChainSchedule.retargetInterval) blocks this difficulty period"
            views.append(progress)
            views.append(row("Period", "\(retarget.blocksDone.withCommas) of \(ExplorerChainSchedule.retargetInterval.withCommas) blocks"))
            views.append(row("Retarget in", "\(retarget.blocksLeft.withCommas) blocks · \(date(afterBlocks: retarget.blocksLeft, spacing: spacing))"))
            if let average = retarget.averageSpacing {
                views.append(row("Block pace", String(format: "%.1f min per block", average / 60)))
            }
            if let change = retarget.projectedChange {
                views.append(row("Projected", String(format: "%@%.2f%% difficulty", change >= 0 ? "+" : "", change)))
            } else {
                views.append(row("Projected", "Too early in this period"))
            }
            views.append(divider())
        } else {
            views.append(row("Retarget", "Regtest doesn't retarget"))
        }
        views.append(row("Halving at", schedule.halvingHeight.withCommas))
        views.append(row("Halving in", "\(schedule.blocksToHalving.withCommas) blocks · \(date(afterBlocks: schedule.blocksToHalving, spacing: spacing))"))
        views.append(row("Block reward", "\(subsidy(schedule.subsidyNow)) → \(subsidy(schedule.subsidyAfter)) BTC"))
        scheduleCard.setContent(views)
    }

    private func subsidy(_ value: Double) -> String {
        var text = String(format: "%.8f", value)
        while text.hasSuffix("0") { text.removeLast() }
        return text.hasSuffix(".") ? text + "0" : text
    }

    /// "~Mar 2028", or a day and month when it's near.
    private func date(afterBlocks blocks: Int, spacing: TimeInterval) -> String {
        let date = Date().addingTimeInterval(TimeInterval(blocks) * spacing)
        let format: Date.FormatStyle = blocks < 5000 ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).year()
        return "~" + date.formatted(format)
    }

    // MARK: - Fee ladder

    private func loadFees() {
        for target in Self.feeTargets {
            service.call(.estimatesmartfee(param: Estimate_Smart_Fee_Param(["conf_target": target.blocks]))) { [weak self] response, _ in
                guard let self = self else { return }
                if let rate = RPCValue.double((response as? [String: Any])?["feerate"]) {
                    self.estimates[target.blocks] = rate * 100_000
                }
                self.renderFees()
            }
        }
        service.mempool { [weak self] info in
            guard let self = self else { return }
            self.mempoolMinimum = RPCValue.double(info?["mempoolminfee"]).map { $0 * 100_000 }
            self.renderFees()
        }
        // The template is several megabytes: on request over Tor.
        if service.isFastConnection { loadTemplate() }
    }

    private func loadTemplate() {
        guard !isLoadingTemplate else { return }
        isLoadingTemplate = true
        templateFailed = false
        renderFees()
        service.template { [weak self] result in
            guard let self = self else { return }
            self.isLoadingTemplate = false
            if case .success(let map) = result {
                self.templateLowest = map.compactMap(\.feeRate).min()
            } else {
                self.templateFailed = true
            }
            self.renderFees()
        }
    }

    private func renderFees() {
        var views: [UIView] = Self.feeTargets.map { target in
            row(target.name, estimates[target.blocks].map(ExplorerFormat.feeRate) ?? "no estimate yet")
        }
        views.append(divider())
        if let lowest = templateLowest {
            views.append(row("Template low", ExplorerFormat.feeRate(lowest) + ": the lowest in the block your node would build now"))
        } else if isLoadingTemplate {
            views.append(row("Template low", "loading…"))
        } else if templateFailed {
            views.append(row("Template low", "Your node didn't return a template"))
        } else {
            let button = UIButton(type: .system)
            button.configuration = WalletTheme.buttonConfiguration(title: "Check your node's next block (a few MB)", systemImage: "square.grid.3x3.fill", filled: false, tint: tint)
            button.addAction(UIAction { [weak self] _ in self?.loadTemplate() }, for: .touchUpInside)
            views.append(button)
        }
        if let minimum = mempoolMinimum {
            views.append(row("Mempool min", ExplorerFormat.feeRate(minimum) + ": below this your node won't relay it"))
        }
        feeCard.setContent(views)
    }

    // MARK: - Network pulse

    private func loadPulse(_ tip: BlockExplorerService.ChainTip) {
        let pulse = PulseContent(tint: tint)
        pulseCard.setContent([pulse])

        // One point per day, oldest first.
        let heights = (0..<Self.hashratePoints).reversed().map { tip.height - $0 * Self.hashrateWindow }.filter { $0 > Self.hashrateWindow }
        var rates: [Int: Double] = [:]
        let group = DispatchGroup()
        for height in heights {
            group.enter()
            service.call(.getnetworkhashps(Get_Network_Hash_PS(blocks: Self.hashrateWindow, height: height))) { response, _ in
                rates[height] = RPCValue.double(response)
                group.leave()
            }
        }
        group.notify(queue: .main) {
            pulse.setHashrate(heights.compactMap { height in rates[height].map { (height, $0) } })
        }

        let feeHeights = Array((0..<Self.feePoints).map { tip.height - $0 }.filter { $0 > 0 }.reversed())
        let showFees: () -> Void = { [weak self] in
            guard let self = self else { return }
            pulse.setFees(feeHeights.compactMap { height in
                self.service.cachedSummary(height)?.medianFeeRate.map { (height, Double($0)) }
            })
        }
        // Only heights not cached are fetched, so on a refresh most of the chart is already here.
        if feeHeights.contains(where: { service.cachedSummary($0) != nil }) { showFees() }
        service.requestSummaries(feeHeights) { _ in showFees() }

        service.call(.getnettotals) { response, _ in
            let totals = response as? [String: Any]
            pulse.setBandwidth(received: RPCValue.int(totals?["totalbytesrecv"]), sent: RPCValue.int(totals?["totalbytessent"]))
        }
    }

    // MARK: - Chain health

    private func loadHealth(_ tip: BlockExplorerService.ChainTip) {
        var info: [String: Any]?
        var tips: [[String: Any]]?
        let group = DispatchGroup()
        group.enter()
        service.call(.getblockchaininfo) { response, _ in
            info = response as? [String: Any]
            group.leave()
        }
        group.enter()
        service.call(.getchaintips) { response, _ in
            tips = response as? [[String: Any]]
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in self?.renderHealth(tip, info: info, tips: tips) }
    }

    private func renderHealth(_ tip: BlockExplorerService.ChainTip, info: [String: Any]?, tips: [[String: Any]]?) {
        var views: [UIView] = [row("Tip", tip.height.withCommas)]
        if let progress = RPCValue.double(info?["verificationprogress"]) {
            let syncing = RPCValue.bool(info?["initialblockdownload"]) == true
            views.append(row("Verified", String(format: "%.2f%%", progress * 100) + (syncing ? " · still syncing" : "")))
        }
        if let size = RPCValue.int(info?["size_on_disk"]) { views.append(row("On disk", ExplorerFormat.size(size))) }
        if let pruneHeight = tip.pruneHeight {
            views.append(row("History", "Pruned below block \(pruneHeight.withCommas)"))
        } else {
            views.append(row("History", "Every block kept"))
        }
        views.append(divider())
        let forks = (tips ?? []).filter { RPCValue.string($0["status"]) != "active" }
            .sorted { (RPCValue.int($0["height"]) ?? 0) > (RPCValue.int($1["height"]) ?? 0) }
        if forks.isEmpty {
            views.append(row("Forks", tips == nil ? "unknown" : "None seen by this node"))
        } else {
            views.append(row("Forks seen", forks.count.withCommas))
            for fork in forks.prefix(5) {
                let height = RPCValue.int(fork["height"]) ?? 0
                let length = RPCValue.int(fork["branchlen"]) ?? 0
                views.append(row("Block \(height.withCommas)", "\(length) block\(length == 1 ? "" : "s") · \(Self.forkStatus(RPCValue.string(fork["status"])))"))
            }
        }
        healthCard.setContent(views)
    }

    private static func forkStatus(_ status: String?) -> String {
        switch status {
        case "valid-fork": return "valid, not chosen"
        case "valid-headers": return "headers valid, blocks not checked"
        case "headers-only": return "headers only"
        case "invalid": return "invalid"
        default: return status ?? "unknown"
        }
    }

    // MARK: - Peer race

    private func loadPeers() {
        NodeLogic.sharedInstance.getPeerInfo { [weak self] response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.peers = response
                self.renderPeers()
            }
        }
    }

    private func renderPeers() {
        guard let peers = peers else {
            peerCard.setNote("Your node didn't answer.")
            return
        }
        let racers = peers.peers.filter { ($0.lastBlock ?? 0) > 0 }.sorted { ($0.lastBlock ?? 0) > ($1.lastBlock ?? 0) }
        var views: [UIView] = [row("Bringing blocks", "\(racers.count) of \(peers.peers.count) peers")]
        for peer in racers.prefix(8) {
            let button = UIButton(type: .system)
            var config = WalletTheme.buttonConfiguration(title: "\(peer.clientName) · \(peer.networkName) · \(ExplorerFormat.ago(peer.lastBlock ?? 0))",
                                                         systemImage: "chevron.right", filled: false, tint: tint)
            config.imagePlacement = .trailing
            config.titleLineBreakMode = .byTruncatingMiddle
            button.configuration = config
            button.addAction(UIAction { [weak self] _ in self?.open(peer) }, for: .touchUpInside)
            views.append(button)
        }
        peerCard.setContent(views)
    }

    private func open(_ peer: PeerInfo) {
        impact()
        let raw = peers?.rawData.first { peer.id != nil && RPCValue.int($0["id"]) == peer.id }
        navigationController?.pushViewController(PeerDetailViewController(peer: peer, raw: raw), animated: true)
    }

    // MARK: - Pieces

    private func row(_ title: String, _ value: String) -> UIView { DashboardCard.row(title, value) }

    private func divider() -> UIView {
        let line = UIView()
        line.backgroundColor = tint.line.withAlphaComponent(0.4)
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}

/// A themed card whose content is replaced as its data arrives.
private final class DashboardCard: UIView {
    let title: String
    private let stack = UIStackView()

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
        let tint = WalletTheme.Tint.dashboard
        backgroundColor = WalletTheme.card
        layer.borderWidth = 1
        layer.borderColor = tint.line.cgColor
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        setNote("Loading…")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setContent(_ views: [UIView]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        views.forEach { stack.addArrangedSubview($0) }
    }

    func setNote(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(12)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
        setContent([label])
    }

    static func row(_ title: String, _ value: String) -> UIView { WalletTheme.infoRow(title, value, titleWidth: 112) }
}

/// The pulse card: one small chart each for hashrate and fees (two scales, so never one chart),
/// then bandwidth.
private final class PulseContent: UIStackView {
    private let hashrate: DashboardSparkline
    private let fees: DashboardSparkline
    private let bandwidth = UIStackView()

    init(tint: WalletTheme.Tint) {
        hashrate = DashboardSparkline(title: "HASHRATE · DAILY", color: tint.accent) { Self.hashrateText($0) }
        fees = DashboardSparkline(title: "MEDIAN FEE · LAST 24 BLOCKS", color: tint.accent) { "\(Int($0)) sat/vB" }
        super.init(frame: .zero)
        axis = .vertical
        spacing = 14
        bandwidth.axis = .vertical
        bandwidth.spacing = 8
        addArrangedSubview(hashrate)
        addArrangedSubview(fees)
        addArrangedSubview(bandwidth)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHashrate(_ points: [(Int, Double)]) { hashrate.setPoints(points) }

    func setFees(_ points: [(Int, Double)]) { fees.setPoints(points) }

    func setBandwidth(received: Int?, sent: Int?) {
        bandwidth.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let received = received { bandwidth.addArrangedSubview(DashboardCard.row("Downloaded", ExplorerFormat.size(received))) }
        if let sent = sent { bandwidth.addArrangedSubview(DashboardCard.row("Uploaded", ExplorerFormat.size(sent))) }
    }

    private static func hashrateText(_ value: Double) -> String {
        let units: [(Double, String)] = [(1e18, "EH/s"), (1e15, "PH/s"), (1e12, "TH/s"), (1e9, "GH/s"), (1e6, "MH/s"), (1e3, "kH/s")]
        for (scale, unit) in units where value >= scale {
            return String(format: "%.1f %@", value / scale, unit)
        }
        return String(format: "%.0f H/s", value)
    }
}

/// One series over blocks: a 2pt line with its latest value called out. Touch anywhere to read a
/// point; VoiceOver gets the range and latest value.
private final class DashboardSparkline: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let plot = SparklinePlot()
    private let rangeLabel = UILabel()
    private var points: [(height: Int, value: Double)] = []
    private let format: (Double) -> String

    init(title: String, color: UIColor, format: @escaping (Double) -> String) {
        self.format = format
        super.init(frame: .zero)
        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(10, weight: .bold)
        titleLabel.textColor = WalletTheme.dim
        valueLabel.font = WalletTheme.mono(15, weight: .semibold)
        valueLabel.textColor = WalletTheme.text
        valueLabel.text = "loading…"
        plot.color = color
        plot.heightAnchor.constraint(equalToConstant: 56).isActive = true
        rangeLabel.font = WalletTheme.mono(10)
        rangeLabel.textColor = WalletTheme.dim
        let stack = UIStackView(arrangedSubviews: [titleLabel, valueLabel, plot, rangeLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        let pan = UILongPressGestureRecognizer(target: self, action: #selector(touched(_:)))
        pan.minimumPressDuration = 0
        pan.cancelsTouchesInView = false
        plot.addGestureRecognizer(pan)
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setPoints(_ points: [(Int, Double)]) {
        self.points = points.map { (height: $0.0, value: $0.1) }
        plot.values = points.map(\.1)
        showLatest()
        if let low = plot.values.min(), let high = plot.values.max(), let last = plot.values.last {
            accessibilityLabel = "\(titleLabel.text ?? ""). Latest \(format(last)). Range \(format(low)) to \(format(high))."
            rangeLabel.text = "LOW \(format(low)) · HIGH \(format(high))"
        } else {
            accessibilityLabel = "\(titleLabel.text ?? ""). No data."
        }
    }

    private func showLatest() {
        plot.selected = nil
        // Pruned blocks and new chains leave too little to draw.
        plot.isHidden = points.count < 2
        rangeLabel.isHidden = points.count < 2
        valueLabel.text = points.last.map { format($0.value) } ?? "not available from this node"
        valueLabel.font = points.isEmpty ? WalletTheme.mono(12) : WalletTheme.mono(15, weight: .semibold)
        valueLabel.textColor = points.isEmpty ? WalletTheme.dim : WalletTheme.text
    }

    @objc private func touched(_ gesture: UILongPressGestureRecognizer) {
        guard points.count >= 2 else { return }
        switch gesture.state {
        case .began, .changed:
            let fraction = gesture.location(in: plot).x / max(plot.bounds.width, 1)
            let index = min(max(Int((fraction * CGFloat(points.count - 1)).rounded()), 0), points.count - 1)
            plot.selected = index
            valueLabel.text = "\(format(points[index].value)) · block \(points[index].height.withCommas)"
        default:
            showLatest()
        }
    }
}

private final class SparklinePlot: UIView {
    var color = WalletTheme.accent { didSet { setNeedsDisplay() } }
    var values: [Double] = [] { didSet { setNeedsDisplay() } }
    var selected: Int? { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ rect: CGRect) {
        guard values.count >= 2, let low = values.min(), let high = values.max(),
              let context = UIGraphicsGetCurrentContext() else { return }
        let inset: CGFloat = 5
        let plot = bounds.insetBy(dx: inset, dy: inset)
        // A flat series sits mid-height rather than dividing by zero.
        let span = high > low ? high - low : 1
        func point(_ index: Int) -> CGPoint {
            let x = plot.minX + plot.width * CGFloat(index) / CGFloat(values.count - 1)
            let fraction = high > low ? (values[index] - low) / span : 0.5
            return CGPoint(x: x, y: plot.maxY - plot.height * CGFloat(fraction))
        }

        let line = UIBezierPath()
        line.move(to: point(0))
        for index in 1..<values.count { line.addLine(to: point(index)) }
        line.lineWidth = 2
        line.lineJoinStyle = .round
        line.lineCapStyle = .round
        color.setStroke()
        line.stroke()

        let marked = selected ?? values.count - 1
        if selected != nil {
            WalletTheme.dim.setStroke()
            context.setLineWidth(1)
            context.move(to: CGPoint(x: point(marked).x, y: bounds.minY))
            context.addLine(to: CGPoint(x: point(marked).x, y: bounds.maxY))
            context.strokePath()
        }
        // An 8pt marker with a ring of the card's colour, so it stands off the line.
        let dot = point(marked)
        WalletTheme.card.setFill()
        context.fillEllipse(in: CGRect(x: dot.x - 6, y: dot.y - 6, width: 12, height: 12))
        color.setFill()
        context.fillEllipse(in: CGRect(x: dot.x - 4, y: dot.y - 4, width: 8, height: 8))
    }
}
