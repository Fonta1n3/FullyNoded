//
//  LightningNodeManagerViewController.swift
//  FullyNoded
//
//  Created by Peter on 05/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class LightningNodeManagerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet weak var iconBackground: UIView!
    let spinner = ConnectingView()
    var peerArray = [[String:Any]]()
    var selectedPeer:[String:Any]?
    var url = ""
    var newlyAdded = Bool()
    @IBOutlet weak var channelTable: UITableView!
    @IBOutlet weak var aliasLabel: UILabel!
    @IBOutlet weak var numPeersLabel: UILabel!
    @IBOutlet weak var numActiveChannelsLabel: UILabel!
    @IBOutlet weak var numInactiveChannelsLabel: UILabel!
    @IBOutlet weak var numPendingChannelsLabel: UILabel!
    @IBOutlet weak var feesCollectedLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        channelTable.delegate = self
        channelTable.dataSource = self
        iconBackground.layer.cornerRadius = 5
        getInfo()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if newlyAdded {
            newlyAdded = false
            showAlert(vc: self, title: "⚡️ Lightning Node added ⚡️", message: "We are fetching info from your lightning node now... Usually to get here you need to go to \"settings\" > \"node manager\" > ⚡️ > ⚙️\n\nFrom here you can see stats about your lightning node, see your peers, tap the plus button to add a new peer and create a channel with them. For others to connect to you tap the export button to share your nodes URI.")
        }
    }
    
    @IBAction func shareNodeUrlAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToShareLightningUrl", sender: vc)
        }
    }
    
    @IBAction func addChannelAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToAddPeer", sender: vc)
        }
    }
    
    private func getInfo() {
        spinner.addConnectingView(vc: self, description: "loading...")
        LightningRPC.command(method: .getinfo, param: "") { [weak self] (response, errorDesc) in
            if let dict = response as? NSDictionary {
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
                DispatchQueue.main.async { [weak self] in
                    if self != nil {
                        self!.aliasLabel.text = alias
                        self!.feesCollectedLabel.text = feesCollected
                        self!.numActiveChannelsLabel.text = "\(num_active_channels)"
                        self!.numInactiveChannelsLabel.text = "\(num_inactive_channels)"
                        self!.numPendingChannelsLabel.text = "\(num_pending_channels)"
                        self!.numPeersLabel.text = "\(num_peers)"
                        self!.url = "\(id)@\(ip):\(port)"
                        self!.loadPeers()
                    }
                }
            } else {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error getting info from lightning node")
            }
        }
    }
    
    private func loadPeers() {
        LightningRPC.command(method: .listpeers, param: "") { [weak self] (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let peers = dict["peers"] as? NSArray {
                    if peers.count > 0 {
                        self?.parsePeers(peers: peers)
                    } else {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "No peers yet", message: "Tap the + button to connect to a peer and start a channel")
                    }
                }
            } else {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error fetching peers")
            }
        }
    }
    
    private func parsePeers(peers: NSArray) {
        for (i, peer) in peers.enumerated() {
            if let peerDict = peer as? [String:Any] {
                peerArray.append(peerDict)
            }
            if i + 1 == peers.count {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.channelTable.reloadData()
                    vc.spinner.removeConnectingView()
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return peerArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "channelCell", for: indexPath)
        cell.selectionStyle = .none
        if peerArray.count > 0 {
            let dict = peerArray[indexPath.section]
            if let id = dict["id"] as? String {
                cell.textLabel?.text = id
            }
            cell.textLabel?.textColor = .white
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.selectedPeer = vc.peerArray[indexPath.section]
            vc.performSegue(withIdentifier: "segueToPeerDetails", sender: vc)
        }
    }
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller
        
        if segue.identifier == "segueToPeerDetails" {
            if let vc = segue.destination as? ProcessPSBTViewController {
                vc.showPeer = true
                if selectedPeer != nil {
                    vc.peer = selectedPeer
                }
            }
        }
        
        if segue.identifier == "segueToShareLightningUrl" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = url
            }
        }
    }
}
