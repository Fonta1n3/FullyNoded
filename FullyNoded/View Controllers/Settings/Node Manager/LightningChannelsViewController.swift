//
//  LightningChannelsViewController.swift
//  FullyNoded
//
//  Created by Peter on 17/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class LightningChannelsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    let spinner = ConnectingView()
    var channels = [[String:Any]]()
    var selectedChannel:[String:Any]?
    var showPending = Bool()
    var showActive = Bool()
    var showInactive = Bool()
    var myId = ""

    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var channelsTable: UITableView!
    @IBOutlet weak var iconBackground: UIView!
    @IBOutlet weak var iconHeader: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        channelsTable.delegate = self
        channelsTable.dataSource = self
        iconBackground.clipsToBounds = true
        iconBackground.layer.cornerRadius = 5
        if showPending {
            header.text = "Pending Channels"
            iconBackground.backgroundColor = .systemOrange
            iconHeader.image = UIImage(systemName: "hourglass")
        } else if showActive {
            header.text = "Active Channels"
            iconBackground.backgroundColor = .systemBlue
            iconHeader.image = UIImage(systemName: "slider.horizontal.3")
        } else {
            header.text = "Inactive Channels"
            iconBackground.backgroundColor = .systemIndigo
            iconHeader.image = UIImage(systemName: "moon.zzz")
        }
        loadPeers()
    }
    
    @IBAction func addChannel(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToCreateChannel", sender: self)
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return channels.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if showActive {
            let cell = tableView.dequeueReusableCell(withIdentifier: "activeChannelCell", for: indexPath)
            cell.selectionStyle = .none
            let amountReceivableLabel = cell.viewWithTag(1) as! UILabel
            let amountSpendableLabel = cell.viewWithTag(2) as! UILabel
            let bar = cell.viewWithTag(3) as! UIProgressView
            let dict = channels[indexPath.section]
            let amountReceivable = dict["receivable_msatoshi"] as? Int ?? 0
            let amountSpendable = dict["spendable_msatoshi"] as? Int ?? 0
            let ourAmount = dict["to_us_msat"] as? String ?? ""
            let totalAmount = dict["total_msat"] as? String ?? ""
            let ourAmountInt = Int(ourAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let totalAmountInt = Int(totalAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let ratio = Double(ourAmountInt) / Double(totalAmountInt)
            bar.setProgress(Float(ratio), animated: true)
            amountReceivableLabel.text = "\(Double(amountReceivable) / 1000.0) sats"
            amountSpendableLabel.text = "\(Double(amountSpendable) / 1000.0) sats"
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "channelCell", for: indexPath)
            cell.selectionStyle = .none
            let dict = channels[indexPath.section]
            let id = dict["channel_id"] as? String ?? ""
            cell.textLabel?.text = id
            cell.textLabel?.textColor = .lightGray
            return cell
        }
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if showActive {
            return 82
        } else {
            return 44
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textLabel.textColor = .lightGray
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        if showActive {
            textLabel.text = "short id: " + "\(channels[section]["short_channel_id"] as? String ?? "")"
        } else {
            textLabel.text = "id: " + "\(channels[section]["channel_id"] as? String ?? "")"
        }
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedChannel = channels[indexPath.section]
        showDetail()
    }
    
    private func loadPeers() {
        spinner.addConnectingView(vc: self, description: "getting channels...")
        LightningRPC.command(method: .listpeers, param: "") { [weak self] (response, errorDesc) in
            if let dict = response as? NSDictionary {
                if let peers = dict["peers"] as? NSArray {
                    if peers.count > 0 {
                        self?.parsePeers(peers: peers)
                    } else {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "No channels yet", message: "Tap the + button to connect to a peer and start a channel")
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
                if let channls = peerDict["channels"] as? NSArray {
                    if channls.count > 0 {
                        for ch in channls {
                            if let dict = ch as? [String:Any] {
                                if let state = dict["state"] as? String {
                                    if showActive {
                                        if state == "CHANNELD_NORMAL" {
                                            channels.append(dict)
                                            channels[channels.count - 1]["peerId"] = peerDict["id"] as! String
                                        }
                                    } else if showPending {
                                        if state == "CHANNELD_AWAITING_LOCKIN" {
                                            channels.append(dict)
                                        }
                                    } else {
                                        if state != "CHANNELD_NORMAL" && state != "CHANNELD_AWAITING_LOCKIN" {
                                            channels.append(dict)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if i + 1 == peers.count {
                        parseChannels()
                    }
                }
            }
        }
    }
    
    private func parseChannels() {
        DispatchQueue.main.async { [weak self] in
            self?.channelsTable.reloadData()
            self?.spinner.removeConnectingView()
        }
    }
    
    private func showDetail() {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToChannelDetails", sender: self)
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToChannelDetails" {
            if let vc = segue.destination as? ChannelDetailViewController {
                vc.selectedChannel = selectedChannel
                vc.channels = channels
                vc.myId = myId
            }
        }
    }

}
