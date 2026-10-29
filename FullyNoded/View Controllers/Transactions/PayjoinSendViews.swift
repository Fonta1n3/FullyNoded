//
//  PayjoinSendViews.swift
//  FullyNoded
//
//  Paying a payjoin invoice (BIP78, sender side), on screen:
//  - PayjoinRequestSheet: what a scanned payment request asks for, and how its payjoin will go.
//  - PayjoinBanner: the review screen's reminder before signing, and the outcome after.
//  - PayjoinNegotiationViewController: each step live while the receiver is asked to join in
//    (with Skip), then a before/after summary or why it fell back to the normal payment.
//

import UIKit

// MARK: - Shared bits

enum PayjoinUI {
    static let tint: WalletTheme.Tint = .send

    /// "abcd…wxyz.onion" / "pay.example.com".
    static func shortHost(_ host: String) -> String {
        let lower = host.lowercased()
        guard lower.hasSuffix(".onion") else { return host }
        let name = String(lower.dropLast(6))
        guard name.count > 12 else { return lower }
        return "\(name.prefix(6))…\(name.suffix(4)).onion"
    }

    static func sats(_ value: Int64) -> String { "\(Int(value).withCommas) sats" }

    static func label(_ text: String, size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = WalletTheme.text) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(size, weight: weight)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    static func icon(_ name: String, size: CGFloat, color: UIColor, width: CGFloat) -> UIImageView {
        let view = UIImageView(image: UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)))
        view.tintColor = color
        view.contentMode = .scaleAspectFit
        view.widthAnchor.constraint(equalToConstant: width).isActive = true
        return view
    }

    /// Key / value line for summaries.
    static func row(_ key: String, _ value: String, valueColor: UIColor = WalletTheme.text) -> UIView {
        let k = label(key.uppercased(), size: 10, weight: .bold, color: WalletTheme.dim)
        k.setContentHuggingPriority(.required, for: .horizontal)
        k.widthAnchor.constraint(equalToConstant: 84).isActive = true
        let v = label(value, size: 12, weight: .semibold, color: valueColor)
        let row = UIStackView(arrangedSubviews: [k, v])
        row.spacing = 10
        row.alignment = .firstBaseline
        return row
    }

    static func numbered(_ steps: [String]) -> UIView {
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 8
        for (i, step) in steps.enumerated() {
            let n = label("\(i + 1)", size: 11, weight: .heavy, color: WalletTheme.bg)
            n.textAlignment = .center
            n.backgroundColor = tint.accent
            n.widthAnchor.constraint(equalToConstant: 18).isActive = true
            n.heightAnchor.constraint(equalToConstant: 18).isActive = true
            let text = label(step, size: 11, color: WalletTheme.text)
            let row = UIStackView(arrangedSubviews: [n, text])
            row.spacing = 10
            row.alignment = .top
            list.addArrangedSubview(row)
        }
        return list
    }
}

// MARK: - Scanned request

/// A scanned payment request, before the transaction is made: the recipient, amount, label and
/// message, and (when offered) what payjoin means for this payment.
final class PayjoinRequestSheet: UIViewController {
    struct Details {
        let address: String
        let amount: String?
        let label: String?
        let message: String?
        let payjoin: URL?
        /// The request offered payjoin with a silent payment address chosen instead.
        let payjoinSkippedForSilentPayment: Bool
        /// The request offers payjoin but this wallet can't take part (why), so it pays normally.
        var payjoinUnavailable: String? = nil
    }

    private let details: Details
    private let tint = PayjoinUI.tint

