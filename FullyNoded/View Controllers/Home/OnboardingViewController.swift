//
//  OnboardingViewController.swift
//  FullyNoded
//
//  First-run flow: welcome → connect a node (Quick Connect QR or manual RPC) → lock the
//  app → done. The connect step also stands alone as the "Connect a node" sheet the home
//  screen shows instead of a "No active node" alert.
//

import UIKit

final class OnboardingViewController: UIViewController, UITextFieldDelegate {

    /// While the flow is on screen, and once right after it closes, the home screen
    /// skips its "No active node" alert (the flow already covers connecting).
    static private var isPresented = false
    static private var suppressNextNoNodeAlert = false

    /// Call as soon as a first run is suspected (before knowing for sure), so nothing
    /// else alerts about a missing node in the meantime.
    static func expect() { isPresented = true }

    /// It turned out not to be a first run.
    static func cancelExpected() { isPresented = false }

    /// Shows the first-run flow full screen. Clears an alert that got there first.
    static func present(from presenter: UIViewController) {
        isPresented = true
        show(OnboardingViewController(mode: .firstRun), from: presenter)
    }

    /// The same flow opened on purpose (home screen's setup-guide button): closable anytime.
    static func replay(from presenter: UIViewController) {
        guard presenter.presentedViewController == nil else { return }
        isPresented = true
        let root = OnboardingViewController(mode: .firstRun)
        root.isReplay = true
        show(root, from: presenter)
    }

    private var isReplay = false
    private let closeButton = UIButton(type: .system)

    /// "Connect a node" sheet: the connect step on its own (no active node).
    /// Doesn't pop up again by itself after "Not now" this session unless `force`d
    /// (pull to refresh / refresh button).
    static func presentAddNode(from presenter: UIViewController, force: Bool = false) {
        guard !isPresented, !isShowingAddNode, force || !addNodeDeclined else { return }
        if let presented = presenter.presentedViewController, !(presented is UIAlertController) { return }
        isShowingAddNode = true
        show(OnboardingViewController(mode: .addNode), from: presenter)
    }

    static private var isShowingAddNode = false
    static private var addNodeDeclined = false

    /// Inside its own navigation controller (the manual node screen and the node list
    /// are pushed onto it).
    private static func show(_ root: OnboardingViewController, from presenter: UIViewController) {
        let nav = UINavigationController(rootViewController: root)
        nav.modalPresentationStyle = .fullScreen
        nav.overrideUserInterfaceStyle = .dark
        if presenter.presentedViewController is UIAlertController {
            presenter.dismiss(animated: false) { presenter.present(nav, animated: true) }
        } else {
            presenter.present(nav, animated: true)
        }
    }

    private enum Mode { case firstRun, addNode }
    private let mode: Mode

    private init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// The home screen calls this before its "No active node" alert.
    /// An explicit refresh (`force`) is never skipped once the flow has closed.
    static func consumeNoNodeAlertSuppression(force: Bool = false) -> Bool {
        if isPresented { return true }
        guard suppressNextNoNodeAlert, !force else {
            suppressNextNoNodeAlert = false
            return false
        }
        suppressNextNoNodeAlert = false
        return true
    }

    private enum Step { case welcome, connect, secure, done }

    private let tint = WalletTheme.Tint.home
    private var step: Step = .welcome
    private var connectedNodeLabel: String?
    private var nodeWasAddedManually = false
    private var nodeCountBeforeManualEntry: Int?
    private var hasSavedNodes = false
    private var openedSavedNodes = false
    /// What's actually saved (the guide can be replayed anytime, so don't assume none).
    private var savedNodeCount = 0
    private var savedActiveNodeLabel: String?
    private var nodesFreshForDone = false

