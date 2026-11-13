//
//  BlockExplorerViews.swift
//  FullyNoded
//
//  The explorer's drawn pieces: a block as a cube filled by how full it is, the next block being
//  mined, the burst when one is found, and the block map of transactions by size and fee rate.
//
//  The mining animation is decoration: a phone can't see anyone's hashing. The numbers next to
//  it (the ETA, from the last block's time and the recent pace) are a real, rough guide.
//

import UIKit

/// Fee rates as colours, cool to hot, in the buckets the legend shows.
enum ExplorerFeeColor {
    static let buckets: [(from: Double, label: String, color: UIColor)] = [
        (0, "<2", UIColor(red: 0.16, green: 0.45, blue: 0.50, alpha: 1)),
        (2, "2", UIColor(red: 0.13, green: 0.68, blue: 0.62, alpha: 1)),
        (5, "5", UIColor(red: 0.25, green: 0.85, blue: 0.48, alpha: 1)),
        (10, "10", UIColor(red: 0.72, green: 0.88, blue: 0.27, alpha: 1)),
        (25, "25", UIColor(red: 1.0, green: 0.72, blue: 0.28, alpha: 1)),
        (50, "50", UIColor(red: 1.0, green: 0.45, blue: 0.32, alpha: 1)),
        (100, "100+", UIColor(red: 1.0, green: 0.28, blue: 0.48, alpha: 1))
    ]

    static func color(_ feeRate: Double?) -> UIColor {
        guard let feeRate = feeRate else { return WalletTheme.dim }
        return buckets.last { feeRate >= $0.from }?.color ?? buckets[0].color
    }
}

enum ExplorerFormat {
    static func btc(_ value: Double) -> String { String(format: "%.8f BTC", value) }

    static func btc(sats: Int) -> String { btc(Double(sats) / 100_000_000) }

    /// The last rate fetched, or nil with none. Used for old blocks too, so it's always today's
    /// value and never what the coins were worth then.
    private static var fxRate: Double? {
        (UserDefaults.standard.object(forKey: "fxRate") as? Double).flatMap { $0 > 0 ? $0 : nil }
    }

    /// "≈ $18,944.56". nil without a rate, or for nothing.
    static func fiat(btc value: Double) -> String? {
        guard let rate = fxRate, value > 0 else { return nil }
        return "≈ " + (value * rate).fiatString
    }

    /// Under an amount: "0.25000000 BTC", then what it's worth today.
    static func btcWithFiat(_ value: Double) -> String {
        btc(value) + (fiat(btc: value).map { "\n\($0) today" } ?? "")
    }

    /// For the small space on a cube: "≈ $238K".
    static func fiatCompact(btc value: Double) -> String? {
        guard let rate = fxRate, value > 0 else { return nil }
        // The user's currency and where its symbol goes, from the app's usual format of zero.
        let template = Double(0).fiatString
        guard let range = template.range(of: #"0[.,]00"#, options: .regularExpression) else { return fiat(btc: value) }
        return "≈ " + template.replacingCharacters(in: range, with: compactNumber(value * rate))
    }

    /// 950 → "950", 1_234 → "1.2K", 238_400 → "238K", 2_500_000 → "2.5M".
    static func compactNumber(_ value: Double) -> String {
        let units: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "K")]
        for (scale, unit) in units where value >= scale {
            let scaled = value / scale
            return (scaled >= 100 ? String(format: "%.0f", scaled) : String(format: "%.1f", scaled)) + unit
        }
        return String(format: "%.0f", value)
    }

    static func feeRate(_ rate: Double) -> String {
        rate >= 10 ? "\(Int(rate.rounded())) sat/vB" : String(format: "%.1f sat/vB", rate)
    }

    /// "12m ago", "1h 59m ago", "2d 5h ago", "3y 20d ago": the two largest units. Never seconds:
    /// a block's time is only what its miner wrote, often minutes out.
    static func ago(_ time: Int, now: Date = Date()) -> String {
        let minutes = Int(max(now.timeIntervalSince1970 - TimeInterval(time), 0)) / 60
        guard minutes >= 1 else { return "just now" }
        let hours = minutes / 60
        let days = hours / 24
        let years = days / 365
        func pair(_ big: Int, _ bigUnit: String, _ small: Int, _ smallUnit: String) -> String {
            small > 0 ? "\(big)\(bigUnit) \(small)\(smallUnit) ago" : "\(big)\(bigUnit) ago"
        }
        if years > 0 { return pair(years, "y", days % 365, "d") }
        if days > 0 { return pair(days, "d", hours % 24, "h") }
        if hours > 0 { return pair(hours, "h", minutes % 60, "m") }
        return "\(minutes)m ago"
    }

    /// Time left until the usual spacing after the last block has passed: "~7m", then "any
    /// moment". A guide only: blocks are found at random, and one is never really "due". A
    /// block's time can be ahead of this clock, hence the cap.
    static func eta(lastBlockTime time: Int, spacing: TimeInterval = ExplorerChainSchedule.targetSpacing, now: Date = Date()) -> String {
        let remaining = min(TimeInterval(time) + spacing - now.timeIntervalSince1970, spacing)
        guard remaining > 0 else { return "any moment" }
        return remaining < 60 ? "<1m" : "~\(Int((remaining / 60).rounded(.up)))m"
    }

    /// A block's size and weight for the strip: "1.58 MB · 3.99 MWU". nil if neither is known.
    static func blockSize(size: Int?, weight: Int?) -> String? {
        func millions(_ value: Int, _ unit: String) -> String {
            let scaled = Double(value) / 1_000_000
            return String(format: scaled >= 0.1 ? "%.2f %@" : "%.4f %@", scaled, unit)
        }
        let parts = [size.map { millions($0, "MB") }, weight.map { millions($0, "MWU") }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// Always in megabytes, with enough places that a small transaction doesn't read as zero.
    static func megabytes(_ bytes: Int) -> String {
        let value = Double(bytes) / 1_000_000
        return String(format: value >= 0.01 ? "%.3f MB" : "%.5f MB", value)
    }

    static func size(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .decimal)
    }
}

