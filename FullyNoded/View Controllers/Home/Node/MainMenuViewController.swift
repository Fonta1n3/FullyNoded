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
        
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node  else {
                guard  UserDefaults.standard.value(forKey: "beenHere") == nil else { return }
                
                CoreDataService.retrieveEntity(entityName: .newNodes) { savedNodes in
                    if savedNodes == nil || savedNodes?.count == 0 {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            removeLoader()
                            performSegue(withIdentifier: "segueToFirstTimeHere", sender: self)
                            UserDefaults.standard.set(true, forKey: "beenHere")
                        }
                    }
                }
                return
            }
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
        nodeLabel.textColor = tint.accent
        nodeLabel.adjustsFontSizeToFitWidth = true
        nodeLabel.minimumScaleFactor = 0.6
        nodeLabel.text = "—"
        
        chainBadge.font = WalletTheme.mono(11, weight: .bold)
        chainBadge.textColor = tint.accent
        chainBadge.layer.borderWidth = 1
        chainBadge.layer.borderColor = tint.line.cgColor
        chainBadge.isHidden = true
        chainBadge.setContentHuggingPriority(.required, for: .horizontal)
        chainBadge.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        let captionRow = UIStackView(arrangedSubviews: [WalletTheme.caption("> NODE", tint: tint), UIView(), chainBadge])
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
        
        torProgressView.progressTintColor = tint.accent
        torProgressView.trackTintColor = tint.line
        torProgressView.isHidden = true
        
        heightLabel.font = WalletTheme.mono(17, weight: .semibold)
        heightLabel.textColor = WalletTheme.text
        heightLabel.text = "BLOCK ···"
        
        syncLabel.font = WalletTheme.mono(11, weight: .semibold)
        syncLabel.textColor = WalletTheme.dim
        syncLabel.text = "SYNC ···"
        syncProgressView.progressTintColor = tint.accent
        syncProgressView.trackTintColor = tint.line
        syncProgressView.progress = 0
        
        let card = WalletTheme.cardView([captionRow, nodeLabel, torRow, torProgressView, heightLabel, syncLabel, syncProgressView],
                                        tint: tint, spacing: 8)
        if let stack = card.subviews.first as? UIStackView {
            stack.setCustomSpacing(10, after: torProgressView)
            stack.setCustomSpacing(4, after: syncLabel)
        }
        return card
    }
    
    // MARK: - Rendering
    
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
            syncLabel.textColor = verified ? tint.accent : WalletTheme.pending
            syncProgressView.progressTintColor = verified ? tint.accent : WalletTheme.pending
            chainBadge.text = Self.chainName(info.chain)
            chainBadge.isHidden = false
        } else {
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
    
    private func alertToAddNode() {
        showAlert(vc: self, title: "No active node.", message: "Navigate to Settings > Node Manager to add or activate a node.")
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
                alertToAddNode()
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
                alertToAddNode()
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
        showBlockchainInfoSpinner = true
        reloadTable()
        
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            
            guard let blockchainInfo = blockchainInfo else {
                
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
                torStatusLabel.textColor = tint.accent
                torDot.backgroundColor = tint.accent
            } else if state == .stopped {
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
                        showAlert(vc: self, title: "", message: "No active node, navigate to Settings > Node Manager to add a node or activate one.")
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
