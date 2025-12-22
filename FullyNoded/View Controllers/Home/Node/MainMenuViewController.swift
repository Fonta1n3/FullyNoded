//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit


class MainMenuViewController: UIViewController {
    
    weak var mgr = TorClient.sharedInstance
    let ud = UserDefaults.standard
    @IBOutlet var mainMenu: UITableView!
    var nodes = [[String:Any]]()
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
    
    var showBlockchainInfoSpinner = false
    var showNetworkInfoSpinner = false
    var showFeeInfoSpinner = false
    var showMempoolInfoSpinner = false
    var showMiningInfoSpinner = false
    var showPeerInfoSpinner = false
    var showUpTimeSpinner = false
    
    let sectionSpinner = UIActivityIndicatorView(style: .medium)
            
    @IBOutlet weak var torStatusLabel: UILabel!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var torProgressLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    private enum Section: Int {
        case blockchainInfo
        case networkInfo
        case peerInfo
        case miningInfo
        case upTime
        case mempoolInfo
        case feeInfo
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        UserDefaults.standard.set(UIDevice.modelName, forKey: "modelName")
        UIApplication.shared.isIdleTimerDisabled = true
        torStatusLabel.alpha = 0
        addNavBarSpinner()
        MakeRPCCall.sharedInstance.getActiveNode { [weak self] node in
            guard let self = self else { return }
            guard let node = node  else {
                CoreDataService.retrieveEntity(entityName: .newNodes) { savedNodes in
                    if savedNodes == nil || savedNodes?.count == 0 {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            removeLoader()
                            performSegue(withIdentifier: "segueToFirstTimeHere", sender: self)
                        }
                    }
                }
                return
            }
            activeNode = node
        }
        