/// A cube: front face filled from the bottom, with a top and a side for depth.
final class ExplorerCubeView: UIView {
    private let topFace = CAShapeLayer()
    private let sideFace = CAShapeLayer()
    private let frontFace = CAShapeLayer()
    private let fillLayer = CAShapeLayer()
    private let outline = CAShapeLayer()
    private static let depth: CGFloat = 14
    private var fullness: CGFloat = 0
    private var fillColor = WalletTheme.dim

    /// The front face, for anything drawn on it.
    var frontRect: CGRect {
        CGRect(x: 0, y: Self.depth, width: bounds.width - Self.depth, height: bounds.height - Self.depth)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        for layer_ in [frontFace, fillLayer, topFace, sideFace, outline] { layer.addSublayer(layer_) }
        outline.fillColor = UIColor.clear.cgColor
        outline.lineWidth = 2
        outline.lineJoin = .round
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(fullness: Double?, color: UIColor, selected: Bool, accent: UIColor, dashed: Bool = false) {
        self.fullness = CGFloat(fullness ?? 0)
        fillColor = color
        outline.strokeColor = selected ? accent.cgColor : WalletTheme.line.withAlphaComponent(0.6).cgColor
        outline.lineWidth = selected ? 2 : 1
        outline.lineDashPattern = dashed ? [5, 4] : nil
        layer.shadowColor = accent.cgColor
        layer.shadowRadius = selected ? 12 : 0
        layer.shadowOpacity = selected ? 0.55 : 0
        layer.shadowOffset = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let d = Self.depth
        let front = frontRect
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        frontFace.path = UIBezierPath(rect: front).cgPath
        frontFace.fillColor = WalletTheme.card.cgColor

        let filled = front.height * fullness
        fillLayer.path = UIBezierPath(rect: CGRect(x: front.minX, y: front.maxY - filled, width: front.width, height: filled)).cgPath
        fillLayer.fillColor = fillColor.withAlphaComponent(0.72).cgColor

        let top = UIBezierPath()
        top.move(to: CGPoint(x: 0, y: d))
        top.addLine(to: CGPoint(x: d, y: 0))
        top.addLine(to: CGPoint(x: bounds.width, y: 0))
        top.addLine(to: CGPoint(x: bounds.width - d, y: d))
        top.close()
        topFace.path = top.cgPath
        topFace.fillColor = (fullness > 0.98 ? fillColor : WalletTheme.card).withAlphaComponent(0.95).cgColor

        let side = UIBezierPath()
        side.move(to: CGPoint(x: bounds.width - d, y: d))
        side.addLine(to: CGPoint(x: bounds.width, y: 0))
        side.addLine(to: CGPoint(x: bounds.width, y: bounds.height - d))
        side.addLine(to: CGPoint(x: bounds.width - d, y: bounds.height))
        side.close()
        sideFace.path = side.cgPath
        sideFace.fillColor = fillColor.withAlphaComponent(fullness > 0 ? 0.4 : 0.12).cgColor

        let edges = UIBezierPath(rect: front)
        edges.append(top)
        edges.append(side)
        outline.path = edges.cgPath
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath
        CATransaction.commit()
    }
}

final class ExplorerBlockCell: UICollectionViewCell {
    static let identifier = "ExplorerBlockCell"
    let cube = ExplorerCubeView()
    private let heightLabel = UILabel()
    private let feeLabel = UILabel()
    private let txLabel = UILabel()
    private let sizeLabel = UILabel()
    private let fiatLabel = UILabel()
    private let timeLabel = UILabel()
    private let minerLabel = UILabel()
    private let tagLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        heightLabel.font = WalletTheme.mono(13, weight: .bold)
        heightLabel.textAlignment = .center
        minerLabel.font = WalletTheme.mono(9, weight: .semibold)
        minerLabel.textColor = WalletTheme.text
        minerLabel.textAlignment = .center
        minerLabel.adjustsFontSizeToFitWidth = true
        minerLabel.minimumScaleFactor = 0.7
        tagLabel.font = WalletTheme.mono(9, weight: .bold)
        tagLabel.textAlignment = .center
        tagLabel.clipsToBounds = true
        feeLabel.font = WalletTheme.mono(12, weight: .bold)
        feeLabel.textAlignment = .center
        feeLabel.numberOfLines = 0
        txLabel.font = WalletTheme.mono(11)
        txLabel.textAlignment = .center
        txLabel.numberOfLines = 0
        sizeLabel.font = WalletTheme.mono(9)
        sizeLabel.textColor = WalletTheme.dim
        sizeLabel.textAlignment = .center
        sizeLabel.adjustsFontSizeToFitWidth = true
        sizeLabel.minimumScaleFactor = 0.7
        fiatLabel.font = WalletTheme.mono(9, weight: .semibold)
        fiatLabel.textColor = WalletTheme.text
        fiatLabel.textAlignment = .center
        fiatLabel.numberOfLines = 2
        timeLabel.font = WalletTheme.mono(10)
        timeLabel.textColor = WalletTheme.dim
        timeLabel.textAlignment = .center
        for view in [heightLabel, cube, timeLabel, feeLabel, txLabel, sizeLabel, fiatLabel, minerLabel, tagLabel] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            heightLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            heightLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            heightLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cube.topAnchor.constraint(equalTo: heightLabel.bottomAnchor, constant: 4),
            cube.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cube.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cube.bottomAnchor.constraint(equalTo: timeLabel.topAnchor, constant: -4),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // On the cube's front face (the side takes 14pt on the right, the top 14pt above).
            feeLabel.centerXAnchor.constraint(equalTo: cube.centerXAnchor, constant: -7),
            feeLabel.centerYAnchor.constraint(equalTo: cube.centerYAnchor, constant: -16),
            feeLabel.widthAnchor.constraint(equalTo: cube.widthAnchor, constant: -22),
            txLabel.centerXAnchor.constraint(equalTo: feeLabel.centerXAnchor),
            txLabel.topAnchor.constraint(equalTo: feeLabel.bottomAnchor, constant: 4),
            txLabel.widthAnchor.constraint(equalTo: feeLabel.widthAnchor),
            sizeLabel.centerXAnchor.constraint(equalTo: feeLabel.centerXAnchor),
            sizeLabel.topAnchor.constraint(equalTo: txLabel.bottomAnchor, constant: 3),
            sizeLabel.widthAnchor.constraint(equalTo: feeLabel.widthAnchor),
            fiatLabel.centerXAnchor.constraint(equalTo: feeLabel.centerXAnchor),
            fiatLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 2),
            fiatLabel.widthAnchor.constraint(equalTo: feeLabel.widthAnchor),
            minerLabel.centerXAnchor.constraint(equalTo: feeLabel.centerXAnchor),
            minerLabel.topAnchor.constraint(equalTo: fiatLabel.bottomAnchor, constant: 2),
            minerLabel.widthAnchor.constraint(equalTo: feeLabel.widthAnchor),
            // At the top of the front face.
            tagLabel.topAnchor.constraint(equalTo: cube.topAnchor, constant: 18),
            tagLabel.centerXAnchor.constraint(equalTo: feeLabel.centerXAnchor),
            tagLabel.widthAnchor.constraint(equalToConstant: 66),
            tagLabel.heightAnchor.constraint(equalToConstant: 15)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func prepareForReuse() {
        super.prepareForReuse()
        transform = .identity
    }

