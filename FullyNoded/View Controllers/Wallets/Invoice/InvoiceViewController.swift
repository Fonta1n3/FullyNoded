//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//
//  Receive screen, built in code: Receive to (Address / Payjoin / Silent payment), the QR, the
//  address, a timelock, then the request fields and the BIP21 text. A BIP21 payment request for a
//  fresh address (optional amount / label / message; Fully Noded wallets can also timelock the
//  address until a date), the same plus a BIP78 payjoin endpoint, or, when the wallet has one,
//  its silent payment address on its own. Requests are never combined with `sp=` (BIP321);
//  paying such requests is still supported (AddressParser).
//

import UIKit

class InvoiceViewController: UIViewController, UITextFieldDelegate {

    /// What the QR asks to be paid (the choice appears when the wallet can do more than an address).
    private enum Mode {
        /// `bitcoin:<address>[?amount=…&label=…&message=…]` (BIP21).
        case address
        /// The same, plus `pj=` to a payjoin endpoint hosted from this phone (BIP78).
        case payjoin
        /// The `sp1…` / `tsp1…` address alone.
        case silentPayment

        var title: String {
            switch self {
            case .address: return "Address"
            case .payjoin: return "Payjoin"
            case .silentPayment: return "Silent pay"
            }
        }
    }

    var wallet: Wallet?
    var fxRate: Double? = UserDefaults.standard.object(forKey: "fxRate") as? Double

    private let tint: WalletTheme.Tint = .receive
    private let qrGenerator = QRGenerator()
    private var mode: Mode = .address
    private var addressString = ""
    /// The silent payment address of a signer of this wallet, if it has one.
    private var silentPaymentAddress: String?
    private var silentPaymentSigner: String?
    /// The signer the silent payment address comes from (for the FN-Server link) and its network.
    private var silentPaymentSignerStruct: SignerStruct?
    private var silentPaymentMainnet = true
    private var timelockedUntil: String?
    private var timelockedDate: Date?
    /// The tabs in Receive to, in order.
    private var modes: [Mode] = [.address]
    /// The text in the QR: the BIP21 request or the silent payment address.
    private var requestText = ""

    // Views
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let modeControl = UISegmentedControl(items: ["Address"])
    private let modeNote = UILabel()
    private var modeCard: UIView!
    private var addressCard: UIView!
    private var silentPaymentCard: UIView!
    /// "One more step to see these payments", above the QR on the Silent payment tab.
    private var spHeadsUpCard: UIView!
    private let spAckButton = UIButton(type: .system)
    /// Wallets whose user acknowledged that silent payments need scanning to show up.
    private static let spAcknowledgedKey = "silentPaymentScanAcknowledged"
    private let silentPaymentLabel = UILabel()
    private let qrImageView = UIImageView()
    private let qrCaption = UILabel()
    private let addressCaption = WalletTheme.caption("> ADDRESS", tint: .receive)
    private let addressLabel = UILabel()
    private let addressInfoButton = UIButton(type: .system)
    private let amountField = UITextField()
    private let amountHint = UILabel()
    private let labelField = UITextField()
    private let messageField = UITextField()
    private let requestLabel = UILabel()
    private let timelockButton = UIButton(type: .system)
    private var timelockPicker: UIView!
    private var timelockLocked: UIView!
    private let timelockDateLabel = UILabel()
    private let timelockCountdownLabel = UILabel()
    private var requestCard: UIView!
    private var uriCard: UIView!
    private var timelockCard: UIView!

