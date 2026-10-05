//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

/// Home: a dashboard for the active node, built in code. The storyboard scene is only
/// the tab's root shell (navigation item with the lock button, and the segues to the
/// lock screen, first-run flow, unlock password and peer detail).
///
///   ┌ > NODE ──────────────────────── MAIN ┐
///   │ My Node                              │
///   │ ● TOR CONNECTED                      │
///   │ BLOCK 912,345                        │
///   │ FULLY VERIFIED ████████████████████  │
///   └──────────────────────────────────────┘
///   [ PEERS      ] [ MEMPOOL    ]
///   [ FEE RATE   ] [ UPTIME     ]
///   [ HASHRATE   ] [ DIFFICULTY ]
///   [ STORAGE    ] [ CORE       ]
class MainMenuViewController: UIViewController {
    
    weak var mgr = TorClient.sharedInstance
    let ud = UserDefaults.standard
    var activeNode: NodeStruct?
    var existingNodeID: UUID!
    var initialLoad = false
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var isUnlocked = false
    let refreshControl = UIRefreshControl()
    
    var blockchainInfo: BlockchainInfo?
    var peerInfo: GetPeerInfoResponse?
    var networkInfo: NetworkInfo?
    var miningInfo: MiningInfo?
    var mempoolInfo: MempoolInfo?
    var uptimeInfo: Uptime?
    var feeInfo: FeeInfo?
    
    /// True while that RPC is in flight (its tile shows "···").
    var showBlockchainInfoSpinner = false
    var showNetworkInfoSpinner = false
    var showFeeInfoSpinner = false
    var showMempoolInfoSpinner = false
    var showMiningInfoSpinner = false
    var showPeerInfoSpinner = false
    var showUpTimeSpinner = false
    
    private let tint = WalletTheme.Tint.home
    
    // MARK: Views
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    private let nodeLabel = UILabel()
    private let chainBadge = PaddedLabel()
    private let torDot = UIView()
    private let torStatusLabel = UILabel()
    private let torProgressView = UIProgressView(progressViewStyle: .bar)
    private let heightLabel = UILabel()
    private let syncLabel = UILabel()
    private let syncProgressView = UIProgressView(progressViewStyle: .bar)
    /// Device clock vs the chain tip's timestamp (generous; see clockCheck).
    private let clockLabel = UILabel()

    // Node connection status row: dot + state, and when we last heard from the node.
    private enum NodeState { case idle, noNode, connecting, connected, unreachable }
    private var nodeState: NodeState = .idle { didSet { renderNodeStatus() } }
    private let nodeDot = UIView()
    private let nodeStatusLabel = UILabel()
    private let updatedLabel = UILabel()
    /// Last successful response from the active node (persisted per node).
    private var lastUpdated: Date?
    private var statusTimer: Timer?
    
    private let peersTile = DashboardTile(caption: "PEERS", symbol: "person.3")
    private let mempoolTile = DashboardTile(caption: "MEMPOOL", symbol: "waveform.path.ecg")
    private let feeTile = DashboardTile(caption: "FEE RATE", symbol: "percent")
    private let uptimeTile = DashboardTile(caption: "UPTIME", symbol: "clock")
    private let hashrateTile = DashboardTile(caption: "HASHRATE", symbol: "speedometer")
    private let difficultyTile = DashboardTile(caption: "DIFFICULTY", symbol: "slider.horizontal.3")
    private let storageTile = DashboardTile(caption: "STORAGE", symbol: "externaldrive")
    private let coreTile = DashboardTile(caption: "CORE", symbol: "cpu")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(UIDevice.modelName, forKey: "modelName")
        UIApplication.shared.isIdleTimerDisabled = true
        addNavBarSpinner()
        
