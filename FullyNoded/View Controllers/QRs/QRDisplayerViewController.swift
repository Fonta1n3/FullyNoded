//
//  QRDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import URKit
//import Bbqr

/// Shows a QR (static, or an animated UR for PSBTs and long payloads) with copy / share.
///
/// The storyboard scene ("QRDisplayer") only supplies the class; the layout is built in code
/// in the app's cypherpunk theme. Callers set `text` / `psbt` / `txn`, `headerText`,
/// `headerIcon`, `descriptionText` and optionally `isUR` before it appears, as before.
class QRDisplayerViewController: UIViewController {

    var text = ""
    var psbt = ""
    var txn = ""
    var headerText = ""
    var descriptionText = ""
    var headerIcon: UIImage!
    let qrGenerator = QRGenerator()
    //var isBbqr = false
    var isUR = false
    /// Accent for this screen (the signer screens use their purple).
    var tint: WalletTheme.Tint = .wallet

    private var encoder:UREncoder!
    private var timer: Timer?
    private var parts: [String] = []
    private var ur: UR!
    private var partIndex = 0
    private var isPaused = false

    private var originalQrText = ""

    // Storyboard outlets: still connected (the scene sets them), but the scene's views are
    // replaced by the layout below.
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var headerImage: UIImageView!

    private let qrImageView = UIImageView()
    private let qrFrame = UIView()
    private let titleLabel = UILabel()
    private let iconView = UIImageView()
    private let partLabel = UILabel()
    private let pauseButton = UIButton(type: .system)
    private let contentLabel = UILabel()
    private let descriptionLabel = UILabel()
    private var copyButton: UIButton!
    private var shareButton: UIButton!
    private var buttonsStackView: UIStackView!
    private var copyResetWork: DispatchWorkItem?