    // Payjoin (BIP78 receiver, hosted on a one-time onion while this screen is open)
    /// The payjoin panel inside Receive to (shown on the Payjoin tab).
    private var payjoinCard: UIView!
    private let payjoinHeadline = UILabel()
    private var payjoinAutoRow: UIView?
    private var payjoinBenefits: UIView!
    private let payjoinButton = UIButton(type: .system)
    private let payjoinAutoSwitch = UISwitch()
    private let payjoinStatus = UILabel()
    private var payjoinBroadcastButton: UIButton!
    /// Leaves payjoin (back to the Address tab): Cancel while setting up, Stop once live.
    private var payjoinQuitButton: UIButton!
    private var qrCardView: UIView!
    private let payjoinProgress = PayjoinProgressView()
    /// The QR's white frame (it glows while payjoin is live).
    private var qrFrame: UIView?
    /// "⇄ PAYJOIN" pinned to the top of the QR while the invoice carries an endpoint.
    private let qrBadge = PaddedLabel()
    private var payjoinSession: PayjoinReceiveSession?
    /// The endpoint in the invoice, once the onion is reachable.
    private var payjoinURL: URL?
    /// The user wants payjoin on this invoice (stays on across a new address).
    private var payjoinOn = false
    /// Whether a signer of this wallet is on this device (nil until checked): it signs the coin we add.
    private var payjoinHasSigner: Bool?
    /// Why this wallet can't receive a payjoin (Payjoin.unavailableReason), shown on the Payjoin tab.
    private var payjoinUnavailableReason: String?
    /// Auto-start is tried once per screen, for the first address.
    private var payjoinAutoTried = false
    /// Invalidates a pending "waiting for Tor" retry.
    private var torWaitID = 0
    private static let payjoinAutoKey = "payjoinAutoStart"

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Receive"
        WalletTheme.apply(to: self, tint: tint)
        buildLayout()
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain,
                                                            target: self, action: #selector(newAddress))
        navigationItem.rightBarButtonItem?.tintColor = tint.accent
        navigationItem.rightBarButtonItem?.accessibilityLabel = "New address"
        updateRequest()
        generateOnchainInvoice()
        loadSilentPaymentAddress()
        checkPayjoinSigner()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isMovingFromParent || isBeingDismissed || navigationController?.isBeingDismissed == true {
            payjoinOn = false
            stopPayjoin()
        }
    }

    // MARK: Layout

    private func buildLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)

        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24)
        ])

        // Receive to → QR → address → timelock → request. Receive to (with the payjoin panel)
        // only appears when there's more than a plain address to choose.
        payjoinCard = makePayjoinCard()
        modeCard = makeModeCard()
        modeCard.setHiddenIfNeeded(true)
        stack.addArrangedSubview(modeCard)

        spHeadsUpCard = makeSilentPaymentHeadsUp()
        spHeadsUpCard.setHiddenIfNeeded(true)
        stack.addArrangedSubview(spHeadsUpCard)
        qrCardView = qrCard()
        stack.addArrangedSubview(qrCardView)
        addressCard = makeAddressCard()
        stack.addArrangedSubview(addressCard)
        silentPaymentCard = makeSilentPaymentCard()
        silentPaymentCard.setHiddenIfNeeded(true)
        stack.addArrangedSubview(silentPaymentCard)
        timelockCard = makeTimelockCard()
        timelockCard.setHiddenIfNeeded(!canTimelock)
        stack.addArrangedSubview(timelockCard)
        requestCard = makeRequestCard()
        stack.addArrangedSubview(requestCard)
        uriCard = makeUriCard()
        stack.addArrangedSubview(uriCard)
        rebuildModes()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func chip(_ title: String, _ image: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = WalletTheme.chipConfiguration(title: title, systemImage: image, tint: tint, fontSize: 12, imageSize: 11,
                                                             imagePadding: 5, insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func chipRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons + [UIView()])
        row.spacing = 8
        row.alignment = .center
        return row
    }

    private func qrCard() -> UIView {
        qrImageView.contentMode = .scaleAspectFit
        qrImageView.layer.magnificationFilter = .nearest
        qrImageView.backgroundColor = .white
        qrImageView.isUserInteractionEnabled = true
        qrImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showQrFullScreen)))
        qrImageView.accessibilityLabel = "Payment request QR code"
        qrImageView.accessibilityHint = "Shows it full screen"
        qrImageView.translatesAutoresizingMaskIntoConstraints = false

        let frame = UIView()
        frame.backgroundColor = .white
        frame.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(qrImageView)
        qrFrame = frame
        NSLayoutConstraint.activate([
            qrImageView.topAnchor.constraint(equalTo: frame.topAnchor, constant: 12),
            qrImageView.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: -12),
            qrImageView.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 12),
            qrImageView.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -12),
            qrImageView.widthAnchor.constraint(equalTo: qrImageView.heightAnchor),
            frame.widthAnchor.constraint(equalToConstant: 264)
        ])
        qrBadge.text = "⇄ PAYJOIN"
        qrBadge.insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        qrBadge.font = WalletTheme.mono(11, weight: .heavy)
        qrBadge.textColor = WalletTheme.bg
        qrBadge.backgroundColor = tint.accent
        qrBadge.setHiddenIfNeeded(true)
        qrBadge.translatesAutoresizingMaskIntoConstraints = false
        frame.addSubview(qrBadge)
        NSLayoutConstraint.activate([
            qrBadge.centerXAnchor.constraint(equalTo: frame.centerXAnchor),
            qrBadge.centerYAnchor.constraint(equalTo: frame.topAnchor)
        ])
        let centered = UIStackView(arrangedSubviews: [UIView(), frame, UIView()])
        centered.distribution = .equalCentering

        qrCaption.font = WalletTheme.mono(11)
        qrCaption.textColor = WalletTheme.dim
        qrCaption.textAlignment = .center
        qrCaption.numberOfLines = 0
        qrCaption.text = "Tap the QR to show it full screen."

        let actions = chipRow([chip("Copy QR", "doc.on.doc", action: #selector(copyQr)),
                               chip("Share QR", "square.and.arrow.up", action: #selector(shareQr))])
        return WalletTheme.cardView([centered, qrCaption, actions], tint: tint, spacing: 12)
    }

    private func makeModeCard() -> UIView {
        WalletTheme.style(modeControl, tint: tint)
        modeControl.selectedSegmentIndex = 0
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeNote.font = WalletTheme.mono(11)
        modeNote.textColor = WalletTheme.dim
        modeNote.numberOfLines = 0
        return WalletTheme.cardView([WalletTheme.caption("> RECEIVE TO", tint: tint), modeControl, modeNote, payjoinCard], tint: tint, spacing: 12)
    }

    /// The tabs: Address always, Payjoin for Fully Noded wallets (once checked; it explains itself
    /// when this wallet can't payjoin), Silent payment when the wallet has a silent payment address.
    private func rebuildModes() {
        var modes: [Mode] = [.address]
        if wallet != nil, payjoinHasSigner != nil { modes.append(.payjoin) }
        if silentPaymentAddress != nil { modes.append(.silentPayment) }
        if modes != self.modes || modeControl.numberOfSegments != modes.count {
            self.modes = modes
            modeControl.removeAllSegments()
            for (index, mode) in modes.enumerated() { modeControl.insertSegment(withTitle: mode.title, at: index, animated: false) }
        }
        if !modes.contains(mode) { mode = .address }
        updateModeControl()
    }

    private func updateModeControl() {
        modeControl.selectedSegmentIndex = modes.firstIndex(of: mode) ?? 0
        let locked = timelockedUntil != nil
        for (index, mode) in modes.enumerated() {
            let enabled = mode == .address || !locked
            modeControl.setEnabled(enabled, forSegmentAt: index)
        }
        modeCard.setHiddenIfNeeded(modes.count < 2)
        // The card lights up while it's on payjoin (not when it's only explaining why it can't).
        let lit = mode == .payjoin && payjoinHasSigner != false
        modeCard.layer.borderColor = (lit ? tint.accent : tint.line).cgColor
        modeCard.backgroundColor = lit ? tint.accent.withAlphaComponent(0.06) : WalletTheme.card
    }

    private func makeSilentPaymentCard() -> UIView {
        silentPaymentLabel.font = WalletTheme.mono(13, weight: .semibold)
        silentPaymentLabel.textColor = WalletTheme.text
        silentPaymentLabel.numberOfLines = 0
        silentPaymentLabel.lineBreakMode = .byCharWrapping
        let actions = chipRow([chip("Copy", "doc.on.doc", action: #selector(copySilentPaymentAddress)),
                               chip("Share", "square.and.arrow.up", action: #selector(shareSilentPaymentAddress))])

        let addressCard = WalletTheme.cardView([WalletTheme.caption("> SILENT PAYMENT ADDRESS", tint: tint), silentPaymentLabel, actions],
                                               tint: tint, spacing: 10)

        // Payments to it are only found by scanning, so the FN-Server link gets its own card.
        let icon = UIImageView(image: UIImage(systemName: "eye", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)))
        icon.tintColor = tint.accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let title = UILabel()
        title.text = "Scan for your payments"
        title.font = WalletTheme.mono(16, weight: .bold)
        title.textColor = WalletTheme.text
        title.numberOfLines = 0
        let header = UIStackView(arrangedSubviews: [icon, title])
        header.spacing = 10
        header.alignment = .center

        let explain = UILabel()
        explain.text = "Silent payments don't show up in your wallet by themselves: they have to be found by scanning the chain. Fully Noded Server does that with your own node. Its link sets it up for this wallet in one step: this address, the signer's scan private key and the wallet's name on your node."
        explain.font = WalletTheme.mono(12)
        explain.textColor = WalletTheme.text
        explain.numberOfLines = 0

        let server = UIButton(type: .system)
        WalletTheme.styleHero(server, title: "FN-Server link", systemImage: "qrcode", tint: tint)
        server.addTarget(self, action: #selector(silentPaymentServerLink), for: .touchUpInside)

        let keyNote = UILabel()
        keyNote.text = "Using another scanner? The scan private key is in the signer's detail view (Signers → your signer → SP Scan Private Key). It can't spend, but it reveals every silent payment you receive: only give it to a scanner you control."
        keyNote.font = WalletTheme.mono(11)
        keyNote.textColor = WalletTheme.dim
        keyNote.numberOfLines = 0

        let serverCard = WalletTheme.cardView([WalletTheme.caption("> FULLY NODED SERVER", tint: tint), header, explain, server, keyNote],
                                              tint: tint, spacing: 12, background: tint.accent.withAlphaComponent(0.06))
        serverCard.layer.borderColor = tint.accent.cgColor

        let both = UIStackView(arrangedSubviews: [addressCard, serverCard])
        both.axis = .vertical
        both.spacing = 16
        return both
    }

    private func makeAddressCard() -> UIView {
        addressLabel.font = WalletTheme.mono(15, weight: .semibold)
        addressLabel.textColor = WalletTheme.text
        addressLabel.numberOfLines = 0
        addressLabel.text = "Fetching an address…"
        addressInfoButton.configuration = WalletTheme.chipConfiguration(title: "Info", systemImage: "info.circle", tint: tint, fontSize: 12, imageSize: 11,
                                                                        imagePadding: 5, insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        addressInfoButton.addTarget(self, action: #selector(addressInfo), for: .touchUpInside)
        let actions = chipRow([chip("Copy", "doc.on.doc", action: #selector(copyAddress)),
                               chip("Share", "square.and.arrow.up", action: #selector(shareAddress)),
                               addressInfoButton])
        return WalletTheme.cardView([addressCaption, addressLabel, actions], tint: tint, spacing: 10)
    }

    private func field(_ field: UITextField, placeholder: String, keyboard: UIKeyboardType = .default) -> UITextField {
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.delegate = self
        field.font = WalletTheme.mono(15)
        field.addTarget(self, action: #selector(fieldChanged), for: .editingChanged)
        WalletTheme.styleField(field, tint: tint)
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
        toolbar.items = [UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
                         UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(dismissKeyboard))]
        toolbar.tintColor = tint.accent
        field.inputAccessoryView = toolbar
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }

    private func makeRequestCard() -> UIView {
        amountHint.font = WalletTheme.mono(11)
        amountHint.textColor = WalletTheme.dim
        amountHint.numberOfLines = 0
        amountHint.setHiddenIfNeeded(true)
        let footer = UILabel()
        footer.font = WalletTheme.mono(11)
        footer.textColor = WalletTheme.dim
        footer.numberOfLines = 0
        footer.text = "Optional. They're added to the payment request, so the payer's wallet can fill them in."
        return WalletTheme.cardView([
            WalletTheme.caption("> REQUEST", tint: tint),
            field(amountField, placeholder: "Amount (BTC)", keyboard: .decimalPad),
            amountHint,
            field(labelField, placeholder: "Label (who it's from)"),
            field(messageField, placeholder: "Message (what it's for)"),
            footer
        ], tint: tint, spacing: 10)
    }

    private func makeUriCard() -> UIView {
        requestLabel.font = WalletTheme.mono(12)
        requestLabel.textColor = WalletTheme.text
        requestLabel.numberOfLines = 0
        requestLabel.lineBreakMode = .byCharWrapping
        let actions = chipRow([chip("Copy", "doc.on.doc", action: #selector(copyRequest)),
                               chip("Share", "square.and.arrow.up", action: #selector(shareRequest))])
        return WalletTheme.cardView([WalletTheme.caption("> PAYMENT REQUEST (BIP21)", tint: tint), requestLabel, actions], tint: tint, spacing: 10)
    }

    /// Unlocked: what a timelock is, quick picks and "Choose a date". Locked: the unlock date,
    /// a countdown and a way back to a regular address.
    private func makeTimelockCard() -> UIView {
        let lockTint: WalletTheme.Tint = .warning

        let icon = UIImageView(image: UIImage(systemName: "hourglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        icon.tintColor = lockTint.accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        let headline = UILabel()
        headline.text = "Lock coins until a date"
        headline.font = WalletTheme.mono(15, weight: .bold)
        headline.textColor = WalletTheme.text
        headline.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text = "Whatever is sent can't be spent before then, not even by you."
        subtitle.font = WalletTheme.mono(11)
        subtitle.textColor = WalletTheme.dim
        subtitle.numberOfLines = 0
        let titles = UIStackView(arrangedSubviews: [headline, subtitle])
        titles.axis = .vertical
        titles.spacing = 3
        let header = UIStackView(arrangedSubviews: [icon, titles])
        header.spacing = 12
        header.alignment = .center

        let presets = UIStackView(arrangedSubviews: TimelockViewController.presets.enumerated().map { index, preset in
            let button = UIButton(type: .system)
            button.tag = index
            button.configuration = WalletTheme.chipConfiguration(title: preset.title, tint: lockTint, fontSize: 11, imageSize: 10, imagePadding: 0,
                                                                 insets: NSDirectionalEdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4),
                                                                 clipsTitle: true)
            button.addTarget(self, action: #selector(timelockPresetTapped(_:)), for: .touchUpInside)
            return button
        })
        presets.spacing = 6
        presets.distribution = .fillEqually
        timelockButton.configuration = WalletTheme.buttonConfiguration(title: "Choose a date", systemImage: "calendar", filled: false, tint: lockTint)
        timelockButton.addTarget(self, action: #selector(addTimelock), for: .touchUpInside)
        let footer = UILabel()
        footer.text = "The timelocked address replaces this one and is added to your wallet backup."
        footer.font = WalletTheme.mono(10)
        footer.textColor = WalletTheme.dim
        footer.numberOfLines = 0
        let picker = UIStackView(arrangedSubviews: [header, presets, timelockButton, footer])
        picker.axis = .vertical
        picker.spacing = 12
        timelockPicker = picker

        let lockIcon = UIImageView(image: UIImage(systemName: "lock.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)))
        lockIcon.tintColor = lockTint.accent
        lockIcon.contentMode = .scaleAspectFit
        lockIcon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        timelockDateLabel.font = WalletTheme.mono(18, weight: .bold)
        timelockDateLabel.textColor = lockTint.accent
        timelockDateLabel.numberOfLines = 0
        timelockDateLabel.adjustsFontSizeToFitWidth = true
        timelockDateLabel.minimumScaleFactor = 0.7
        timelockCountdownLabel.font = WalletTheme.mono(12, weight: .semibold)
        timelockCountdownLabel.textColor = WalletTheme.text
        timelockCountdownLabel.numberOfLines = 0
        let lockTexts = UIStackView(arrangedSubviews: [timelockDateLabel, timelockCountdownLabel])
        lockTexts.axis = .vertical
        lockTexts.spacing = 3
        let lockHeader = UIStackView(arrangedSubviews: [lockIcon, lockTexts])
        lockHeader.spacing = 12
        lockHeader.alignment = .center
        let lockNote = UILabel()
        lockNote.text = "Funds sent to this address can't be spent before then, not even by you. Payjoin and silent payments are off for it: they'd let the payer bypass the lock."
        lockNote.font = WalletTheme.mono(11)
        lockNote.textColor = WalletTheme.dim
        lockNote.numberOfLines = 0
        let regular = UIButton(type: .system)
        regular.configuration = WalletTheme.chipConfiguration(title: "Use a regular address", systemImage: "arrow.uturn.backward", tint: tint, fontSize: 12, imageSize: 11,
                                                              imagePadding: 5, insets: NSDirectionalEdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
        regular.addTarget(self, action: #selector(newAddress), for: .touchUpInside)
        let locked = UIStackView(arrangedSubviews: [lockHeader, lockNote, chipRow([regular])])
        locked.axis = .vertical
        locked.spacing = 12
        locked.setHiddenIfNeeded(true)
        timelockLocked = locked

        return WalletTheme.cardView([WalletTheme.caption("> TIMELOCK", tint: lockTint), picker, locked], tint: lockTint, spacing: 12)
    }

    private func updateTimelockCard() {
        let locked = timelockedUntil != nil
        timelockPicker.setHiddenIfNeeded(locked)
        timelockLocked.setHiddenIfNeeded(!locked)
        timelockCard.backgroundColor = locked ? WalletTheme.pending.withAlphaComponent(0.08) : WalletTheme.card
        timelockCard.layer.borderColor = (locked ? WalletTheme.pending : WalletTheme.Tint.warning.line).cgColor
        guard locked else { return }
        if let date = timelockedDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .short
            timelockDateLabel.text = "Locked until \(formatter.string(from: date))"
            timelockCountdownLabel.text = "Unlocks in \(TimelockViewController.countdown(to: date))"
        } else {
            timelockDateLabel.text = "Locked until \(timelockedUntil ?? "")"
            timelockCountdownLabel.text = nil
        }
    }

    /// Timelocks are created for single-sig taproot and segwit Fully Noded wallets.
    private var canTimelock: Bool {
        guard let wallet = wallet else { return false }
        let desc = Descriptor(wallet.receiveDescriptor)
        return desc.isP2TR || desc.isP2WPKH
    }

    // MARK: Request

    @objc private func fieldChanged() {
        payjoinSession?.amountSats = amountSats
        updateRequest()
    }

    /// The invoice amount in sats (what a payjoin original must pay at least).
    private var amountSats: Int64? {
        amount.flatMap(Double.init).map { Int64(($0 * 100_000_000).rounded()) }
    }

    /// Amount as BIP21 wants it (decimal BTC), or nil when empty / not a valid amount.
    private var amount: String? {
        let text = (amountField.text ?? "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        guard !text.isEmpty, let value = Double(text), value > 0, value <= 21_000_000 else { return nil }
        return text
    }

    /// The silent payment address shown, if that's the mode. Never with a timelocked address
    /// (the mode is forced back to the address while one is shown).
    private var shownSilentPayment: String? {
        guard mode == .silentPayment, timelockedUntil == nil else { return nil }
        return silentPaymentAddress
    }

    /// Rebuilds the QR and the request text from the addresses and fields.
    private func updateRequest() {
        if timelockedUntil != nil { mode = .address }
        let sp = shownSilentPayment

        addressLabel.text = addressString.isEmpty ? "Fetching an address…" : addressString.addressExpanded
        // On Payjoin, the QR and the request only appear once the endpoint is live: a QR shown
        // before then would be paid without payjoin.
        // That includes a wallet that can't payjoin: the tab only explains why.
        let payjoinPending = mode == .payjoin && payjoinURL == nil
        // The silent payment address only appears once the user has acknowledged that payments
        // to it need scanning before they show in the wallet.
        let spLocked = sp != nil && !silentPaymentAcknowledged
        spHeadsUpCard.setHiddenIfNeeded(sp == nil)
        spAckButton.setHiddenIfNeeded(!spLocked)
        qrCardView.setHiddenIfNeeded(payjoinPending || spLocked)
        addressCard.setHiddenIfNeeded(sp != nil || payjoinPending)
        requestCard.setHiddenIfNeeded(sp != nil || payjoinPending)
        uriCard.setHiddenIfNeeded(sp != nil || payjoinPending)
        silentPaymentCard.setHiddenIfNeeded(sp == nil || spLocked)
        silentPaymentLabel.text = sp
        payjoinCard.setHiddenIfNeeded(mode != .payjoin)
        updateModeControl()

        if sp != nil {
            modeNote.text = "\(silentPaymentSigner.map { "\($0)'s" } ?? "Your") silent payment address: every payment to it lands on a fresh, unlinkable output. The payer's wallet must support silent payments (BIP352)."
            qrCaption.text = "Silent payment address. Tap the QR to show it full screen."
            requestText = sp!
        } else {
            if mode == .payjoin, payjoinHasSigner == false {
                modeNote.text = "Use Address to get paid normally."
            } else if mode == .payjoin {
                modeNote.text = "Your address plus a payjoin endpoint hosted from this phone over Tor. A wallet with payjoin adds its coins and yours joins in; any other wallet pays the address normally."
            } else if timelockedUntil != nil {
                modeNote.text = "Timelocked address: payjoin and silent payments are off for it."
            } else {
                modeNote.text = "A regular address, with an optional amount, label and message. Any bitcoin wallet can pay it."
            }
            qrCaption.text = payjoinURL != nil
                ? "Payjoin invoice: a wallet that supports it joins in, any other pays normally. Tap the QR to show it full screen."
                : "Tap the QR to show it full screen."
            requestText = Self.bip21(address: addressString, amount: amount,
                                     label: labelField.text ?? "", message: messageField.text ?? "",
                                     payjoin: payjoinURL)
        }

        let amountText = (amountField.text ?? "").trimmingCharacters(in: .whitespaces)
        if amountText.isEmpty {
            amountHint.setHiddenIfNeeded(true)
        } else if let amount = amount, let value = Double(amount) {
            amountHint.setHiddenIfNeeded(fxRate == nil)
            amountHint.textColor = WalletTheme.dim
            if let fxRate = fxRate { amountHint.text = "≈ \((value * fxRate).fiatString)" }
        } else {
            amountHint.setHiddenIfNeeded(false)
            amountHint.textColor = WalletTheme.danger
            amountHint.text = "Not a valid amount: it's left out of the request."
        }

        timelockCard.setHiddenIfNeeded(sp != nil || mode == .payjoin || !canTimelock)
        updateTimelockCard()
        requestLabel.text = requestText

        let text = requestText.isEmpty ? "bitcoin:" : (sp != nil ? requestText.uppercased() : requestText)
        qrGenerator.qrText = text
        let image = qrGenerator.getQRCode()
        UIView.transition(with: qrImageView, duration: 0.3, options: .transitionCrossDissolve,
                          animations: { self.qrImageView.image = image })
    }

    /// BIP21: `bitcoin:<address>[?amount=…&label=…&message=…]`. Values percent-encoded. With a
    /// payjoin endpoint, BIP78's `pj=` and `pjos=0` (we never change the payment output).
    static func bip21(address: String, amount: String?, label: String, message: String, payjoin: URL? = nil) -> String {
        guard !address.isEmpty else { return "" }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?#+")
        var params: [String] = []
        if let amount = amount { params.append("amount=\(amount)") }
        let label = label.trimmingCharacters(in: .whitespaces)
        if !label.isEmpty, let encoded = label.addingPercentEncoding(withAllowedCharacters: allowed) { params.append("label=\(encoded)") }
        let message = message.trimmingCharacters(in: .whitespaces)
        if !message.isEmpty, let encoded = message.addingPercentEncoding(withAllowedCharacters: allowed) { params.append("message=\(encoded)") }
        if let payjoin = payjoin {
            params.append("pj=\(payjoin.absoluteString)")
            params.append("pjos=0")
        }
        return "bitcoin:\(address)" + (params.isEmpty ? "" : "?" + params.joined(separator: "&"))
    }

    @objc private func modeChanged() {
        let selected = modes.indices.contains(modeControl.selectedSegmentIndex) ? modes[modeControl.selectedSegmentIndex] : .address
        guard selected != mode else { return }
        view.endEditing(true)
        setMode(selected)
    }

    /// Switching to Payjoin turns it on; switching away takes the endpoint down.
    private func setMode(_ new: Mode) {
        let old = mode
        mode = new
        if old == .payjoin, new != .payjoin, payjoinOn {
            payjoinOn = false
            stopPayjoin()
        }
        UIView.animate(withDuration: 0.25) {
            self.updateRequest()
            self.stack.layoutIfNeeded()
        }
        if new == .payjoin, payjoinHasSigner == false {
            updatePayjoinControls()
        } else if new == .payjoin, !payjoinOn {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            turnOnPayjoin()
        }
    }

    // MARK: Silent payment address

    /// The wallet's silent payment address: a stored signer whose fingerprint is in the wallet's
    /// descriptors and whose address is known (from its seed, or saved before the words were
    /// deleted). The Address / Silent payment choice only appears when there is one.
    private func loadSilentPaymentAddress() {
        guard let wallet = wallet else { return }
        let descriptors = wallet.receiveDescriptor + wallet.changeDescriptor
        let mainnet = !descriptors.contains("tpub")
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            DispatchQueue.global(qos: .userInitiated).async {
                var found: (address: String, label: String, signer: SignerStruct)?
                for dict in signers ?? [] {
                    let signer = SignerStruct(dictionary: dict)
                    guard let encrypted = signer.xfp,
                          let xfp = Crypto.decrypt(encrypted)?.utf8String?.lowercased(),
                          descriptors.lowercased().contains("[\(xfp)"),
                          let info = SignerSilentPayment.info(for: signer, mainnet: mainnet) else { continue }
                    found = (info.address, signer.label, signer)
                    break
                }
                DispatchQueue.main.async {
                    guard let self = self, let found = found else { return }
                    self.silentPaymentAddress = found.address
                    self.silentPaymentSigner = found.label
                    self.silentPaymentSignerStruct = found.signer
                    self.silentPaymentMainnet = mainnet
                    self.rebuildModes()
                    self.updateRequest()
                }
            }
        }
    }

    // MARK: Address

    @objc private func newAddress() {
        guard !isShowingActivity else { return }
        timelockedUntil = nil
        timelockedDate = nil
        generateOnchainInvoice()
    }

    func generateOnchainInvoice() {
        showActivity("fetching address...")
        guard let wallet = wallet else {
            getAddress()
            return
        }
        getReceiveAddressForFullyNodedWallet(wallet)
    }

    private func getReceiveAddressForFullyNodedWallet(_ wallet: Wallet) {
        showActivity("getting address from \(wallet.label)...")
        let addressType = Descriptor(wallet.receiveDescriptor).addressType
        let p = Get_New_Address(["address_type": addressType])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            self.hideActivity()
            guard let address = response as? String else {
                showAlert(vc: self, title: "", message: errorDesc ?? "Unknown error fetching a new address.")
                return
            }
            self.showAddress(address: address)
        }
    }

    func showAddress(address: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let changed = self.addressString != address
            self.addressString = address
            self.updateRequest()
            self.hideActivity()
            // The payjoin endpoint belongs to one address: start again for the new one.
            guard changed else { return }
            if self.payjoinOn {
                // A timelocked address (or no wallet) can't take a payjoin: the card is hidden.
                if self.payjoinCard.isHidden {
                    self.payjoinOn = false
                    self.stopPayjoin()
                    self.updatePayjoinControls()
                } else {
                    self.restartPayjoin()
                }
            } else {
                self.autoStartPayjoinIfWanted()
            }
        }
    }

    // MARK: Payjoin

    private func makePayjoinCard() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "arrow.triangle.merge",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .bold)))
        icon.tintColor = tint.accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 30).isActive = true
        payjoinHeadline.text = "Get paid privately"
        payjoinHeadline.font = WalletTheme.mono(17, weight: .bold)
        payjoinHeadline.textColor = WalletTheme.text
        payjoinHeadline.numberOfLines = 0
        let subtitle = UILabel()
        subtitle.text = "Payjoin (BIP78): you and the payer both put coins in."
        subtitle.font = WalletTheme.mono(11)
        subtitle.textColor = WalletTheme.dim
        subtitle.numberOfLines = 0
        let titles = UIStackView(arrangedSubviews: [payjoinHeadline, subtitle])
        titles.axis = .vertical
        titles.spacing = 3
        let header = UIStackView(arrangedSubviews: [icon, titles])
        header.spacing = 12
        header.alignment = .center

        payjoinBenefits = benefitList([
            ("eye.slash", "Breaks chain analysis", "Your coin goes in too, so \"all inputs are the payer's\" is wrong."),
            ("questionmark.square.dashed", "Hides the amount", "The outputs no longer show what was paid."),
            ("arrow.triangle.2.circlepath", "Consolidates for free", "One of your coins rides along; the payer covers its fee.")
        ])

        WalletTheme.styleHero(payjoinButton, title: "Try again", systemImage: "arrow.clockwise", tint: tint)
        payjoinButton.addTarget(self, action: #selector(payjoinTapped), for: .touchUpInside)

        payjoinStatus.font = WalletTheme.mono(11)
        payjoinStatus.textColor = WalletTheme.dim
        payjoinStatus.numberOfLines = 0
        payjoinStatus.text = "Hosted over Tor from this phone, on a one-time onion, while this screen is open. A wallet without payjoin just pays normally."
        payjoinQuitButton = chip("Cancel payjoin", "xmark", action: #selector(quitPayjoin))
        payjoinBroadcastButton = chip("Broadcast the payer's payment", "paperplane", action: #selector(broadcastPayerPayment))
        payjoinBroadcastButton.setHiddenIfNeeded(true)
        payjoinProgress.tint = tint
        payjoinProgress.setHiddenIfNeeded(true)

        let autoLabel = UILabel()
        autoLabel.text = "Always open on Payjoin"
        autoLabel.font = WalletTheme.mono(12, weight: .semibold)
        autoLabel.textColor = WalletTheme.text
        payjoinAutoSwitch.onTintColor = tint.accent
        payjoinAutoSwitch.isOn = UserDefaults.standard.bool(forKey: Self.payjoinAutoKey)
        payjoinAutoSwitch.addTarget(self, action: #selector(payjoinAutoChanged), for: .valueChanged)
        let autoRow = UIStackView(arrangedSubviews: [autoLabel, UIView(), payjoinAutoSwitch])
        autoRow.alignment = .center
        payjoinAutoRow = autoRow

        let divider = UIView()
        divider.backgroundColor = tint.line
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        let panel = UIStackView(arrangedSubviews: [divider, header, payjoinBenefits, payjoinProgress, payjoinStatus, payjoinButton,
                                                   chipRow([payjoinQuitButton, payjoinBroadcastButton]), autoRow])
        panel.axis = .vertical
        panel.spacing = 12
        panel.setHiddenIfNeeded(true)
        updatePayjoinControls()
        return panel
    }

    private func benefitList(_ items: [(icon: String, title: String, detail: String)]) -> UIView {
        let list = UIStackView()
        list.axis = .vertical
        list.spacing = 8
        for item in items {
            let icon = UIImageView(image: UIImage(systemName: item.icon,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            icon.tintColor = tint.accent
            icon.contentMode = .scaleAspectFit
            icon.widthAnchor.constraint(equalToConstant: 20).isActive = true
            let text = UILabel()
            text.numberOfLines = 0
            let attributed = NSMutableAttributedString(string: item.title + "  ", attributes: [
                .font: WalletTheme.mono(12, weight: .semibold), .foregroundColor: WalletTheme.text])
            attributed.append(NSAttributedString(string: item.detail, attributes: [
                .font: WalletTheme.mono(11), .foregroundColor: WalletTheme.dim]))
            text.attributedText = attributed
            let row = UIStackView(arrangedSubviews: [icon, text])
            row.spacing = 8
            row.alignment = .firstBaseline
            list.addArrangedSubview(row)
        }
        return list
    }

    /// Setting up: the pitch while Tor works. Live: progress and status. Failed: Try again.
    private func updatePayjoinControls() {
        let unavailable = payjoinHasSigner == false
        payjoinBenefits.setHiddenIfNeeded(payjoinURL != nil)
        payjoinButton.setHiddenIfNeeded(payjoinOn || unavailable)
        payjoinAutoSwitch.isEnabled = !unavailable
        payjoinAutoRow?.setHiddenIfNeeded(unavailable)
        if unavailable {
            payjoinHeadline.text = "Payjoin isn't available for this wallet"
            setPayjoinStatus(payjoinUnavailableReason ?? "This wallet can't sign a payjoin on this device.", color: WalletTheme.text)
        } else {
            payjoinHeadline.text = payjoinURL != nil ? "Payjoin is live" : (payjoinOn ? "Setting up payjoin…" : "Get paid privately")
        }
        let quit = payjoinURL != nil ? "Stop payjoin" : (payjoinOn ? "Cancel payjoin" : "Use a regular address")
        payjoinQuitButton.configuration?.title = quit
        payjoinQuitButton.configuration?.image = UIImage(systemName: payjoinOn ? "xmark" : "arrow.uturn.backward",
                                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold))
    }

    /// Payjoin can only add a coin when a signer of this wallet is on this device.
    private func checkPayjoinSigner() {
        guard let wallet = wallet else { return }
        Payjoin.unavailableReason(for: wallet) { [weak self] reason in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.payjoinHasSigner = reason == nil
                self.payjoinUnavailableReason = reason
                self.rebuildModes()
                self.updatePayjoinControls()
                self.updateRequest()
                self.autoStartPayjoinIfWanted()
            }
        }
    }

    /// With "Always open on Payjoin", the screen switches to Payjoin by itself once there's an
    /// address and a signer.
    private func autoStartPayjoinIfWanted() {
        guard !payjoinAutoTried, !payjoinOn, mode == .address, modes.contains(.payjoin), timelockedUntil == nil,
              payjoinHasSigner == true, !addressString.isEmpty,
              UserDefaults.standard.bool(forKey: Self.payjoinAutoKey) else { return }
        payjoinAutoTried = true
        setMode(.payjoin)
    }

    /// Back to a regular address: takes the endpoint down (setting up or live).
    @objc private func quitPayjoin() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        setMode(.address)
        setPayjoinStatus("Hosted over Tor from this phone, on a one-time onion, while this screen is open. A wallet without payjoin just pays normally.", color: WalletTheme.dim)
    }

    @objc private func payjoinTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        turnOnPayjoin()
    }

    @objc private func payjoinAutoChanged() {
        UserDefaults.standard.set(payjoinAutoSwitch.isOn, forKey: Self.payjoinAutoKey)
    }

    private func turnOnPayjoin() {
        payjoinOn = true
        payjoinBroadcastButton.setHiddenIfNeeded(true)
        updatePayjoinControls()
        startPayjoin()
    }

    private func setPayjoinStatus(_ text: String, color: UIColor = WalletTheme.dim) {
        payjoinStatus.text = text
        payjoinStatus.textColor = color
    }

    /// Checks this wallet can receive a payjoin (a signer for it on this device, Tor up; waits
    /// for Tor while it's still connecting), asks for the passphrase if the prompt is on, then
    /// hosts the endpoint.
    private func startPayjoin() {
        guard payjoinOn else { return }
        guard let wallet = wallet, !addressString.isEmpty else {
            payjoinFailed("Payjoin needs a Fully Noded wallet and an address.")
            return
        }
        guard payjoinHasSigner != false else {
            payjoinFailed("Payjoin needs this wallet's signer on this device: it signs the coin you add.")
            return
        }
        switch TorClient.sharedInstance.state {
        case .connected:
            break
        case .started, .refreshing:
            waitForTor(attempt: 0)
            return
        default:
            payjoinFailed("Payjoin is hosted over Tor, which is off. Turn Tor on, then try again.")
            return
        }
        if UserDefaults.standard.object(forKey: "passphrasePrompt") == nil {
            hostPayjoin(wallet: wallet, passphrase: nil)
        } else {
            promptPayjoinPassphrase { [weak self] passphrase in
                guard let passphrase = passphrase else { self?.payjoinFailed(nil); return }
                self?.hostPayjoin(wallet: wallet, passphrase: passphrase)
            }
        }
    }

    /// Tor is still connecting (often right after launch): starts as soon as it's up.
    private func waitForTor(attempt: Int) {
        torWaitID += 1
        let id = torWaitID
        guard payjoinOn else { return }
        if TorClient.sharedInstance.state == .connected {
            startPayjoin()
            return
        }
        guard attempt < 90 else {
            payjoinFailed("Tor didn't connect. Try again once it's connected.")
            return
        }
        setPayjoinStatus("Waiting for Tor to connect… \(attempt)s. Payjoin starts as soon as it's up.", color: WalletTheme.pending)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self, self.torWaitID == id else { return }
            self.waitForTor(attempt: attempt + 1)
        }
    }

    private func hostPayjoin(wallet: Wallet, passphrase: String?) {
        guard payjoinOn else { return }
        let session = PayjoinReceiveSession(address: addressString, amountSats: amountSats, walletName: wallet.name, passphrase: passphrase)
        session.onStatus = { [weak self] status in self?.payjoinStatusChanged(status) }
        payjoinSession = session
        payjoinBroadcastButton.setHiddenIfNeeded(true)
        payjoinProgress.reset()
        UIView.animate(withDuration: 0.25) { self.payjoinProgress.setHiddenIfNeeded(false) }
        setPayjoinStatus("Building a private payjoin endpoint on this phone. Your QR appears as soon as payers can reach it (usually under a minute).", color: WalletTheme.dim)
        // iOS pauses the listener when the phone locks: stay awake while hosting.
        UIApplication.shared.isIdleTimerDisabled = true
        session.start()
    }

    private func payjoinStatusChanged(_ status: PayjoinReceiveSession.Status) {
        switch status {
        case .step(let step):
            payjoinProgress.advance(to: step)
        case .onion(let host):
            payjoinProgress.reveal(onion: host)
        case .ready(let url):
            payjoinURL = url
            payjoinProgress.finish()
            setPayjoinStatus("Your QR now asks for a payjoin. Keep this screen open until you're paid (the phone stays awake meanwhile). A wallet that can't reach it simply pays normally.", color: tint.accent)
            UIView.animate(withDuration: 0.3) {
                self.updateRequest()
                self.stack.layoutIfNeeded()
            }
            glowQR(true)
            showQrBadge(true)
            updatePayjoinControls()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .handling:
            payjoinProgress.pulse(true)
            setPayjoinStatus("⚡ Payer connected: checking their payment and adding your coin…", color: WalletTheme.pending)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .refused(let reason):
            // Still live: another payment (or a normal one) can still come in.
            payjoinProgress.pulse(false)
            payjoinProgress.finish()
            setPayjoinStatus("⚠︎ A payment was turned down for payjoin: \(reason) The invoice is still live; the payer's wallet sends a normal payment instead.", color: WalletTheme.pending)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .sent(let contributed):
            payjoinProgress.pulse(false)
            payjoinProgress.complete()
            glowQR(false)
            payjoinHeadline.text = "Payjoin sent ✓"
            setPayjoinStatus("✓ Payjoin sent. The payer now signs and broadcasts it.", color: tint.accent)
            SuccessView.show(in: self, title: "Payjoin complete",
                             subtitle: "Both of you put coins into this payment, so it doesn't look like one on-chain. You added \(Int(contributed).withCommas) sats of your own coin: it comes back to you with the payment.\n\nThe payer's wallet now signs and broadcasts it.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in
                guard let self = self, self.payjoinSession?.originalHex != nil else { return }
                self.payjoinBroadcastButton.setHiddenIfNeeded(false)
                self.setPayjoinStatus("If the payer hasn't broadcast anything, broadcast their original payment yourself (it replaces the payjoin; only one can confirm).", color: WalletTheme.dim)
            }
        case .failed(let text):
            payjoinFailed(text)
        }
    }

    private func payjoinFailed(_ message: String?) {
        payjoinOn = false
        stopPayjoin()
        updatePayjoinControls()
        if let message = message {
            setPayjoinStatus(message, color: WalletTheme.danger)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            let shake = CAKeyframeAnimation(keyPath: "transform.translation.x")
            shake.values = [-8, 8, -5, 5, -2, 2, 0]
            shake.duration = 0.35
            payjoinCard.layer.add(shake, forKey: "shake")
        }
    }

    /// Takes the endpoint down (`payjoinOn` stays as it is, so a new address can start again).
    private func stopPayjoin() {
        torWaitID += 1
        payjoinSession?.stop()
        payjoinSession = nil
        UIApplication.shared.isIdleTimerDisabled = false
        payjoinProgress.reset()
        UIView.animate(withDuration: 0.25) { self.payjoinProgress.setHiddenIfNeeded(true) }
        glowQR(false)
        showQrBadge(false)
        if payjoinURL != nil {
            payjoinURL = nil
            updateRequest()
        }
    }

    private func showQrBadge(_ on: Bool) {
        guard on != !qrBadge.isHidden else { return }
        if on {
            qrBadge.setHiddenIfNeeded(false)
            qrBadge.transform = CGAffineTransform(scaleX: 0.2, y: 0.2)
            UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.9) {
                self.qrBadge.transform = .identity
            }
        } else {
            qrBadge.setHiddenIfNeeded(true)
        }
    }

    /// The QR's frame glows in the accent colour while the payjoin endpoint is live.
    private func glowQR(_ on: Bool) {
        guard let layer = qrFrame?.layer else { return }
        layer.removeAnimation(forKey: "payjoinGlow")
        layer.shadowColor = tint.accent.cgColor
        layer.shadowOffset = .zero
        layer.shadowRadius = 18
        guard on else {
            layer.shadowOpacity = 0
            return
        }
        layer.shadowOpacity = 0.55
        let pulse = CABasicAnimation(keyPath: "shadowOpacity")
        pulse.fromValue = 0.95
        pulse.toValue = 0.35
        pulse.duration = 1.4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        layer.add(pulse, forKey: "payjoinGlow")
    }

    private func restartPayjoin() {
        stopPayjoin()
        startPayjoin()
    }

    @objc private func broadcastPayerPayment() {
        payjoinSession?.broadcastOriginal { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                showAlert(vc: self, title: "Not broadcast", message: error)
            } else {
                self.payjoinBroadcastButton.setHiddenIfNeeded(true)
                showAlert(vc: self, title: "Payment broadcast ✓", message: "The payer's original payment was broadcast.")
            }
        }
    }

    private func promptPayjoinPassphrase(completion: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: "Passphrase", message: "Enter the passphrase for signing the coin you add to a payjoin.", preferredStyle: .alert)
        alert.addTextField { field in
            field.isSecureTextEntry = true
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Use", style: .default) { [weak alert] _ in completion(alert?.textFields?.first?.text ?? "") })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion(nil) })
        present(alert, animated: true)
    }

    func getAddress() {
        promptBitcoinAddressType { [weak self] addressType in
            guard let self = self else { return }
            guard !addressType.isEmpty else {
                self.hideActivity()
                return
            }
            let param: Get_New_Address = .init(["address_type": addressType])
            MakeRPCCall.sharedInstance.executeRPCCommand(method: .getnewaddress(param: param)) { [weak self] (response, errorMessage) in
                guard let self = self else { return }
                guard let address = response as? String else {
                    self.hideActivity()
                    showAlert(vc: self, title: "Error", message: errorMessage ?? "unknown error fetching address")
                    return
                }
                self.showAddress(address: address)
            }
        }
    }

    // Only gets called when a user is using a non Fully Noded wallet.
    func promptBitcoinAddressType(completion: @escaping (String) -> Void) {
        let alert = UIAlertController(
            title: "Choose Address Type",
            message: "Select the Bitcoin address format (only required when using non Fully Noded wallets, for experts only):",
            preferredStyle: .alert
        )
        let options: [(title: String, value: String)] = [
            ("Legacy (P2PKH)", "legacy"),
            ("Nested SegWit (P2SH)", "p2sh-segwit"),
            ("Native SegWit (Bech32)", "bech32"),
            ("Taproot (Bech32m)", "bech32m")
        ]
        for opt in options {
            alert.addAction(UIAlertAction(title: opt.title, style: .default) { _ in completion(opt.value) })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completion("") })
        present(alert, animated: true)
    }

    @objc private func addressInfo() {
        guard !addressString.isEmpty else { return }
        OnchainUtils.getAddressInfo(address: addressString) { [weak self] (addressInfo, message) in
            guard let self = self else { return }
            guard let addressInfo = addressInfo else {
                showAlert(vc: self, title: "", message: message ?? "No address info.")
                return
            }
            self.showModal(data: addressInfo.rawData, title: "getaddressinfo")
        }
    }

    private func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            let nav = UINavigationController(rootViewController: TextModalViewController(data: data, viewTitle: title))
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            self?.present(nav, animated: true)
        }
    }

    // MARK: Copy / share

    @objc private func copyAddress() {
        guard !addressString.isEmpty else { return }
        UIPasteboard.general.string = addressString
        SuccessView.toast("Address copied", in: self)
    }

    @objc private func shareAddress() {
        guard !addressString.isEmpty else { return }
        share([addressString])
    }

    /// First thing on the Silent payment tab: payments to this address need scanning before
    /// they show in the wallet. Informative, not a warning: the accent color, an info icon.
    private func makeSilentPaymentHeadsUp() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "info.circle.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)))
        icon.tintColor = tint.accent
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
        let title = UILabel()
        title.text = "One more step to see these payments"
        title.font = WalletTheme.mono(14, weight: .bold)
        title.textColor = WalletTheme.text
        title.numberOfLines = 0
        let header = UIStackView(arrangedSubviews: [icon, title])
        header.spacing = 10
        header.alignment = .center

        let body = UILabel()
        body.text = "Bitcoin sent to this address is yours straight away, but it won't show in this wallet's balance or history until a scanner finds it. Unlike a regular address, your node can't spot it on its own."
        body.font = WalletTheme.mono(12)
        body.textColor = WalletTheme.text
        body.numberOfLines = 0

        let steps = UIStackView()
        steps.axis = .vertical
        steps.spacing = 6
        for (i, text) in ["Set up scanning once with Fully Noded Server (the FN-Server link below).",
                          "Keep Fully Noded Server running: it scans with your node and adds what it finds to this wallet.",
                          "Payments then show here like any other, ready to spend."].enumerated() {
            let number = UILabel()
            number.text = "\(i + 1)"
            number.font = WalletTheme.mono(11, weight: .bold)
            number.textColor = tint.accent
            number.widthAnchor.constraint(equalToConstant: 14).isActive = true
            let line = UILabel()
            line.text = text
            line.font = WalletTheme.mono(11)
            line.textColor = WalletTheme.dim
            line.numberOfLines = 0
            let row = UIStackView(arrangedSubviews: [number, line])
            row.spacing = 8
            row.alignment = .firstBaseline
            steps.addArrangedSubview(row)
        }

        WalletTheme.styleHero(spAckButton, title: "I understand, show my address", systemImage: "checkmark", tint: tint)
        spAckButton.addTarget(self, action: #selector(acknowledgeSilentPayment), for: .touchUpInside)

        let card = WalletTheme.cardView([header, body, steps, spAckButton], tint: tint, spacing: 10,
                                        background: tint.accent.withAlphaComponent(0.1))
        card.layer.borderColor = tint.accent.cgColor
        return card
    }

    private var silentPaymentAcknowledged: Bool {
        guard let id = wallet?.id.uuidString else { return false }
        return (UserDefaults.standard.stringArray(forKey: Self.spAcknowledgedKey) ?? []).contains(id)
    }

    @objc private func acknowledgeSilentPayment() {
        guard let id = wallet?.id.uuidString else { return }
        var ids = UserDefaults.standard.stringArray(forKey: Self.spAcknowledgedKey) ?? []
        if !ids.contains(id) { ids.append(id) }
        UserDefaults.standard.set(ids, forKey: Self.spAcknowledgedKey)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        UIView.animate(withDuration: 0.25) {
            self.updateRequest()
            self.stack.layoutIfNeeded()
        }
    }

    @objc private func copySilentPaymentAddress() {
        guard let sp = silentPaymentAddress else { return }
        UIPasteboard.general.string = sp
        SuccessView.toast("Silent payment address copied", in: self)
    }

    @objc private func shareSilentPaymentAddress() {
        guard let sp = silentPaymentAddress else { return }
        share([sp])
    }

    /// Fully Noded Server quick connect for silent payments: this address, the signer's scan
    /// private key and the wallet's name on the node, so the server imports what it finds
    /// straight into this wallet. The scan key is private, so it asks for authentication first.
    @objc private func silentPaymentServerLink() {
        guard let signer = silentPaymentSignerStruct, let wallet = wallet else { return }
        // Same rule as the signer's export: without an app password there's nothing to check
        // (the prompt could never succeed), so say what's needed instead.
        guard AppAuthentication.hasAppPassword else {
            showAlert(vc: self, title: "Add an app lock first", message: "The FN-Server link contains your scan private key, so it needs your app password (or Face ID / Touch ID). Tap the lock button on the home screen to add a password, then come back here.")
            return
        }
        AppAuthentication.authenticate(from: self, reason: "To export your silent payment scan private key") { [weak self] success in
            guard let self, success else { return }
            let mainnet = self.silentPaymentMainnet
            guard let info = SignerSilentPayment.info(for: signer, mainnet: mainnet),
                  let link = SilentPaymentServerLink.make(address: info.address, scanKey: info.scanKey, wallet: wallet.name) else {
                showAlert(vc: self, title: "", message: "Unable to derive the silent payment address and scan private key.")
                return
            }
            DispatchQueue.main.async {
                let vc = QRDisplayerViewController()
                vc.headerIcon = UIImage(systemName: "eye")
                vc.headerText = "Fully Noded Server"
                vc.descriptionText = "In Fully Noded Server, open Silent Payments and use Import from Fully Noded: Paste link (tap Copy Text here; Universal Clipboard brings it to your Mac) or QR image… (Share QR, then save or AirDrop the image). It sets up silent payment scanning for \"\(wallet.label)\" in one step: the silent payment address and scan private key of \(signer.label) (\(mainnet ? "mainnet" : "testnet / signet")), and this wallet's name on your node. It can't spend your bitcoin, but it reveals every silent payment you receive. Only use it with a server you control."
                vc.text = link
                self.navigationController?.pushViewController(vc, animated: true)
            }
        }
    }

    @objc private func copyRequest() {
        UIPasteboard.general.string = requestText
        SuccessView.toast("Payment request copied", in: self)
    }

    @objc private func shareRequest() {
        share([requestText])
    }

    @objc private func copyQr() {
        guard let image = qrImageView.image else { return }
        UIPasteboard.general.image = image
        SuccessView.toast("QR copied", in: self)
    }

    @objc private func shareQr() {
        guard let image = qrImageView.image else { return }
        share([image])
    }

    private func share(_ items: [Any]) {
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.popoverPresentationController?.sourceView = view
        activity.popoverPresentationController?.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
        present(activity, animated: true)
    }

    @objc private func showQrFullScreen() {
        guard !requestText.isEmpty else { return }
        let vc = QRDisplayerViewController()
        let silentPayment = shownSilentPayment != nil
        vc.headerIcon = UIImage(systemName: silentPayment ? "eye.slash" : "qrcode")
        vc.headerText = silentPayment ? "Silent Payment Address" : "Payment Request"
        vc.descriptionText = silentPayment
            ? "Scan with a wallet that supports silent payments (BIP352)."
            : "Scan with any bitcoin wallet to pay this request."
        vc.text = requestText
        navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: Keyboard

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: Timelock

    @objc private func addTimelock() {
        getTimelockedAddress(initialDate: nil)
    }

    @objc private func timelockPresetTapped(_ sender: UIButton) {
        guard TimelockViewController.presets.indices.contains(sender.tag) else { return }
        getTimelockedAddress(initialDate: TimelockViewController.date(for: TimelockViewController.presets[sender.tag]))
    }

    private func getTimelockedAddress(initialDate: Date?) {
        showActivity("fetching address...")

        guard let wallet = self.wallet, !addressString.isEmpty else {
            hideActivity()
            return
        }

        let p = Get_Address_Info(["address": addressString])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }

            guard let addressInfoResponse = response as? [String: Any] else {
                self.hideActivity()
                showAlert(vc: self, title: "", message: errorDesc ?? "Unable to read this address's info.")
                return
            }

            let addressInfo = AddressInfo(addressInfoResponse)

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.hideActivity()

                let timelockVC = TimelockViewController()
                timelockVC.initialDate = initialDate

                timelockVC.completion = { [weak self] (timestamp, afterFragment, displayDate) in
                    guard let self = self else { return }
                    self.showActivity("creating timelock...")

                    // The timelock is built on this address's own key: its child index comes from
                    // its hdkeypath (a timelock on the wrong key would lock the wrong coins).
                    guard let keyIndex = Self.childIndex(of: addressInfo) else {
                        self.hideActivity()
                        showAlert(title: "", message: "Can't tell which key this address uses, so a timelock can't be created for it.")
                        return
                    }

                    do {
                        let (timelockedAddress, descriptor) = try WalletLogic.shared.createTimelockedAddress(fnWallet: wallet, pubkey: nil, descriptor: addressInfo.parent_desc, timelock: timestamp, keyIndex: keyIndex, derivedDescriptor: addressInfo.desc)

                        OnchainUtils.getDescriptorInfo(Get_Descriptor_Info(["descriptor": descriptor])) { [weak self] (descriptorInfo, message) in
                            guard let self = self else { return }

                            guard let descriptorInfo = descriptorInfo else {
                                self.hideActivity()
                                showAlert(title: "", message: message ?? "Unknown error getting the descriptor info.")
                                return
                            }

                            let request = [
                                "desc": descriptorInfo.descriptor,
                                "timestamp": "now",
                                "label": "Locked until \(displayDate)"
                            ]

                            // Import FIRST, pinned to this wallet. Nothing is saved locally unless the node accepted it.
                            MakeRPCCall.sharedInstance.executeRPCCommand(method: .importdescriptors(param: Import_Descriptors(["requests": [request]])), walletName: wallet.name) { [weak self] (response, errorDesc) in
                                guard let self = self else { return }

                                guard let items = response as? [[String: Any]], !items.isEmpty else {
                                    self.hideActivity()
                                    showAlert(title: "", message: errorDesc ?? "Unknown error importing the timelock descriptor.")
                                    return
                                }

                                // Every request must have succeeded, or none of the success steps run.
                                if let failed = items.map({ ImportDescriportsResponse($0) }).first(where: { !$0.success }) {
                                    self.hideActivity()
                                    let message = (failed.error?["message"] as? String) ?? "Unknown error importing the timelock descriptor."
                                    showAlert(title: "", message: message)
                                    return
                                }

                                let record: [String: Any] = ["descriptor": descriptor, "id": UUID()]
                                CoreDataService.saveEntity(dict: record, entityName: .timelocks) { [weak self] saved in
                                    if !saved {
                                        showAlert(title: "Timelock not saved locally.", message: "The timelocked address was imported on your node, but saving it in Fully Noded failed. Your backup will still include it.")
                                    }

                                    DispatchQueue.main.async { [weak self] in
                                        timelockVC.dismiss(animated: true) { [weak self] in
                                            guard let self = self else { return }

                                            BackupWarningView.show { [weak self] in
                                                guard let self = self else { return }

                                                self.timelockedUntil = displayDate
                                                self.timelockedDate = Date(timeIntervalSince1970: TimeInterval(timestamp))
                                                self.showAddress(address: timelockedAddress)
                                                self.backUpNow(displayDate: displayDate)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } catch {
                        self.hideActivity()
                        showAlert(title: "", message: error.localizedDescription)
                    }
                }
                self.present(timelockVC, animated: true)
            }
        }
    }

    /// The child index the address was derived at: from hdkeypath for single-sig, otherwise from
    /// the derivation path inside the derived descriptor (multisig addresses have no hdkeypath),
    /// where every cosigner's key sits at the same index.
    static func childIndex(of info: AddressInfo) -> UInt32? {
        if let last = info.hdkeypath.split(separator: "/").last, let index = UInt32(last) { return index }

        let desc = info.desc
        guard let regex = try? NSRegularExpression(pattern: #"\[[0-9a-fA-F]{8}[^\]]*/[01]/(\d+)\]"#) else { return nil }
        let matches = regex.matches(in: desc, range: NSRange(desc.startIndex..., in: desc))
        let indexes = Set(matches.compactMap { match -> UInt32? in
            guard let range = Range(match.range(at: 1), in: desc) else { return nil }
            return UInt32(desc[range])
        })
        return indexes.count == 1 ? indexes.first : nil
    }

    /// Refreshes the stored wallet backup so it includes the new timelocked descriptor. Pinned to
    /// this wallet and only saved if the node answered for exactly this wallet, so a hiccup (or the
    /// wrong wallet being active) can never replace a good backup with someone else's descriptors.
    func backUpNow(displayDate: String) {
        guard let wallet = wallet else { return }
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .listdescriptors, walletName: wallet.name) { [weak self] (response, errorDesc) in
            guard let self = self else { return }

            guard let response = response,
                  let data = try? JSONSerialization.data(withJSONObject: response),
                  let listed = try? JSONDecoder().decode(ListDescriptorsResponse.self, from: data),
                  listed.walletName == wallet.name,
                  !listed.descriptors.isEmpty else {
                showAlert(title: "Backup not updated", message: errorDesc ?? "Couldn't read this wallet's descriptors from your node. Export a fresh backup from the Active Wallet view as soon as you can.")
                return
            }

            let backup = WalletBackup(lastUpdate: Date(), descriptors: listed.descriptors.map(BackupItem.init(listed:)))
            self.updateNow(backup: backup)
        }
    }

    private func updateNow(backup: WalletBackup) {
        guard let walletId = wallet?.id else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970

        do {
            let jsonData = try encoder.encode(backup)
            CoreDataService.update(id: walletId, keyToUpdate: "walletBackup", newValue: jsonData, entity: .wallets) { [weak self] walletBackupUpdated in
                guard walletBackupUpdated else {
                    showAlert(title: "Backup not saved", message: "The timelocked address exists, but updating the stored backup failed. Export a fresh backup from the Active Wallet view now.")
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    SuccessView.show(
                        in: self,
                        title: "Wallet backup updated",
                        subtitle: "Export it now to keep a copy that includes this timelock. You can also export it later from the Active Wallet view with the export button in the top right.",
                        onDismiss: {
                            NotificationCenter.default.post(name: .refreshWallet, object: nil)
                        },
                        secondaryTitle: "Export backup",
                        onSecondary: { [weak self] in
                            self?.presentBackupExport(backup, walletLabel: self?.wallet?.label)
                        }
                    )
                }
            }
        } catch {
            showAlert(title: "", message: "Updating failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Payjoin progress

/// "Establishing a private endpoint": the four steps of hosting a payjoin over Tor, each with a
/// spinner that turns into a check, the onion address decrypting into place, and a timer while
/// Tor publishes it.
private final class PayjoinProgressView: UIView {
    var tint: WalletTheme.Tint = .receive

    private struct Row {
        let icon = UIImageView()
        let spinner = UIActivityIndicatorView(style: .medium)
        let title = UILabel()
        let detail = UILabel()
    }

    private let header = UILabel()
    private let dot = UIView()
    private var rows: [Row] = []
    private var current: PayjoinReceiveSession.Step?
    private var timer: Timer?
    private var publishStarted: Date?
    private var scrambleTimer: Timer?
    /// Since the endpoint went live, for the "waiting for a payer" clock.
    private var liveSince: Date?
    private var liveTimer: Timer?
    private var payerConnected = false

    private static let titles: [PayjoinReceiveSession.Step: String] = [
        .listener: "Private listener on this phone",
        .onion: "One-time onion address",
        .publishing: "Announcing it to the Tor network",
        .reachable: "Reachable by the payer's wallet"
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        dot.layer.cornerRadius = 4
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        header.font = WalletTheme.mono(11, weight: .bold)
        header.adjustsFontSizeToFitWidth = true
        header.minimumScaleFactor = 0.7
        let headerRow = UIStackView(arrangedSubviews: [dot, header, UIView()])
        headerRow.spacing = 8
        headerRow.alignment = .center
        stack.addArrangedSubview(headerRow)

        for step in PayjoinReceiveSession.Step.allCases {
            let row = Row()
            row.icon.contentMode = .scaleAspectFit
            row.icon.translatesAutoresizingMaskIntoConstraints = false
            row.icon.widthAnchor.constraint(equalToConstant: 18).isActive = true
            row.icon.heightAnchor.constraint(equalToConstant: 18).isActive = true
            row.spinner.hidesWhenStopped = true
            row.title.text = Self.titles[step]
            row.title.font = WalletTheme.mono(12, weight: .semibold)
            row.detail.font = WalletTheme.mono(10)
            row.detail.textColor = WalletTheme.dim
            row.detail.numberOfLines = 0
            row.detail.lineBreakMode = .byCharWrapping
            let iconBox = UIView()
            iconBox.translatesAutoresizingMaskIntoConstraints = false
            iconBox.widthAnchor.constraint(equalToConstant: 20).isActive = true
            iconBox.addSubview(row.icon)
            iconBox.addSubview(row.spinner)
            row.spinner.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                row.icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                row.icon.topAnchor.constraint(equalTo: iconBox.topAnchor),
                row.spinner.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
                row.spinner.centerYAnchor.constraint(equalTo: row.icon.centerYAnchor)
            ])
            let text = UIStackView(arrangedSubviews: [row.title, row.detail])
            text.axis = .vertical
            text.spacing = 2
            let line = UIStackView(arrangedSubviews: [iconBox, text])
            line.spacing = 10
            line.alignment = .top
            stack.addArrangedSubview(line)
            rows.append(row)
        }
        reset()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset() {
        timer?.invalidate()
        scrambleTimer?.invalidate()
        liveTimer?.invalidate()
        liveSince = nil
        current = nil
        publishStarted = nil
        pulse(false)
        header.text = "ESTABLISHING PRIVATE ENDPOINT"
        header.textColor = WalletTheme.pending
        dot.backgroundColor = WalletTheme.pending
        startDotPulse()
        for row in rows {
            row.spinner.stopAnimating()
            row.icon.setHiddenIfNeeded(false)
            row.icon.image = UIImage(systemName: "circle.dotted")
            row.icon.tintColor = WalletTheme.dim
            row.title.textColor = WalletTheme.dim
            row.detail.text = nil
            row.detail.setHiddenIfNeeded(true)
        }
    }

    /// Steps before `step` are done; `step` is in progress.
    func advance(to step: PayjoinReceiveSession.Step) {
        for s in PayjoinReceiveSession.Step.allCases where s.rawValue < step.rawValue { markDone(s) }
        guard current != step else { return }
        current = step
        let row = rows[step.rawValue]
        row.icon.setHiddenIfNeeded(true)
        row.spinner.color = tint.accent
        row.spinner.startAnimating()
        UIView.transition(with: row.title, duration: 0.2, options: .transitionCrossDissolve) {
            row.title.textColor = WalletTheme.text
        }
        if step == .publishing {
            publishStarted = Date()
            row.detail.setHiddenIfNeeded(false)
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tickPublishing() }
            tickPublishing()
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func tickPublishing() {
        guard let started = publishStarted else { return }
        let seconds = Int(Date().timeIntervalSince(started))
        rows[PayjoinReceiveSession.Step.publishing.rawValue].detail.text = "Tor relays are learning the address… \(seconds)s (usually under a minute)"
    }

    private func markDone(_ step: PayjoinReceiveSession.Step) {
        let row = rows[step.rawValue]
        guard row.icon.image != UIImage(systemName: "checkmark.circle.fill") else { return }
        row.spinner.stopAnimating()
        row.icon.setHiddenIfNeeded(false)
        row.icon.image = UIImage(systemName: "checkmark.circle.fill")
        row.icon.tintColor = tint.accent
        row.title.textColor = WalletTheme.text
        row.icon.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.8) {
            row.icon.transform = .identity
        }
        if step == .publishing {
            timer?.invalidate()
            if let started = publishStarted {
                row.detail.text = "Announced in \(Int(Date().timeIntervalSince(started)))s"
            }
        }
    }

    /// The onion address "decrypts" into place.
    func reveal(onion host: String) {
        let row = rows[PayjoinReceiveSession.Step.onion.rawValue]
        row.detail.setHiddenIfNeeded(false)
        row.detail.textColor = tint.accent
        let target = Array(host)
        let alphabet = Array("abcdefghijklmnopqrstuvwxyz234567")
        var frame = 0
        let frames = 36
        scrambleTimer?.invalidate()
        scrambleTimer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: true) { [weak self] timer in
            frame += 1
            let revealed = Int(Double(target.count) * Double(frame) / Double(frames))
            row.detail.text = String(target.enumerated().map { i, c in
                i < revealed || c == "." ? c : alphabet.randomElement()!
            })
            if frame >= frames {
                timer.invalidate()
                row.detail.text = host
                self?.markDone(.onion)
            }
        }
    }

    /// Everything done: the header goes live.
    func finish() {
        for s in PayjoinReceiveSession.Step.allCases { markDone(s) }
        current = nil
        header.textColor = tint.accent
        dot.backgroundColor = tint.accent
        startDotPulse()
        if liveSince == nil { liveSince = Date() }
        liveTimer?.invalidate()
        liveTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tickLive() }
        tickLive()
    }

    /// "LIVE ON TOR · 02:14 · WAITING FOR A PAYER"
    private func tickLive() {
        guard let since = liveSince, !payerConnected else { return }
        let seconds = Int(Date().timeIntervalSince(since))
        header.text = String(format: "LIVE ON TOR · %02d:%02d · WAITING FOR A PAYER", seconds / 60, seconds % 60)
    }

    /// The payjoin was proposed: the clock stops.
    func complete() {
        liveTimer?.invalidate()
        dot.layer.removeAllAnimations()
        header.text = "PAYJOIN SENT TO THE PAYER"
        header.textColor = tint.accent
        dot.backgroundColor = tint.accent
    }

    /// A payer is connected: the header pulses faster.
    func pulse(_ on: Bool) {
        dot.layer.removeAnimation(forKey: "fast")
        payerConnected = on
        guard on else { tickLive(); return }
        header.text = "PAYER CONNECTED"
        let fast = CABasicAnimation(keyPath: "transform.scale")
        fast.fromValue = 1.0
        fast.toValue = 1.8
        fast.duration = 0.3
        fast.autoreverses = true
        fast.repeatCount = .infinity
        dot.layer.add(fast, forKey: "fast")
    }

    private func startDotPulse() {
        dot.layer.removeAnimation(forKey: "pulse")
        let pulse = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue = 1.0
        pulse.toValue = 0.25
        pulse.duration = 0.8
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        dot.layer.add(pulse, forKey: "pulse")
    }
}

private extension UIView {
    /// Sets isHidden only when it changes. A stack view miscounts an arranged subview that's
    /// hidden again while already hidden inside an animation block, and cards then show, vanish
    /// or overlap at random (switching Receive tabs animates every card's visibility at once).
    func setHiddenIfNeeded(_ hidden: Bool) {
        if isHidden != hidden { isHidden = hidden }
    }
}
