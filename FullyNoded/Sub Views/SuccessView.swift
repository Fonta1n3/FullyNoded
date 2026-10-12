//
//  SuccessView.swift
//  FullyNoded
//
//  The one way the app says "that worked":
//
//  - `SuccessView.show(in:title:subtitle:detail:onDismiss:secondaryTitle:onSecondary:)` for real milestones (transaction
//    sent or signed, wallet created, backup recovered...): a full-screen card with a check
//    that draws itself in a glowing ring, and a Done button. `detail` (e.g. a txid) is shown
//    in a box and copied with a tap.
//  - `SuccessView.toast(_:in:)` for small confirmations ("Address copied"): a pill at the
//    top that goes away on its own.
//
//  Both cover the whole window (navigation and tab bars included), play a haptic and
//  announce themselves to VoiceOver.
//
//  The card also has `.notice` (amber "!") and `.error` (red ✕) kinds: every
//  `showAlert(...)` / `displayAlert(...)` in the app is drawn with it (see Utilities.swift).
//  Cards never stack: one shown while another is up waits its turn.
//

import UIKit

final class SuccessView: UIView {

    enum Kind {
        case success, notice, error

        var tint: WalletTheme.Tint {
            switch self {
            case .success: return .home
            case .notice: return .warning
            case .error: return .danger
            }
        }
    }

    /// Called after Done is tapped and the card has gone.
    var onDismiss: (() -> Void)?
    /// Called after the optional secondary button is tapped and the card has gone (after `onDismiss`).
    var onSecondary: (() -> Void)?

    private let kind: Kind
    private let tint: WalletTheme.Tint
    private let overlay = UIView()
    private let card = UIView()
    private let ring = CAShapeLayer()
    private let check = CAShapeLayer()
    private let checkContainer = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let subtitleScroll = UIScrollView()
    private let detailButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let detail: String?

    private static let checkSize: CGFloat = 96

    // MARK: - Showing