        let firstRun = UserDefaults.standard.value(forKey: "beenHere") == nil
        if firstRun { OnboardingViewController.expect() }
        
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node  else {
                guard firstRun else { return }
                
                CoreDataService.retrieveEntity(entityName: .newNodes) { savedNodes in
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        guard savedNodes == nil || savedNodes?.count == 0 else {
                            OnboardingViewController.cancelExpected()
                            return
                        }
                        removeLoader()
                        OnboardingViewController.present(from: self.tabBarController ?? self)
                        UserDefaults.standard.set(true, forKey: "beenHere")
                    }
                }
                return
            }
            if firstRun { OnboardingViewController.cancelExpected() }
            activeNode = node
            DispatchQueue.main.async { [weak self] in
                self?.nodeLabel.text = node.label
            }
        }
        
        buildLayout()
        initialLoad = true
        showUnlockScreen()
        setFeeTarget()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNode), name: .refreshNode, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startTorFromAppDelegate), name: .startTorFromAppDelegate, object: nil)
        refreshControl.addTarget(self, action: #selector(refreshNode), for: UIControl.Event.valueChanged)
        scrollView.refreshControl = refreshControl
        ensureXfpSaved()
        renderDashboard()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.renderNodeStatus()
            if let info = self.blockchainInfo { self.renderClockCheck(info) }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            if !firstTimeHere() {
                displayAlert(viewController: self, isError: true, message: "There was a critical error setting your devices encryption key, please delete and reinstall the app")
            } else {
                startTor()
            }
        } else {
            MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
                guard let self = self else { return }
                guard let node = node else {
                    removeLoader()
                    alertToAddNode()
                    return
                }
                
                self.activeNode = node
            }
        }
        
        updateTorStatus()
    }
    
    // MARK: - Layout
    
    private func buildLayout() {
        // Replays the onboarding flow (next to the lock; the right side is the refresh/spinner slot).
        let guide = UIBarButtonItem(image: UIImage(systemName: "signpost.right"), style: .plain,
                                    target: self, action: #selector(showOnboarding))
        guide.tintColor = tint.accent
        guide.accessibilityLabel = "Setup guide"
        navigationItem.leftBarButtonItems = (navigationItem.leftBarButtonItems ?? []) + [guide]

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        
        contentStack.axis = .vertical
        contentStack.spacing = 12
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
        
        contentStack.addArrangedSubview(nodeCard())
        contentStack.addArrangedSubview(WalletTheme.caption("> NETWORK STATS", tint: tint))
        contentStack.setCustomSpacing(8, after: contentStack.arrangedSubviews.last!)
        
        let tiles: [(DashboardTile, Selector)] = [
            (peersTile, #selector(peersTapped)),
            (mempoolTile, #selector(mempoolTapped)),
            (feeTile, #selector(feeTapped)),
            (uptimeTile, #selector(uptimeTapped)),
            (hashrateTile, #selector(miningTapped)),
            (difficultyTile, #selector(blockchainTapped)),
            (storageTile, #selector(blockchainTapped)),
            (coreTile, #selector(networkTapped))
        ]
        for (tile, action) in tiles {
            tile.addTarget(self, action: action, for: .touchUpInside)
        }
        for pair in stride(from: 0, to: tiles.count, by: 2) {
            let row = UIStackView(arrangedSubviews: [tiles[pair].0, tiles[pair + 1].0])
            row.axis = .horizontal
            row.spacing = 12
            row.distribution = .fillEqually
            contentStack.addArrangedSubview(row)
        }
        
        let hint = UILabel()
        hint.text = "Tap a tile for the raw RPC response. Pull down to refresh."
        hint.font = WalletTheme.mono(11)
        hint.textColor = WalletTheme.dim
        hint.numberOfLines = 0
        hint.textAlignment = .center
        contentStack.addArrangedSubview(hint)
        
        // Cypherpunk look (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.apply(to: self, tint: tint)
        // The theme pass paints progress tracks green; keep the node card's neutral so
        // only actual progress is green.
        for bar in [torProgressView, syncProgressView] {
            bar.trackTintColor = WalletTheme.dim.withAlphaComponent(0.18)
        }
        navigationController?.navigationBar.tintColor = tint.accent
        // Also styled from SceneDelegate; repeated here in case the tab bar wasn't the
        // window's root yet when the scene connected.
        if let tabBarController = tabBarController {
            WalletTheme.styleTabBar(tabBarController)
        }
        refreshControl.tintColor = tint.accent
        spinner.color = tint.accent
    }
    
    /// Node label, chain, Tor status, block height and sync progress.
    private func nodeCard() -> UIView {
        nodeLabel.font = WalletTheme.mono(22, weight: .bold)
        nodeLabel.textColor = WalletTheme.text
        nodeLabel.adjustsFontSizeToFitWidth = true
        nodeLabel.minimumScaleFactor = 0.6
        nodeLabel.text = "—"
        
        chainBadge.font = WalletTheme.mono(11, weight: .bold)
        chainBadge.textColor = WalletTheme.dim
        chainBadge.layer.borderWidth = 1
        chainBadge.layer.borderColor = WalletTheme.dim.withAlphaComponent(0.5).cgColor
        chainBadge.isHidden = true
        chainBadge.setContentHuggingPriority(.required, for: .horizontal)
        chainBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
        chevron.tintColor = WalletTheme.dim
        chevron.setContentHuggingPriority(.required, for: .horizontal)
        let captionRow = UIStackView(arrangedSubviews: [WalletTheme.caption("> NODE", tint: tint), UIView(), chainBadge, chevron])
        captionRow.spacing = 8
        captionRow.axis = .horizontal
        captionRow.alignment = .center
        
        torDot.translatesAutoresizingMaskIntoConstraints = false
        torDot.backgroundColor = WalletTheme.dim
        NSLayoutConstraint.activate([
            torDot.widthAnchor.constraint(equalToConstant: 8),
            torDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        torStatusLabel.font = WalletTheme.mono(12, weight: .semibold)
        torStatusLabel.textColor = WalletTheme.dim
        torStatusLabel.text = "TOR …"
        let torRow = UIStackView(arrangedSubviews: [torDot, torStatusLabel])
        torRow.axis = .horizontal
        torRow.alignment = .center
        torRow.spacing = 8
        
        nodeDot.translatesAutoresizingMaskIntoConstraints = false
        nodeDot.layer.cornerRadius = 4
        NSLayoutConstraint.activate([
            nodeDot.widthAnchor.constraint(equalToConstant: 8),
            nodeDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        nodeStatusLabel.font = WalletTheme.mono(12, weight: .semibold)
        updatedLabel.font = WalletTheme.mono(10, weight: .medium)
        updatedLabel.textColor = WalletTheme.dim
        updatedLabel.textAlignment = .right
        updatedLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updatedLabel.adjustsFontSizeToFitWidth = true
        updatedLabel.minimumScaleFactor = 0.8
        nodeStatusLabel.setContentHuggingPriority(.required, for: .horizontal)
        nodeStatusLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        let nodeRow = UIStackView(arrangedSubviews: [nodeDot, nodeStatusLabel, updatedLabel])
        nodeRow.axis = .horizontal
        nodeRow.alignment = .center
        nodeRow.spacing = 8
        renderNodeStatus()

        torProgressView.progressTintColor = tint.accent
        torProgressView.trackTintColor = WalletTheme.dim.withAlphaComponent(0.18)   // only progress is green
        torProgressView.isHidden = true
        
        heightLabel.font = WalletTheme.mono(17, weight: .semibold)
        heightLabel.textColor = WalletTheme.text
        heightLabel.text = "BLOCK ···"
        
        syncLabel.font = WalletTheme.mono(11, weight: .semibold)
        syncLabel.textColor = WalletTheme.dim
        syncLabel.text = "SYNC ···"
        syncProgressView.progressTintColor = tint.accent
        syncProgressView.trackTintColor = WalletTheme.dim.withAlphaComponent(0.18)   // only progress is green
        syncProgressView.progress = 0

        clockLabel.font = WalletTheme.mono(10, weight: .semibold)
        clockLabel.textColor = WalletTheme.dim
        clockLabel.numberOfLines = 0
        clockLabel.isHidden = true
        
        let card = WalletTheme.cardView([captionRow, nodeLabel, nodeRow, torRow, torProgressView, heightLabel, syncLabel, syncProgressView, clockLabel],
                                        tint: tint, spacing: 8)
        if let stack = card.subviews.first as? UIStackView {
            stack.setCustomSpacing(10, after: torProgressView)
            stack.setCustomSpacing(4, after: syncLabel)
        }
        // Tap: the getblockchaininfo response already loaded for this card.
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nodeCardTapped(_:))))
        card.accessibilityTraits = .button
        card.accessibilityHint = "Shows the raw getblockchaininfo response"
        return card
    }
    
    // MARK: - Rendering

    /// Node status row. The timestamp reads "UPDATED …" while connected, otherwise
    /// "LAST CONNECTED …" (or nothing if this node has never answered).
    private func renderNodeStatus() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.renderNodeStatus() }
            return
        }
        let (text, color): (String, UIColor) = {
            switch nodeState {
            case .connected: return ("NODE CONNECTED", WalletTheme.text)
            case .connecting: return ("CONNECTING…", WalletTheme.pending)
            case .unreachable: return ("NODE UNREACHABLE", WalletTheme.danger)
            case .noNode: return ("NO NODE", WalletTheme.dim)
            case .idle: return ("NOT CONNECTED", WalletTheme.dim)
            }
        }()
        nodeStatusLabel.text = text
        nodeStatusLabel.textColor = color
        nodeDot.backgroundColor = nodeState == .connected ? tint.accent : color

        guard nodeState != .noNode, let lastUpdated = lastUpdated else {
            updatedLabel.text = nil
            return
        }
        let ago = Self.relativeAgo(lastUpdated)
        updatedLabel.text = nodeState == .connected ? "UPDATED \(ago)" : "LAST CONNECTED \(ago)"
    }

    /// "JUST NOW", "45S AGO", "12M AGO", "3H AGO", "2D AGO".
    private static func relativeAgo(_ date: Date) -> String {
        let seconds = max(0, Int(Date().timeIntervalSince(date)))
        switch seconds {
        case ..<10: return "JUST NOW"
        case ..<60: return "\(seconds)S AGO"
        case ..<3600: return "\(seconds / 60)M AGO"
        case ..<86400: return "\(seconds / 3600)H AGO"
        default: return "\(seconds / 86400)D AGO"
        }
    }

    /// Compares the device clock with the chain tip's timestamp. Generous on purpose: a
    /// block's time is set by its miner (consensus allows up to 2h ahead of network time)
    /// and blocks are ~10 min apart, so only clear mismatches are flagged.
    /// - tip more than ~2h15m in the FUTURE: impossible for a valid tip with a correct
    ///   device clock, so the device clock is behind.
    /// - mainnet tip older than 3h while not in IBD: node stuck or device clock ahead.
    /// Falls back to `mediantime` (lags ~1h) when `time` isn't reported, with 1h more slack.
    private func renderClockCheck(_ info: BlockchainInfo) {
        let raw = info.rawData
        let usesMedian = raw["time"] == nil
        guard !info.initialblockdownload, info.chain != "regtest",
              let tipTime = ((raw["time"] ?? raw["mediantime"]) as? NSNumber)?.doubleValue, tipTime > 0 else {
            clockLabel.isHidden = true
            return
        }
        let age = Date().timeIntervalSince1970 - tipTime
        let slack: TimeInterval = usesMedian ? 3600 : 0
        let tipAge = age < 0 ? "TIP IN THE FUTURE" : "TIP " + Self.relativeAgo(Date(timeIntervalSince1970: tipTime))

        clockLabel.isHidden = false
        if age < -(2 * 3600 + 15 * 60) {
            clockLabel.text = "DEVICE CLOCK BEHIND? · \(tipAge)"
            clockLabel.textColor = WalletTheme.pending
        } else if info.chain == "main" {
            if age <= 3 * 3600 + slack {
                clockLabel.text = "TIME IN SYNC · \(tipAge)"
                clockLabel.textColor = WalletTheme.dim
            } else {
                clockLabel.text = "\(tipAge.replacingOccurrences(of: " AGO", with: " OLD")) · CHECK CLOCK"
                clockLabel.textColor = WalletTheme.pending
            }
        } else {
            // Test networks: irregular blocks, no verdict beyond the future check.
            clockLabel.text = tipAge
            clockLabel.textColor = WalletTheme.dim
        }
    }

    private static func lastUpdatedKey(_ id: UUID) -> String { "nodeLastUpdated.\(id.uuidString)" }

    /// Shows the stored "last connected" time for `node` (before it answers this session).
    private func loadLastUpdated(for node: NodeStruct) {
        lastUpdated = node.id.flatMap { UserDefaults.standard.object(forKey: Self.lastUpdatedKey($0)) as? Date }
        renderNodeStatus()
    }

    /// A successful RPC response from the active node: it's connected, and "UPDATED" moves
    /// to now. Called for every response in the home screen's load chain, so the final
    /// stamp is when the screen finished loading (fee estimate, the last call).
    private func noteRPCSuccess() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.noteRPCSuccess() }
            return
        }
        let now = Date()
        lastUpdated = now
        if let id = activeNode?.id ?? existingNodeID {
            UserDefaults.standard.set(now, forKey: Self.lastUpdatedKey(id))
        }
        nodeState = .connected
    }
    
    /// Fills every view from the latest RPC responses. "···" = loading, "—" = no data.
    private func renderDashboard() {
        let loading = "···"
        let none = "—"
        
        // Node card
        if let info = blockchainInfo {
            heightLabel.text = "BLOCK \(info.blockheight.withCommas)"
            let progress = Float(max(0, min(1, info.verificationprogress)))
            syncProgressView.setProgress(progress, animated: true)
            let verified = info.progressString == "Fully verified"
            syncLabel.text = info.progressString.uppercased() + (info.initialblockdownload ? " · IBD" : "")
            syncLabel.textColor = verified ? WalletTheme.dim : WalletTheme.pending
            syncProgressView.progressTintColor = verified ? tint.accent.withAlphaComponent(0.55) : WalletTheme.pending
            chainBadge.text = Self.chainName(info.chain)
            chainBadge.isHidden = false
            renderClockCheck(info)
        } else {
            clockLabel.isHidden = true
            heightLabel.text = "BLOCK " + (showBlockchainInfoSpinner ? loading : none)
            syncLabel.text = "SYNC " + (showBlockchainInfoSpinner ? loading : none)
            syncLabel.textColor = WalletTheme.dim
            syncProgressView.setProgress(0, animated: false)
            chainBadge.isHidden = true
        }
        
        // Tiles
        if let peers = peerInfo {
            peersTile.set(value: "\(peers.outgoingCount) / \(peers.incomingCount)", detail: "out / in ›")
        } else {
            peersTile.set(value: showPeerInfoSpinner ? loading : none, detail: "out / in")
        }
        
        if let mempool = mempoolInfo {
            mempoolTile.set(value: mempool.mempoolCount.withCommas, detail: "transactions")
        } else {
            mempoolTile.set(value: showMempoolInfoSpinner ? loading : none, detail: "transactions")
        }
        
        if let fee = feeInfo {
            feeTile.set(value: fee.feeRate, detail: "your target")
        } else {
            feeTile.set(value: showFeeInfoSpinner ? loading : none, detail: "your target")
        }
        
        if let uptime = uptimeInfo {
            uptimeTile.set(value: "\(uptime.uptime / 86400)d \((uptime.uptime % 86400) / 3600)h", detail: "since restart")
        } else {
            uptimeTile.set(value: showUpTimeSpinner ? loading : none, detail: "since restart")
        }
        
        if let mining = miningInfo {
            hashrateTile.set(value: "\(mining.hashrate) EH/s", detail: "network")
        } else {
            hashrateTile.set(value: showMiningInfoSpinner ? loading : none, detail: "network")
        }
        
        if let info = blockchainInfo {
            difficultyTile.set(value: "\(Int(info.difficulty / 1000000000000).withCommas) T", detail: "trillion")
            storageTile.set(value: info.size, detail: info.pruned ? "pruned node" : "full node")
        } else {
            difficultyTile.set(value: showBlockchainInfoSpinner ? loading : none, detail: "trillion")
            storageTile.set(value: showBlockchainInfoSpinner ? loading : none, detail: "on disk")
        }
        
        if let network = networkInfo {
            coreTile.set(value: network.version, detail: network.torReachable ? "onion service on" : "onion service off")
        } else {
            coreTile.set(value: showNetworkInfoSpinner ? loading : none, detail: "version")
        }
    }
    
    private static func chainName(_ chain: String) -> String {
        switch chain {
        case "main": return "MAINNET"
        case "test": return "TESTNET"
        case "testnet4": return "TESTNET4"
        case "signet": return "SIGNET"
        case "regtest": return "REGTEST"
        default: return chain.uppercased()
        }
    }
    
    // MARK: - Tile actions (raw RPC responses)
    
    @objc private func peersTapped() {
        guard peerInfo != nil else { return }
        impact()
        chevronButtonTapped()
    }
    
    @objc private func mempoolTapped() {
        guard let mempoolInfo = mempoolInfo else { return }
        showModal(data: mempoolInfo.rawData, title: "getmempoolinfo")
    }
    
    @objc private func feeTapped() {
        showAlert(vc: self, title: "Fee rate", message: "The fee rate Bitcoin Core estimates for your confirmation target. Change the target when sending a transaction.")
    }
    
    @objc private func uptimeTapped() {
        guard let uptimeInfo = uptimeInfo else { return }
        showModal(data: ["uptime": uptimeInfo.uptime], title: "uptime")
    }
    
    @objc private func miningTapped() {
        guard let miningInfo = miningInfo else { return }
        showModal(data: miningInfo.rawData, title: "getmininginfo")
    }
    
    @objc private func nodeCardTapped(_ gesture: UITapGestureRecognizer) {
        guard blockchainInfo != nil, let card = gesture.view else { return }
        impact()
        UIView.animate(withDuration: 0.08, animations: { card.alpha = 0.6 }) { _ in
            UIView.animate(withDuration: 0.15) { card.alpha = 1 }
        }
        blockchainTapped()
    }

    @objc private func blockchainTapped() {
        guard let blockchainInfo = blockchainInfo else { return }
        showModal(data: blockchainInfo.rawData, title: "getblockchaininfo")
    }
    
    @objc private func networkTapped() {
        guard let networkInfo = networkInfo else { return }
        showModal(data: networkInfo.rawData, title: "getnetworkinfo")
    }
    
    // If XFP was not saved (which seems to be possible currently) we need it to identify potential signers.
    private func ensureXfpSaved() {
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] encryptedSigners in
            guard let _ = self else { return }
            
            guard let encryptedSigners = encryptedSigners else { return }
            
            guard encryptedSigners.count > 0 else { return }
            
            for encryptedSigner in encryptedSigners {
                let signerStruct = SignerStruct(dictionary: encryptedSigner)
                
                guard signerStruct.xfp == nil else { return }
                
                var passphrase = ""
                
                if let encryptedPassphrase = signerStruct.passphrase,
                   let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase),
                   let string = decryptedPassphrase.utf8String {
                    passphrase = string
                }
                                
                // Only fires off if account xpubs had not been saved before.
                if var encryptedWords = signerStruct.words,
                   var decryptedSigner = Crypto.decrypt(encryptedWords),
                   var words = decryptedSigner.utf8String,
                   let mkMain = Keys.masterKey(words: words, coinType: "0", passphrase: passphrase),
                   let xfp = Keys.fingerprint(masterKey: mkMain),
                   let encryptedXfp = Crypto.encrypt(xfp.utf8) {
                                        
                    defer {
                        encryptedWords.secureZero()
                        decryptedSigner.secureZero()
                        words.secureWipe()
                        passphrase.secureWipe()
                    }
                    
                    CoreDataService.update(id: signerStruct.id, keyToUpdate: "xfp", newValue: encryptedXfp, entity: .signers) { _ in }
                }
            }
        }
    }
    
    private func startTor() {
        if mgr?.state != .started && mgr?.state != .connected  {
            showTorBootstrapping(progress: 0)
            
            if KeyChain.getData("UnlockPassword") != nil {
                if isUnlocked {
                    mgr?.start(delegate: self)
                }
            } else {
                mgr?.start(delegate: self)
                if activeNode != nil {
                    refreshNode()
                    loadTable()
                    removeTorStatus()
                } else {
                    removeLoader()
                    alertToAddNode()
                }
            }
        }
    }
    
    /// No active node: show the "Connect a node" sheet. `force` for explicit refreshes,
    /// otherwise it stays away for the session once dismissed with "Not now".
    private func alertToAddNode(force: Bool = false) {
        nodeState = .noNode
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Onboarding already covers connecting a node.
            guard !OnboardingViewController.consumeNoNodeAlertSuppression(force: force) else { return }
            OnboardingViewController.presentAddNode(from: self.tabBarController ?? self, force: force)
        }
    }
    
        
    @objc private func showOnboarding() {
        OnboardingViewController.replay(from: tabBarController ?? self)
    }

    @IBAction func lockAction(_ sender: Any) {
        if KeyChain.getData("UnlockPassword") != nil {
            showUnlockScreen()
        } else {
            DispatchQueue.main.async {[weak self] in
                guard let self = self else { return }
                
                self.performSegue(withIdentifier: "segueToCreateUnlockPassword", sender: self)
            }
        }
    }
    
    func addNavBarSpinner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.dataRefresher = UIBarButtonItem(customView: self.spinner)
            self.navigationItem.setRightBarButton(self.dataRefresher, animated: true)
            self.spinner.alpha = 1
            self.spinner.startAnimating()
        }
    }
    
    @objc func startTorFromAppDelegate() {
        startTor()
    }
    
    @objc func refreshNode() {
        addNavBarSpinner()
        refreshTable()
        updateTorStatus()
        
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node else {
                removeLoader()
                alertToAddNode(force: true)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshTable()
                self.existingNodeID = nil
                
            }
            
            self.initialLoad = false
            self.loadNode(node: node)
        }
    }
    
    private func loadTable() {
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node else {
                alertToAddNode()
                return
            }
            self.initialLoad = false
            self.loadNode(node: node)
        }
    }
    
    private func loadNode(node: NodeStruct) {
        if node.id != existingNodeID || nodeState == .idle || nodeState == .noNode {
            loadLastUpdated(for: node)
        }
        if initialLoad {
            existingNodeID = node.id
            loadTableData()
        } else {
            checkIfNodesChanged(newNodeId: node.id!)
        }
        DispatchQueue.main.async { [weak self] in
            self?.nodeLabel.text = node.label
        }
    }
    
    private func checkIfNodesChanged(newNodeId: UUID) {
        if newNodeId != existingNodeID {
            loadTableData()
        }
    }
    
    private func refreshTable() {
        existingNodeID = nil
        blockchainInfo = nil
        mempoolInfo = nil
        uptimeInfo = nil
        peerInfo = nil
        feeInfo = nil
        networkInfo = nil
        miningInfo = nil
        reloadTable()
    }
    
    @objc func refreshData(_ sender: Any) {
        refreshTable()
        refreshDataNow()
    }
    
    func refreshDataNow() {
        addNavBarSpinner()
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node else {
                removeLoader()
                alertToAddNode(force: true)
                return
            }
            self.activeNode = node
            self.loadNode(node: node)
        }
    }
    
    func showUnlockScreen() {
        if KeyChain.getData("UnlockPassword") != nil {
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "lockScreen", sender: self)
            }
        }
    }
    
    // MARK: - Data
    
    func loadTableData() {
        nodeState = .connecting
        showBlockchainInfoSpinner = true
        reloadTable()
        
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            
            guard let blockchainInfo = blockchainInfo else {
                
                nodeState = .unreachable
                showBlockchainInfoSpinner = false
                reloadTable()
                
                guard let message = message else {
                    showAlert(vc: self, title: "", message: "unknown error")
                    return
                }
                
                showAlert(vc: self, title: "", message: message)
                
                removeLoader()
                
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                impact()
                initialLoad = false
                noteRPCSuccess()
                self.blockchainInfo = blockchainInfo
                showBlockchainInfoSpinner = false
                reloadTable()
                getNetworkInfo()
            }
        }
    }
    
    private func getPeerInfo() {
        showPeerInfoSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.getPeerInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showPeerInfoSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                peerInfo = response
                noteRPCSuccess()
                showPeerInfoSpinner = false
                reloadTable()
                getMiningInfo()
            }
        }
    }
    
    private func getNetworkInfo() {
        showNetworkInfoSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.getNetworkInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showNetworkInfoSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                networkInfo = NetworkInfo(dictionary: response)
                noteRPCSuccess()
                showNetworkInfoSpinner = false
                reloadTable()
                getPeerInfo()
            }
        }
    }
    
    private func getMiningInfo() {
        showMiningInfoSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.getMiningInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showMiningInfoSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.miningInfo = MiningInfo(dictionary: response)
                self.noteRPCSuccess()
                showMiningInfoSpinner = false
                reloadTable()
                self.getUptime()
            }
        }
    }
    
    private func getUptime() {
        showUpTimeSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.getUptime { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showUpTimeSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.uptimeInfo = Uptime(dictionary: response)
                self.noteRPCSuccess()
                showUpTimeSpinner = false
                reloadTable()
                self.getMempoolInfo()
            }
        }
    }
    
    private func getMempoolInfo() {
        showMempoolInfoSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.getMempoolInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showMempoolInfoSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            self.mempoolInfo = MempoolInfo(dictionary: response)
            self.noteRPCSuccess()
            showMempoolInfoSpinner = false
            reloadTable()
            self.getFeeInfo()
        }
    }
    
    private func getFeeInfo() {
        showFeeInfoSpinner = true
        reloadTable()
        
        NodeLogic.sharedInstance.estimateSmartFee { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.showFeeInfoSpinner = false
                self.reloadTable()
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            self.feeInfo = FeeInfo(dictionary: response)
            self.noteRPCSuccess()
            showFeeInfoSpinner = false
            reloadTable()
            self.removeLoader()
        }
    }
    
    //MARK: User Interface
    
    func removeLoader() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            refreshControl.endRefreshing()
            spinner.stopAnimating()
            spinner.alpha = 0
            refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            refreshButton.tintColor = tint.accent
            navigationItem.setRightBarButton(refreshButton, animated: true)
        }
    }
    
    /// Redraws the dashboard (name kept from the old table-based screen).
    func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            self?.renderDashboard()
        }
    }
    
    private func setFeeTarget() {
        if ud.object(forKey: "feeTarget") == nil {
            ud.set(432, forKey: "feeTarget")
        }
    }
    
    private func timeStamp() {
        if KeyChain.getData(timestampData) == nil {
            if let currentDate = Data(base64Encoded: currentDate()) {
                let _ = KeyChain.set(currentDate, forKey: timestampData)
            }
        }
    }
    
    private func isNotAnOnion() -> Bool {
        guard let encAddress = self.activeNode?.onionAddress, let decryptedAddress = Crypto.decrypt(encAddress), let addressText = decryptedAddress.utf8String, !addressText.contains(".onion") else {
            return false
        }
        return true
    }
    
    /// Tor line of the node card: connected (accent), disconnected (red), or starting.
    private func updateTorStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let state = mgr?.state
            if state == .connected {
                torStatusLabel.text = "TOR CONNECTED"
                torStatusLabel.textColor = WalletTheme.dim
                torDot.backgroundColor = tint.accent
            } else if state == .stopped {
                if nodeState == .connected { nodeState = .idle }
                torStatusLabel.text = "TOR DISCONNECTED"
                torStatusLabel.textColor = WalletTheme.danger
                torDot.backgroundColor = WalletTheme.danger
            } else if state == .started || state == .refreshing {
                if torProgressView.isHidden {
                    torStatusLabel.text = "TOR STARTING…"
                }
                torStatusLabel.textColor = WalletTheme.pending
                torDot.backgroundColor = WalletTheme.pending
            }
        }
    }
    
    private func showTorBootstrapping(progress: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            torProgressView.isHidden = false
            torProgressView.setProgress(Float(progress) / 100, animated: progress > 0)
            torStatusLabel.text = "TOR BOOTSTRAPPING \(progress)%"
            torStatusLabel.textColor = WalletTheme.pending
            torDot.backgroundColor = WalletTheme.pending
        }
    }
    
    private func removeTorStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.torProgressView.isHidden = true
            self?.updateTorStatus()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "segueToPeerInfo":
            guard let vc = segue.destination as? PeersDetailTableViewController else { fallthrough }
            
            vc.peerResponse = peerInfo
            
        case "lockScreen":
            guard let vc = segue.destination as? LogInViewController else { fallthrough }
            
            vc.onDoneBlock = { [weak self] in
                guard let self = self else { return }
                
                self.isUnlocked = true                
                
                if self.mgr?.state != .started && self.mgr?.state != .connected  {
                    self.mgr?.start(delegate: self)
                    
                    if let node = self.activeNode {
                        if isNotAnOnion() {
                            loadNode(node: node)
                        }
                    } else {
                        self.alertToAddNode()
                    }
                }
            }
        default:
            break
        }
    }
    
    //MARK: Helpers
    func firstTimeHere() -> Bool {
        return FirstTime.firstTimeHere()
    }
    
    private func chevronButtonTapped() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToPeerInfo", sender: self)
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        impact()
        let modalVC = TextModalViewController(data: data, viewTitle: title)
        let nav = UINavigationController(rootViewController: modalVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        present(nav, animated: true)
    }
}