    init(_ details: Details) {
        self.details = details
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = details.payjoin == nil ? [.medium(), .large()] : [.large()]
            sheet.prefersGrabberVisible = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        WalletTheme.apply(to: self, tint: tint)
        view.backgroundColor = WalletTheme.bg
        overrideUserInterfaceStyle = .dark

        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        stack.addArrangedSubview(PayjoinUI.label("Payment request", size: 20, weight: .bold))

        var rows: [UIView] = [WalletTheme.caption("> PAYING", tint: tint),
                              PayjoinUI.row("Address", details.address.addressExpanded),
                              PayjoinUI.row("Amount", details.amount.map { "\($0) btc" } ?? "not set: enter it on the next screen")]
        if let label = details.label, !label.isEmpty { rows.append(PayjoinUI.row("Label", label)) }
        if let message = details.message, !message.isEmpty { rows.append(PayjoinUI.row("Message", message)) }
        stack.addArrangedSubview(WalletTheme.cardView(rows, tint: tint, spacing: 10))

        if let url = details.payjoin {
            stack.addArrangedSubview(payjoinCard(url))
        } else if let reason = details.payjoinUnavailable {
            stack.addArrangedSubview(WalletTheme.cardView([
                PayjoinUI.label("This request also offers payjoin. This wallet pays it as a regular payment, which works just the same. \(reason)", size: 11, color: WalletTheme.dim)
            ], tint: tint))
        } else if details.payjoinSkippedForSilentPayment {
            stack.addArrangedSubview(WalletTheme.cardView([
                PayjoinUI.label("This request also offers payjoin, but only with its regular address. A silent payment is private in its own way.", size: 11, color: WalletTheme.dim)
            ], tint: tint))
        }

        let done = UIButton(type: .system)
        WalletTheme.styleHero(done, title: "Continue", systemImage: "arrow.right", tint: tint)
        done.addTarget(self, action: #selector(close), for: .touchUpInside)
        stack.addArrangedSubview(done)
    }

    private func payjoinCard(_ url: URL) -> UIView {
        let icon = PayjoinUI.icon("arrow.triangle.merge", size: 22, color: tint.accent, width: 30)
        let title = PayjoinUI.label("Payjoin supported", size: 16, weight: .bold)
        let subtitle = PayjoinUI.label("The receiver can add one of their coins to your payment (BIP78).", size: 11, color: WalletTheme.dim)
        let titles = UIStackView(arrangedSubviews: [title, subtitle])
        titles.axis = .vertical
        titles.spacing = 3
        let header = UIStackView(arrangedSubviews: [icon, titles])
        header.spacing = 12
        header.alignment = .center

        let host = url.host ?? url.absoluteString
        let onion = host.lowercased().hasSuffix(".onion")
        let tor = TorClient.sharedInstance.state == .connected
        let route = onion ? "over Tor, to the receiver's onion" : (tor ? "over Tor, to the receiver's server" : "directly over HTTPS (Tor isn't connected)")
        let endpoint = PayjoinUI.row("Receiver", "\(PayjoinUI.shortHost(host))\n\(route)", valueColor: tint.accent)

        let steps = PayjoinUI.numbered([
            "Make and sign the transaction as usual. That signed payment is kept: it's your fallback.",
            "Fully Noded sends it to the receiver, who adds a coin of theirs and sends it back.",
            "Their version is checked against BIP78's rules: same address, same amount, a fee you allow. Only then are your inputs signed again.",
            "You review it and tap Send. Nothing is broadcast before that."
        ])

        var rows: [UIView] = [WalletTheme.caption("> PAYJOIN", tint: tint), header, endpoint, steps]
        if onion && !tor {
            rows.append(PayjoinUI.label("⚠︎ Tor isn't connected yet. If it still isn't when you sign, this is paid normally.", size: 11, weight: .semibold, color: WalletTheme.pending))
        }
        rows.append(PayjoinUI.label("If anything goes wrong, the normal payment is used instead. A payjoin never blocks a payment.", size: 11, color: WalletTheme.dim))
        let card = WalletTheme.cardView(rows, tint: tint, spacing: 12, background: tint.accent.withAlphaComponent(0.06))
        card.layer.borderColor = tint.accent.cgColor
        return card
    }

    @objc private func close() { dismiss(animated: true) }
}

// MARK: - Review screen banner

/// Top of the review screen for a payjoin invoice: what will happen when it's signed, then what
/// happened.
final class PayjoinBanner: UIView {
    enum State {
        case offered(host: String)
        case used(receiverInputs: Int)
        case fellBack(reason: String)
    }

