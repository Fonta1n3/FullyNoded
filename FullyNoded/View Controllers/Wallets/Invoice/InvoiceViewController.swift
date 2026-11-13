//
//  InvoiceViewController.swift
//  BitSense
//
//  Created by Peter on 21/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//
//  Receive screen, built in code. Either a BIP21 payment request for a fresh address (optional
//  amount / label / message; Fully Noded wallets can also timelock the address until a date),
//  or, when the wallet has one, its silent payment address on its own. Requests are never
//  combined (no BIP321 `sp=`); paying such requests is still supported (AddressParser).
//

import UIKit

class InvoiceViewController: UIViewController, UITextFieldDelegate {

    /// What the QR asks to be paid (the choice only appears when the wallet has a silent payment address).
    private enum Mode: Int {
        /// `bitcoin:<address>[?amount=…&label=…&message=…]` (BIP21).
        case address
        /// The `sp1…` / `tsp1…` address alone.
        case silentPayment
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
    private var timelockedUntil: String?
    /// The text in the QR: the BIP21 request or the silent payment address.
    private var requestText = ""

    // Views
    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let modeControl = UISegmentedControl(items: ["Address", "Silent payment"])
    private let modeNote = UILabel()
    private var modeCard: UIView!
    private var addressCard: UIView!
    private var silentPaymentCard: UIView!
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
    private var requestCard: UIView!
    private var uriCard: UIView!
    private var timelockCard: UIView!
    private var timelockWarningCard: UIView!
    private let timelockWarningLabel = UILabel()

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

        // Address or silent payment: only when the wallet has a silent payment address (see
        // loadSilentPaymentAddress).
        modeCard = makeModeCard()
        modeCard.isHidden = true
        stack.addArrangedSubview(modeCard)

        stack.addArrangedSubview(qrCard())
        addressCard = makeAddressCard()
        stack.addArrangedSubview(addressCard)
        silentPaymentCard = makeSilentPaymentCard()
        silentPaymentCard.isHidden = true
        stack.addArrangedSubview(silentPaymentCard)
        requestCard = makeRequestCard()
        stack.addArrangedSubview(requestCard)
        uriCard = makeUriCard()
        stack.addArrangedSubview(uriCard)
        timelockCard = makeTimelockCard()
        timelockCard.isHidden = !canTimelock
        stack.addArrangedSubview(timelockCard)
        timelockWarningCard = makeTimelockWarningCard()
        timelockWarningCard.isHidden = true
        stack.addArrangedSubview(timelockWarningCard)

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
        NSLayoutConstraint.activate([
            qrImageView.topAnchor.constraint(equalTo: frame.topAnchor, constant: 12),
            qrImageView.bottomAnchor.constraint(equalTo: frame.bottomAnchor, constant: -12),
            qrImageView.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: 12),
            qrImageView.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -12),
            qrImageView.widthAnchor.constraint(equalTo: qrImageView.heightAnchor),
            frame.widthAnchor.constraint(equalToConstant: 264)
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
        modeControl.selectedSegmentIndex = Mode.address.rawValue
        modeControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        modeNote.font = WalletTheme.mono(11)
        modeNote.textColor = WalletTheme.dim
        modeNote.numberOfLines = 0
        return WalletTheme.cardView([WalletTheme.caption("> RECEIVE TO", tint: tint), modeControl, modeNote], tint: tint, spacing: 10)
    }