    /// `miner`: known once this block has been opened. `isYours`: the active wallet has a
    /// transaction in it. `isPruned`: the node no longer has its transactions.
    func configure(height: Int, summary: ExplorerBlockSummary?, selected: Bool, accent: UIColor,
                   miner: String? = nil, isYours: Bool = false, isSolo: Bool = false, isPruned: Bool = false) {
        minerLabel.text = miner
        minerLabel.isHidden = miner == nil
        tagLabel.isHidden = !isYours && !isSolo && !isPruned
        tagLabel.text = isYours ? "YOUR TX" : isSolo ? "SOLO WIN" : "PRUNED"
        tagLabel.textColor = isYours || isSolo ? WalletTheme.bg : WalletTheme.dim
        tagLabel.backgroundColor = isYours ? accent : isSolo ? ExplorerBlockBurst.gold : .clear
        tagLabel.layer.borderWidth = isYours || isSolo ? 0 : 1
        tagLabel.layer.borderColor = WalletTheme.dim.cgColor
        heightLabel.text = height.withCommas
        heightLabel.textColor = selected ? accent : WalletTheme.text
        let rate = summary?.medianFeeRate
        cube.configure(fullness: summary?.fullness, color: ExplorerFeeColor.color(rate.map(Double.init)), selected: selected, accent: accent)
        if let summary = summary {
            // Only the coinbase: no fee rate to speak of.
            let empty = summary.txCount <= 1
            let txs = "\(summary.txCount.withCommas) tx\(summary.txCount == 1 ? "" : "s")"
            feeLabel.text = empty ? "Empty" : (rate.map { "~\($0) sat/vB" } ?? "\(summary.txCount.withCommas)")
            txLabel.text = rate != nil || empty ? txs : (summary.txCount == 1 ? "tx" : "txs")
            timeLabel.text = ExplorerFormat.ago(summary.time)
            sizeLabel.text = ExplorerFormat.blockSize(size: summary.size, weight: summary.weight)
            fiatLabel.text = summary.rewardBtc.map { reward in
                String(format: "%.3f BTC reward", reward) + (ExplorerFormat.fiatCompact(btc: reward).map { "\n\($0)" } ?? "")
            }
        } else {
            feeLabel.text = "…"
            txLabel.text = ""
            sizeLabel.text = nil
            fiatLabel.text = nil
            timeLabel.text = " "
        }
        feeLabel.textColor = WalletTheme.text
        txLabel.textColor = WalletTheme.text
        accessibilityLabel = "Block \(height)" + (summary.map { ", \($0.txCount) transactions, \(ExplorerFormat.ago($0.time))" } ?? "")
            + (sizeLabel.text.map { ", \($0)" } ?? "")
            + (fiatLabel.text.map { ", \($0.replacingOccurrences(of: "\n", with: ", ")) at today's rate" } ?? "")
            + (isSolo ? ", won by a solo miner" : "")
            + (miner.map { ", mined by \($0)" } ?? "") + (isYours ? ", contains your transaction" : "") + (isPruned ? ", pruned" : "")
    }
}