    private let progress = UIStackView()
    private let scrollView = UIScrollView()
    private let content = UIStackView()
    private let actions = UIStackView()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let passwordField = UITextField()
    private let confirmField = UITextField()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletTheme.bg
        buildChrome()
        view.bringSubviewToFront(progress)
        view.bringSubviewToFront(closeButton)
        guard mode == .addNode else {
            render(.welcome, animated: false)
            refreshSavedNodes { [weak self] in
                // Replayed with nodes already saved: the connect step mentions them.
                if self?.step == .connect { self?.render(.connect, animated: false) }
            }
            return
        }
        // Saved but inactive nodes: offer to pick one.
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.hasSavedNodes = !(nodes ?? []).isEmpty
                self.render(.connect, animated: false)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        checkForManuallyAddedNode()
        checkForActivatedSavedNode()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if navigationController?.topViewController !== self {
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: Chrome (progress, scrolling content, pinned actions)

    private func buildChrome() {
        progress.axis = .horizontal
        progress.spacing = 6
        progress.distribution = .fillEqually
        for _ in 0..<3 {
            let bar = UIView()
            bar.heightAnchor.constraint(equalToConstant: 3).isActive = true
            progress.addArrangedSubview(bar)
        }

        content.axis = .vertical
        content.spacing = 18
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(content)
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.showsVerticalScrollIndicator = false

        WalletTheme.styleHero(primaryButton, title: "", tint: tint)
        primaryButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)

        var secondary = UIButton.Configuration.plain()
        secondary.baseForegroundColor = WalletTheme.dim
        secondary.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(13, weight: .semibold)
            return attributes
        }
        secondaryButton.configuration = secondary
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)

        actions.axis = .vertical
        actions.spacing = 6
        actions.addArrangedSubview(primaryButton)
        actions.addArrangedSubview(secondaryButton)

        for v in [progress, scrollView, actions] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let guide = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            progress.topAnchor.constraint(equalTo: guide.topAnchor, constant: 12),
            progress.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            progress.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),

            // Full height behind the progress bar, so the logo's glow isn't cut off at a hard edge;
            // the safe-area inset keeps the content itself below the bar.
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actions.topAnchor, constant: -12),

            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 47),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            content.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -24),

            actions.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 24),
            actions.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -24),
            actions.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12)
        ])

        if isReplay {
            closeButton.setImage(UIImage(systemName: "xmark",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)), for: .normal)
            closeButton.tintColor = WalletTheme.dim
            closeButton.accessibilityLabel = "Close"
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(closeButton)
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: progress.bottomAnchor, constant: 6),
                closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -14),
                closeButton.widthAnchor.constraint(equalToConstant: 40),
                closeButton.heightAnchor.constraint(equalToConstant: 40)
            ])
        }
    }

    private func setProgress(_ filled: Int) {
        progress.alpha = filled == 0 || mode == .addNode ? 0 : 1
        for (i, bar) in progress.arrangedSubviews.enumerated() {
            bar.backgroundColor = i < filled ? tint.accent : tint.line.withAlphaComponent(0.3)
        }
    }

    private func setActions(primary: String?, primaryIcon: String = "arrow.right", secondary: String?) {
        if let primary = primary {
            WalletTheme.styleHero(primaryButton, title: primary, systemImage: primaryIcon, tint: tint)
        }
        primaryButton.isHidden = primary == nil
        secondaryButton.configuration?.title = secondary
        secondaryButton.isHidden = secondary == nil
    }

    // MARK: Steps

    private func render(_ step: Step, animated: Bool = true) {
        // Done step: re-read saved nodes first, so ones added during the flow count too.
        if step == .done && !nodesFreshForDone {
            refreshSavedNodes { [weak self] in
                self?.nodesFreshForDone = true
                self?.render(.done, animated: animated)
                self?.nodesFreshForDone = false
            }
            return
        }
        self.step = step
        view.endEditing(true)

        let build = { [self] in
            content.arrangedSubviews.forEach { $0.removeFromSuperview() }
            switch step {
            case .welcome: buildWelcome()
            case .connect: buildConnect()
            case .secure: buildSecure()
            case .done: buildDone()
            }
            scrollView.setContentOffset(.zero, animated: false)
        }

        guard animated else { build(); return }
        UIView.animate(withDuration: 0.15, animations: {
            self.content.alpha = 0
            self.content.transform = CGAffineTransform(translationX: -24, y: 0)
        }, completion: { _ in
            build()
            self.content.transform = CGAffineTransform(translationX: 24, y: 0)
            UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
                self.content.alpha = 1
                self.content.transform = .identity
            }
        })
    }

    private func buildWelcome() {
        setProgress(0)

        // Same glowing mark as the launch and unlock screens (website corner ratio, no cropping).
        let logo = BrandLockup(logoSize: 84, showsTitle: false)
        let logoRow = UIStackView(arrangedSubviews: [logo, UIView()])
        logoRow.alignment = .center

        let name = UILabel()
        var attributed = AttributedString("FULLY NODED")
        attributed.font = WalletTheme.mono(30, weight: .bold)
        attributed.kern = 3
        attributed.foregroundColor = tint.accent
        name.attributedText = NSAttributedString(attributed)

        content.addArrangedSubview(logoRow)
        content.setCustomSpacing(20, after: logoRow)
        content.addArrangedSubview(name)
        content.setCustomSpacing(6, after: name)
        content.addArrangedSubview(body("A miniscript-powered wallet, wired to your own node.", size: 17, color: WalletTheme.text))
        content.addArrangedSubview(spacer(8))
        content.addArrangedSubview(feature("desktopcomputer", "Your node",
                                           "Talk directly to Bitcoin Core or Knots. No middlemen, no third-party servers."))
        content.addArrangedSubview(feature("key.horizontal", "Serious wallet power",
                                           "Multisig, miniscript timelocks, Taproot and silent payments. Keys stay encrypted on this device, or go watch-only and sign elsewhere."))
        content.addArrangedSubview(feature("network.badge.shield.half.filled", "Private by default",
                                           "Built-in Tor reaches your node over onion, from anywhere."))

        setActions(primary: "Get started", secondary: "Learn more at fullynoded.app")
    }

    private func buildConnect() {
        setProgress(1)
        if mode == .addNode {
            content.addArrangedSubview(WalletTheme.caption("> NO ACTIVE NODE", tint: tint))
            content.addArrangedSubview(title("Connect a node"))
            content.addArrangedSubview(body(hasSavedNodes
                ? "None of your saved nodes is active. Pick one, or add a new node."
                : "Fully Noded needs a node to talk to. Pick how you'd like to connect."))
        } else {
            content.addArrangedSubview(WalletTheme.caption("> STEP 1 OF 3 · CONNECT", tint: tint))
            content.addArrangedSubview(title("Connect your node"))
            if savedNodeCount > 0 {
                let plural = savedNodeCount == 1 ? "1 saved node" : "\(savedNodeCount) saved nodes"
                let active = savedActiveNodeLabel.map { " (active: \($0))" } ?? ", none active"
                content.addArrangedSubview(body("You already have \(plural)\(active). Add another, or skip ahead."))
            } else {
                content.addArrangedSubview(body("Pick how you'd like to connect. You can add more nodes later in Settings › Node Manager."))
            }
        }

        if mode == .addNode && hasSavedNodes {
            content.addArrangedSubview(OptionCard(
                symbol: "list.bullet.rectangle",
                title: "Use a saved node",
                detail: "Open Node Manager and tap a node to make it active.",
                badge: nil,
                tint: tint,
                action: { [weak self] in self?.openSavedNodes() }))
        }

        content.addArrangedSubview(OptionCard(
            symbol: "qrcode.viewfinder",
            title: "Scan Quick Connect",
            detail: "Umbrel, Start9, myNode, RaspiBlitz, Parmanode, NODL, BTCPay or Fully Noded Server.",
            badge: mode == .addNode && hasSavedNodes ? nil : "RECOMMENDED",
            tint: tint,
            action: { [weak self] in self?.scanQuickConnect() }))
        content.addArrangedSubview(OptionCard(
            symbol: "terminal",
            title: "Enter details manually",
            detail: "RPC address and credentials for Bitcoin Core or Knots, over Tor or your local network.",
            badge: nil,
            tint: tint,
            action: { [weak self] in self?.enterManually() }))
        content.addArrangedSubview(nodelessNote())

        setActions(primary: nil, secondary: mode == .addNode ? "Not now" : "Skip for now")
    }

    private func buildSecure() {
        setProgress(2)
        if let label = connectedNodeLabel {
            let note = nodeWasAddedManually
                ? "Add the rpcauth line from the node screen to your bitcoin.conf and restart your node, if you haven't already."
                : "Tor will connect to it as soon as you finish."
            content.addArrangedSubview(banner(symbol: "checkmark.circle.fill",
                                              title: nodeWasAddedManually ? "Saved \(label)" : "Connected to \(label)",
                                              detail: note))
        }
        content.addArrangedSubview(WalletTheme.caption("> STEP 2 OF 3 · SECURE", tint: tint))
        content.addArrangedSubview(title("Lock the app"))
        content.addArrangedSubview(body("Anyone holding this phone could open your wallets. Set a password to unlock Fully Noded: at least 8 characters, and not just numbers."))

        for (field, placeholder) in [(passwordField, "Password"), (confirmField, "Confirm password")] {
            field.text = ""
            field.placeholder = placeholder
            field.isSecureTextEntry = true
            field.textContentType = .newPassword
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.font = WalletTheme.mono(15)
            field.delegate = self
            WalletTheme.styleField(field, tint: tint)
            field.heightAnchor.constraint(equalToConstant: 48).isActive = true
            content.addArrangedSubview(field)
        }
        passwordField.returnKeyType = .next
        confirmField.returnKeyType = .done
        content.setCustomSpacing(10, after: passwordField)

        let warning = body("There's no reset. If you forget it you'll need your wallet backups.", size: 12, color: WalletTheme.pending)
        content.addArrangedSubview(warning)

        setActions(primary: "Set password", primaryIcon: "lock.fill", secondary: "Not now")
    }

    private func buildDone() {
        setProgress(3)
        let check = UIImageView(image: UIImage(systemName: "checkmark.seal.fill",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 56, weight: .semibold)))
        check.tintColor = tint.accent
        check.contentMode = .left
        content.addArrangedSubview(check)
        content.addArrangedSubview(WalletTheme.caption("> STEP 3 OF 3 · DONE", tint: tint))
        content.addArrangedSubview(title("You're all set"))

        let hasLock = KeyChain.getData("UnlockPassword") != nil
        let activeLabel = connectedNodeLabel ?? savedActiveNodeLabel
        let others = savedNodeCount > 1 ? " \(savedNodeCount) nodes saved." : ""
        let nodeRow: UIView
        if let activeLabel = activeLabel {
            nodeRow = checklistRow(done: true, title: "Node · \(activeLabel)",
                                   detail: "Connects over Tor when you open the app.\(others)")
        } else if savedNodeCount > 0 {
            nodeRow = checklistRow(done: false,
                                   title: savedNodeCount == 1 ? "1 node saved, not active" : "\(savedNodeCount) nodes saved, none active",
                                   detail: "Tap one in Settings › Node Manager to make it active.")
        } else {
            nodeRow = checklistRow(done: false, title: "No node yet",
                                   detail: "Add one anytime in Settings › Node Manager, or go Nodeless once you've added a signer.")
        }
        let rows: [UIView] = [
            nodeRow,
            checklistRow(done: hasLock,
                         title: hasLock ? "App lock on" : "App lock off",
                         detail: hasLock ? "You'll enter your password to open Fully Noded."
                            : "Turn it on anytime in Settings › Security Center.")
        ]
        content.addArrangedSubview(WalletTheme.cardView(rows, tint: tint, spacing: 14))
        content.addArrangedSubview(body("Tip: pull down on the home screen to refresh your node.", size: 12))

        setActions(primary: "Open Fully Noded", secondary: nil)
    }

    // MARK: Actions

    @objc private func primaryTapped() {
        switch step {
        case .welcome: render(.connect)
        case .connect: break
        case .secure: setPassword()
        case .done: finish()
        }
    }

    @objc private func secondaryTapped() {
        switch step {
        case .welcome:
            UIApplication.shared.open(URL(string: "https://fullynoded.app")!)
        case .connect:
            if mode == .addNode {
                Self.addNodeDeclined = true
                close(addedNode: false)
            } else {
                advancePastConnect()
            }
        case .secure:
            render(.done)
        case .done:
            break
        }
    }

    private func advancePastConnect() {
        guard mode == .firstRun else {
            close(addedNode: connectedNodeLabel != nil)
            return
        }
        render(KeyChain.getData("UnlockPassword") == nil ? .secure : .done)
    }

    private func scanQuickConnect() {
        guard !isShowingActivity,
              let scanner = UIStoryboard(name: "Main", bundle: nil)
                .instantiateViewController(withIdentifier: "QRScanner") as? QRScannerViewController else { return }
        scanner.isQuickConnect = true
        scanner.onDoneBlock = { [weak self] url in
            guard let self = self, let url = url else { return }
            DispatchQueue.main.async { self.addQuickConnectNode(url) }
        }
        present(scanner, animated: true)
    }

    private func addQuickConnectNode(_ url: String) {
        showActivity("adding node...")
        QuickConnect.addNode(url: url) { [weak self] success, errorMessage in
            guard let self = self else { return }
            self.hideActivity()
            guard success else {
                showAlert(vc: self, title: "Couldn't add that node", message: errorMessage ?? "Unknown error.")
                return
            }
            self.activeNodeLabel { label in
                self.connectedNodeLabel = label ?? "your node"
                self.nodeWasAddedManually = false
                self.advancePastConnect()
            }
        }
    }

    private func enterManually() {
        countNodes { [weak self] count in
            guard let self = self else { return }
            self.nodeCountBeforeManualEntry = count
            let detail = NodeDetailViewController()
            detail.selectedNode = nil
            self.navigationController?.pushViewController(detail, animated: true)
        }
    }

    /// Back from the manual node screen: move on if a node was saved there.
    private func checkForManuallyAddedNode() {
        guard step == .connect, let before = nodeCountBeforeManualEntry else { return }
        countNodes { [weak self] count in
            guard let self = self, count > before else { return }
            self.nodeCountBeforeManualEntry = nil
            self.activeNodeLabel { label in
                self.connectedNodeLabel = label ?? "your node"
                self.nodeWasAddedManually = true
                self.advancePastConnect()
            }
        }
    }

    private func openSavedNodes() {
        openedSavedNodes = true
        navigationController?.pushViewController(NodesViewController(), animated: true)
    }

    /// Back from Node Manager: close if a node is active now.
    private func checkForActivatedSavedNode() {
        guard openedSavedNodes else { return }
        openedSavedNodes = false
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            let active = (nodes ?? []).map { NodeStruct(dictionary: $0) }.first { $0.isActive }
            DispatchQueue.main.async {
                guard let self = self, let active = active else { return }
                self.connectedNodeLabel = active.label
                self.close(addedNode: true)
            }
        }
    }

    private func setPassword() {
        let password = passwordField.text ?? ""
        guard password.count > 7 else {
            shake(passwordField)
            showAlert(vc: self, title: "Too short", message: "Use at least 8 characters.")
            return
        }
        guard !password.isNumber else {
            shake(passwordField)
            showAlert(vc: self, title: "Not just numbers", message: "This is a password, not a PIN. Mix in some letters.")
            return
        }
        guard confirmField.text == password else {
            shake(confirmField)
            showAlert(vc: self, title: "Passwords don't match", message: "Enter the same password in both fields.")
            return
        }
        // Same storage as AppPasswordViewController: sha256 of the password, in the keychain.
        guard let data = Data(hexString: Crypto.sha256hash(password)),
              KeyChain.set(data, forKey: "UnlockPassword") else {
            showAlert(vc: self, title: "Error", message: "We couldn't save your password.")
            return
        }
        passwordField.text = ""
        confirmField.text = ""
        render(.done)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
        Self.isPresented = false
        Self.suppressNextNoNodeAlert = true
        close(addedNode: connectedNodeLabel != nil)
    }

    @objc private func closeTapped() {
        Self.isPresented = false
        close(addedNode: connectedNodeLabel != nil)
    }

    private func close(addedNode: Bool) {
        if mode == .addNode { Self.isShowingAddNode = false }
        dismiss(animated: true) {
            if addedNode {
                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
            }
        }
    }

    // MARK: Text fields

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === passwordField {
            confirmField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            setPassword()
        }
        return true
    }

    // MARK: Data

    /// Saved node count and the active node's label, on the main queue.
    private func refreshSavedNodes(_ completion: @escaping () -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            let all = (nodes ?? []).map { NodeStruct(dictionary: $0) }
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.savedNodeCount = all.count
                self.hasSavedNodes = !all.isEmpty
                self.savedActiveNodeLabel = all.first { $0.isActive }?.label
                completion()
            }
        }
    }

    private func countNodes(_ completion: @escaping (Int) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            DispatchQueue.main.async { completion(nodes?.count ?? 0) }
        }
    }

    private func activeNodeLabel(_ completion: @escaping (String?) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            let all = (nodes ?? []).map { NodeStruct(dictionary: $0) }
            let node = all.first { $0.isActive } ?? all.last
            DispatchQueue.main.async { completion(node?.label) }
        }
    }

    // MARK: Building blocks

    private func title(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(26, weight: .bold)
        label.textColor = WalletTheme.text
        label.numberOfLines = 0
        return label
    }

    private func body(_ text: String, size: CGFloat = 14, color: UIColor = WalletTheme.dim) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = WalletTheme.mono(size)
        label.textColor = color
        label.numberOfLines = 0
        return label
    }

    private func spacer(_ height: CGFloat) -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func icon(_ symbol: String, size: CGFloat = 18, color: UIColor? = nil) -> UIImageView {
        let imageView = UIImageView(image: UIImage(systemName: symbol,
                                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)))
        imageView.tintColor = color ?? tint.accent
        imageView.contentMode = .center
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        return imageView
    }

    private func feature(_ symbol: String, _ title: String, _ detail: String) -> UIView {
        let titleLabel = body(title, size: 15, color: WalletTheme.text)
        titleLabel.font = WalletTheme.mono(15, weight: .bold)
        let text = UIStackView(arrangedSubviews: [titleLabel, body(detail, size: 13)])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [icon(symbol, size: 20), text])
        row.spacing = 14
        row.alignment = .top
        return row
    }

    private func banner(symbol: String, title: String, detail: String) -> UIView {
        let titleLabel = body(title, size: 14, color: WalletTheme.text)
        titleLabel.font = WalletTheme.mono(14, weight: .bold)
        let text = UIStackView(arrangedSubviews: [titleLabel, body(detail, size: 12)])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [icon(symbol), text])
        row.spacing = 10
        row.alignment = .top
        return WalletTheme.cardView([row], tint: tint)
    }

    /// Not a way in from here: Nodeless wallets come from a signer.
    private func nodelessNote() -> UIView {
        let titleLabel = body("No node? Nodeless works too", size: 13, color: WalletTheme.text)
        titleLabel.font = WalletTheme.mono(13, weight: .bold)
        let text = UIStackView(arrangedSubviews: [
            titleLabel,
            body("Once you've added a signer you can use it Nodeless anytime, over a Tor tunnel to mempool.space's onion service.", size: 12)
        ])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [icon("square.stack", size: 16, color: WalletTheme.dim), text])
        row.spacing = 10
        row.alignment = .top
        return row
    }

    private func checklistRow(done: Bool, title: String, detail: String) -> UIView {
        let titleLabel = body(title, size: 14, color: WalletTheme.text)
        titleLabel.font = WalletTheme.mono(14, weight: .bold)
        let text = UIStackView(arrangedSubviews: [titleLabel, body(detail, size: 12)])
        text.axis = .vertical
        text.spacing = 3
        let row = UIStackView(arrangedSubviews: [
            icon(done ? "checkmark.circle.fill" : "circle.dashed", color: done ? tint.accent : WalletTheme.dim),
            text
        ])
        row.spacing = 10
        row.alignment = .top
        return row
    }

    private func shake(_ view: UIView) {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [-8, 8, -6, 6, -3, 3, 0]
        animation.duration = 0.35
        view.layer.add(animation, forKey: "shake")
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

/// Tappable bordered card: icon, title (+ optional badge), detail, chevron.
private final class OptionCard: UIControl {
    private let action: () -> Void
    private let tint: WalletTheme.Tint

    init(symbol: String, title: String, detail: String, badge: String?, tint: WalletTheme.Tint, action: @escaping () -> Void) {
        self.action = action
        self.tint = tint
        super.init(frame: .zero)
        backgroundColor = WalletTheme.card
        layer.borderWidth = 1
        layer.borderColor = tint.line.cgColor

        let iconView = UIImageView(image: UIImage(systemName: symbol,
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold)))
        iconView.tintColor = tint.accent
        iconView.contentMode = .center
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 36).isActive = true

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = WalletTheme.mono(15, weight: .bold)
        titleLabel.textColor = WalletTheme.text
        titleLabel.numberOfLines = 0

        var titleViews: [UIView] = [titleLabel]
        if let badge = badge {
            let badgeLabel = BadgeLabel()
            badgeLabel.text = badge
            badgeLabel.font = WalletTheme.mono(9, weight: .bold)
            badgeLabel.textColor = WalletTheme.bg
            badgeLabel.backgroundColor = tint.accent
            badgeLabel.setContentHuggingPriority(.required, for: .horizontal)
            titleViews.append(badgeLabel)
        }
        titleViews.append(UIView())
        let titleRow = UIStackView(arrangedSubviews: titleViews)
        titleRow.spacing = 8
        titleRow.alignment = .center

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = WalletTheme.mono(12)
        detailLabel.textColor = WalletTheme.dim
        detailLabel.numberOfLines = 0

        let text = UIStackView(arrangedSubviews: [titleRow, detailLabel])
        text.axis = .vertical
        text.spacing = 4

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)))
        chevron.tintColor = tint.line
        chevron.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [iconView, text, chevron])
        row.spacing = 12
        row.alignment = .center
        row.isUserInteractionEnabled = false
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14)
        ])

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = "\(title). \(detail)"
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? tint.accent.withAlphaComponent(0.12) : WalletTheme.card
            layer.borderColor = (isHighlighted ? tint.accent : tint.line).cgColor
        }
    }

    @objc private func tapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        action()
    }
}

private final class BadgeLabel: UILabel {
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 12, height: size.height + 4)
    }
}