    private func makeSilentPaymentCard() -> UIView {
        silentPaymentLabel.font = WalletTheme.mono(13, weight: .semibold)
        silentPaymentLabel.textColor = WalletTheme.text
        silentPaymentLabel.numberOfLines = 0
        silentPaymentLabel.lineBreakMode = .byCharWrapping
        let actions = chipRow([chip("Copy", "doc.on.doc", action: #selector(copySilentPaymentAddress)),
                               chip("Share", "square.and.arrow.up", action: #selector(shareSilentPaymentAddress))])
        return WalletTheme.cardView([WalletTheme.caption("> SILENT PAYMENT ADDRESS", tint: tint), silentPaymentLabel, actions], tint: tint, spacing: 10)
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
        amountHint.isHidden = true
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

    private func makeTimelockCard() -> UIView {
        let text = UILabel()
        text.font = WalletTheme.mono(11)
        text.textColor = WalletTheme.dim
        text.numberOfLines = 0
        text.text = "Lock whatever is sent to this address until a date you choose: it can't be spent before then, not even by you. The timelocked address replaces this one and is added to your wallet backup."
        timelockButton.configuration = WalletTheme.buttonConfiguration(title: "Timelock this address", systemImage: "hourglass", filled: false, tint: .warning)
        timelockButton.addTarget(self, action: #selector(addTimelock), for: .touchUpInside)
        return WalletTheme.cardView([WalletTheme.caption("> TIMELOCK", tint: tint), text, timelockButton], tint: tint, spacing: 10)
    }

    private func makeTimelockWarningCard() -> UIView {
        let icon = UIImageView(image: UIImage(systemName: "hourglass"))
        icon.tintColor = WalletTheme.pending
        icon.contentMode = .scaleAspectFit
        icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        timelockWarningLabel.font = WalletTheme.mono(12, weight: .semibold)
        timelockWarningLabel.textColor = WalletTheme.pending
        timelockWarningLabel.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [icon, timelockWarningLabel])
        row.spacing = 10
        row.alignment = .top
        return WalletTheme.cardView([row], tint: .warning, background: WalletTheme.pending.withAlphaComponent(0.08))
    }

    /// Timelocks are created for single-sig taproot and segwit Fully Noded wallets.
    private var canTimelock: Bool {
        guard let wallet = wallet else { return false }
        let desc = Descriptor(wallet.receiveDescriptor)
        return desc.isP2TR || desc.isP2WPKH
    }

    // MARK: Request

    @objc private func fieldChanged() {
        updateRequest()
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
        addressCard.isHidden = sp != nil
        requestCard.isHidden = sp != nil
        uriCard.isHidden = sp != nil
        silentPaymentCard.isHidden = sp == nil
        silentPaymentLabel.text = sp
        modeCard.isHidden = silentPaymentAddress == nil
        modeControl.isEnabled = timelockedUntil == nil
        modeControl.selectedSegmentIndex = (sp == nil ? Mode.address : Mode.silentPayment).rawValue

        if sp != nil {
            modeNote.text = "\(silentPaymentSigner.map { "\($0)'s" } ?? "Your") silent payment address: every payment to it lands on a fresh, unlinkable output. The payer's wallet must support silent payments (BIP352)."
            qrCaption.text = "Silent payment address. Tap the QR to show it full screen."
            requestText = sp!
        } else {
            modeNote.text = timelockedUntil != nil
                ? "Timelocked address: a silent payment address would let the payer bypass the lock."
                : "A regular address, with an optional amount, label and message. Any bitcoin wallet can pay it."
            qrCaption.text = "Tap the QR to show it full screen."
            requestText = Self.bip21(address: addressString, amount: amount,
                                     label: labelField.text ?? "", message: messageField.text ?? "")
        }

        let amountText = (amountField.text ?? "").trimmingCharacters(in: .whitespaces)
        if amountText.isEmpty {
            amountHint.isHidden = true
        } else if let amount = amount, let value = Double(amount) {
            amountHint.isHidden = fxRate == nil
            amountHint.textColor = WalletTheme.dim
            if let fxRate = fxRate { amountHint.text = "≈ \((value * fxRate).fiatString)" }
        } else {
            amountHint.isHidden = false
            amountHint.textColor = WalletTheme.danger
            amountHint.text = "Not a valid amount: it's left out of the request."
        }

        timelockCard.isHidden = sp != nil || !canTimelock || timelockedUntil != nil
        timelockWarningCard.isHidden = timelockedUntil == nil
        requestLabel.text = requestText

        let text = requestText.isEmpty ? "bitcoin:" : (sp != nil ? requestText.uppercased() : requestText)
        qrGenerator.qrText = text
        let image = qrGenerator.getQRCode()
        UIView.transition(with: qrImageView, duration: 0.3, options: .transitionCrossDissolve,
                          animations: { self.qrImageView.image = image })
    }

    /// BIP21: `bitcoin:<address>[?amount=…&label=…&message=…]`. Values percent-encoded.
    static func bip21(address: String, amount: String?, label: String, message: String) -> String {
        guard !address.isEmpty else { return "" }
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?#+")
        var params: [String] = []
        if let amount = amount { params.append("amount=\(amount)") }
        let label = label.trimmingCharacters(in: .whitespaces)
        if !label.isEmpty, let encoded = label.addingPercentEncoding(withAllowedCharacters: allowed) { params.append("label=\(encoded)") }
        let message = message.trimmingCharacters(in: .whitespaces)
        if !message.isEmpty, let encoded = message.addingPercentEncoding(withAllowedCharacters: allowed) { params.append("message=\(encoded)") }
        return "bitcoin:\(address)" + (params.isEmpty ? "" : "?" + params.joined(separator: "&"))
    }

    @objc private func modeChanged() {
        mode = Mode(rawValue: modeControl.selectedSegmentIndex) ?? .address
        view.endEditing(true)
        updateRequest()
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
                var found: (address: String, label: String)?
                for dict in signers ?? [] {
                    let signer = SignerStruct(dictionary: dict)
                    guard let encrypted = signer.xfp,
                          let xfp = Crypto.decrypt(encrypted)?.utf8String?.lowercased(),
                          descriptors.lowercased().contains("[\(xfp)"),
                          let info = SignerSilentPayment.info(for: signer, mainnet: mainnet) else { continue }
                    found = (info.address, signer.label)
                    break
                }
                DispatchQueue.main.async {
                    guard let self = self, let found = found else { return }
                    self.silentPaymentAddress = found.address
                    self.silentPaymentSigner = found.label
                    self.updateRequest()
                }
            }
        }
    }

    // MARK: Address

    @objc private func newAddress() {
        guard !isShowingActivity else { return }
        timelockedUntil = nil
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
            self.addressString = address
            self.updateRequest()
            self.hideActivity()
        }
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

    @objc private func copySilentPaymentAddress() {
        guard let sp = silentPaymentAddress else { return }
        UIPasteboard.general.string = sp
        SuccessView.toast("Silent payment address copied", in: self)
    }

    @objc private func shareSilentPaymentAddress() {
        guard let sp = silentPaymentAddress else { return }
        share([sp])
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
        guard !requestText.isEmpty,
              let vc = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "QRDisplayer") as? QRDisplayerViewController else { return }
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
        getTimelockedAddress()
    }

    private func getTimelockedAddress() {
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
                                                self.timelockWarningLabel.text = "Timelocked until \(displayDate). Funds sent to this address can't be spent before then, not even by you."
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

extension Date {
    var unixTimestamp: Int {
        return Int(self.timeIntervalSince1970)
    }

    var unixTimestampUInt32: UInt32 {
        return UInt32(self.timeIntervalSince1970)
    }
}