    /// Full card. Must be dismissed with its button. Safe from any thread.
    static func show(in viewController: UIViewController,
                     kind: Kind = .success,
                     title: String,
                     subtitle: String = "",
                     detail: String? = nil,
                     onDismiss: (() -> Void)? = nil,
                     secondaryTitle: String? = nil,
                     onSecondary: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            show(on: viewController.view.window ?? viewController.view, kind: kind, title: title, subtitle: subtitle,
                 detail: detail, onDismiss: onDismiss, secondaryTitle: secondaryTitle, onSecondary: onSecondary)
        }
    }

    /// Same, on a window (or any view) directly. Main queue only.
    static func show(on host: UIView?,
                     kind: Kind = .success,
                     title: String,
                     subtitle: String = "",
                     detail: String? = nil,
                     onDismiss: (() -> Void)? = nil,
                     secondaryTitle: String? = nil,
                     onSecondary: (() -> Void)? = nil) {
        guard let host = host else { return }
        let present = {
            let view = SuccessView(kind: kind, title: title, subtitle: subtitle, detail: detail, secondaryTitle: secondaryTitle)
            view.onDismiss = onDismiss
            view.onSecondary = onSecondary
            view.translatesAutoresizingMaskIntoConstraints = false
            // The card must not hide behind the keyboard.
            host.endEditing(true)
            host.addSubview(view)
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: host.topAnchor),
                view.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: host.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: host.bottomAnchor)
            ])
            host.layoutIfNeeded()
            view.animateIn()
        }
        // One card at a time: a second one (UIAlertController just dropped it) waits.
        if isShowing {
            queue.append(present)
        } else {
            isShowing = true
            present()
        }
    }

    private static var isShowing = false
    private static var queue: [() -> Void] = []

    private static func showNext() {
        if queue.isEmpty {
            isShowing = false
        } else {
            queue.removeFirst()()
        }
    }

    /// Small confirmation that disappears by itself. Safe from any thread.
    static func toast(_ message: String, in viewController: UIViewController) {
        toast(message, in: viewController.view)
    }

    /// Same, from any view (e.g. a button in a table cell). Safe from any thread.
    static func toast(_ message: String, in view: UIView?) {
        DispatchQueue.main.async {
            guard let host = view?.window ?? view else { return }
            host.subviews.filter { $0 is SuccessToast }.forEach { $0.removeFromSuperview() }
            let toast = SuccessToast(message: message)
            toast.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(toast)
            NSLayoutConstraint.activate([
                toast.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor, constant: 8),
                toast.centerXAnchor.constraint(equalTo: host.centerXAnchor),
                toast.leadingAnchor.constraint(greaterThanOrEqualTo: host.leadingAnchor, constant: 24)
            ])
            toast.present()
        }
    }

    // MARK: - Card

    private init(kind: Kind, title: String, subtitle: String, detail: String?, secondaryTitle: String?) {
        self.kind = kind
        self.tint = kind.tint
        self.detail = detail
        super.init(frame: .zero)
        accessibilityViewIsModal = true

        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.82)
        overlay.translatesAutoresizingMaskIntoConstraints = false
        addSubview(overlay)

        card.backgroundColor = WalletTheme.card
        card.layer.borderWidth = 1
        card.layer.borderColor = tint.line.cgColor
        card.layer.shadowColor = tint.accent.cgColor
        card.layer.shadowOpacity = 0.25
        card.layer.shadowRadius = 30
        card.layer.shadowOffset = .zero
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)

        // Ring + check drawn as strokes so they can animate.
        checkContainer.translatesAutoresizingMaskIntoConstraints = false
        let size = Self.checkSize
        let ringPath = UIBezierPath(arcCenter: CGPoint(x: size / 2, y: size / 2), radius: size / 2 - 3,
                                    startAngle: -.pi / 2, endAngle: 1.5 * .pi, clockwise: true)
        ring.path = ringPath.cgPath
        ring.fillColor = tint.accent.withAlphaComponent(0.08).cgColor
        ring.strokeColor = tint.accent.cgColor
        ring.lineWidth = 3
        ring.strokeEnd = 0
        // The mark drawn inside the ring: ✓, ✕ or "!".
        let checkPath = UIBezierPath()
        switch kind {
        case .success:
            checkPath.move(to: CGPoint(x: size * 0.28, y: size * 0.52))
            checkPath.addLine(to: CGPoint(x: size * 0.44, y: size * 0.67))
            checkPath.addLine(to: CGPoint(x: size * 0.73, y: size * 0.36))
        case .error:
            checkPath.move(to: CGPoint(x: size * 0.34, y: size * 0.34))
            checkPath.addLine(to: CGPoint(x: size * 0.66, y: size * 0.66))
            checkPath.move(to: CGPoint(x: size * 0.66, y: size * 0.34))
            checkPath.addLine(to: CGPoint(x: size * 0.34, y: size * 0.66))
        case .notice:
            checkPath.move(to: CGPoint(x: size * 0.5, y: size * 0.26))
            checkPath.addLine(to: CGPoint(x: size * 0.5, y: size * 0.58))
            checkPath.move(to: CGPoint(x: size * 0.5, y: size * 0.72))
            checkPath.addLine(to: CGPoint(x: size * 0.5, y: size * 0.73))
        }
        check.path = checkPath.cgPath
        check.fillColor = UIColor.clear.cgColor
        check.strokeColor = tint.accent.cgColor
        check.lineWidth = 6
        check.lineCap = .round
        check.lineJoin = .round
        check.strokeEnd = 0
        checkContainer.layer.addSublayer(ring)
        checkContainer.layer.addSublayer(check)
        checkContainer.layer.shadowColor = tint.accent.cgColor
        checkContainer.layer.shadowRadius = 14
        checkContainer.layer.shadowOpacity = 0
        checkContainer.layer.shadowOffset = .zero

        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(20, weight: .bold)
        titleLabel.textColor = WalletTheme.text
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        subtitleLabel.text = subtitle
        subtitleLabel.font = WalletTheme.mono(13)
        subtitleLabel.textColor = WalletTheme.dim
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.isHidden = subtitle.isEmpty

        var detailConfig = UIButton.Configuration.plain()
        detailConfig.title = detail
        detailConfig.image = UIImage(systemName: "doc.on.doc",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
        detailConfig.imagePlacement = .trailing
        detailConfig.imagePadding = 8
        detailConfig.titleLineBreakMode = .byTruncatingMiddle
        detailConfig.baseForegroundColor = tint.accent
        detailConfig.background.backgroundColor = WalletTheme.bg
        detailConfig.background.strokeColor = tint.line
        detailConfig.background.strokeWidth = 1
        detailConfig.background.cornerRadius = WalletTheme.radius
        detailConfig.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
        detailConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(12, weight: .medium)
            return attributes
        }
        detailButton.configuration = detailConfig
        detailButton.isHidden = (detail ?? "").isEmpty
        detailButton.accessibilityLabel = "Copy \(detail ?? "")"
        detailButton.addTarget(self, action: #selector(copyDetail), for: .touchUpInside)

        WalletTheme.styleHero(doneButton,
                              title: kind == .success ? "Done" : "OK",
                              systemImage: "checkmark",
                              tint: tint)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        var secondaryConfig = UIButton.Configuration.plain()
        secondaryConfig.title = secondaryTitle
        secondaryConfig.image = UIImage(systemName: "square.and.arrow.up",
                                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        secondaryConfig.imagePlacement = .leading
        secondaryConfig.imagePadding = 8
        secondaryConfig.baseForegroundColor = tint.accent
        secondaryConfig.background.backgroundColor = .clear
        secondaryConfig.background.strokeColor = tint.line
        secondaryConfig.background.strokeWidth = 1
        secondaryConfig.background.cornerRadius = WalletTheme.radius
        secondaryConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(14, weight: .semibold)
            return attributes
        }
        secondaryButton.configuration = secondaryConfig
        secondaryButton.isHidden = (secondaryTitle ?? "").isEmpty
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        let checkRow = UIStackView(arrangedSubviews: [checkContainer])
        checkRow.axis = .vertical
        checkRow.alignment = .center
        // Long messages (node error dumps) scroll inside the card instead of pushing it off screen.
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleScroll.addSubview(subtitleLabel)
        subtitleScroll.isHidden = subtitle.isEmpty
        subtitleScroll.showsVerticalScrollIndicator = true
        subtitleScroll.alwaysBounceVertical = false
        NSLayoutConstraint.activate([
            subtitleLabel.topAnchor.constraint(equalTo: subtitleScroll.contentLayoutGuide.topAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: subtitleScroll.contentLayoutGuide.bottomAnchor),
            subtitleLabel.leadingAnchor.constraint(equalTo: subtitleScroll.contentLayoutGuide.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: subtitleScroll.contentLayoutGuide.trailingAnchor),
            subtitleLabel.widthAnchor.constraint(equalTo: subtitleScroll.frameLayoutGuide.widthAnchor)
        ])
        // As tall as the text, until the card reaches the screen edges.
        let fitText = subtitleScroll.heightAnchor.constraint(equalTo: subtitleLabel.heightAnchor)
        fitText.priority = .defaultLow
        fitText.isActive = true

        let stack = UIStackView(arrangedSubviews: [checkRow, titleLabel, subtitleScroll, detailButton, secondaryButton, doneButton])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(22, after: checkRow)
        stack.setCustomSpacing(22, after: detailButton.isHidden ? subtitleScroll : detailButton)
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor),

            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 400),
            card.topAnchor.constraint(greaterThanOrEqualTo: safeAreaLayoutGuide.topAnchor, constant: 20),
            card.bottomAnchor.constraint(lessThanOrEqualTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),

            checkContainer.widthAnchor.constraint(equalToConstant: size),
            checkContainer.heightAnchor.constraint(equalToConstant: size),

            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
            doneButton.heightAnchor.constraint(equalToConstant: 52),
            secondaryButton.heightAnchor.constraint(equalToConstant: 48)
        ])
        let preferredWidth = card.widthAnchor.constraint(equalToConstant: 400)
        preferredWidth.priority = .defaultHigh
        preferredWidth.isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Animation

    private func animateIn() {
        UINotificationFeedbackGenerator().notificationOccurred(kind == .success ? .success : (kind == .error ? .error : .warning))
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)

        overlay.alpha = 0
        card.alpha = 0
        card.transform = CGAffineTransform(scaleX: 0.88, y: 0.88).translatedBy(x: 0, y: 12)
        UIView.animate(withDuration: 0.25) { self.overlay.alpha = 1 }
        UIView.animate(withDuration: 0.55, delay: 0.05, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.4) {
            self.card.alpha = 1
            self.card.transform = .identity
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            ring.strokeEnd = 1
            check.strokeEnd = 1
            checkContainer.layer.shadowOpacity = 0.7
            return
        }

        // Ring sweeps round, then the check draws itself, then a soft glow pulse.
        let now = CACurrentMediaTime()
        draw(ring, duration: 0.45, begin: now + 0.15)
        draw(check, duration: 0.3, begin: now + 0.55)

        let glow = CABasicAnimation(keyPath: "shadowOpacity")
        glow.fromValue = 0
        glow.toValue = 0.7
        glow.duration = 0.35
        glow.beginTime = now + 0.8
        glow.fillMode = .backwards
        checkContainer.layer.add(glow, forKey: "glow")
        checkContainer.layer.shadowOpacity = 0.7

        let pop = CAKeyframeAnimation(keyPath: "transform.scale")
        pop.values = [1, 1.12, 0.97, 1]
        pop.keyTimes = [0, 0.4, 0.75, 1]
        pop.duration = 0.4
        pop.beginTime = now + 0.82
        checkContainer.layer.add(pop, forKey: "pop")
    }

    private func draw(_ layer: CAShapeLayer, duration: CFTimeInterval, begin: CFTimeInterval) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0
        animation.toValue = 1
        animation.duration = duration
        animation.beginTime = begin
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        animation.fillMode = .backwards
        layer.add(animation, forKey: "draw")
        layer.strokeEnd = 1
    }

    // MARK: - Actions

    @objc private func copyDetail() {
        guard let detail = detail else { return }
        UIPasteboard.general.string = detail
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var config = detailButton.configuration
        config?.image = UIImage(systemName: "checkmark",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold))
        detailButton.configuration = config
        UIAccessibility.post(notification: .announcement, argument: "Copied")
    }

    @objc private func secondaryTapped() {
        dismissCard(runSecondary: true)
    }

    @objc private func doneTapped() {
        dismissCard(runSecondary: false)
    }

    private func dismissCard(runSecondary: Bool) {
        doneButton.isUserInteractionEnabled = false
        secondaryButton.isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.25, animations: {
            self.overlay.alpha = 0
            self.card.alpha = 0
            self.card.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }, completion: { _ in
            self.removeFromSuperview()
            self.onDismiss?()
            if runSecondary { self.onSecondary?() }
            Self.showNext()
        })
    }
}

