//
//  MainMenuViewController.swift
//  BitSense
//
//  Created by Peter on 08/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class MainMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, OnionManagerDelegate {
    
    weak var mgr = TorClient.sharedInstance
    let backView = UIView()
    let ud = UserDefaults.standard
    var command = ""
    @IBOutlet var mainMenu: UITableView!
    var connectingView = ConnectingView()
    var nodes = [[String:Any]]()
    var activeNode:[String:Any]?
    var existingNodeID:UUID!
    var initialLoad = false
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var viewHasLoaded = false
    var nodeLabel = ""
    var detailImage = UIImage()
    var detailImageTint = UIColor()
    var detailHeaderText = ""
    var detailSubheaderText = ""
    var detailTextDescription = ""
    var host = ""
    var blockchainInfo:BlockchainInfo!
    var peerInfo:PeerInfo!
    var networkInfo:NetworkInfo!
    var miningInfo:MiningInfo!
    var mempoolInfo:MempoolInfo!
    var uptimeInfo:Uptime!
    var feeInfo:FeeInfo!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var torProgressLabel: UILabel!
    
    private enum Section: Int {
        case verificationProgress
        case totalSupply
        case nodeVersion
        case blockchainNetwork
        case peerConnections
        case blockchainState
        case miningHashrate
        case currentBlockHeight
        case miningDifficulty
        case blockchainSizeOnDisc
        case memPool
        case feeRate
        case p2pHiddenService
        case nodeUptime
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainMenu.delegate = self
        mainMenu.alpha = 0
        mainMenu.tableFooterView = UIView(frame: .zero)
        initialLoad = true
        viewHasLoaded = false
        addNavBarSpinner()
        showUnlockScreen()
        setFeeTarget()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNode), name: .refreshNode, object: nil)
        torProgressLabel.layer.zPosition = 1
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            addlaunchScreen()
            firstTimeHere() { [unowned vc = self] success in
                if !success {
                    displayAlert(viewController: vc, isError: true, message: "there was a critical error setting your devices encryption key, please delete and reinstall the app")
                } else {
                    if vc.mgr?.state != .started && vc.mgr?.state != .connected  {
                        displayAlert(viewController: self, isError: false, message: "Tor is bootstrapping, please wait")
                        vc.mgr?.start(delegate: self)
                    }
                }
            }
        }
    }
    
    @IBAction func showRemoteControl(_ sender: Any) {
        #if targetEnvironment(macCatalyst)
            // Code specific to Mac.
            if activeNode != nil {
                let nodeStruct = NodeStruct(dictionary: activeNode!)
                var prefix = "btcrpc"
                if nodeStruct.isLightning {
                    prefix = "clightning-rpc"
                }
                
                func decryptedValue(_ encryptedValue: Data) -> String? {
                    var decryptedValue = ""
                    Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                        if decryptedData != nil {
                            decryptedValue = decryptedData!.utf8
                        }
                    }
                    return decryptedValue
                }
                
                guard let address = decryptedValue(nodeStruct.onionAddress!) else { return }
                guard let rpcusername = decryptedValue(nodeStruct.rpcuser!) else { return }
                guard let rpcpassword = decryptedValue(nodeStruct.rpcpassword!) else { return }
                let macName = UIDevice.current.name
                
                if address.contains("127.0.0.1") || address.contains("localhost") || address.contains(macName) {
                    var hostname = mgr?.hostname()
                    if hostname != nil {
                        hostname = hostname?.replacingOccurrences(of: "\n", with: "")
                        DispatchQueue.main.async { [weak self] in
                            self?.host = "\(prefix)://\(rpcusername):\(rpcpassword)@\(hostname!):11221/?label=\(nodeStruct.label.replacingOccurrences(of: " ", with: "%20"))"
                            self?.performSegue(withIdentifier: "segueToRemoteControl", sender: self)
                        }
                    } else {
                        showAlert(vc: self, title: "Ooops", message: "There was an error getting your hostname for remote connection... Please make sure you are connected to the internet and that Tor successfully bootstrapped.")
                    }
                } else {
                    showAlert(vc: self, title: "Ooops", message: "This feature can only be used with nodes which are running on the same computer as Fully Noded - Desktop.\n\nTo take advantage of this feature just download Bitcoin Core and run it.\n\nThen add your local node to Fully Noded - Desktop using 127.0.0.1:8332 as the address.\n\nYou can then tap this button to get a QR code which will allow you to connect your node via your iPhone or iPad on the mobile app.")
                }
            }

        #else
            // Code to exclude from Mac.
            showAlert(vc: self, title: "Ooops", message: "This is a macOS feature only, when you use Fully Noded - Desktop, it has the ability to display a QR code you can scan with your iPhone or iPad to connect to your node remotely.")
        #endif
        
    }
    
    
    @IBAction func showLightningNode(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToLightningNode", sender: self)
        }
    }
    
    private func setEncryptionKey() {
        firstTimeHere() { [unowned vc = self] success in
            if !success {
                displayAlert(viewController: vc, isError: true, message: "there was a critical error setting your devices encryption key, please delete and reinstall the app")
            }
        }
    }
    
    func torConnProgress(_ progress: Int) {
        print("progress = \(progress)")
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.text = "Tor progress: \(progress)%"
        }
    }
    
    func torConnFinished() {
        viewHasLoaded = true
        removeBackView()
        loadTable()
        displayAlert(viewController: self, isError: false, message: "Tor finished bootstrapping")
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.isHidden = true
        }
    }
    
    func torConnDifficulties() {
        displayAlert(viewController: self, isError: true, message: "We are having issues connecting tor")
        DispatchQueue.main.async { [weak self] in
            self?.torProgressLabel.isHidden = true
        }
    }
    
    func addNavBarSpinner() {
        spinner.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        dataRefresher = UIBarButtonItem(customView: spinner)
        navigationItem.setRightBarButton(dataRefresher, animated: true)
        spinner.startAnimating()
        spinner.alpha = 1
    }
    
    @objc func refreshNode() {
        existingNodeID = nil
        addNavBarSpinner()
        loadTable()
    }
    
    private func loadTable() {
        getNodes { [unowned vc = self] nodeArray in
            if nodeArray != nil {
                if nodeArray!.count > 0 {
                    vc.loopThroughNodes(nodes: nodeArray!)
                } else {
                    vc.removeLoader()
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "segueToAddANode", sender: vc)
                    }
                }
            } else {
                vc.removeLoader()
            }
            vc.initialLoad = false
        }
    }
    
    private func loopThroughNodes(nodes: [[String:Any]]) {
        var activeNode:[String:Any]?
        for (i, node) in nodes.enumerated() {
            let nodeStruct = NodeStruct.init(dictionary: node)
            if nodeStruct.isActive {
                activeNode = node
                self.activeNode = node
            }
            if i + 1 == nodes.count {
                if activeNode != nil {
                    loadNode(node: activeNode!)
                } else {
                    removeLoader()
                    connectingView.removeConnectingView()
                    showAlert(vc: self, title: "No Active Node", message: "Go to \"settings\" > \"node manager\" and toggle on one of your nodes.")
                }
            }
        }
    }
    
    private func loadNode(node: [String:Any]) {
        let nodeStruct = NodeStruct(dictionary: node)
        if initialLoad {
            existingNodeID = nodeStruct.id
            loadTableData()
        } else {
            checkIfNodesChanged(newNodeId: nodeStruct.id!)
        }
        DispatchQueue.main.async { [unowned vc = self] in
            vc.headerLabel.text = nodeStruct.label
        }
    }
    
    private func checkIfNodesChanged(newNodeId: UUID) {
        if newNodeId != existingNodeID {
            loadTableData()
        }
    }
    
    @objc func refreshData(_ sender: Any) {
        existingNodeID = nil
        blockchainInfo = nil
        mempoolInfo = nil
        uptimeInfo = nil
        peerInfo = nil
        feeInfo = nil
        networkInfo = nil
        DispatchQueue.main.async { [unowned vc = self] in
            vc.mainMenu.reloadData()
        }
        refreshDataNow()
    }
    
    func refreshDataNow() {
        addNavBarSpinner()
        loadTable()
    }
    
    @IBAction func lockButton(_ sender: Any) {
        showUnlockScreen()
    }
    
    func showUnlockScreen() {
        if KeyChain.getData("UnlockPassword") != nil {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "lockScreen", sender: vc)
            }
        }
    }
    
    //MARK: Tableview Methods
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 14
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
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
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let background = cell.viewWithTag(3)!
        let icon = cell.viewWithTag(1) as! UIImageView
        let label = cell.viewWithTag(2) as! UILabel
        let chevron = cell.viewWithTag(4) as! UIImageView
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        icon.tintColor = .white
        
        switch Section(rawValue: indexPath.section) {
        case .verificationProgress:
            if blockchainInfo != nil {
                if blockchainInfo.progress == "Fully verified" {
                    background.backgroundColor = .systemGreen
                    icon.image = UIImage(systemName: "checkmark.seal")
                } else {
                    background.backgroundColor = .systemRed
                    icon.image = UIImage(systemName: "exclamationmark.triangle")
                }
                label.text = blockchainInfo.progress
                chevron.alpha = 1
            }
            
        case .totalSupply:
            if uptimeInfo != nil {
                label.text = "Verify total supply"
                icon.image = UIImage(systemName: "bitcoinsign.circle")
                background.backgroundColor = .systemYellow
                chevron.alpha = 1
            }
            
        case .nodeVersion:
            if networkInfo != nil {
                label.text = "Bitcoin Core v\(networkInfo.version)"
                icon.image = UIImage(systemName: "v.circle")
                background.backgroundColor = .systemBlue
                chevron.alpha = 1
            }
            
        case .blockchainNetwork:
            if blockchainInfo != nil {
                label.text = blockchainInfo.network
                icon.image = UIImage(systemName: "link")
                if blockchainInfo.network == "test chain" {
                    background.backgroundColor = .systemGreen
                } else if blockchainInfo.network == "main chain" {
                    background.backgroundColor = .systemOrange
                } else {
                    background.backgroundColor = .systemTeal
                }
                chevron.alpha = 1
            }
            
        case .peerConnections:
            if peerInfo != nil {
                label.text = "\(peerInfo.outgoingCount) outgoing / \(peerInfo.incomingCount) incoming"
                icon.image = UIImage(systemName: "person.3")
                background.backgroundColor = .systemIndigo
                chevron.alpha = 1
            }
            
        case .blockchainState:
            if blockchainInfo != nil {
                if blockchainInfo.pruned {
                    label.text = "Pruned"
                    icon.image = UIImage(systemName: "rectangle.compress.vertical")
                    
                } else if !blockchainInfo.pruned {
                    label.text = "Not pruned"
                    icon.image = UIImage(systemName: "rectangle.expand.vertical")
                }
                background.backgroundColor = .systemPurple
                chevron.alpha = 1
            }
            
        case .miningHashrate:
            if miningInfo != nil {
                label.text = miningInfo.hashrate + " " + "EH/s hashrate"
                icon.image = UIImage(systemName: "speedometer")
                background.backgroundColor = .systemRed
                chevron.alpha = 0
            }
            
        case .currentBlockHeight:
            if blockchainInfo != nil {
                label.text = "\(blockchainInfo.blockheight.withCommas()) blocks"
                icon.image = UIImage(systemName: "square.stack.3d.up")
                background.backgroundColor = .systemYellow
                chevron.alpha = 0
            }
            
        case .miningDifficulty:
            if blockchainInfo != nil {
                label.text = blockchainInfo.difficulty
                icon.image = UIImage(systemName: "slider.horizontal.3")
                background.backgroundColor = .systemBlue
                chevron.alpha = 0
            }
            
        case .blockchainSizeOnDisc:
            if blockchainInfo != nil {
                label.text = blockchainInfo.size
                background.backgroundColor = .systemPink
                icon.image = UIImage(systemName: "archivebox")
                chevron.alpha = 0
            }
        
        case .memPool:
            if mempoolInfo != nil {
                label.text = "\(mempoolInfo.mempoolCount.withCommas()) mempool"
                icon.image = UIImage(systemName: "waveform.path.ecg")
                background.backgroundColor = .systemGreen
                chevron.alpha = 0
            }
            
        case .feeRate:
            if feeInfo != nil {
                label.text = feeInfo.feeRate + " " + "fee rate"
                icon.image = UIImage(systemName: "percent")
                background.backgroundColor = .systemGray
                chevron.alpha = 0
            }
            
        case .p2pHiddenService:
            if networkInfo != nil {
                if networkInfo.torReachable {
                    label.text = "tor hidden service on"
                    icon.image = UIImage(systemName: "wifi")
                    background.backgroundColor = .black
                    
                } else {
                    label.text = "tor hidden service off"
                    icon.image = UIImage(systemName: "wifi.slash")
                    background.backgroundColor = .darkGray
                }
                chevron.alpha = 0
            }
            
        case .nodeUptime:
            if uptimeInfo != nil {
                label.text = "\(uptimeInfo.uptime / 86400) days \((uptimeInfo.uptime % 86400) / 3600) hours uptime"
                icon.image = UIImage(systemName: "clock")
                background.backgroundColor = .systemOrange
                chevron.alpha = 0
            }
            
        default:
            break
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .verificationProgress,
             .blockchainNetwork,
             .blockchainState,
             .currentBlockHeight,
             .miningDifficulty,
             .blockchainSizeOnDisc:
            if blockchainInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .peerConnections:
            if peerInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .nodeVersion,
             .p2pHiddenService:
            if networkInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .miningHashrate:
            if miningInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .nodeUptime,
             .totalSupply:
            if uptimeInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .memPool:
            if mempoolInfo == nil {
                return blankCell()
            } else {
                return homeCell(indexPath)
            }
        case .feeRate:
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
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(rawValue: indexPath.section) {
        case .verificationProgress:
            if blockchainInfo != nil {
                command = "getblockchaininfo"
                detailHeaderText = headerName(for: .verificationProgress)
                if blockchainInfo.progress == "Fully verified" {
                    detailImageTint = .systemGreen
                    detailImage = UIImage(systemName: "checkmark.seal")!
                } else {
                    detailImageTint = .systemRed
                    detailImage = UIImage(systemName: "exclamationmark.triangle")!
                }
                detailSubheaderText = "\(blockchainInfo.actualProgress * 100)%"
                detailTextDescription = """
                Don't trust, verify!
                
                Simply put the "verification progress" field lets you know what percentage of the blockchain's transactions have been verified by your node. The value your node returns is a decimal number between 0.0 and 1.0. 1 meaning your node has verified 100% of the transactions on the blockchain. As new transactions and blocks are always being added to the blockchain your node is constantly catching up and this field will generally be a number such as "0.99999974646", never quite reaching 1 (although it is possible). Fully Noded checks if this number is greater than 0.99 (e.g. 0.999) and if it is we consider your node's copy of the blockchain to be "Fully Verified".
                
                Fully Noded makes the bitcoin-cli getblockchaininfo call to your node in order to get the "verification progress" of your node. Your node is always verifying each transaction that is broadcast onto the Bitcoin network. This is the fundamental reason to run your own node. If you use someone elses node you are trusting them to verify your utxo's which defeats the purpose of Bitcoin in the first place. Bitcoin was invented to disintermediate 3rd parties, removing trust from the foundation of our financial system, reintroducing that trust defeats Bitcoin's purpose. This is why it is so important to run your own node.
                
                During the initial block download your node proccesses each transaction starting from the genesis block, ensuring all the inputs and outputs of each transaction balance out with future transactions, this is possible because all transactions can be traced back to their coinbase transaction (also known as a "block reward"). This is true whether your node is pruned or not. In this way your node verifies all new transactions are valid, preventing double spending or inflation of the Bitcoin supply. You can think of it as preventing the counterfeiting of bitcoins as it would be impossible for an attacker to fake historic transactions in order to make the new one appear valid.
                """
                segueToShowDetail()
            }
            
        case .totalSupply:
            if feeInfo != nil {
                command = "gettxoutsetinfo"
                detailHeaderText = headerName(for: .totalSupply)
                detailSubheaderText = "Use your own node to verify total supply"
                detailImage = UIImage(systemName: "bitcoinsign.circle")!
                detailImageTint = .systemYellow
                detailTextDescription = """
                Fully Noded uses the bitcoin-cli gettxoutsetinfo command to determine the total amount of mined Bitcoins. This command can take considerable time to load, usually around 30 seconds so please be patient while it loads.
                
                With this command you can at anytime verify all the Bitcoins that have ever been issued without using any third parties at all.
                """
                segueToShowDetail()
            }
            
        case .nodeVersion:
            if networkInfo != nil {
                command = "getnetworkinfo"
                detailHeaderText = headerName(for: .nodeVersion)
                detailImageTint = .systemBlue
                detailImage = UIImage(systemName: "v.circle")!
                detailSubheaderText = "Bitcoin Core v\(networkInfo.version)"
                detailTextDescription = """
                The current version number of your node's software.
                
                Fully Noded makes the bitcoin-cli getnetworkinfo command to your node in order to obtain information about your node's connection to the Bitcoin peer to peer network. The command returns your node's current version number along with other info regarding your connections. To get the version number Fully Noded looks specifically at the "subversion" field.
                
                See the list of releases for each version along with detailed release notes.
                """
                segueToShowDetail()
            }
            
        case .blockchainNetwork:
            if blockchainInfo != nil {
                command = "getblockchaininfo"
                detailHeaderText = headerName(for: .blockchainNetwork)
                detailSubheaderText = blockchainInfo.network
                if blockchainInfo.network == "test chain" {
                    detailImageTint = .systemGreen
                } else if blockchainInfo.network == "main chain" {
                    detailImageTint = .systemOrange
                } else {
                    detailImageTint = .systemTeal
                }
                detailImage = UIImage(systemName: "link")!
                detailTextDescription = """
                Fully Noded makes the bitcoin-cli getblockchaininfo command to determine which network your node is running on. Your node can run three different chain's simultaneously; "main", "test" and "regtest". Fully Noded is capable of connecting to either one. To launch mutliple chains simultaneously you would want to run the "bitcoind" command with the "-chain=test", "-chain=regtest" arguments or omit the argument to run the main chain.
                
                It should be noted when running multiple chains simultaneously you can not specifiy the network in your bitcoin.conf file.
                
                The main chain is of course the real one, where real bitcoin can be spent and received.
                
                The test chain is called "testnet3" and is mostly for users who would like to test new functionality or get familiar with how bitcoin really works before commiting real funds. Its also usefull for developers and stress testing.
                
                The regtest chain is for developers who want to create their own personal blockchain, it is incredibly handy for developing bitcoin software as no internet is required and you can mine your own test bitcoins instantly. You may even setup multiple nodes and simulate specific kinds of network conditions.
                
                Fully Noded talks to each node via a port. Generally mainnet uses the default port 8332, testnet 18332 and regtest 18443. However because Fully Noded works over Tor we actually use what are called virtual ports under the hood. The rpcports as just mentioned are only ever exposed to your nodes localhost meaning they are only accessible remotely via a Tor hidden service.
                """
                segueToShowDetail()
            }
            
        case .peerConnections:
            if peerInfo != nil {
                command = "getpeerinfo"
                detailHeaderText = headerName(for: .peerConnections)
                detailSubheaderText = "\(peerInfo.outgoingCount) outgoing / \(peerInfo.incomingCount) incoming"
                detailImage = UIImage(systemName: "person.3")!
                detailImageTint = .systemIndigo
                detailTextDescription = """
                Fully Noded makes the bitcoin-cli getpeerinfo command to your node in order to find out how many peers you are connected to.
                            
                You can have a number of incoming and outgoing peers, these are other nodes which your node is connected to over the peer to peer network (p2p). In order to receive incoming connections you can either forward port 8333 from your router or (more easily) use bitcoin core's built in functionality to create a hidden service using Tor to get incoming connections on, that way you can get incoming connections but do not need to forward a port.
                
                The p2p network is where your node receives all the information it needs about historic transactions when carrying out its initial block download and verification as well as all newly broadcast transactions.
                
                All new potential transactions are broadcast to the p2p network and whenever a peer learns of a new transaction it immedietly validates it and lets all of its peers know about the transaction, this is how bitcoin transactions propogate across the network. This way all nodes can stay up to date on the latest blocks/transactions.
                
                Check out this link for a deeper dive into the Bitcoin p2p network.
                """
                segueToShowDetail()
            }
            
        case .blockchainState:
            if blockchainInfo != nil {
                command = "getblockchaininfo"
                detailHeaderText = headerName(for: .blockchainState)
                if blockchainInfo.pruned {
                    detailSubheaderText = "Pruned"
                    detailImage = UIImage(systemName: "rectangle.compress.vertical")!
                    
                } else if !blockchainInfo.pruned {
                    detailSubheaderText = "Not pruned"
                    detailImage = UIImage(systemName: "rectangle.expand.vertical")!
                }
                detailImageTint = .systemPurple
                detailTextDescription = """
                Fully Noded makes the bitcoin-cli getblockchaininfo command to determine the blockchain's state. When configuring your node you can set "prune=1" or specifiy a size in mebibytes to prune the blockchain to.
                
                In this way you can avoid having to keep an entire copy of the blockchain on your computer, the minimum size is 550 mebibytes and the full current size is around 320gb.
                
                Pruned nodes still verify and validate every single transaction so no trust is needed to prune your node, however you can lose some convenient functionality like restoring old wallets that you may want to migrate to your new node.
                
                Once your initial block download and verification completes you can not "rescan" the blockchain past your prune height which is the block at which have pruned from.
                """
                segueToShowDetail()
            }
        
        default:
            break
        }
    }
    
    private func segueToShowDetail() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "showDetailSegue", sender: vc)
        }
    }
    
    func loadTableData() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getblockchaininfo")
        NodeLogic.loadBlockchainInfo { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.blockchainInfo = BlockchainInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 0, 3, 5, 7, 8, 9), with: .fade)
                    vc.getPeerInfo()
                }
            } else if errorMessage != nil {
                vc.removeLoader()
                
                if errorMessage!.contains("Loading block index") || errorMessage!.contains("Verifying") || errorMessage!.contains("Rewinding") {
                    displayAlert(viewController: self, isError: true, message: "Your node is still getting warmed up! Wait 15 seconds and tap the refresh button to try again")
                    
                } else if errorMessage!.contains("Could not connect to the server.") {
                    displayAlert(viewController: self, isError: true, message: "Looks like your node is not on, make sure it is running and try again.")
                    
                } else if errorMessage!.contains("unknown error") {
                    displayAlert(viewController: self, isError: true, message: "We got a strange response from your node, first of all make 100% sure your credentials are correct, if they are then your node could be overloaded... Either wait a few minutes and try again or reboot Tor on your node, if that fails reboot your node too, force quit Fully Noded and open it again.")
                    
                } else if errorMessage!.contains("timed out") || errorMessage!.contains("The Internet connection appears to be offline") {
                    displayAlert(viewController: self, isError: true, message: "Hmmm we are not getting a response from your node, you can try rebooting Tor on your node and force quitting Fully Noded and reopening it, that generally fixes the issue.")
                    
                } else {
                    displayAlert(viewController: self, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    private func getPeerInfo() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getpeerinfo")
        NodeLogic.getPeerInfo { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.peerInfo = PeerInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 4), with: .fade)
                    vc.getNetworkInfo()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func getNetworkInfo() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getnetworkinfo")
        NodeLogic.getNetworkInfo { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.networkInfo = NetworkInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 2, 12), with: .fade)
                    vc.getMiningInfo()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func getMiningInfo() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getmininginfo")
        NodeLogic.getMiningInfo { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.miningInfo = MiningInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 6), with: .fade)
                    vc.getUptime()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func getUptime() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getuptime")
        NodeLogic.getUptime { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.uptimeInfo = Uptime(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 13), with: .fade)
                    vc.getMempoolInfo()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func getMempoolInfo() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getmempoolinfo")
        NodeLogic.getMempoolInfo { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.mempoolInfo = MempoolInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 10), with: .fade)
                    vc.getFeeInfo()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    private func getFeeInfo() {
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli estimatesmartfee")
        NodeLogic.estimateSmartFee { [unowned vc = self] (response, errorMessage) in
            if response != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.feeInfo = FeeInfo(dictionary: response!)
                    vc.mainMenu.reloadSections(IndexSet(arrayLiteral: 11, 1), with: .fade)
                    vc.removeLoader()
                }
            } else {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: errorMessage!)
            }
        }
    }
    
    //MARK: User Interface
    
    func addlaunchScreen() {

        if let _ = self.tabBarController {
            
            DispatchQueue.main.async {
                self.backView.alpha = 0
                self.backView.frame = self.tabBarController!.view.frame
                self.backView.backgroundColor = .black
                let imageView = UIImageView()
                imageView.frame = CGRect(x: self.view.center.x - 75, y: self.view.center.y - 75, width: 150, height: 150)
                imageView.image = UIImage(named: "logo_grey.png")
                self.backView.addSubview(imageView)
                self.view.addSubview(self.backView)
                
                UIView.animate(withDuration: 0.8, animations: {
                    self.backView.alpha = 1
                })
                
            }
            
        }
        
    }
    
    func removeLoader() {
        
        DispatchQueue.main.async { [unowned vc = self] in
            
            vc.spinner.stopAnimating()
            vc.spinner.alpha = 0
            
            vc.refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: vc, action: #selector(vc.refreshData(_:)))
            
            vc.refreshButton.tintColor = UIColor.lightGray.withAlphaComponent(1)
            
            vc.navigationItem.setRightBarButton(vc.refreshButton,
                                                  animated: true)
            
            vc.viewHasLoaded = true
            
        }
        
    }
    
    func removeBackView() {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.3, animations: {
                self.backView.alpha = 0
                self.mainMenu.alpha = 1
            }) { (_) in
                self.backView.removeFromSuperview()
            }
            
        }
        
    }
    
    func reloadTable() {
        //used when user switches between nodes so old node data is not displayed
        
        DispatchQueue.main.async {
            
            self.mainMenu.reloadData()
            
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "showDetailSegue":
            
            if let vc = segue.destination as? ShowDetailViewController {
                vc.command = command
                vc.iconImage = detailImage
                vc.backgroundTint = detailImageTint
                vc.detailHeaderText = detailHeaderText
                vc.detailSubheaderText = detailSubheaderText
                vc.detailTextDescription = detailTextDescription
            }
            
        case "segueToAddANode":
            
            if let vc = segue.destination as? NodeDetailViewController {
                vc.createNew = true
                vc.isLightning = false
            }
            
        case "segueToRemoteControl":
            
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = host
                vc.headerIcon = UIImage(systemName: "antenna.radiowaves.left.and.right")
                vc.headerText = "Remote Control - Quick Connect"
                vc.descriptionText = "Fully Noded macOS hosts a secure hidden service for your node which can be used to remotely connect to it.\n\nSimply scan this QR with your iPhone or iPad using the Fully Noded iOS app and connect to your node remotely from anywhere in the world!"
            }
            
        default:
            break
        }
        
    }
    
    //MARK: Helpers
    
    func firstTimeHere(completion: @escaping ((Bool)) -> Void) {
        FirstTime.firstTimeHere() { success in
            completion(success)
        }
    }
    
}

// MARK: Helpers

extension MainMenuViewController {
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .verificationProgress:
            return "Verification progress"
        case .totalSupply:
            return "Total supply"
        case .nodeVersion:
            return "Node version"
        case .blockchainNetwork:
            return "Blockchain network"
        case .peerConnections:
            return "Peer connections"
        case .blockchainState:
            return "Blockchain state"
        case .miningHashrate:
            return "Mining hashrate"
        case .currentBlockHeight:
            return "Current blockheight"
        case .miningDifficulty:
            return "Mining difficulty"
        case .blockchainSizeOnDisc:
            return "Blockchain size on disc"
        case .memPool:
            return "Node's mempool"
        case .feeRate:
            return "Fee rate"
        case .p2pHiddenService:
            return "P2P hidden service"
        case .nodeUptime:
            return "Node uptime"
        }
    }
    
}