    private let icon = UIImageView()
    private let title = UILabel()
    private let detail = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let card = UIView()
        card.layer.borderWidth = 1
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
        title.font = WalletTheme.mono(12, weight: .bold)
        title.numberOfLines = 0
        detail.font = WalletTheme.mono(11)
        detail.textColor = WalletTheme.dim
        detail.numberOfLines = 0
        let texts = UIStackView(arrangedSubviews: [title, detail])
        texts.axis = .vertical
        texts.spacing = 3
        let row = UIStackView(arrangedSubviews: [icon, texts])
        row.spacing = 12
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])
        self.card = card
    }

    private var card: UIView!

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(_ state: State) {
        let color: UIColor
        switch state {
        case .offered(let host):
            color = PayjoinUI.tint.accent
            icon.image = UIImage(systemName: "arrow.triangle.merge")
            title.text = "⇄ PAYJOIN INVOICE"
            detail.text = "When you sign, Fully Noded asks \(PayjoinUI.shortHost(host)) to add a coin, checks their version and signs it. Your normal signed payment stays as the fallback."
        case .used(let receiverInputs):
            color = WalletTheme.Tint.home.accent
            icon.image = UIImage(systemName: "checkmark.seal.fill")
            title.text = receiverInputs > 0 ? "⇄ PAYJOIN READY" : "PAYJOIN: NO COIN ADDED"
            detail.text = receiverInputs > 0
                ? "The receiver's \(receiverInputs == 1 ? "coin is" : "\(receiverInputs) coins are") in this transaction and every BIP78 check passed. Review it, then tap Send."
                : "The receiver replied without adding a coin: it's an ordinary payment, checked and signed."
        case .fellBack(let reason):
            color = WalletTheme.pending
            icon.image = UIImage(systemName: "arrow.uturn.backward.circle.fill")
            title.text = "NORMAL PAYMENT (NO PAYJOIN)"
            detail.text = "\(reason) Your normal payment is signed and ready to send."
        }
        icon.tintColor = color
        title.textColor = color
        card.layer.borderColor = color.cgColor
        card.backgroundColor = color.withAlphaComponent(0.07)
    }
}

// MARK: - Negotiation

/// Full screen while a payjoin is negotiated: each step with a spinner, then a check or a cross;
/// the BIP78 checks ticking off; a clock while the receiver answers; Skip. It ends with a
/// summary (payjoin) or the reason it fell back (normal payment), and one button to review.
final class PayjoinNegotiationViewController: UIViewController {
    /// Tapped Review (or Skip): the transaction to load, and the outcome if it's the payjoin.
    var onDone: ((_ rawTx: String, _ outcome: Payjoin.Outcome?, _ fallbackReason: String?) -> Void)?

    private enum Step: Int, CaseIterable {
        case original, contacting, proposal, checks, signing, node

        var title: String {
            switch self {
            case .original: return "Your payment, signed"
            case .contacting: return "Asking the receiver to join in"
            case .proposal: return "Receiver's proposal"
            case .checks: return "BIP78 safety checks"
            case .signing: return "Signing your inputs"
            case .node: return "Your node's mempool test"
            }
        }
    }

    private struct Row {
        let icon = UIImageView()
        let spinner = UIActivityIndicatorView(style: .medium)
        let title = UILabel()
        let detail = UILabel()
    }

    private let tint = PayjoinUI.tint
    private let host: String
    private let fallbackRawTx: String
    private var rows: [Row] = []
    private var current: Step?
    private var finished = false
    private var contactStarted: Date?
    private var clock: Timer?

    private let header = UILabel()
    private let dot = UIView()
    private let checklist = UIStackView()
    private let resultBox = UIStackView()
    private let skipButton = UIButton(type: .system)
    private let reviewButton = UIButton(type: .system)
    private var payjoinRawTx: String?
    private var outcome: Payjoin.Outcome?
    private var fallbackReason: String?

    init(host: String, fallbackRawTx: String) {
        self.host = host
        self.fallbackRawTx = fallbackRawTx
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
        isModalInPresentation = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletTheme.bg.withAlphaComponent(0.97)
        overrideUserInterfaceStyle = .dark
        buildLayout()
        start(.original)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        clock?.invalidate()
    }

    // MARK: Layout