    override func viewDidLoad() {
        super.viewDidLoad()

        originalQrText = txn != "" ? txn : (text != "" ? text : psbt)

        buildLayout()

        /*if isBbqr {
            ...
        } else */if isUR {
            showActivity("loading...")

            if psbt != "" {
                guard let data = Data(base64Encoded: psbt) else {
                    hideActivity()
                    showAlert(vc: self, title: "", message: "Unable to convert base64 text to data.")
                    return
                }

                guard let psbtUr = URHelper.psbtUr(data) else {
                    hideActivity()
                    showAlert(vc: self, title: "", message: "Unable to convert to ur:crypto-psbt QR.")
                    return
                }

                animateUr(ur: psbtUr)

            } else {
                if text.lowercased().hasPrefix("ur:") {
                    guard let ur = URHelper.ur(text) else { return }

                    animateUr(ur: ur)
                }
            }
        } else if psbt.lowercased().hasPrefix("ur:") || text.lowercased().hasPrefix("ur:") {
            showActivity("loading...")

            guard let ur = URHelper.ur(text == "" ? psbt : text) else { return }

            animateUr(ur: ur)

        } else if txn != "" {
            qrImageView.image = qR(text: txn)

        } else if text != "" {
            qrImageView.image = qR(text: text)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Modal presentations (no navigation bar to go back with) get a close button.
        let isModalRoot = presentingViewController != nil
            && (navigationController == nil || navigationController?.viewControllers.first === self)
        if isModalRoot, navigationItem.rightBarButtonItem == nil {
            let close = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(closeAction(_:)))
            close.tintColor = tint.accent
            navigationItem.rightBarButtonItem = close
            if navigationController == nil { addFloatingCloseButton() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        text = ""
        psbt = ""
        txn = ""
        //isBbqr = false
        isUR = false
        partIndex = 0
        parts.removeAll()
        headerText = ""
        descriptionText = ""
        timer?.invalidate()
    }

    // MARK: - Layout

    private func buildLayout() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = WalletTheme.bg
        view.tintColor = tint.accent
        WalletTheme.styleNavigation(navigationItem, tint: tint)
        // The scene's own views are replaced by this layout.
        view.subviews.forEach { $0.removeFromSuperview() }

        // Header: icon + title.
        iconView.image = (headerIcon ?? UIImage(systemName: "qrcode"))?.withRenderingMode(.alwaysTemplate)
        iconView.tintColor = tint.accent
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        titleLabel.text = headerText.isEmpty ? "QR code" : headerText
        titleLabel.font = WalletTheme.mono(17, weight: .semibold)
        titleLabel.textColor = tint.text
        titleLabel.numberOfLines = 0

        let header = UIStackView(arrangedSubviews: [iconView, titleLabel])
        header.axis = .horizontal
        header.spacing = 10
        header.alignment = .center

        // The QR on a white quiet zone, in a thin accent frame with a soft glow.
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.layer.magnificationFilter = .nearest
        qrImageView.backgroundColor = .white
        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.isAccessibilityElement = true
        qrImageView.accessibilityLabel = "QR code"
        qrFrame.backgroundColor = .white
        qrFrame.layer.borderWidth = 1
        qrFrame.layer.borderColor = tint.accent.withAlphaComponent(0.7).cgColor
        qrFrame.layer.shadowColor = tint.accent.cgColor
        qrFrame.layer.shadowRadius = 14
        qrFrame.layer.shadowOpacity = 0.25
        qrFrame.layer.shadowOffset = .zero
        qrFrame.translatesAutoresizingMaskIntoConstraints = false
        qrFrame.addSubview(qrImageView)
        NSLayoutConstraint.activate([
            qrImageView.topAnchor.constraint(equalTo: qrFrame.topAnchor, constant: 14),
            qrImageView.leadingAnchor.constraint(equalTo: qrFrame.leadingAnchor, constant: 14),
            qrImageView.trailingAnchor.constraint(equalTo: qrFrame.trailingAnchor, constant: -14),
            qrImageView.bottomAnchor.constraint(equalTo: qrFrame.bottomAnchor, constant: -14),
            qrFrame.heightAnchor.constraint(equalTo: qrFrame.widthAnchor)
        ])

        // Animated QR status: "PART 3 / 12" and pause / play (hidden for static QRs).
        partLabel.font = WalletTheme.mono(11, weight: .semibold)
        partLabel.textColor = tint.dim
        pauseButton.setImage(UIImage(systemName: "pause.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)), for: .normal)
        pauseButton.tintColor = tint.accent
        pauseButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)
        pauseButton.accessibilityLabel = "Pause animation"
        let partRow = UIStackView(arrangedSubviews: [UIView(), partLabel, pauseButton, UIView()])
        partRow.axis = .horizontal
        partRow.spacing = 8
        partRow.alignment = .center
        partRow.distribution = .equalCentering
        partRow.isHidden = true
        partRow.tag = 0x9A27

        // What the QR holds: kind, size and a middle-truncated preview.
        contentLabel.text = contentSummary()
        contentLabel.font = WalletTheme.mono(11)
        contentLabel.textColor = tint.dim
        contentLabel.numberOfLines = 2
        contentLabel.lineBreakMode = .byTruncatingMiddle
        contentLabel.textAlignment = .center

        descriptionLabel.text = descriptionText
        descriptionLabel.font = WalletTheme.mono(12)
        descriptionLabel.textColor = tint.text.withAlphaComponent(0.85)
        descriptionLabel.numberOfLines = 0
        descriptionLabel.isHidden = descriptionText.isEmpty

        let descriptionCard = WalletTheme.cardView([descriptionLabel], tint: tint)
        descriptionCard.isHidden = descriptionText.isEmpty

        // Copy / share.
        copyButton = UIButton(type: .system)
        copyButton.configuration = WalletTheme.buttonConfiguration(title: "Copy text", systemImage: "doc.on.doc", filled: false, tint: tint)
        copyButton.addTarget(self, action: #selector(copyQrTextToClipboard), for: .touchUpInside)
        shareButton = UIButton(type: .system)
        shareButton.configuration = WalletTheme.buttonConfiguration(title: "Share", systemImage: "square.and.arrow.up", filled: true, tint: tint)
        shareButton.addTarget(self, action: #selector(shareQRCode), for: .touchUpInside)
        buttonsStackView = UIStackView(arrangedSubviews: [copyButton, shareButton])
        buttonsStackView.axis = .horizontal
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.spacing = 12
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        // Scrolling content (long descriptions), buttons pinned to the bottom.
        let content = UIStackView(arrangedSubviews: [header, qrFrame, partRow, contentLabel, descriptionCard])
        content.axis = .vertical
        content.spacing = 16
        content.alignment = .center
        content.setCustomSpacing(10, after: qrFrame)
        content.setCustomSpacing(6, after: partRow)
        content.translatesAutoresizingMaskIntoConstraints = false

        let scroll = UIScrollView()
        scroll.indicatorStyle = .white
        scroll.alwaysBounceVertical = true
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        view.addSubview(scroll)
        view.addSubview(buttonsStackView)

        let guide = view.safeAreaLayoutGuide
        let qrWidth = qrFrame.widthAnchor.constraint(equalTo: content.widthAnchor)
        qrWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: guide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: buttonsStackView.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 20),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
            content.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -24),

            // Big but never wider than ~420pt (iPad / Mac), and centred.
            qrWidth,
            qrFrame.widthAnchor.constraint(lessThanOrEqualToConstant: 420),

            buttonsStackView.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            buttonsStackView.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            buttonsStackView.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -16),
            buttonsStackView.heightAnchor.constraint(equalToConstant: 50)
        ])
        [header, partRow, contentLabel, descriptionCard].forEach {
            $0.widthAnchor.constraint(equalTo: content.widthAnchor).isActive = true
        }

