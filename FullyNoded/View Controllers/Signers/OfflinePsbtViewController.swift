//
//  OfflinePsbtViewController.swift
//  FullyNoded
//
//  Review (and, with the seed words, sign) a PSBT with one signer, completely offline:
//  no node, no Esplora, no Tor. The checks and signing are OfflinePsbt; this screen loads
//  the PSBT (paste, QR, file), shows what it does and what was verified, and exports it.
//

import UIKit
import UniformTypeIdentifiers

class OfflinePsbtViewController: UIViewController, UINavigationControllerDelegate, UIDocumentPickerDelegate {

    private let signerId: UUID
    private var signer: SignerStruct?
    /// The PSBT as loaded, then as signed.
    private var psbt: Data?
    private var report: OfflinePsbt.Report?
    private var keys: OfflineKeySource?
    /// Typed by the user when the stored candidates don't match the PSBT.
    private var typedPassphrase: String?
    private var addedSignatures = 0

    private let tint = WalletTheme.Tint.signer
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    init(signerId: UUID) {
        self.signerId = signerId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Review PSBT"
        navigationController?.delegate = self
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "questionmark.circle"), style: .plain,
                                                            target: self, action: #selector(showHelp))
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        WalletTheme.apply(to: self, tint: tint)

        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            DispatchQueue.main.async {
                guard let self else { return }
                self.signer = (signers ?? []).map { SignerStruct(dictionary: $0) }.first { $0.id == self.signerId }
                self.render()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent else { return }
        keys = nil
        typedPassphrase?.secureWipe()
        typedPassphrase = nil
    }

    // MARK: - Rendering

    private func render() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let signer else {
            stack.addArrangedSubview(hint("This signer couldn't be loaded."))
            return
        }