    private func buildLayout() {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        let icon = PayjoinUI.icon("arrow.triangle.merge", size: 26, color: tint.accent, width: 34)
        let title = PayjoinUI.label("Payjoin", size: 22, weight: .bold)
        let subtitle = PayjoinUI.label("with \(PayjoinUI.shortHost(host))", size: 12, color: WalletTheme.dim)
        let titles = UIStackView(arrangedSubviews: [title, subtitle])
        titles.axis = .vertical
        titles.spacing = 2
        let top = UIStackView(arrangedSubviews: [icon, titles])
        top.spacing = 12
        top.alignment = .center
        stack.addArrangedSubview(top)

        dot.layer.cornerRadius = 4
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        header.font = WalletTheme.mono(11, weight: .bold)
        header.adjustsFontSizeToFitWidth = true
        header.minimumScaleFactor = 0.7
        let headerRow = UIStackView(arrangedSubviews: [dot, header, UIView()])
        headerRow.spacing = 8
        headerRow.alignment = .center
        setHeader("NEGOTIATING", color: WalletTheme.pending, pulse: true)

        var stepViews: [UIView] = [headerRow]
        for step in Step.allCases {
            let row = Row()
            row.icon.image = UIImage(systemName: "circle.dotted")
            row.icon.tintColor = WalletTheme.dim
            row.icon.contentMode = .scaleAspectFit
            row.icon.translatesAutoresizingMaskIntoConstraints = false
            row.icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
            row.icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
            row.spinner.hidesWhenStopped = true
            row.spinner.color = tint.accent
            row.spinner.translatesAutoresizingMaskIntoConstraints = false
            row.title.text = step.title
            row.title.font = WalletTheme.mono(13, weight: .semibold)
            row.title.textColor = WalletTheme.dim
            row.title.numberOfLines = 0
            row.detail.font = WalletTheme.mono(11)
            row.detail.textColor = WalletTheme.dim
            row.detail.numberOfLines = 0
            row.detail.isHidden = true
            let iconBox = UIView()
            iconBox.translatesAutoresizingMaskIntoConstraints = false
            iconBox.widthAnchor.constraint(equalToConstant: 22).isActive = true
            iconBox.addSubview(row.icon)
            iconBox.addSubview(row.spinner)
            NSLayoutConstraint.activate([
                row.icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                row.icon.topAnchor.constraint(equalTo: iconBox.topAnchor),
                row.spinner.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                row.spinner.centerYAnchor.constraint(equalTo: row.icon.centerYAnchor)
            ])
            var texts: [UIView] = [row.title, row.detail]
            if step == .checks {
                checklist.axis = .vertical
                checklist.spacing = 4
                checklist.isHidden = true
                texts.append(checklist)
            }
            let textStack = UIStackView(arrangedSubviews: texts)
            textStack.axis = .vertical
            textStack.spacing = 4
            let line = UIStackView(arrangedSubviews: [iconBox, textStack])
            line.spacing = 10
            line.alignment = .top
            stepViews.append(line)
            rows.append(row)
        }
        stack.addArrangedSubview(WalletTheme.cardView(stepViews, tint: tint, spacing: 14))

        resultBox.axis = .vertical
        resultBox.spacing = 10
        resultBox.isHidden = true
        stack.addArrangedSubview(resultBox)

        skipButton.configuration = WalletTheme.buttonConfiguration(title: "Skip payjoin, pay normally", systemImage: "forward.fill", filled: false, tint: tint)
        skipButton.addTarget(self, action: #selector(skip), for: .touchUpInside)
        stack.addArrangedSubview(skipButton)
        stack.addArrangedSubview(PayjoinUI.label("Nothing is broadcast from here: you review the transaction and tap Send.", size: 10, color: WalletTheme.dim))

        WalletTheme.styleHero(reviewButton, title: "Review", systemImage: "arrow.right", tint: tint)
        reviewButton.addTarget(self, action: #selector(review), for: .touchUpInside)
        reviewButton.isHidden = true
        stack.addArrangedSubview(reviewButton)
    }

    private func setHeader(_ text: String, color: UIColor, pulse: Bool) {
        header.text = text
        header.textColor = color
        dot.backgroundColor = color
        dot.layer.removeAllAnimations()
        guard pulse else { return }
        let animation = CABasicAnimation(keyPath: "opacity")
        animation.fromValue = 1.0
        animation.toValue = 0.25
        animation.duration = 0.7
        animation.autoreverses = true
        animation.repeatCount = .infinity
        dot.layer.add(animation, forKey: "pulse")
    }

    // MARK: Progress

    func advance(_ stage: Payjoin.Stage) {
        guard !finished, isViewLoaded else { return }
        switch stage {
        case .original(let inputs, let fee, let feeRate):
            setDetail(.original, "\(inputs) input\(inputs == 1 ? "" : "s") · \(PayjoinUI.sats(fee)) fee (\(String(format: "%.1f", feeRate)) sat/vB). Kept as the fallback.")
            done(.original)
        case .contacting(let host, let overTor):
            start(.contacting)
            contactStarted = Date()
            let route = overTor ? "over Tor" : "over HTTPS"
            clock?.invalidate()
            clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                guard let self = self, let started = self.contactStarted else { return }
                let seconds = Int(Date().timeIntervalSince(started))
                self.setDetail(.contacting, "\(PayjoinUI.shortHost(host)) \(route) · waiting for their reply… \(seconds)s (up to 60s)")
            }
            setDetail(.contacting, "\(PayjoinUI.shortHost(host)) \(route) · sending your signed payment…")
        case .proposal(let inputs, let outputs):
            clock?.invalidate()
            if let started = contactStarted {
                setDetail(.contacting, "Replied in \(Int(Date().timeIntervalSince(started)))s")
            }
            done(.contacting)
            setDetail(.proposal, "\(inputs) inputs, \(outputs) outputs")
            done(.proposal)
            start(.checks)
            setDetail(.checks, "Checking the receiver's version against your payment…")
        case .checked(let receiverInputs, let contribution):
            setDetail(.proposal, "\(receiverInputs) coin\(receiverInputs == 1 ? "" : "s") added by the receiver" +
                      (contribution > 0 ? " · \(PayjoinUI.sats(contribution)) of fee from your change" : ""))
            setDetail(.checks, "All \(Payjoin.checklist.count) passed")
            revealChecks()
            done(.checks)
        case .signing:
            start(.signing)
            setDetail(.signing, "Only your own inputs: the receiver signed theirs.")
        case .nodeCheck:
            done(.signing)
            start(.node)
            setDetail(.node, "finalizepsbt and testmempoolaccept: would the network accept it?")
        }
    }

    private func revealChecks() {
        checklist.arrangedSubviews.forEach { $0.removeFromSuperview() }
        checklist.isHidden = false
        for (i, text) in Payjoin.checklist.enumerated() {
            let line = PayjoinUI.label("✓ \(text)", size: 10, color: WalletTheme.Tint.home.accent)
            line.alpha = 0
            checklist.addArrangedSubview(line)
            UIView.animate(withDuration: 0.2, delay: 0.07 * Double(i)) { line.alpha = 1 }
        }
    }

    private func setDetail(_ step: Step, _ text: String) {
        let row = rows[step.rawValue]
        row.detail.text = text
        row.detail.isHidden = false
    }

    private func start(_ step: Step) {
        for s in Step.allCases where s.rawValue < step.rawValue && rows[s.rawValue].spinner.isAnimating { done(s) }
        current = step
        let row = rows[step.rawValue]
        row.icon.isHidden = true
        row.spinner.startAnimating()
        row.title.textColor = WalletTheme.text
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func done(_ step: Step) {
        let row = rows[step.rawValue]
        row.spinner.stopAnimating()
        row.icon.isHidden = false
        row.icon.image = UIImage(systemName: "checkmark.circle.fill")
        row.icon.tintColor = tint.accent
        row.title.textColor = WalletTheme.text
        row.icon.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            row.icon.transform = .identity
        }
    }

    private func fail(_ step: Step, _ reason: String) {
        let row = rows[step.rawValue]
        row.spinner.stopAnimating()
        row.icon.isHidden = false
        row.icon.image = UIImage(systemName: "xmark.circle.fill")
        row.icon.tintColor = WalletTheme.danger
        row.title.textColor = WalletTheme.danger
        row.detail.text = reason
        row.detail.textColor = WalletTheme.danger
        row.detail.isHidden = false
        for s in Step.allCases where s.rawValue > step.rawValue {
            rows[s.rawValue].title.textColor = WalletTheme.dim.withAlphaComponent(0.5)
            rows[s.rawValue].icon.tintColor = WalletTheme.dim.withAlphaComponent(0.5)
        }
    }

    // MARK: Result

    func finish(_ result: Result<Payjoin.Outcome, Payjoin.Failure>) {
        guard !finished else { return }
        finished = true
        clock?.invalidate()
        skipButton.isHidden = true
        switch result {
        case .success(let outcome):
            done(.node)
            setDetail(.node, "Accepted. It's valid and fully signed.")
            self.outcome = outcome
            payjoinRawTx = outcome.rawTx
            setHeader(outcome.receiverInputs > 0 ? "PAYJOIN READY" : "READY (NO COIN ADDED)", color: WalletTheme.Tint.home.accent, pulse: false)
            showSummary(outcome)
            WalletTheme.styleHero(reviewButton, title: "Review payjoin", systemImage: "arrow.right", tint: tint)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .failure(let error):
            let reason = error.errorDescription ?? "The payjoin didn't work."
            fallbackReason = reason
            fail(current ?? .contacting, reason)
            setHeader("FELL BACK TO A NORMAL PAYMENT", color: WalletTheme.pending, pulse: false)
            showFallback(reason)
            WalletTheme.styleHero(reviewButton, title: "Review payment", systemImage: "arrow.right", tint: .warning)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        reviewButton.isHidden = false
        reviewButton.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.resultBox.isHidden = false
            self.reviewButton.alpha = 1
        }
    }

    private func showSummary(_ o: Payjoin.Outcome) {
        let inputsAfter = o.originalInputs + o.receiverInputs
        let feeDelta = o.proposalFee - o.originalFee
        var feeText = "\(PayjoinUI.sats(o.originalFee)) → \(PayjoinUI.sats(o.proposalFee))"
        if feeDelta > 0 {
            feeText += o.feeContribution > 0
                ? "\n+\(PayjoinUI.sats(o.feeContribution)) from your change (within your limit)" + (feeDelta > o.feeContribution ? ", the rest paid by the receiver" : "")
                : "\nthe extra \(PayjoinUI.sats(feeDelta)) paid by the receiver"
        }
        var rows: [UIView] = [
            WalletTheme.caption("> WHAT CHANGED", tint: .home),
            PayjoinUI.row("Inputs", "\(o.originalInputs) → \(inputsAfter)" + (o.receiverInputs > 0 ? " (+\(o.receiverInputs) from the receiver)" : "")),
            PayjoinUI.row("Fee", feeText),
            PayjoinUI.row("Payment", "Same address, same amount to them"),
            PayjoinUI.row("Checks", "\(Payjoin.checklist.count)/\(Payjoin.checklist.count) passed · node accepted it")
        ]
        if o.receiverAmount > 0 {
            rows.insert(PayjoinUI.row("Their coin", "\(PayjoinUI.sats(o.receiverAmount)): it comes back to them in the payment output"), at: 2)
        }
        let why = o.receiverInputs > 0
            ? "On-chain, this no longer looks like you paid them: some inputs are theirs, so \"all inputs belong to the sender\" is wrong, and the payment amount is hidden."
            : "The receiver didn't add a coin, so this is an ordinary payment (still checked and signed)."
        rows.append(PayjoinUI.label(why, size: 11, color: WalletTheme.dim))
        let card = WalletTheme.cardView(rows, tint: .home, spacing: 10, background: WalletTheme.Tint.home.accent.withAlphaComponent(0.06))
        resultBox.addArrangedSubview(card)
    }

    private func showFallback(_ reason: String) {
        let card = WalletTheme.cardView([
            WalletTheme.caption("> NO PAYJOIN THIS TIME", tint: .warning),
            PayjoinUI.label(reason, size: 12, weight: .semibold, color: WalletTheme.pending),
            PayjoinUI.label("Your normal payment is signed and ready: same address, same amount, the fee you chose. Review it and tap Send.", size: 11, color: WalletTheme.text)
        ], tint: .warning, spacing: 10, background: WalletTheme.pending.withAlphaComponent(0.07))
        resultBox.addArrangedSubview(card)
    }

    // MARK: Actions

    @objc private func skip() {
        guard !finished else { return }
        finished = true
        clock?.invalidate()
        let reason = "You skipped the payjoin."
        fallbackReason = reason
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.onDone?(self.fallbackRawTx, nil, reason)
        }
    }

    @objc private func review() {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            if let rawTx = self.payjoinRawTx, let outcome = self.outcome {
                self.onDone?(rawTx, outcome, nil)
            } else {
                self.onDone?(self.fallbackRawTx, nil, self.fallbackReason)
            }
        }
    }
}