        // Tap the QR for a full-screen view (easier to scan from another device).
        qrFrame.isUserInteractionEnabled = true
        qrFrame.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showFullscreen)))
    }

    /// e.g. "PSBT · 1,204 chars · cHNidP8BAH…AAAAAA==".
    private func contentSummary() -> String {
        guard !originalQrText.isEmpty else { return "" }
        let kind: String
        let lower = originalQrText.lowercased()
        if psbt != "" { kind = "PSBT" }
        else if txn != "" { kind = "Signed transaction" }
        else if lower.hasPrefix("ur:") { kind = "UR" }
        else if lower.hasPrefix("fnsp:") { kind = "Fully Noded Server link" }
        else if lower.hasPrefix("bitcoin:") { kind = "Payment request" }
        else if lower.hasPrefix("sp1") || lower.hasPrefix("tsp1") { kind = "Silent payment address" }
        else { kind = "Text" }
        // Secrets (scan keys inside fnsp links) aren't echoed under the QR.
        if lower.hasPrefix("fnsp:") { return kind }
        let count = NumberFormatter.localizedString(from: NSNumber(value: originalQrText.count), number: .decimal)
        let preview = originalQrText.count > 40
            ? "\(originalQrText.prefix(18))…\(originalQrText.suffix(18))"
            : originalQrText
        return "\(kind) · \(count) chars\n\(preview)"
    }

    private func addFloatingCloseButton() {
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
        close.tintColor = tint.accent
        close.backgroundColor = WalletTheme.card
        close.layer.borderWidth = 1
        close.layer.borderColor = tint.line.cgColor
        close.accessibilityLabel = "Close"
        close.addTarget(self, action: #selector(closeAction(_:)), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            close.widthAnchor.constraint(equalToConstant: 36),
            close.heightAnchor.constraint(equalToConstant: 36)
        ])
    }

    // MARK: - Actions

    @objc private func copyQrTextToClipboard() {
        UIPasteboard.general.string = originalQrText
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Inline confirmation on the button itself, then back to normal.
        copyButton.configuration = WalletTheme.buttonConfiguration(title: "Copied", systemImage: "checkmark", filled: false, tint: tint)
        copyResetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.copyButton.configuration = WalletTheme.buttonConfiguration(title: "Copy text", systemImage: "doc.on.doc", filled: false, tint: self.tint)
        }
        copyResetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    @objc private func shareQRCode() {
        // An animated QR can't be shared as one image: share its text instead.
        let item: Any
        if parts.count > 1 {
            item = originalQrText
        } else if let image = qrImageView.image {
            item = shareableImage(image)
        } else {
            return
        }

        let activityController = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.userInterfaceIdiom == .mac {
            activityController.popoverPresentationController?.sourceView = shareButton
            activityController.popoverPresentationController?.sourceRect = shareButton.bounds
        }

        present(activityController, animated: true)
    }

    /// The QR with a white quiet zone, so a shared / saved image scans reliably anywhere.
    private func shareableImage(_ qr: UIImage) -> UIImage {
        let side: CGFloat = 1024
        let margin: CGFloat = 64
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.cgContext.interpolationQuality = .none
            qr.draw(in: CGRect(x: margin, y: margin, width: side - margin * 2, height: side - margin * 2))
        }
    }

    @objc private func togglePause() {
        isPaused.toggle()
        pauseButton.setImage(UIImage(systemName: isPaused ? "play.fill" : "pause.fill",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)), for: .normal)
        pauseButton.accessibilityLabel = isPaused ? "Play animation" : "Pause animation"
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Full-screen white QR, easier to scan from another device. Tap anywhere to close.
    @objc private func showFullscreen() {
        let viewer = QRFullscreenViewController(source: qrImageView, tint: tint)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.modalTransitionStyle = .crossDissolve
        present(viewer, animated: true)
    }

    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - QR generation

    private func qR(text: String) -> UIImage {
        qrGenerator.qrText = text
        return qrGenerator.getQRCode()
    }

    @objc func animate() {
        guard !isPaused, !parts.isEmpty else { return }
        showQR(parts[partIndex])
        partLabel.text = "PART \(partIndex + 1) / \(parts.count)"

        if partIndex < parts.count - 1 {
            partIndex += 1
        } else {
            partIndex = 0
        }
    }

    private func showQR(_ string: String) {
        qrGenerator.qrText = string
        qrImageView.image = qrGenerator.getQRCode()
    }

    private func animateUr(ur: UR) {
        let encoder = UREncoder(ur, maxFragmentLen: 250)
        if encoder.isSinglePart {
            hideActivity()
            showQR(ur.qrString)
        } else {
            view.viewWithTag(0x9A27)?.isHidden = false
            timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
                guard let self = self else { return }

                let part = encoder.nextPart()
                let index = encoder.seqNum

                if index <= encoder.seqLen {
                    self.parts.append(part.uppercased())
                } else {
                    self.hideActivity()
                    self.animate()
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(timeInterval: 0.3, target: self, selector: #selector(self.animate), userInfo: nil, repeats: true)
                }
            }
        }
    }

    private func showBbqrParts(bbQrparts: [String]) {
        #if DEBUG
        print("showBbqrParts: \(bbQrparts)")
        #endif

        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            if partIndex < bbQrparts.count {
                showQR(bbQrparts[partIndex])
                partIndex += 1
            } else {
                partIndex = 0
            }
        }
    }

}

/// A QR shown as large as the screen allows on white, mirroring the source image view (so
/// an animated QR keeps animating). Tap to close.
final class QRFullscreenViewController: UIViewController {
    private weak var source: UIImageView?
    private let tint: WalletTheme.Tint
    private let imageView = UIImageView()
    private var link: CADisplayLink?

    init(source: UIImageView, tint: WalletTheme.Tint) {
        self.source = source
        self.tint = tint
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.layer.magnificationFilter = .nearest
        imageView.image = source?.image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)

        let hint = UILabel()
        hint.text = "tap to close"
        hint.font = WalletTheme.mono(12)
        hint.textColor = .darkGray
        hint.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hint)

        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor, constant: -32),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor),
            imageView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor, constant: -80),
            hint.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(close)))

        // Follow the source (animated QRs change frame several times a second).
        link = CADisplayLink(target: self, selector: #selector(sync))
        link?.preferredFramesPerSecond = 15
        link?.add(to: .main, forMode: .common)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        link?.invalidate()
        link = nil
    }

    @objc private func sync() {
        if let image = source?.image, image !== imageView.image { imageView.image = image }
    }

    @objc private func close() { dismiss(animated: true) }
}
