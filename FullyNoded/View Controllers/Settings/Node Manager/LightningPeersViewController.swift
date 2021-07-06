//
//  LightningPeersViewController.swift
//  FullyNoded
//
//  Created by Peter on 17/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class LightningPeersViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var id = ""
    let spinner = ConnectingView()
    var peerArray = [[String:Any]]()
    var selectedPeer:[String:Any]?
    var lndNode = false
    var initialLoad = true

    @IBOutlet weak var iconBackground: UIView!
    @IBOutlet weak var peersTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        peersTable.delegate = self
        peersTable.dataSource = self
        iconBackground.clipsToBounds = true
        iconBackground.layer.cornerRadius = 5
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadPeers()
        initialLoad = false
    }
    
    @IBAction func addPeerAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToAddPeer", sender: self)
        }
    }
    
    private func loadPeers() {
        if initialLoad {
            spinner.addConnectingView(vc: self, description: "getting peers...")
        }
        
        peerArray.removeAll()
        selectedPeer = nil
        id = ""
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            self.lndNode = isLnd
            
            guard isLnd else {
                self.loadCLPeers()
                return
            }
            
            self.loadLNDPeers()
        }
    }
    
    private func loadLNDPeers() {
        LndRpc.sharedInstance.makeLndCommand(command: .listpeers, param: [:], urlExt: nil, query: nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let dict = response, let peers = dict["peers"] as? NSArray else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "unknown error fetching peers")
                return
            }
            
            guard peers.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No peers yet", message: "Tap the + button to connect to a peer and start a channel")
                return
            }
            
            self.parsePeers(peers: peers)
        }
    }
    
    private func loadCLPeers() {
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .listpeers, param: "") { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard commandId == uuid, let dict = response as? NSDictionary, let peers = dict["peers"] as? NSArray else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error fetching peers")
                return
            }
            
            guard peers.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No peers yet", message: "Tap the + button to connect to a peer and start a channel")
                return
            }
            
            self.parsePeers(peers: peers)
        }
    }
    
    private func getLNDChannels() {
        LndRpc.sharedInstance.makeLndCommand(command: .listchannels, param: [:], urlExt: nil, query: nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response, let channels = response["channels"] as? NSArray, channels.count > 0 else { return }
            
            for (c, channel) in channels.enumerated() {
                let dict = channel as! [String:Any]
                let remote_pubkey = dict["remote_pubkey"] as! String
                let channelActive = dict["active"] as! Bool
                let channelStatus = dict["chan_status_flags"] as! String
                
                for (i, peer) in self.peerArray.enumerated() {
                    let pub_key = peer["pub_key"] as! String
                    
                    if pub_key == remote_pubkey {
                        self.peerArray[i]["hasChannel"] = true
                        self.peerArray[i]["channelActive"] = channelActive
                        self.peerArray[i]["channelStatus"] = channelStatus
                    }
                    
                    if i + 1 == self.peerArray.count && c + 1 == channels.count {
                        self.fetchLocalPeers { _ in
                            DispatchQueue.main.async { [weak self] in
                                guard let self = self else { return }
                                
                                self.peersTable.reloadData()
                                self.spinner.removeConnectingView()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func parsePeers(peers: NSArray) {
        for (i, peer) in peers.enumerated() {
            if var peerDict = peer as? [String:Any] {
                if lndNode {
                    peerDict["connected"] = true
                    peerDict["hasChannel"] = false
                    peerDict["channelActive"] = false
                    peerDict["channelStatus"] = ""
                }
                
                peerArray.append(peerDict)
            }
            
            if i + 1 == peers.count {
                
                if lndNode {
                    self.getLNDChannels()
                } else {
                    fetchLocalPeers { _ in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.peersTable.reloadData()
                            self.spinner.removeConnectingView()
                        }
                    }
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "peerCell", for: indexPath)
        cell.selectionStyle = .none
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.layer.borderWidth = 0.5
        
        let connectedImageView = cell.viewWithTag(1) as! UIImageView
        let idLabel = cell.viewWithTag(2) as! UILabel
        let channelsImageView = cell.viewWithTag(3) as! UIImageView
        let channelStatus = cell.viewWithTag(4) as! UILabel
        
        if peerArray.count > 0 {
            let dict = peerArray[indexPath.section]
            
            if let name = dict["name"] as? String {
                idLabel.text = name
            } else {
                idLabel.text = dict["id"] as? String ?? dict["pub_key"] as? String ?? "unknown ID"
            }
            
            if let connected = dict["connected"] as? Bool {
                if connected {
                    connectedImageView.image = UIImage(systemName: "person.crop.circle.badge.checkmark")
                    connectedImageView.tintColor = .systemGreen
                } else {
                    connectedImageView.image = UIImage(systemName: "person.crop.circle.badge.exclam")
                    connectedImageView.tintColor = .systemRed
                }
            }
            
            if lndNode {
                let hasChannel = dict["hasChannel"] as! Bool
                let channelActive = dict["channelActive"] as! Bool
                let status = dict["channelStatus"] as! String
                
                if hasChannel {
                    if channelActive {
                        channelsImageView.image = UIImage(systemName: "bolt")
                        channelsImageView.tintColor = .systemYellow
                    } else {
                        channelsImageView.image = UIImage(systemName: "bolt")
                        channelsImageView.tintColor = .systemBlue
                    }
                    channelStatus.text = status
                } else {
                    channelsImageView.image = UIImage(systemName: "bolt.slash")
                    channelsImageView.tintColor = .systemBlue
                    channelStatus.text = "No channels with peer."
                }
                
            } else if let channels = dict["channels"] as? NSArray {
                if channels.count > 0 {
                    channelsImageView.image = UIImage(systemName: "bolt")
                    channelsImageView.tintColor = .systemYellow
                    if let status = (channels[0] as! NSDictionary)["state"] as? String {
                        channelStatus.text = status
                    } else {
                        channelStatus.text = ""
                    }
                } else {
                    channelsImageView.image = UIImage(systemName: "bolt.slash")
                    channelsImageView.tintColor = .systemBlue
                    channelStatus.text = "no channels with peer"
                }
            }
            
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let peer = self.peerArray[indexPath.section]
            
            self.id = peer["id"] as? String ?? peer["pub_key"] as? String ?? ""
            self.performSegue(withIdentifier: "segueToPeerDetails", sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 96
    }
    
    private func addPeer(id: String, ip: String, port: String?) {
        spinner.addConnectingView(vc: self, description: "connecting peer...")
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            guard isLnd else {
                self.addPeerCL(id: id, ip: ip, port: port)
                return
            }
            
            self.addPeerLND(id: id, ip: ip, port: port)
        }
    }
    
    private func addPeerLND(id: String, ip: String, port: String?) {
        let host = "\(ip):\(port ?? "9735")"
        LndRpc.sharedInstance.makeLndCommand(command: .connect, param: ["addr": ["pubkey":id, "host": host]], urlExt: nil, query: nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let response = response else {
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error connecting peer.")
                return
            }
            
            if let errorMessage = response["error"] as? String, errorMessage != "" {
                showAlert(vc: self, title: "Error", message: errorMessage)
            } else {
                showAlert(vc: self, title: "Peer connected ✓", message: "")
                self.loadPeers()
            }
        }
    }
    
    private func addPeerCL(id: String, ip: String, port: String?) {
        let param = "\(id)@\(ip):\(port ?? "9735")"
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .connect, param: "\(param)") { [weak self] (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    self?.spinner.removeConnectingView()
                    if let id = dict["id"] as? String {
                        showAlert(vc: self, title: "Success ✅", message: "⚡️ peer added with id: \(id)")
                    } else {
                        showAlert(vc: self, title: "Something is not quite right", message: "This is the response we got: \(dict)")
                    }
                    self?.loadPeers()
                } else {
                    self?.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "error adding peer")
                }
            }
        }
    }
    
    private func fetchLocalPeers(completion: @escaping ((Bool)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .peers) { [weak self] peers in
            guard let self = self else { return }
            
            guard let peers = peers, peers.count > 0 else {
                completion(true)
                return
            }
            
            for (x, peer) in peers.enumerated() {
                let peerStruct = PeersStruct(dictionary: peer)
                
                for (i, p) in self.peerArray.enumerated() {
                    var id = ""
                    if self.lndNode {
                        id = p["pub_key"] as! String
                    } else {
                        id = p["id"] as! String
                    }
                    if id == peerStruct.pubkey {
                        if peerStruct.label == "" {
                            self.peerArray[i]["name"] = peerStruct.alias
                        } else {
                            self.peerArray[i]["name"] = peerStruct.label
                        }
                    }
                    
                    if i + 1 == self.peerArray.count && x + 1 == peers.count {
                        completion(true)
                    }
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller
        
        if segue.identifier == "segueToPeerDetails" {
            if let vc = segue.destination as? PeerDetailsViewController {
                vc.id = id
            }
        }
        
        if segue.identifier == "segueToAddPeer" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { url in
                    if url != nil {
                        let arr = url!.split(separator: "@")
                        if arr.count > 0 {
                            let arr1 = "\(arr[1])".split(separator: ":")
                            let id = "\(arr[0])"
                            let ip = "\(arr1[0])"
                            if arr1.count > 0 {
                                let port = "\(arr1[1])"
                                self.addPeer(id: id, ip: ip, port: port)
                            }
                        }
                    }
                }
            }
        }
    }

}