/// The block being worked on, at the right end of the strip, with its rough ETA.
final class ExplorerPendingCell: UICollectionViewCell {
    static let identifier = "ExplorerPendingCell"
    private let cube = ExplorerCubeView()
    private let titleLabel = UILabel()
    private let hashLabel = UILabel()
    private let timeLabel = UILabel()
    private let sweep = CAGradientLayer()
    private let clip = UIView()
    private var timer: Timer?
    private var lastBlockTime: Int?
    private var spacing = ExplorerChainSchedule.targetSpacing
    private var accent = WalletTheme.accent
    private let yourTag = UILabel()
    /// A grid flickering like hashes being tried, and the outline crawling around the face. Both
    /// only show that work is going on: nothing in them comes from real mining.
    private let tiles = CALayer()
    private let outline = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = WalletTheme.mono(13, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.text = "NEXT"
        hashLabel.font = WalletTheme.mono(10, weight: .medium)
        hashLabel.textAlignment = .center
        hashLabel.numberOfLines = 0
        hashLabel.backgroundColor = WalletTheme.card.withAlphaComponent(0.8)
        timeLabel.font = WalletTheme.mono(10)
        timeLabel.textColor = WalletTheme.dim
        timeLabel.textAlignment = .center
        clip.clipsToBounds = true
        clip.isUserInteractionEnabled = false
        clip.layer.addSublayer(tiles)
        clip.layer.addSublayer(sweep)
        clip.layer.addSublayer(outline)
        outline.fillColor = nil
        outline.strokeColor = WalletTheme.pending.cgColor
        outline.lineWidth = 2
        outline.lineDashPattern = [5, 5]
        yourTag.text = "YOUR TX"
        yourTag.font = WalletTheme.mono(9, weight: .bold)
        yourTag.textAlignment = .center
        yourTag.clipsToBounds = true
        for view in [titleLabel, cube, clip, hashLabel, timeLabel, yourTag] as [UIView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(view)
        }
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cube.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            cube.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cube.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cube.bottomAnchor.constraint(equalTo: timeLabel.topAnchor, constant: -4),
            timeLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            timeLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            // The cube's front face.
            clip.topAnchor.constraint(equalTo: cube.topAnchor, constant: 14),
            clip.leadingAnchor.constraint(equalTo: cube.leadingAnchor),
            clip.trailingAnchor.constraint(equalTo: cube.trailingAnchor, constant: -14),
            clip.bottomAnchor.constraint(equalTo: cube.bottomAnchor),
            hashLabel.centerXAnchor.constraint(equalTo: clip.centerXAnchor),
            hashLabel.centerYAnchor.constraint(equalTo: clip.centerYAnchor),
            hashLabel.widthAnchor.constraint(equalToConstant: 76),
            yourTag.topAnchor.constraint(equalTo: clip.topAnchor, constant: 4),
            yourTag.centerXAnchor.constraint(equalTo: clip.centerXAnchor),
            yourTag.widthAnchor.constraint(equalToConstant: 66),
            yourTag.heightAnchor.constraint(equalToConstant: 15)
        ])
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(height: Int, lastBlockTime: Int?, spacing: TimeInterval, hasYourTx: Bool, selected: Bool, accent: UIColor) {
        self.lastBlockTime = lastBlockTime
        self.spacing = spacing
        yourTag.isHidden = !hasYourTx
        yourTag.textColor = WalletTheme.bg
        yourTag.backgroundColor = accent
        self.accent = accent
        titleLabel.text = "NEXT · \(height.withCommas)"
        titleLabel.textColor = selected ? accent : WalletTheme.pending
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.7
        cube.configure(fullness: nil, color: WalletTheme.pending, selected: selected, accent: selected ? accent : WalletTheme.pending, dashed: true)
        hashLabel.textColor = WalletTheme.pending
        updateTime()
        render()
        accessibilityLabel = "Next block, \(height), being mined. \(timeLabel.text ?? "")"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // The content view lays out after this cell, and everything below needs the face's size.
        contentView.layoutIfNeeded()
        let band = clip.bounds.height * 0.3
        sweep.frame = CGRect(x: 0, y: -band, width: clip.bounds.width, height: band)
        // A soft trail under a bright leading edge, moving down.
        sweep.colors = [UIColor.clear.cgColor, WalletTheme.pending.withAlphaComponent(0.35).cgColor, WalletTheme.pending.withAlphaComponent(0.95).cgColor]
        sweep.locations = [0, 0.92, 1]
        outline.frame = clip.bounds
        outline.path = UIBezierPath(rect: clip.bounds.insetBy(dx: 1, dy: 1)).cgPath
        if tiles.bounds.size != clip.bounds.size { buildTiles() }
        if timer != nil { startSweep() }
    }

    private func buildTiles() {
        tiles.frame = clip.bounds
        tiles.sublayers?.forEach { $0.removeFromSuperlayer() }
        let columns = 7
        guard clip.bounds.width > 0 else { return }
        let gap: CGFloat = 2
        let inset: CGFloat = 4
        let side = (clip.bounds.width - inset * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns)
        guard side > 0 else { return }
        let rows = Int((clip.bounds.height - inset * 2 + gap) / (side + gap))
        for row in 0..<max(rows, 0) {
            for column in 0..<columns {
                let tile = CALayer()
                tile.frame = CGRect(x: inset + CGFloat(column) * (side + gap), y: inset + CGFloat(row) * (side + gap), width: side, height: side)
                tile.backgroundColor = WalletTheme.pending.cgColor
                tile.opacity = 0.14
                tiles.addSublayer(tile)
            }
        }
    }

    func startAnimating() {
        guard timer == nil else { return }
        startSweep()
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        let timer = Timer(timeInterval: 0.09, repeats: true) { [weak self] _ in self?.render() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        sweep.removeAllAnimations()
        outline.removeAllAnimations()
        tiles.sublayers?.forEach { $0.removeAllAnimations() }
    }

    private func startSweep() {
        guard !UIAccessibility.isReduceMotionEnabled, clip.bounds.height > 0 else { return }
        sweep.removeAnimation(forKey: "sweep")
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = -clip.bounds.height * 0.2
        animation.toValue = clip.bounds.height * 1.2
        animation.duration = 1.8
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        // Survives the app going to the background and back.
        animation.isRemovedOnCompletion = false
        sweep.add(animation, forKey: "sweep")

        let crawl = CABasicAnimation(keyPath: "lineDashPhase")
        crawl.fromValue = 0
        crawl.toValue = -10
        crawl.duration = 0.45
        crawl.repeatCount = .infinity
        crawl.isRemovedOnCompletion = false
        outline.add(crawl, forKey: "crawl")

        // Each tile on its own clock, so the grid twinkles instead of pulsing together.
        let now = CACurrentMediaTime()
        for tile in tiles.sublayers ?? [] where tile.animation(forKey: "flicker") == nil {
            let flicker = CAKeyframeAnimation(keyPath: "opacity")
            flicker.values = [0.1, 0.1, 0.75, 0.1]
            flicker.keyTimes = [0, 0.7, 0.78, 1]
            flicker.duration = Double.random(in: 1.0...3.2)
            flicker.beginTime = now + Double.random(in: 0...2)
            flicker.repeatCount = .infinity
            flicker.isRemovedOnCompletion = false
            tile.add(flicker, forKey: "flicker")
        }
    }

    /// Hex rolling by (only ever decoration).
    private func render() {
        let hex = Array("0123456789abcdef")
        var lines: [String] = ["MINING"]
        if UIAccessibility.isReduceMotionEnabled {
            lines.append("working…")
        } else {
            lines.append(String((0..<8).map { _ in hex.randomElement()! }))
        }
        hashLabel.text = lines.joined(separator: "\n")
    }

    private func updateTime() {
        timeLabel.text = lastBlockTime.map { "ETA " + ExplorerFormat.eta(lastBlockTime: $0, spacing: spacing) } ?? " "
    }

    deinit { timer?.invalidate() }
}