        let offline = signer.words == nil
            ? "This signer has no seed words, so it can't sign. It checks the PSBT against its saved public keys and tells you whether it's safe to sign on your other device."
            : "Checked and signed on this device only: no node, no internet. The PSBT is checked against this signer's keys before anything is signed."
        stack.addArrangedSubview(WalletTheme.cardView([
            WalletTheme.caption("> \(signer.label.uppercased())", tint: tint),
            hint(offline),
            buttonRow([
                chip("Paste", "doc.on.clipboard", #selector(pastePsbt)),
                chip("Scan QR", "qrcode.viewfinder", #selector(scanPsbt)),
                chip("File", "folder", #selector(importFile))
            ])
        ], tint: tint, spacing: 10))

        guard let report else { return }
        stack.addArrangedSubview(verdictCard(report))
        stack.addArrangedSubview(summaryCard(report))
        stack.addArrangedSubview(outputsCard(report))
        stack.addArrangedSubview(inputsCard(report))
        actions(report)
    }

    private func verdictCard(_ report: OfflinePsbt.Report) -> UIView {
        let (title, detail, color): (String, String, UIColor) = {
            if addedSignatures > 0 {
                return ("✓ SIGNED", "Added \(addedSignatures) signature\(addedSignatures == 1 ? "" : "s"). Export the PSBT to the coordinator to finalize and broadcast it.", tint.accent)
            }
            switch report.verdict {
            case .danger:
                return ("✗ DO NOT SIGN", "This PSBT failed a check (below). It may be trying to send your bitcoin somewhere you don't expect.", WalletTheme.danger)
            case .warning:
                return report.involvesUs
                    ? ("! CHECK THE WARNINGS", "Nothing failed, but some things couldn't be verified offline. Read them before signing.", WalletTheme.pending)
                    : ("NOTHING TO SIGN", "This signer's keys aren't used by this PSBT.", WalletTheme.pending)
            default:
                return keys?.canSign == true
                    ? ("✓ SAFE TO SIGN", "Every input of this signer and the change were verified against its keys.", tint.accent)
                    : ("✓ VERIFIED SAFE TO SIGN", "Every input of this signer and the change were verified against its saved keys. Sign it on the device that holds the seed.", tint.accent)
            }
        }()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(17, weight: .bold)
        titleLabel.textColor = color
        let detailLabel = hint(detail)
        detailLabel.textColor = WalletTheme.text
        var rows: [UIView] = [titleLabel, detailLabel]
        rows += report.notes.map(noteLabel)
        return WalletTheme.cardView(rows, tint: report.verdict == .danger && addedSignatures == 0 ? .danger : tint, spacing: 8)
    }

    private func summaryCard(_ report: OfflinePsbt.Report) -> UIView {
        let change = report.outputs.filter { $0.kind == .change }.reduce(UInt64(0)) { $0 + $1.amount }
        var rows: [UIView] = [WalletTheme.caption("> TRANSACTION", tint: tint)]
        rows.append(row("Sending", btc(report.sending)))
        if change > 0 { rows.append(row("Change", btc(change))) }
        rows.append(row("Inputs", report.totalIn.map(btc) ?? "unknown"))
        if let fee = report.fee, let rate = report.feeRate {
            rows.append(row("Fee", "\(fee) sats · ≈\(String(format: "%.1f", rate)) sat/vB"))
        } else {
            rows.append(row("Fee", "unknown"))
        }
        rows.append(row("Size", "≈\(report.vsize) vB once signed"))
        rows.append(row("Replaceable", report.rbf ? "yes (RBF)" : "no"))
        if report.locktime > 0 {
            rows.append(row("Locktime", report.locktime < 500_000_000 ? "block \(report.locktime)" : "\(Date(timeIntervalSince1970: TimeInterval(report.locktime)))"))
        }
        rows.append(row("Network", report.mainnet ? "Mainnet" : "Test network"))
        return WalletTheme.cardView(rows, tint: tint, spacing: 6)
    }

    private func outputsCard(_ report: OfflinePsbt.Report) -> UIView {
        var rows: [UIView] = [WalletTheme.caption("> OUTPUTS · \(report.outputs.count)", tint: tint)]
        for output in report.outputs {
            let (badge, color): (String, UIColor) = {
                switch output.kind {
                case .change: return ("CHANGE ✓", tint.accent)
                case .badChange: return ("NOT YOUR CHANGE ✗", WalletTheme.danger)
                case .external: return ("SENDING", WalletTheme.text)
                }
            }()
            rows.append(entry(title: "#\(output.index) · \(btc(output.amount))", badge: badge, badgeColor: color,
                              detail: output.address ?? "\(output.scriptType.rawValue) script", notes: output.notes))
        }
        return WalletTheme.cardView(rows, tint: tint, spacing: 10)
    }

    private func inputsCard(_ report: OfflinePsbt.Report) -> UIView {
        var rows: [UIView] = [WalletTheme.caption("> INPUTS · \(report.inputs.count)", tint: tint)]
        for input in report.inputs {
            let (badge, color): (String, UIColor) = {
                if input.severity == .danger { return ("FAILED ✗", WalletTheme.danger) }
                if input.finalized { return ("FINAL", WalletTheme.dim) }
                if !input.jobs.isEmpty { return (keys?.canSign == true ? "SIGNS HERE" : "VERIFIED", tint.accent) }
                if input.signedByUs > 0 { return ("SIGNED ✓", tint.accent) }
                return ("NOT THIS SIGNER", WalletTheme.dim)
            }()
            let amount = input.amount.map(btc) ?? "amount unknown"
            let short = input.outpoint.count > 24 ? "\(input.outpoint.prefix(10))…\(input.outpoint.suffix(10))" : input.outpoint
            rows.append(entry(title: "#\(input.index) · \(amount)", badge: badge, badgeColor: color,
                              detail: "\(input.scriptType.rawValue) · \(short)\(input.address.map { "\n\($0)" } ?? "")",
                              notes: input.notes.filter { $0.severity != .ok || input.notes.count <= 3 }))
        }
        return WalletTheme.cardView(rows, tint: tint, spacing: 10)
    }

    private func actions(_ report: OfflinePsbt.Report) {
        let canSign = keys?.canSign == true && report.signable > 0 && report.verdict != .danger && addedSignatures == 0
        if canSign {
            let sign = UIButton(type: .system)
            WalletTheme.styleHero(sign, title: "Sign \(report.signable) input\(report.signable == 1 ? "" : "s")", systemImage: "signature", tint: tint)
            sign.addTarget(self, action: #selector(signTapped), for: .touchUpInside)
            stack.setCustomSpacing(20, after: stack.arrangedSubviews.last ?? stack)
            stack.addArrangedSubview(sign)
        }
        if keys?.canSign == true, !report.involvesUs, signer?.words != nil {
            stack.addArrangedSubview(buttonRow([chip("Enter passphrase", "key", #selector(promptPassphrase))]))
        }
        stack.addArrangedSubview(buttonRow([
            chip("Copy", "doc.on.doc", #selector(copyPsbt)),
            chip("QR", "qrcode", #selector(showQr)),
            chip("Share", "square.and.arrow.up", #selector(sharePsbt))
        ]))
    }

    // MARK: - Pieces

    private func hint(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(11)
        label.textColor = WalletTheme.dim
        label.numberOfLines = 0
        return label
    }

    private func noteLabel(_ note: OfflinePsbt.Note) -> UILabel {
        let label = hint({
            switch note.severity {
            case .danger: return "✗ " + note.text
            case .warning: return "! " + note.text
            case .info: return "· " + note.text
            case .ok: return "✓ " + note.text
            }
        }())
        label.textColor = {
            switch note.severity {
            case .danger: return WalletTheme.danger
            case .warning: return WalletTheme.pending
            case .info: return WalletTheme.dim
            case .ok: return tint.accent.withAlphaComponent(0.85)
            }
        }()
        return label
    }

    private func row(_ title: String, _ value: String) -> UIView {
        let left = UILabel()
        left.text = title
        left.font = WalletTheme.mono(12)
        left.textColor = WalletTheme.dim
        left.setContentHuggingPriority(.required, for: .horizontal)
        let right = UILabel()
        right.text = value
        right.font = WalletTheme.mono(12, weight: .semibold)
        right.textColor = WalletTheme.text
        right.textAlignment = .right
        right.numberOfLines = 0
        let row = UIStackView(arrangedSubviews: [left, right])
        row.spacing = 12
        return row
    }

    private func entry(title: String, badge: String, badgeColor: UIColor, detail: String, notes: [OfflinePsbt.Note]) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(13, weight: .semibold)
        titleLabel.textColor = WalletTheme.text
        let badgeLabel = UILabel()
        badgeLabel.text = badge
        badgeLabel.font = WalletTheme.mono(10, weight: .bold)
        badgeLabel.textColor = badgeColor
        badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
        let header = UIStackView(arrangedSubviews: [titleLabel, badgeLabel])
        header.spacing = 8
        let detailLabel = hint(detail)
        detailLabel.lineBreakMode = .byCharWrapping
        let column = UIStackView(arrangedSubviews: [header, detailLabel] + notes.map(noteLabel))
        column.axis = .vertical
        column.spacing = 4
        return column
    }

    private func buttonRow(_ buttons: [UIButton]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: buttons)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func chip(_ title: String, _ image: String, _ action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.configuration = WalletTheme.chipConfiguration(title: title, systemImage: image, tint: tint, fontSize: 12,
                                                             imageSize: 11, imagePadding: 5,
                                                             insets: NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8),
                                                             clipsTitle: true)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func btc(_ sats: UInt64) -> String {
        String(format: "%.8f BTC", Double(sats) / 100_000_000)
    }

    // MARK: - Loading

    @objc private func pastePsbt() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            showAlert(vc: self, title: "", message: "The clipboard is empty.")
            return
        }
        load(text: text)
    }

    @objc private func scanPsbt() {
        guard let vc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "QRScanner") as? QRScannerViewController else { return }
        vc.fromSignAndVerify = true
        vc.onDoneBlock = { [weak self] text in
            guard let self, let text else { return }
            DispatchQueue.main.async { self.load(text: text) }
        }
        present(vc, animated: true)
    }

    @objc private func importFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.data, .text, .item], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let data = try? Data(contentsOf: url) else { return }
        try? FileManager.default.removeItem(at: url)
        guard let raw = OfflinePsbt.decode(data) else {
            showAlert(vc: self, title: "Not a PSBT", message: "That file isn't a PSBT (binary, base64 or hex).")
            return
        }
        load(raw: raw)
    }

    private func load(text: String) {
        guard let raw = OfflinePsbt.decode(text) else {
            showAlert(vc: self, title: "Not a PSBT", message: Keys.validTx(text)
                      ? "That's a signed transaction, not a PSBT. There's nothing to sign."
                      : "That isn't a PSBT (base64, hex or a PSBT QR).")
            return
        }
        load(raw: raw)
    }

    private func load(raw: Data) {
        psbt = raw
        addedSignatures = 0
        analyze()
    }

    /// Builds the signer's keys (choosing the passphrase the PSBT's fingerprints match),
    /// then reviews the PSBT.
    private func analyze() {
        guard let signer, let psbt else { return }
        do {
            keys = try keySource(for: signer, psbt: psbt)
            report = try OfflinePsbt.analyze(psbt, keys: keys!)
        } catch {
            report = nil
            showAlert(vc: self, title: "Can't review this PSBT", message: error.localizedDescription)
        }
        render()
        scrollView.setContentOffset(.zero, animated: true)
    }

    private func keySource(for signer: SignerStruct, psbt: Data) throws -> OfflineKeySource {
        guard let encryptedWords = signer.words else {
            return try watchKeys(for: signer)
        }
        guard var wordsData = Crypto.decrypt(encryptedWords), var words = wordsData.utf8String else {
            throw OfflinePsbt.PsbtError("Unable to decrypt this signer's words.")
        }
        defer {
            wordsData.secureZero()
            words.secureWipe()
        }

        // Typed, stored, then no passphrase: the first whose fingerprint the PSBT uses.
        var candidates: [String] = []
        if let typedPassphrase { candidates.append(typedPassphrase) }
        if let encrypted = signer.passphrase, var data = Crypto.decrypt(encrypted), let stored = data.utf8String {
            candidates.append(stored)
            data.secureZero()
        }
        candidates.append("")
        let fingerprints = Set(OfflinePsbt.fingerprints(in: psbt))
        var first: OfflineKeySource?
        for candidate in candidates {
            guard let keys = OfflineSeedKeys(words: words, passphrase: candidate) else { continue }
            if fingerprints.contains(keys.fingerprint) { return keys }
            if first == nil { first = keys }
        }
        guard let first else { throw OfflinePsbt.PsbtError("This signer's words aren't a valid recovery phrase.") }
        return first
    }

    /// Saved account xpubs (no words): BIP84, BIP86 and BIP48 P2WSH, mainnet and testnet.
    private func watchKeys(for signer: SignerStruct) throws -> OfflineKeySource {
        func decrypted(_ data: Data?) -> String? {
            guard let data, let plain = Crypto.decrypt(data) else { return nil }
            return plain.utf8String
        }
        guard let xfp = decrypted(signer.xfp), xfp.count == 8 else {
            throw OfflinePsbt.PsbtError("This signer has no seed words and no saved fingerprint, so there's nothing to check the PSBT against.")
        }
        let h = OfflineBIP32.hardened
        var accounts: [(path: [UInt32], xpub: String)] = []
        let saved: [([UInt32], Data?)] = [
            ([84 | h, 0 | h, 0 | h], signer.bip84xpub), ([84 | h, 1 | h, 0 | h], signer.bip84tpub),
            ([86 | h, 0 | h, 0 | h], signer.bip86xpub), ([86 | h, 1 | h, 0 | h], signer.bip86tpub),
            ([48 | h, 0 | h, 0 | h, 2 | h], signer.bip48xpub), ([48 | h, 1 | h, 0 | h, 2 | h], signer.bip48tpub)
        ]
        for (path, data) in saved {
            if let xpub = decrypted(data) { accounts.append((path, xpub)) }
        }
        return OfflineWatchKeys(fingerprint: xfp, accounts: accounts)
    }

    @objc private func promptPassphrase() {
        let alert = UIAlertController(title: "Passphrase", message: "If this signer's PSBT was made with a BIP39 passphrase, enter it.", preferredStyle: .alert)
        alert.addTextField { field in
            field.isSecureTextEntry = true
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Use", style: .default) { [weak self, weak alert] _ in
            self?.typedPassphrase = alert?.textFields?.first?.text ?? ""
            self?.analyze()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Signing

    @objc private func signTapped() {
        guard let report else { return }
        let warnings = (report.notes + report.inputs.flatMap(\.notes) + report.outputs.flatMap(\.notes)).filter { $0.severity == .warning }
        guard !warnings.isEmpty else {
            sign()
            return
        }
        let alert = UIAlertController(title: "Sign anyway?",
                                      message: warnings.prefix(4).map { "• " + $0.text }.joined(separator: "\n\n"),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sign", style: .destructive) { [weak self] _ in self?.sign() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func sign() {
        guard let psbt, let keys else { return }
        do {
            let (signed, added) = try OfflinePsbt.sign(psbt, keys: keys)
            self.psbt = signed
            report = try OfflinePsbt.analyze(signed, keys: keys)
            addedSignatures = added
            render()
            scrollView.setContentOffset(.zero, animated: true)
            SuccessView.show(in: self,
                             title: "Signed 100% offline",
                             subtitle: "\(added) signature\(added == 1 ? "" : "s") added on this device alone: no node, no internet, no Tor. Your keys never left this phone.\n\nExport the PSBT to your coordinator to finalize and broadcast it.",
                             onDismiss: nil,
                             secondaryTitle: "Show QR",
                             onSecondary: { [weak self] in self?.showQr() })
        } catch {
            showAlert(vc: self, title: "Not signed", message: error.localizedDescription)
        }
    }

    // MARK: - Export

    private var base64: String? { psbt?.base64EncodedString() }

    @objc private func copyPsbt() {
        guard let base64 else { return }
        UIPasteboard.general.string = base64
        SuccessView.toast("PSBT copied", in: self)
    }

    @objc private func showQr() {
        guard let base64 else { return }
        let qr = QRViewController(text: base64,
                                  headerText: addedSignatures > 0 ? "Signed PSBT" : "PSBT",
                                  descriptionText: "Scan with the coordinator or your next signer",
                                  headerIcon: UIImage(systemName: "qrcode"),
                                  isBbqr: false,
                                  isUR: true)
        let nav = UINavigationController(rootViewController: qr)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
    }

    @objc private func sharePsbt() {
        guard let psbt else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(addedSignatures > 0 ? "signed.psbt" : "reviewed.psbt")
        do {
            try psbt.write(to: url, options: .completeFileProtection)
        } catch {
            showAlert(vc: self, title: "Error", message: "Couldn't write the PSBT file.")
            return
        }
        let share = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        share.completionWithItemsHandler = { _, _, _, _ in try? FileManager.default.removeItem(at: url) }
        share.popoverPresentationController?.sourceView = view
        present(share, animated: true)
    }

    @objc private func showHelp() {
        showAlert(vc: self, title: "Offline review",
                  message: "Load a PSBT by pasting it, scanning its QR or opening its file. Fully Noded checks it using only the PSBT and this signer's keys, with no node or internet:\n\n• each input's amount, against its full previous transaction when it's included\n• that this signer's keys really are what each input spends with\n• that change really goes back to this signer\n• the fee, sighash types and locktime\n\nWith the seed words it then signs (segwit and taproot, single and multisig). Without them it tells you whether the PSBT is safe to sign on the device that holds the seed.")
    }
}