        if !Crypto.setupinit() {
            showAlert(vc: self, title: "", message: "There was an error setupinit.")
        }
        mainMenu.delegate = self
        mainMenu.tableFooterView = UIView(frame: .zero)
        mainMenu.layer.cornerRadius = 8
        mainMenu.clipsToBounds = true
        initialLoad = true
        showUnlockScreen()
        setFeeTarget()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNode), name: .refreshNode, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(startTorFromAppDelegate), name: .startTorFromAppDelegate, object: nil)
        refreshControl.addTarget(self, action: #selector(refreshNode), for: UIControl.Event.valueChanged)
        mainMenu.addSubview(refreshControl)
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
    
    private func confirgureTorProgressView() {
        blurView.layer.cornerRadius = 8
        blurView.clipsToBounds = true
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.clear
        blurView.layer.zPosition = 0
        progressView.layer.zPosition = 3
        torProgressLabel.layer.zPosition = 2
        progressView.setNeedsDisplay()
        progressView.setNeedsLayout()
        progressView.layoutIfNeeded()
        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: torProgressLabel.bottomAnchor, constant: 12),
            progressView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 30),
            progressView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -30),
            progressView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
    
    private func startTor() {
        confirgureTorProgressView()
        blurView.isHidden = false
        torProgressLabel.isHidden = false
        progressView.isHidden = false
        
        if mgr?.state != .started && mgr?.state != .connected  {
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
        
    
    @IBAction func showLightningNode(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToLightningNode", sender: self)
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
            self?.headerLabel.text = node.label
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
        DispatchQueue.main.async { [weak self] in
            self?.mainMenu.reloadData()
        }
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
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            if blockchainInfo != nil {
                return 6
            } else {
                return 0
            }
        case 1:
            if networkInfo != nil {
                return 2
            } else {
                return 0
            }
        case 2:
            if peerInfo != nil {
                return 1
            } else {
                return 0
            }
        case 3:
            if miningInfo != nil {
                return 1
            } else {
                return 0
            }
        case 4:
            if uptimeInfo != nil {
                return 1
            } else {
                return 0
            }
        case 5:
            if mempoolInfo != nil {
                return 1
            } else {
                return 0
            }
        case 6:
            if feeInfo != nil {
                return 1
            } else {
                return 0
            }
        default:
            return 0
        }
    }
    
    func blankCell() -> UITableViewCell {
        let cell = UITableViewCell()
        cell.selectionStyle = .none
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        return cell
    }
    
    private func homeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = mainMenu.dequeueReusableCell(withIdentifier: "homeCell", for: indexPath)
        cell.selectionStyle = .none
        let icon = cell.viewWithTag(1) as! UIImageView
        let label = cell.viewWithTag(2) as! UILabel
        
        var chevronButton = cell.contentView.viewWithTag(999) as? UIButton
            if chevronButton == nil {
                chevronButton = UIButton(type: .system)
                chevronButton!.tag = 999
                chevronButton!.translatesAutoresizingMaskIntoConstraints = false
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .default)
                chevronButton!.setImage(UIImage(systemName: "chevron.right", withConfiguration: config), for: .normal)
                chevronButton!.tintColor = .tintColor
                chevronButton!.backgroundColor = .clear
                chevronButton!.layer.cornerRadius = 20
                cell.contentView.addSubview(chevronButton!)
                
                NSLayoutConstraint.activate([
                    chevronButton!.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                    chevronButton!.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
                    chevronButton!.widthAnchor.constraint(equalToConstant: 80),
                    chevronButton!.heightAnchor.constraint(equalToConstant: 36)
                ])
            }
            
            chevronButton!.alpha = 0
            chevronButton!.isHidden = true
        
        switch Section(rawValue: indexPath.section) {
            
        case .blockchainInfo:
            guard let blockchainInfo = blockchainInfo else { return blankCell() }
            
            switch indexPath.row {
            case 0:
                if blockchainInfo.progressString == "Fully verified" {
                    icon.image = UIImage(systemName: "checkmark.seal")
                    icon.tintColor = .tintColor
                } else {
                    icon.image = UIImage(systemName: "exclamationmark.triangle")
                    icon.tintColor = .systemRed
                }
                label.text = blockchainInfo.progressString
                
            case 1:
                icon.tintColor = .tintColor
                label.text = blockchainInfo.network.capitalized + " blockchain"
                icon.image = UIImage(systemName: "bitcoinsign.circle")
                
            case 2:
                icon.tintColor = .tintColor
                if blockchainInfo.pruned {
                    label.text = "Pruned node"
                    icon.image = UIImage(systemName: "rectangle.compress.vertical")
                } else if !blockchainInfo.pruned {
                    label.text = "Full node"
                    icon.image = UIImage(systemName: "rectangle.expand.vertical")
                }
                
            case 3:
                icon.tintColor = .tintColor
                label.text = "Blockheight \(blockchainInfo.blockheight.withCommas)"
                icon.image = UIImage(systemName: "square.stack.3d.up")
                
            case 4:
                icon.tintColor = .tintColor
                label.text = "Blockchain size \(blockchainInfo.size)"
                icon.image = UIImage(systemName: "archivebox")
                
            case 5:
                icon.tintColor = .tintColor
                label.text = "\(blockchainInfo.diffString)"
                icon.image = UIImage(systemName: "slider.horizontal.3")
                
            default:
                break
            }
            
        case .networkInfo:
            guard let networkInfo = networkInfo else { return blankCell() }
                        
            switch indexPath.row {
            case 0:
                icon.tintColor = .tintColor
                label.text = networkInfo.version
                icon.image = UIImage(systemName: "v.circle")
                
            case 1:
                icon.tintColor = .tintColor
                if networkInfo.torReachable {
                    label.text = "Tor hidden service on"
                    icon.image = UIImage(systemName: "wifi")
                    
                } else {
                    label.text = "Tor hidden service off"
                    icon.image = UIImage(systemName: "wifi.slash")
                }
                
            default:
                break
            }
            
        case .peerInfo:
            icon.tintColor = .tintColor
            guard let peerInfo = peerInfo else { return blankCell() }
            
            label.text = "Peers \(peerInfo.outgoingCount) outgoing / \(peerInfo.incomingCount) incoming"
            icon.image = UIImage(systemName: "person.3")
            
            chevronButton!.alpha = 1
            chevronButton!.isHidden = false
            chevronButton!.removeTarget(nil, action: nil, for: .allEvents)
            chevronButton!.addTarget(self, action: #selector(chevronButtonTapped(_:)), for: .touchUpInside)
            
        case .miningInfo:
            icon.tintColor = .tintColor
            guard let miningInfo = miningInfo else { return blankCell() }
                        
            label.text = miningInfo.hashrate + " " + "EH/s mining hashrate"
            icon.image = UIImage(systemName: "speedometer")
            
        case .upTime:
            icon.tintColor = .tintColor
            guard let uptimeInfo = uptimeInfo else { return blankCell() }
            
            label.text = "\(uptimeInfo.uptime / 86400) days \((uptimeInfo.uptime % 86400) / 3600) hours of uptime"
            icon.image = UIImage(systemName: "clock")
            
        case .mempoolInfo:
            icon.tintColor = .tintColor
            guard let mempoolInfo = mempoolInfo else { return blankCell() }
            
            label.text = "\(mempoolInfo.mempoolCount.withCommas) transactions in mempool"
            icon.image = UIImage(systemName: "waveform.path.ecg")
            
        case .feeInfo:
            icon.tintColor = .tintColor
            guard let feeInfo = feeInfo else { return blankCell() }
            
            label.text = feeInfo.feeRate + " " + "fee rate setting"
            icon.image = UIImage(systemName: "percent")
            
        default:
            break
        }
        return cell
    }
    
    private func segueToShowDetail() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "showDetailSegue", sender: self)
        }
    }
        
    func loadTableData() {
        showBlockchainInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            headerLabel.textColor = .secondaryLabel
            mainMenu.reloadSections(IndexSet(arrayLiteral: Section.blockchainInfo.rawValue), with: .none)
        }
        
        OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
            guard let self = self else { return }
            
            guard let blockchainInfo = blockchainInfo else {
                
                showBlockchainInfoSpinner = false
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    mainMenu.reloadSections(IndexSet(arrayLiteral: Section.blockchainInfo.rawValue), with: .none)
                }
                
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
                headerLabel.textColor = .none
                self.blockchainInfo = blockchainInfo
                showBlockchainInfoSpinner = false
                mainMenu.reloadSections(IndexSet(arrayLiteral: Section.blockchainInfo.rawValue), with: .fade)
                getNetworkInfo()
            }
        }
    }
    
    private func getPeerInfo() {
        showPeerInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            mainMenu.reloadSections(IndexSet(arrayLiteral: Section.peerInfo.rawValue), with: .none)
        }
        
        NodeLogic.sharedInstance.getPeerInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                peerInfo = response
                showPeerInfoSpinner = false
                mainMenu.reloadSections(IndexSet(arrayLiteral: Section.peerInfo.rawValue), with: .fade)
                getMiningInfo()
            }
        }
    }
    
    private func getNetworkInfo() {
        showNetworkInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            mainMenu.reloadSections(IndexSet(arrayLiteral: Section.networkInfo.rawValue), with: .fade)
        }
        
        NodeLogic.sharedInstance.getNetworkInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage!)
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                networkInfo = NetworkInfo(dictionary: response)
                showNetworkInfoSpinner = false
                mainMenu.reloadSections(IndexSet(arrayLiteral: Section.networkInfo.rawValue), with: .fade)
                getPeerInfo()
            }
        }
    }
    
    private func getMiningInfo() {
        showMiningInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.miningInfo.rawValue), with: .none)
        }
        
        NodeLogic.sharedInstance.getMiningInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.miningInfo = MiningInfo(dictionary: response)
                showMiningInfoSpinner = false
                self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.miningInfo.rawValue), with: .fade)
                self.getUptime()
            }
        }
    }
    
    private func getUptime() {
        showUpTimeSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.upTime.rawValue), with: .fade)
        }
        
        NodeLogic.sharedInstance.getUptime { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.uptimeInfo = Uptime(dictionary: response)
                showUpTimeSpinner = false
                self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.upTime.rawValue), with: .fade)
                self.getMempoolInfo()
            }
        }
    }
    
    private func getMempoolInfo() {
        showMempoolInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.mempoolInfo.rawValue), with: .none)
        }
        
        NodeLogic.sharedInstance.getMempoolInfo { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.mempoolInfo = MempoolInfo(dictionary: response)
                showMempoolInfoSpinner = false
                self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.mempoolInfo.rawValue), with: .fade)
                self.getFeeInfo()
            }
        }
    }
    
    private func getFeeInfo() {
        showFeeInfoSpinner = true
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.feeInfo.rawValue), with: .none)
        }
        
        NodeLogic.sharedInstance.estimateSmartFee { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.removeLoader()
                showAlert(vc: self, title: "", message: errorMessage ?? "unknown error")
                return
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.feeInfo = FeeInfo(dictionary: response)
                showFeeInfoSpinner = false
                self.mainMenu.reloadSections(IndexSet(arrayLiteral: Section.feeInfo.rawValue), with: .fade)
                self.removeLoader()
            }
        }
    }
    
    //MARK: User Interface
    
    func removeLoader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            refreshControl.endRefreshing()
            spinner.stopAnimating()
            spinner.alpha = 0
            refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(self.refreshData(_:)))
            refreshButton.tintColor = UIColor.systemBlue.withAlphaComponent(1)
            navigationItem.setRightBarButton(self.refreshButton, animated: true)
        }
    }
    
    func reloadTable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            mainMenu.reloadData()
        }
    }
    
    func getNodes(completion: @escaping (([[String:Any]]?)) -> Void) {
        nodes.removeAll()
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            if nodes != nil {
                completion(nodes!)
            } else {
                displayAlert(viewController: self, isError: true, message: "error getting nodes from coredata")
                completion(nil)
            }
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
    
    private func updateTorStatus() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if mgr?.state == .connected {
                torStatusLabel.text = "Tor connected ✓"
                torStatusLabel.textColor = .green
                torStatusLabel.alpha = 1.0
            } else if mgr?.state == .stopped {
                torStatusLabel.text = "Tor disconnected"
                torStatusLabel.textColor = .label
                torStatusLabel.alpha = 1.0
            }
        }
    }
    
    private func removeTorStatus() {
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.isHidden = true
            self?.progressView.isHidden = true
            self?.blurView.isHidden = true
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
    
    @objc private func iconButtonTapped(_ sender: UIButton) {
        let section = sender.tag
        
        switch Section(rawValue: section) {
        case .blockchainInfo:
            guard let blockchainInfo = blockchainInfo else { return }
            
            showModal(data: blockchainInfo.rawData, title: "getblockchaininfo")
        case .networkInfo:
            guard let networkInfo = networkInfo else { return }
            
            showModal(data: networkInfo.rawData, title: "getnetworkinfo")
        case .peerInfo:
            guard let peerInfo = peerInfo else { return }
            
            showModal(data: ["peerInfo": peerInfo.rawData], title: "getpeerinfo")
        case .miningInfo:
            guard let miningInfo = miningInfo else { return }
            
            showModal(data: miningInfo.rawData, title: "getmininginfo")
        case .mempoolInfo:
            guard let mempoolInfo = mempoolInfo else { return }
            
            showModal(data: mempoolInfo.rawData, title: "getmempoolinfo")
        default:
            break
        }
    }
    
    @objc private func chevronButtonTapped(_ sender: UIButton) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            performSegue(withIdentifier: "segueToPeerInfo", sender: self)
        }
    }
    
    private func showModal(data: [String: Any], title: String) {
        let modalVC = TextModalViewController(data: data, viewTitle: title)
        let nav = UINavigationController(rootViewController: modalVC)
        nav.modalPresentationStyle = .fullScreen
        nav.modalTransitionStyle = .coverVertical
        present(nav, animated: true)
    }
}