/// The moment a block is found: rings and a shower of little blocks from `view`, with a haptic.
enum ExplorerBlockBurst {
    static let gold = UIColor(red: 1.0, green: 0.8, blue: 0.25, alpha: 1)

    /// A solo miner took a whole block. Gold coins rain down over everything for a few seconds,
    /// without getting in the way of a touch.
    static func celebrateSoloWin(in view: UIView) {
        let haptics = UINotificationFeedbackGenerator()
        haptics.notificationOccurred(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { haptics.notificationOccurred(.success) }
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        let rain = CAEmitterLayer()
        rain.emitterShape = .line
        rain.emitterPosition = CGPoint(x: view.bounds.midX, y: -24)
        rain.emitterSize = CGSize(width: view.bounds.width, height: 1)
        rain.zPosition = 1000
        func coin(_ symbol: String, size: CGFloat, color: UIColor, rate: Float) -> CAEmitterCell {
            let cell = CAEmitterCell()
            cell.contents = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .bold))?
                .withTintColor(color, renderingMode: .alwaysOriginal).cgImageRendered
            // The bitmap is at screen resolution: without this it draws at two or three times the size.
            cell.contentsScale = view.traitCollection.displayScale
            cell.birthRate = rate
            cell.lifetime = 5
            cell.velocity = 150
            cell.velocityRange = 70
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 8
            cell.yAcceleration = 90
            cell.spin = 2
            cell.spinRange = 4
            cell.scale = 1
            cell.scaleRange = 0.4
            cell.alphaSpeed = -0.12
            return cell
        }
        rain.emitterCells = [coin("bitcoinsign.circle.fill", size: 24, color: gold, rate: 16),
                             coin("sparkle", size: 14, color: .white, rate: 8)]
        view.layer.addSublayer(rain)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { rain.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { rain.removeFromSuperlayer() }
    }