// MARK: - Toast

/// "✓ Address copied" pill: slides down, stays ~1.6 s, slides away. Taps pass through.
private final class SuccessToast: UIView {
    private let tint = WalletTheme.Tint.home

    init(message: String) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = WalletTheme.card
        layer.borderWidth = 1
        layer.borderColor = tint.line.cgColor
        layer.shadowColor = tint.accent.cgColor
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 12
        layer.shadowOffset = .zero

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)))
        icon.tintColor = tint.accent
        icon.setContentHuggingPriority(.required, for: .horizontal)
        let label = UILabel()
        label.text = message.replacingOccurrences(of: " ✓", with: "")
        label.font = WalletTheme.mono(13, weight: .semibold)
        label.textColor = WalletTheme.text
        label.numberOfLines = 2

        let row = UIStackView(arrangedSubviews: [icon, label])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        ])
        isAccessibilityElement = true
        accessibilityLabel = label.text
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        UIAccessibility.post(notification: .announcement, argument: accessibilityLabel)
        alpha = 0
        transform = CGAffineTransform(translationX: 0, y: -16)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.4) {
            self.alpha = 1
            self.transform = .identity
        } completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 1.4, options: [.curveEaseIn]) {
                self.alpha = 0
                self.transform = CGAffineTransform(translationX: 0, y: -10)
            } completion: { _ in
                self.removeFromSuperview()
            }
        }
    }
}
