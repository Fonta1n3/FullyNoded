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
    var hashrateString = String()
    var version = String()
    var incomingCount = Int()
    var outgoingCount = Int()
    var isPruned = Bool()
    var currentBlock = Int()
    @IBOutlet var mainMenu: UITableView!
    var connectingView = ConnectingView()
    let cd = CoreDataService()
    var nodes = [[String:Any]]()
    var uptime = Int()
    var activeNode:[String:Any]?
    var existingNodeID:UUID!
    var initialLoad = Bool()
    var mempoolCount = Int()
    var torReachable = Bool()
    var progress = ""
    var difficulty = ""
    var feeRate = ""
    var size = ""
    var network = ""
    var sectionOneLoaded = Bool()
    let spinner = UIActivityIndicatorView(style: .medium)
    var refreshButton = UIBarButtonItem()
    var dataRefresher = UIBarButtonItem()
    var viewHasLoaded = Bool()
    var nodeLabel = ""
    @IBOutlet weak var headerLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mainMenu.delegate = self
        mainMenu.alpha = 0
        mainMenu.tableFooterView = UIView(frame: .zero)
        initialLoad = true
        viewHasLoaded = false
        sectionOneLoaded = false
        addNavBarSpinner()
        showUnlockScreen()
        NotificationCenter.default.addObserver(self, selector: #selector(refreshNode), name: .refreshNode, object: nil)
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
    
    private func setEncryptionKey() {
        firstTimeHere() { [unowned vc = self] success in
            if !success {
                displayAlert(viewController: vc, isError: true, message: "there was a critical error setting your devices encryption key, please delete and reinstall the app")
            }
        }
    }
    
    func torConnProgress(_ progress: Int) {
        print("progress = \(progress)")
    }
    
    func torConnFinished() {
        print("finished connecting")
        viewHasLoaded = true
        removeBackView()
        loadTable()
        displayAlert(viewController: self, isError: false, message: "Tor finished bootstrapping")
    }
    
    func torConnDifficulties() {
        displayAlert(viewController: self, isError: true, message: "We are having issues connecting tor")
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
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "addNodeNow", sender: vc)
                    }
                }
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
            loadSectionOne()
        } else {
            checkIfNodesChanged(newNodeId: nodeStruct.id!)
        }
        DispatchQueue.main.async { [unowned vc = self] in
            vc.headerLabel.text = nodeStruct.label
        }
    }
    
    private func checkIfNodesChanged(newNodeId: UUID) {
        if newNodeId != existingNodeID {
            loadSectionOne()
        }
    }
    
    @objc func refreshData(_ sender: Any) {
        existingNodeID = nil
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
        return 13//1
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
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        icon.tintColor = .white
        
        switch indexPath.section {
        case 0:
            if progress == "99% synced" {
                label.text = "fully synced"
                background.backgroundColor = .systemGreen
                icon.image = UIImage(systemName: "checkmark.seal")
            } else {
                label.text = progress
                background.backgroundColor = .systemRed
                icon.image = UIImage(systemName: "exclamationmark.triangle")
            }
            
        case 1:
            label.text = "bitcoin core v\(self.version)"
            icon.image = UIImage(systemName: "v.circle")
            background.backgroundColor = .systemBlue
            
        case 2:
            label.text = network
            icon.image = UIImage(systemName: "link")
            if network == "test chain" {
                background.backgroundColor = .systemGreen
            } else if network == "main chain" {
                background.backgroundColor = .systemOrange
            } else {
                background.backgroundColor = .systemTeal
            }
            
        case 3:
            label.text = "\(outgoingCount) outgoing / \(incomingCount) incoming"
            icon.image = UIImage(systemName: "person.3")
            background.backgroundColor = .systemIndigo
            
        case 4:
            if isPruned {
                label.text = "pruned"
                icon.image = UIImage(systemName: "rectangle.compress.vertical")
                
            } else if !isPruned {
                label.text = "not pruned"
                icon.image = UIImage(systemName: "rectangle.expand.vertical")
            }
            background.backgroundColor = .systemPurple
            
        case 5:
            label.text = hashrateString + " " + "EH/s hashrate"
            icon.image = UIImage(systemName: "speedometer")
            background.backgroundColor = .systemRed
            
        case 6:
            label.text = "\(self.currentBlock.withCommas()) blocks"
            icon.image = UIImage(systemName: "square.stack.3d.up")
            background.backgroundColor = .systemYellow
            
        case 7:
            label.text = difficulty
            icon.image = UIImage(systemName: "slider.horizontal.3")
            background.backgroundColor = .systemBlue
            
        case 8:
            label.text = size
            background.backgroundColor = .systemPink
            icon.image = UIImage(systemName: "archivebox")
        
        case 9:
            label.text = "\(self.mempoolCount.withCommas()) mempool"
            icon.image = UIImage(systemName: "waveform.path.ecg")
            background.backgroundColor = .systemGreen
            
        case 10:
            label.text = self.feeRate + " " + "fee rate"
            icon.image = UIImage(systemName: "percent")
            background.backgroundColor = .systemGray
            
        case 11:
            if torReachable {
                label.text = "tor hidden service on"
                icon.image = UIImage(systemName: "wifi")
                background.backgroundColor = .black
                
            } else {
                label.text = "tor hidden service off"
                icon.image = UIImage(systemName: "wifi.slash")
                background.backgroundColor = .darkGray
            }
            
        case 12:
            label.text = "\(uptime / 86400) days \((uptime % 86400) / 3600) hours uptime"
            icon.image = UIImage(systemName: "clock")
            background.backgroundColor = .systemOrange
            
        default:
            break
        }
        return cell
    }
    
    private func nodeCell(_ indexPath: IndexPath) -> UITableViewCell {
        let cell = mainMenu.dequeueReusableCell(withIdentifier: "NodeInfo", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let network = cell.viewWithTag(1) as! UILabel
        let pruned = cell.viewWithTag(2) as! UILabel
        let connections = cell.viewWithTag(3) as! UILabel
        let version = cell.viewWithTag(4) as! UILabel
        let hashRate = cell.viewWithTag(5) as! UILabel
        let sync = cell.viewWithTag(6) as! UILabel
        let blockHeight = cell.viewWithTag(7) as! UILabel
        let uptime = cell.viewWithTag(8) as! UILabel
        let mempool = cell.viewWithTag(10) as! UILabel
        let tor = cell.viewWithTag(11) as! UILabel
        let difficultyLabel = cell.viewWithTag(12) as! UILabel
        let sizeLabel = cell.viewWithTag(13) as! UILabel
        let feeRate = cell.viewWithTag(14) as! UILabel
        
        network.layer.cornerRadius = 6
        pruned.layer.cornerRadius = 6
        connections.layer.cornerRadius = 6
        version.layer.cornerRadius = 6
        hashRate.layer.cornerRadius = 6
        sync.layer.cornerRadius = 6
        blockHeight.layer.cornerRadius = 6
        uptime.layer.cornerRadius = 6
        mempool.layer.cornerRadius = 6
        tor.layer.cornerRadius = 6
        difficultyLabel.layer.cornerRadius = 6
        sizeLabel.layer.cornerRadius = 6
        feeRate.layer.cornerRadius = 6
        
        sizeLabel.text = self.size
        difficultyLabel.text = self.difficulty
        if self.progress == "99% synced" {
            sync.text = "fully synced"
        } else {
            sync.text = self.progress
        }
        feeRate.text = self.feeRate + " " + "fee rate"
        
        if torReachable {
            
            tor.text = "tor hidden service on"
            
        } else {
            
            tor.text = "tor hidden service off"
            
        }
        
        mempool.text = "\(self.mempoolCount.withCommas()) mempool"
        
        if self.isPruned {
            
            pruned.text = "pruned"
            
        } else if !self.isPruned {
            
            pruned.text = "not pruned"
        }
        
        if self.network != "" {
            
            network.text = self.network
            
        }
        
        blockHeight.text = "\(self.currentBlock.withCommas()) blocks"
        connections.text = "\(outgoingCount) ↑ / \(incomingCount) ↓ connections"
        version.text = "bitcoin core v\(self.version)"
        hashRate.text = self.hashrateString + " " + "EH/s hashrate"
        uptime.text = "\(self.uptime / 86400) days \((self.uptime % 86400) / 3600) hours uptime"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if sectionOneLoaded {
            return homeCell(indexPath)//nodeCell(indexPath)
        } else {
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
        
        switch section {
        case 0:
            textLabel.text = "Verification progress"
        case 1:
            textLabel.text = "Node version"
        case 2:
            textLabel.text = "Blockchain network"
        case 3:
            textLabel.text = "Peer connections"
        case 4:
            textLabel.text = "Blockchain state"
        case 5:
            textLabel.text = "Mining hashrate"
        case 6:
            textLabel.text = "Current blockheight"
        case 7:
            textLabel.text = "Mining difficulty"
        case 8:
            textLabel.text = "Blockchain size on disc"
        case 9:
            textLabel.text = "Node's mempool"
        case 10:
            textLabel.text = "Fee rate"
        case 11:
            textLabel.text = "P2P hidden service"
        case 12:
            textLabel.text = "Node uptime"
        default:
            break
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if sectionOneLoaded {
//            return 203
//        } else {
//            return 47
//        }
        return 54
    }
    
    func loadSectionOne() {
        let nodeLogic = NodeLogic()
        displayAlert(viewController: self, isError: false, message: "bitcoin-cli getblockchaininfo")
        nodeLogic.loadSectionOne { [unowned vc = self] in
            if nodeLogic.errorBool {
                vc.removeLoader()
                displayAlert(viewController: self, isError: true, message: nodeLogic.errorDescription)
            } else {
                let dict = nodeLogic.dictToReturn
                let str = HomeStruct(dictionary: dict)
                vc.sectionOneLoaded = true
                vc.feeRate = str.feeRate
                vc.mempoolCount = str.mempoolCount
                vc.network = str.network
                vc.torReachable = str.torReachable
                vc.size = str.size
                vc.difficulty = str.difficulty
                vc.progress = str.progress
                vc.isPruned = str.pruned
                vc.incomingCount = str.incomingCount
                vc.outgoingCount = str.outgoingCount
                vc.version = str.version
                vc.hashrateString = str.hashrate
                vc.uptime = str.uptime
                vc.currentBlock = str.blockheight
                vc.sectionOneLoaded = true
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.mainMenu.reloadData()
                    vc.removeLoader()
                }
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
                imageView.image = UIImage(named: "ItunesArtwork@2x.png")
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
        sectionOneLoaded = false
        
        DispatchQueue.main.async {
            
            self.mainMenu.reloadData()
            
        }
        
    }
    
    func getNodes(completion: @escaping (([[String:Any]]?)) -> Void) {
        
        nodes.removeAll()
        
        cd.retrieveEntity(entityName: .newNodes) {
            
            if !self.cd.errorBool {
                
                completion(self.cd.entities)
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "error getting nodes from coredata")
                completion(nil)
                
            }
            
        }
        
    }
    
//    func activeNodeDict() -> (isAnyNodeActive: Bool, node: [String:Any]) {
//        var dictToReturn = [String:Any]()
//        var boolToReturn = false
//        for nodeDict in nodes {
//            let node = NodeStruct(dictionary: nodeDict)
//            let nodeActive = node.isActive
//            if nodeActive {
//                boolToReturn = true
//                dictToReturn = nodeDict
//            }
//        }
//        return (boolToReturn, dictToReturn)
//    }
    
    //MARK: User Actions
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "addNodeNow":
            
            if let vc = segue.destination as? ChooseConnectionTypeViewController {
                
                vc.cameFromHome = true
                
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

extension Double {
    
    func withCommas() -> String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
        
    }
    
}