    static func play(on view: UIView, color: UIColor) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        guard !UIAccessibility.isReduceMotionEnabled else { return }

        view.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.8, options: [.allowUserInteraction]) {
            view.transform = .identity
        }

        guard let host = view.superview else { return }
        let center = view.center
        for (index, delay) in [0.0, 0.14, 0.28].enumerated() {
            let ring = CAShapeLayer()
            let size = max(view.bounds.width, view.bounds.height)
            ring.path = UIBezierPath(rect: CGRect(x: -size / 2, y: -size / 2, width: size, height: size)).cgPath
            ring.position = center
            ring.fillColor = UIColor.clear.cgColor
            ring.strokeColor = color.cgColor
            ring.lineWidth = CGFloat(3 - index)
            ring.opacity = 0
            host.layer.addSublayer(ring)

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 0.6
            scale.toValue = 1.9
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0.9, 0.5, 0]
            fade.keyTimes = [0, 0.5, 1]
            let group = CAAnimationGroup()
            group.animations = [scale, fade]
            group.duration = 0.9
            group.beginTime = CACurrentMediaTime() + delay
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ring.add(group, forKey: "ring")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + 1) { ring.removeFromSuperlayer() }
        }

        let emitter = CAEmitterLayer()
        emitter.emitterPosition = center
        emitter.emitterShape = .point
        let cell = CAEmitterCell()
        cell.contents = squareImage(color)?.cgImage
        cell.birthRate = 90
        cell.lifetime = 1.1
        cell.velocity = 150
        cell.velocityRange = 70
        cell.emissionRange = .pi * 2
        cell.yAcceleration = 160
        cell.scale = 0.9
        cell.scaleRange = 0.5
        cell.alphaSpeed = -0.9
        cell.spin = 2
        cell.spinRange = 3
        emitter.emitterCells = [cell]
        host.layer.addSublayer(emitter)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { emitter.removeFromSuperlayer() }
    }

    private static func squareImage(_ color: UIColor) -> UIImage? {
        UIGraphicsImageRenderer(size: CGSize(width: 7, height: 7)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 7, height: 7))
        }
    }
}