// MARK: Helpers

extension MainMenuViewController {
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .blockchainInfo:
            return "Blockchain info"
        case .networkInfo:
            return "Network info"
        case .peerInfo:
            return "Peer info"
        case .miningInfo:
            return "Mining info"
        case .upTime:
            return "Up time"
        case .mempoolInfo:
            return "Mempool info"
        case .feeInfo:
            return "Fee info"
        }
    }
    
}

extension MainMenuViewController: OnionManagerDelegate {
    
    func torConnProgress(_ progress: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let progressFloat = Float(Double(progress) / 100.0)
            progressView.setProgress(progressFloat, animated: true)
            torProgressLabel.text = "Tor bootstrapping \(progress)% complete"
        }
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

extension MainMenuViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch Section(rawValue: indexPath.section) {
        case .blockchainInfo:
            if blockchainInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .networkInfo:
            if networkInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .peerInfo:
            if peerInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .miningInfo:
            if miningInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .upTime:
            if uptimeInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .mempoolInfo:
            if mempoolInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        case .feeInfo:
            if feeInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
            
        default:
            return blankCell()
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 20)
        
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        textLabel.textColor = .quaternaryLabel
        
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .light, scale: .default)
        
        let iconImage = UIImage(systemName: "info.circle", withConfiguration: config)
        let iconButton = UIButton(type: .system)
        iconButton.translatesAutoresizingMaskIntoConstraints = false
        iconButton.setImage(iconImage, for: .normal)
        iconButton.tintColor = .tertiaryLabel
        iconButton.backgroundColor = .clear
        iconButton.layer.cornerRadius = 20
        iconButton.addTarget(self, action: #selector(iconButtonTapped(_:)), for: .touchUpInside)
        iconButton.tag = section
        
        switch section {
        case 0:
            textLabel.frame = CGRect(x: 0, y: 16, width: 300, height: 20)
        default:
            textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 20)
        }
        
        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
            
            switch section {
            case .blockchainInfo:
                if blockchainInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showBlockchainInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: 4, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
            case .networkInfo:
                if networkInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showNetworkInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
            case .feeInfo:
                if feeInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showFeeInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
                iconButton.alpha = 0
            case .mempoolInfo:
                if mempoolInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showMempoolInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
            case .miningInfo:
                if miningInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showMiningInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
            case .peerInfo:
                if peerInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showPeerInfoSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
            case .upTime:
                if uptimeInfo != nil {
                    textLabel.textColor = .secondaryLabel
                    iconButton.tintColor = .tintColor
                }
                if showUpTimeSpinner {
                    spinner.stopAnimating()
                    textLabel.textColor = .tertiaryLabel
                    sectionSpinner.frame = CGRect(x: mainMenu.frame.maxX - 50, y: -14, width: 44, height: 44)
                    sectionSpinner.startAnimating()
                } else {
                    sectionSpinner.stopAnimating()
                }
                iconButton.alpha = 0
            }
        }
        
        header.addSubview(textLabel)
        header.addSubview(iconButton)
        
        NSLayoutConstraint.activate([
            iconButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            iconButton.centerYAnchor.constraint(equalTo: textLabel.centerYAnchor),
            iconButton.widthAnchor.constraint(equalToConstant: 30),
            iconButton.heightAnchor.constraint(equalToConstant: 30)
        ])
        
        header.addSubview(sectionSpinner)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch section {
        case 0:
            return 40
        default:
            return 25
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
}

extension MainMenuViewController: UITableViewDataSource {}

extension MainMenuViewController: UINavigationControllerDelegate {}