extension MainMenuViewController: OnionManagerDelegate {
    
    func torConnProgress(_ progress: Int) {
        showTorBootstrapping(progress: progress)
    }
    
    func torConnFinished() {
        if let _ = activeNode {
            loadTable()
        } else {
            removeLoader()
        }
        
        removeTorStatus()
        updateTorStatus()
        timeStamp()
    }
    
    func torConnDifficulties() {
        displayAlert(viewController: self, isError: true, message: "We are having issues connecting tor.")
        removeTorStatus()
        updateTorStatus()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let _ = activeNode {
                loadTable()
            }
        }
    }
}

extension MainMenuViewController: UINavigationControllerDelegate {}

// MARK: - Dashboard tile

/// One stat on the home dashboard: caption with icon, a big value and a detail line.
/// Tappable (UIControl); dims while highlighted.
final class DashboardTile: UIControl {
    private let captionLabel = UILabel()
    private let iconView = UIImageView()
    private let valueLabel = UILabel()
    private let detailLabel = UILabel()
    private let tint: WalletTheme.Tint

    init(caption: String, symbol: String, tint: WalletTheme.Tint = .home) {
        self.tint = tint
        super.init(frame: .zero)

        backgroundColor = WalletTheme.card
        layer.borderWidth = 1
        layer.borderColor = tint.line.cgColor
        layer.cornerRadius = WalletTheme.radius

        captionLabel.text = caption
        captionLabel.font = WalletTheme.mono(10, weight: .bold)
        captionLabel.textColor = WalletTheme.dim
        iconView.image = UIImage(systemName: symbol)
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        iconView.tintColor = tint.accent
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        valueLabel.font = WalletTheme.mono(18, weight: .bold)
        valueLabel.textColor = WalletTheme.text
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.5
        valueLabel.text = "—"

        detailLabel.font = WalletTheme.mono(10)
        detailLabel.textColor = WalletTheme.dim
        detailLabel.adjustsFontSizeToFitWidth = true
        detailLabel.minimumScaleFactor = 0.7

        let top = UIStackView(arrangedSubviews: [captionLabel, UIView(), iconView])
        top.axis = .horizontal
        top.alignment = .center

        let stack = UIStackView(arrangedSubviews: [top, valueLabel, detailLabel])
        stack.axis = .vertical
        stack.spacing = 6
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 86)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(value: String, detail: String) {
        valueLabel.text = value
        detailLabel.text = detail
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }
}