/// Every transaction in a block: area by size, colour by fee rate. Tap one to open it.
final class ExplorerBlockMapView: UIView {
    var onSelect: ((ExplorerMapTx) -> Void)?
    private var items: [ExplorerMapTx] = []
    private var rects: [CGRect] = []
    private var laidOutSize: CGSize = .zero
    private var highlighted: Int?
    private var yours = Set<String>()
    private var yoursColor = WalletTheme.accent
    /// What's laid out now: the table reconfigures this cell whenever anything else changes.
    private var configuredFor: (count: Int, first: String?)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = WalletTheme.bg
        contentMode = .redraw
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// `yours` get an outline, whatever else is true of them.
    func configure(_ transactions: [ExplorerMapTx], yours: Set<String> = [], yoursColor: UIColor = WalletTheme.accent) {
        if yours != self.yours || yoursColor != self.yoursColor {
            self.yours = yours
            self.yoursColor = yoursColor
            setNeedsDisplay()
        }
        if let current = configuredFor, current.count == transactions.count, current.first == transactions.first?.txid { return }
        configuredFor = (transactions.count, transactions.first?.txid)
        items = transactions.sorted { $0.vsize > $1.vsize }
        laidOutSize = .zero
        highlighted = nil
        accessibilityLabel = "Block map of \(items.count) transactions"
        setNeedsLayout()
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != laidOutSize else { return }
        laidOutSize = bounds.size
        rects = ExplorerTreemap.layout(areas: items.map { Double($0.vsize) }, in: bounds.size)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), rects.count == items.count else { return }
        WalletTheme.bg.setFill()
        context.fill(rect)
        for (index, frame) in rects.enumerated() where frame.intersects(rect) {
            let item = items[index]
            (item.isCoinbase ? WalletTheme.text : ExplorerFeeColor.color(item.feeRate)).setFill()
            // A hairline gap, until they're too small to spare it.
            context.fill(frame.width > 2 && frame.height > 2 ? frame.insetBy(dx: 0.5, dy: 0.5) : frame)
        }
        if !yours.isEmpty {
            yoursColor.setStroke()
            context.setLineWidth(2)
            for (index, frame) in rects.enumerated() where yours.contains(items[index].txid) {
                context.stroke(frame.insetBy(dx: 1, dy: 1))
            }
        }
        if let highlighted = highlighted, highlighted < rects.count {
            UIColor.white.setStroke()
            context.setLineWidth(2)
            context.stroke(rects[highlighted].insetBy(dx: -1, dy: -1))
        }
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        guard let index = rects.firstIndex(where: { $0.contains(point) }) else { return }
        highlighted = index
        setNeedsDisplay()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onSelect?(items[index])
    }
}

/// Inputs on the left, outputs on the right, the money flowing between them: each ribbon's
/// width is its share of the value. Long lists are summed into one "+N more" ribbon.
final class ExplorerFlowView: UIView {
    /// `.input(i)` or `.output(i)` of the real lists; nil for a "+N more" ribbon.
    enum Side { case input(Int), output(Int) }
    var onSelect: ((Side) -> Void)?

    private struct Band {
        let value: Double
        let color: UIColor
        let side: Side?
    }

