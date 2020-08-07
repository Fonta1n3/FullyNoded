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
    @IBOutlet weak var channelTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        channelTable.delegate = self
        channelTable.dataSource = self
        iconBackground.layer.cornerRadius = 5
        loadPeers()
    }
    
    @IBAction func addChannelAction(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToAddPeer", sender: vc)
        }
    }
    
    private func loadPeers() {
        spinner.addConnectingView(vc: self, description: "getting peers...")
        LightningRPC.command(method: .listpeers, param: "") { [unowned vc = self] (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let peers = dict["peers"] as? NSArray {
                    if peers.count > 0 {
                        vc.parsePeers(peers: peers)
                    } else {
                        vc.spinner.removeConnectingView()
                        showAlert(vc: vc, title: "No peers yet", message: "Tap the + button to connect to a peer and start a channel")
                    }
                }
            } else {
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: errorDesc ?? "unknown error fetching peers")
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
    }
}
