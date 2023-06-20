//
//  LightningNodeManagerViewController.swift
//  FullyNoded
//
//  Created by Peter on 05/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class LightningNodeManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var iconBackground: UIView!
    let spinner = ConnectingView()
    var url = ""
    var myId = ""
    var newlyAdded = Bool()
    var tableArray = [String]()
    var showPending = Bool()
    var showActive = Bool()
    var showInactive = Bool()
    var color = ""
    var activeNode:[String:Any]?
    var initialLoad = Bool()
    var authenticated = false
    
    @IBOutlet weak var nodeTable: UITableView!
    @IBOutlet weak var onchainBalanceConf: UILabel!
    @IBOutlet weak var onchainBalanceUnconfirmed: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nodeTable.delegate = self
        nodeTable.dataSource = self
        iconBackground.layer.cornerRadius = 5
        initialLoad = true
        onchainBalanceConf.alpha = 0
        onchainBalanceUnconfirmed.alpha = 0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadData()
    }
    
    private func loadData() {
        showInactive = false
        showActive = false
        showPending = false
        
        checkForLightningNodes { [weak self] node in
            guard let self = self else { return }
            
            guard let node = node else {
                self.promptToAddNode()
                
                return
            }
            
            self.getInfo(node: node)
        }
    }
    
    private func promptToAddNode() {
        showAlert(
            vc: self,
            title: "No active lightning node.",
            message: "Go back, tap settings, tap node manager, tap the plus button to add a new node."
        )
    }
    
    private func checkForLightningNodes(completion: @escaping ((NodeStruct?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else {
                completion(nil)
                return
            }
            
            var lightningNode:NodeStruct?
            
            for (i, node) in nodes.enumerated() {
                let ns = NodeStruct(dictionary: node)
                
                if ns.isActive {
                    if ns.isLightning || ns.isNostr {
                        lightningNode = ns
                        self.activeNode = node
                    }
                }                
                
                if i + 1 == nodes.count {
                    completion(lightningNode)
                }
            }
        }
    }
    
    private func goToChannels() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToLightningChannels", sender: self)
        }
    }
    
    private func goToPeers() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "goToSeeLightningPeers", sender: self)
        }
    }
    
    @IBAction func shareNodeUrlAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToShareLightningUrl", sender: vc)
        }
    }
    
    private func getInfo(node: NodeStruct) {
        if initialLoad {
            spinner.addConnectingView(vc: self, description: "loading...")
            initialLoad = false
        }
        
        tableArray.removeAll()
        
        if node.macaroon == nil {
            clightningGetInfo()
        } else {
            lndGetInfo()
        }
    }
    
    private func clightningGetInfo() {
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .getinfo, param: nil) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            guard let dict = response as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error getting info from lightning node")
                return
            }
            let alias = dict["alias"] as? String ?? ""
            let num_peers = dict["num_peers"] as? Int ?? 0
            let num_pending_channels = dict["num_pending_channels"] as? Int ?? 0
            let num_active_channels = dict["num_active_channels"] as? Int ?? 0
            let num_inactive_channels = dict["num_inactive_channels"] as? Int ?? 0
            let addresses = dict["address"] as? NSArray ?? []
            var ip = ""
            var port = 9735
            
            if addresses.count > 0 {
                ip = (addresses[0] as! NSDictionary)["address"] as? String ?? ""
                port = (addresses[0] as! NSDictionary)["port"] as? Int ?? 9735
            }
            
            let id = dict["id"] as? String ?? ""
            let feesCollected = dict["fees_collected_msat"] as? String ?? "0msat"
            let version = dict["version"] as? String ?? ""
            
            self.color = dict["color"] as? String ?? "03c304"
            self.myId = id
            self.tableArray.append(alias)
            self.tableArray.append("\(num_peers)")
            self.tableArray.append("\(num_active_channels)")
            self.tableArray.append("\(num_inactive_channels)")
            self.tableArray.append("\(num_pending_channels)")
            self.tableArray.append(feesCollected)
            self.tableArray.append(version)
            self.url = "\(id)@\(ip):\(port)"
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.nodeTable.reloadData()
                self.spinner.removeConnectingView()
                self.listFundsCL()
            }
        }
    }
    
    private func listFundsCL() {
        let commandId = UUID()
        
        LightningRPC.sharedInstance.command(id: commandId, method: .listfunds, param: nil) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let outputs = dict["outputs"] as? [[String:Any]] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error getting info from lightning node")
                return
            }
            
            guard outputs.count > 0 else {
                self.setOnchainAmounts("0", "0")
                return
            }
            
            var onchainConfirmed = 0
            var onchainUnconfirmed = 0
            
            for (i, output) in outputs.enumerated() {
                if let value = output["value"] as? Int, let status = output["status"] as? String {
                    if status == "confirmed" {
                        onchainConfirmed += value
                    } else if status == "unconfirmed" {
                        onchainUnconfirmed += value
                    }
                }
                
                if i + 1 == outputs.count {
                    self.setOnchainAmounts(onchainConfirmed.withCommas, onchainUnconfirmed.withCommas)
                }
            }
        }
    }
    
    private func setOnchainAmounts(_ confirmed: String, _ unconfirmed: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.onchainBalanceConf.text = "Onchain confirmed: " + confirmed + " sats"
            self.onchainBalanceUnconfirmed.text = "Onchain unconfirmed: " + unconfirmed + " sats"
            self.onchainBalanceConf.alpha = 1
            self.onchainBalanceUnconfirmed.alpha = 1
        }
    }
    
    private func lndGetInfo() {
        let lnd = LndRpc.sharedInstance
        
        lnd.command(.getinfo, nil, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let dict = response else {
                showAlert(vc: self, title: "Error", message: error ?? "unknown")
                return
            }
            
            let alias = dict["alias"] as? String ?? ""
            let num_peers = dict["num_peers"] as? Int ?? 0
            let num_pending_channels = dict["num_pending_channels"] as? Int ?? 0
            let num_active_channels = dict["num_active_channels"] as? Int ?? 0
            let num_inactive_channels = dict["num_inactive_channels"] as? Int ?? 0
            let id = dict["identity_pubkey"] as? String ?? ""
            UserDefaults.standard.setValue(id, forKey: "LightningPubkey")
            let version = dict["version"] as? String ?? ""
            let uris = dict["uris"] as? NSArray ?? []
            
            self.color = dict["color"] as? String ?? "03c304"
            self.myId = id
            self.tableArray.append(alias)
            self.tableArray.append("\(num_peers)")
            self.tableArray.append("\(num_active_channels)")
            self.tableArray.append("\(num_inactive_channels)")
            self.tableArray.append("\(num_pending_channels)")
            self.tableArray.append("fetching...")
            self.tableArray.append(version)
            
            if uris.count > 0 {
                self.url = "\(uris[0])"
            }
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.nodeTable.reloadData()
                self.spinner.removeConnectingView()
                self.lndGetFees()
            }
        }
    }
    
    private func lndGetFees() {
        let body:[String:Any] = ["num_max_events":"50000"]
        
        LndRpc.sharedInstance.command(.fwdinghistory, body, nil, nil) { (response, error) in
            guard let response = response else { return }
            
            var totalEarned = 0
            
            guard let events = response["forwarding_events"] as? NSArray, events.count > 0 else {
                self.tableArray[5] = "\(totalEarned) sats"
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.nodeTable.reloadData()
                }
                
                return
            }
            
            for (i, event) in events.enumerated() {
                if let dict = event as? [String:Any] {
                    if let fee = dict["fee"] as? String, let int = Int(fee) {
                        totalEarned += int
                    }
                    
                    if i + 1 == events.count {
                        self.tableArray[5] = "\(totalEarned) sats"
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.nodeTable.reloadSections(IndexSet(arrayLiteral: 5), with: .none)
                            self.getOnchainSpendableLND()
                        }
                    }
                }
            }
        }
    }
    
    private func getOnchainSpendableLND() {
        LndRpc.sharedInstance.command(.walletbalance, nil, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response,
                  let confirmed_balance = response["confirmed_balance"] as? String,
                  let unconfirmed_balance = response["unconfirmed_balance"] as? String else {
                return
            }
            
            self.setOnchainAmounts(confirmed_balance.withCommas, unconfirmed_balance.withCommas)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableArray.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "lightningCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        let iconbackground = cell.viewWithTag(1)!
        let icon = cell.viewWithTag(2) as! UIImageView
        let label = cell.viewWithTag(3) as! UILabel
        let chevron = cell.viewWithTag(4) as! UIImageView
        if tableArray.count > 0 {
            let value = tableArray[indexPath.section]
            label.text = value
            iconbackground.clipsToBounds = true
            iconbackground.layer.cornerRadius = 5
            switch indexPath.section {
            case 0:
                iconbackground.backgroundColor = hexStringToUIColor(hex: color)
                icon.image = UIImage(systemName: "person")
                chevron.alpha = 0
            case 1:
                iconbackground.backgroundColor = .systemOrange
                icon.image = UIImage(systemName: "person.3")
                chevron.alpha = 1
            case 2:
                iconbackground.backgroundColor = .systemBlue
                icon.image = UIImage(systemName: "slider.horizontal.3")
                chevron.alpha = 1
            case 3:
                iconbackground.backgroundColor = .systemIndigo
                icon.image = UIImage(systemName: "moon.zzz")
                chevron.alpha = 1
            case 4:
                iconbackground.backgroundColor = .systemOrange
                icon.image = UIImage(systemName: "hourglass")
                chevron.alpha = 1
            case 5:
                iconbackground.backgroundColor = .systemPurple
                icon.image = UIImage(systemName: "bitcoinsign.circle")
                chevron.alpha = 0
            case 6:
                iconbackground.backgroundColor = .systemYellow
                icon.image = UIImage(systemName: "v.circle")
                chevron.alpha = 0
            default:
                break
            }
        }
        return cell
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
            textLabel.text = "Alias"
        case 1:
            textLabel.text = "Number of peers"
        case 2:
            textLabel.text = "Active channels"
        case 3:
            textLabel.text = "Inactive channels"
        case 4:
            textLabel.text = "Pending channels"
        case 5:
            textLabel.text = "Fees collected"
        case 6:
            textLabel.text = "Version"
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
        return 54
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case 1:
            goToPeers()
        case 2:
            showActive = true
            goToChannels()
        case 3:
            showInactive = true
            goToChannels()
        case 4:
            showPending = true
            goToChannels()
        default:
            break
        }
    }
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller
        switch segue.identifier {
        case "segueToShareLightningUrl":
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = url
                vc.headerText = "Lightning URI"
                vc.descriptionText = "This is your lightning node's address, others can scan this QR to add you as a peer or open a channel."
                vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
            }
        case "segueToLightningChannels":
            if let vc = segue.destination as? LightningChannelsViewController {
                vc.myId = myId
                vc.showPending = showPending
                vc.showActive = showActive
                vc.showInactive = showInactive
            }
        case "segueToLightningCreds":
            if let vc = segue.destination as? NodeDetailViewController {
                vc.isLightning = true
                vc.selectedNode = activeNode
            }
            
        default:
            break
        }
    }
}