    private var left: [Band] = []
    private var right: [Band] = []
    private var leftRects: [CGRect] = []
    private var rightRects: [CGRect] = []
    private static let maxBands = 14
    private static let gap: CGFloat = 3
    private static let barWidth: CGFloat = 10

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        isAccessibilityElement = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ tx: ExplorerTx, tint: WalletTheme.Tint) {
        configure(inputs: tx.inputs.map { $0.coinbase ? nil : $0.valueBtc }, outputs: tx.outputs.map(\.valueBtc), fee: tx.feeBtc, tint: tint)
    }

    /// In BTC, in the transaction's order. A nil input: a coinbase, or one whose value isn't known.
    func configure(inputs: [Double?], outputs: [Double], fee: Double?, tint: WalletTheme.Tint) {
        let total = outputs.reduce(0, +)
        // If any is unknown, there's no telling their shares: inputs share the width equally.
        let isComplete = !inputs.contains { $0 == nil }
        let inputValues: [(Double, Int)] = inputs.enumerated().map { index, value in
            (isComplete ? value ?? 0 : max(total, 0.00000001) / Double(max(inputs.count, 1)), index)
        }
        left = Self.bands(inputValues, color: tint.accent) { .input($0) }
        right = Self.bands(outputs.enumerated().map { ($1, $0) }, color: WalletTheme.accent) { .output($0) }
        if let fee = fee, fee > 0 { right.append(Band(value: fee, color: WalletTheme.pending, side: nil)) }
        accessibilityLabel = "\(inputs.count) inputs flow to \(outputs.count) outputs"
        setNeedsDisplay()
    }

    private static func bands(_ values: [(Double, Int)], color: UIColor, side: (Int) -> Side) -> [Band] {
        var result: [Band] = []
        for (value, index) in values.prefix(maxBands) { result.append(Band(value: value, color: color, side: side(index))) }
        if values.count > maxBands {
            let rest = values.dropFirst(maxBands).reduce(0) { $0 + $1.0 }
            result.append(Band(value: rest, color: WalletTheme.dim, side: nil))
        }
        return result
    }

    /// Stacks the bands down `x`, heights by value with a small minimum so dust stays visible.
    private func stack(_ bands: [Band], x: CGFloat, height: CGFloat) -> [CGRect] {
        guard !bands.isEmpty else { return [] }
        let total = max(bands.reduce(0) { $0 + $1.value }, 0.00000001)
        let available = max(height - Self.gap * CGFloat(bands.count - 1), 1)
        let minimum = min(4, available / CGFloat(bands.count))
        let scaled = max(available - minimum * CGFloat(bands.count), 0)
        var y: CGFloat = 0
        return bands.map { band in
            let h = minimum + scaled * CGFloat(band.value / total)
            defer { y += h + Self.gap }
            return CGRect(x: x, y: y, width: Self.barWidth, height: h)
        }
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        leftRects = stack(left, x: 0, height: bounds.height)
        rightRects = stack(right, x: bounds.width - Self.barWidth, height: bounds.height)

        // Everything passes through a narrow waist in the middle, the transaction itself.
        let waistHeight = bounds.height * 0.55
        let waistY = (bounds.height - waistHeight) / 2
        let midX = bounds.midX

        func ribbons(_ rects: [CGRect], _ bands: [Band], isLeft: Bool) {
            let total = max(bands.reduce(0) { $0 + $1.value }, 0.00000001)
            var y = waistY
            for (index, frame) in rects.enumerated() {
                let share = waistHeight * CGFloat(bands[index].value / total)
                let edge = isLeft ? frame.maxX : frame.minX
                let path = UIBezierPath()
                let control = (edge + midX) / 2
                path.move(to: CGPoint(x: edge, y: frame.minY))
                path.addCurve(to: CGPoint(x: midX, y: y), controlPoint1: CGPoint(x: control, y: frame.minY), controlPoint2: CGPoint(x: control, y: y))
                path.addLine(to: CGPoint(x: midX, y: y + share))
                path.addCurve(to: CGPoint(x: edge, y: frame.maxY), controlPoint1: CGPoint(x: control, y: y + share), controlPoint2: CGPoint(x: control, y: frame.maxY))
                path.close()
                bands[index].color.withAlphaComponent(0.28).setFill()
                path.fill()
                bands[index].color.setFill()
                context.fill(frame)
                y += share
            }
        }
        ribbons(leftRects, left, isLeft: true)
        ribbons(rightRects, right, isLeft: false)
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let isLeft = point.x < bounds.midX
        let rects = isLeft ? leftRects : rightRects
        let bands = isLeft ? left : right
        guard let index = rects.firstIndex(where: { point.y >= $0.minY - Self.gap && point.y <= $0.maxY + Self.gap }),
              let side = bands[index].side else { return }
        onSelect?(side)
    }
}

private extension UIImage {
    /// A symbol as a bitmap: emitter cells can't draw one directly.
    var cgImageRendered: CGImage? {
        UIGraphicsImageRenderer(size: size).image { _ in draw(at: .zero) }.cgImage
    }
}
