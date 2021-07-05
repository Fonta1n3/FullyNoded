//
//  LightningChannelsViewController.swift
//  FullyNoded
//
//  Created by Peter on 17/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class LightningChannelsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var ours = [[String:Any]]()
    var theirs = [[String:Any]]()
    let spinner = ConnectingView()
    var channels = [[String:Any]]()
    var selectedChannel:[String:Any]?
    var showPending = Bool()
    var showActive = Bool()
    var showInactive = Bool()
    var myId = ""
    var lndNode = false

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
        
        loadChannels()
    }
    
    @IBAction func addChannel(_ sender: Any) {
        if !lndNode {
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "segueToCreateChannel", sender: self)
            }
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
            
            amountReceivableLabel.text = "\(Double(amountReceivable) / 1000.0) sats"
            amountSpendableLabel.text = "\(Double(amountSpendable) / 1000.0) sats"
            
            if lndNode {
                bar.setProgress((dict["ratio"] as! Float), animated: true)
            } else {
                let ourAmount = dict["to_us_msat"] as? String ?? ""
                let totalAmount = dict["total_msat"] as? String ?? ""
                let ourAmountInt = Int(ourAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
                let totalAmountInt = Int(totalAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
                let ratio = Double(ourAmountInt) / Double(totalAmountInt)
                bar.setProgress(Float(ratio), animated: true)
            }
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "channelCell", for: indexPath)
            cell.selectionStyle = .none
            let dict = channels[indexPath.section]
            let id = dict["channel_id"] as? String ?? dict["chan_id"] as? String ?? "?"
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
        textLabel.frame = CGRect(x: 0, y: 0, width: view.frame.width - 32, height: 50)
        let dict = channels[section]
        if showActive {
            if let name = dict["name"] as? String {
                textLabel.text = name
            } else {
                textLabel.text = "ID: " + "\(dict["short_channel_id"] as? String ?? "\(dict["chan_id"] as? String ?? "")")"
            }
        } else {
            if let name = dict["name"] as? String {
                textLabel.text = name
            } else {
                textLabel.text = "ID: " + "\(dict["channel_id"] as? String ?? dict["chan_id"] as? String ?? "")"
            }
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if showActive && !lndNode {
            selectedChannel = channels[indexPath.section]
            promptToRebalanceCL()
        } else if lndNode && showActive {
            promptToRebalanceLND()
        }
    }
    
    private func loadChannels() {
        spinner.addConnectingView(vc: self, description: "getting channels...")
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            self.lndNode = isLnd
            
            guard isLnd else {
                self.loadCLPeers()
                return
            }
            
            self.loadLndChannels()
        }
    }
    
    private func loadLndChannels() {
        if showPending {
            showPendingLndChannels()
        } else {
            LndRpc.sharedInstance.makeLndCommand(command: .listchannels, param: [:], urlExt: nil, query: ["inactive_only":showInactive,"active_only":showActive]) { [weak self] (response, error) in
                guard let self = self else { return }
                
                guard let channels = response?["channels"] as? NSArray else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: error ?? "Unknown error fetching channels.")
                    return
                }
                
                guard channels.count > 0 else {
                    self.spinner.removeConnectingView()
                    var title = "No channels yet."
                    if self.showInactive {
                        title = "No inactive channels."
                    }
                    showAlert(vc: self, title: title, message: "Tap the + button to connect to a peer and start a channel.")
                    return
                }
                
                self.parseLNDChannels(channels)
            }
        }
    }
    
    private func showPendingLndChannels() {
        LndRpc.sharedInstance.makeLndCommand(command: .listchannels, param: [:], urlExt: "pending", query: nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let waiting_close_channels = response?["waiting_close_channels"] as? NSArray,
                  let pending_force_closing_channels = response?["pending_force_closing_channels"] as? NSArray,
                  let pending_open_channels = response?["pending_open_channels"] as? NSArray,
                  let pending_closing_channels = response?["pending_closing_channels"] as? NSArray else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error fetching channels.")
                return
            }
            
            guard waiting_close_channels.count > 0 || pending_force_closing_channels.count > 0 || pending_open_channels.count > 0 || pending_closing_channels.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No pending channels.", message: "Tap the + button to connect to a peer and start a channel.")
                return
            }
            
            var allPendingChannels:[[String:Any]] = []
            
            for channel in waiting_close_channels {
                allPendingChannels.append(channel as! [String:Any])
            }
            
            for channel in pending_force_closing_channels {
                allPendingChannels.append(channel as! [String:Any])
            }
            
            for channel in pending_open_channels {
                allPendingChannels.append(channel as! [String:Any])
            }
            
            for channel in pending_closing_channels {
                allPendingChannels.append(channel as! [String:Any])
            }
            
            self.parsePendingLNDChannels(allPendingChannels)
        }
    }
    
    private func loadCLPeers() {
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .listpeers, param: "") { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard commandId == uuid, let dict = response as? NSDictionary, let peers = dict["peers"] as? NSArray else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "Unknown error fetching channels.")
                return
            }
            
            guard peers.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No channels yet.", message: "Tap the + button to connect to a peer and start a channel.")
                return
            }
            
            self.parseCLPeers(peers)
        }
    }
    
    private func parseLNDChannels(_ channels: NSArray) {
        for (i, channel) in channels.enumerated() {
            var dict = channel as! [String:Any]
            
            let localBalance = Int(dict["local_balance"] as! String)!
            let remoteBalance = Int(dict["remote_balance"] as! String)!
            if remoteBalance == 0 {
                dict["ratio"] = Float(1)
            } else {
                dict["ratio"] = Float(Double(localBalance) / Double(remoteBalance))
            }
            
            for (key, value) in dict {
                switch key {
                case "local_balance":
                    dict["to_us_msat"] = "\(localBalance * 1000)"
                    dict["spendable_msatoshi"] = Int(value as! String)! * 1000
                case "capacity":
                    dict["total_msat"] = "\(remoteBalance * 1000)"
                case "remote_balance":
                    dict["receivable_msatoshi"] = remoteBalance * 1000
                default:
                    break
                }
            }
                        
            self.channels.append(dict)
            
            if i + 1 == channels.count {
                load()
            }
        }
    }
    
    private func parsePendingLNDChannels(_ channels: [[String:Any]]) {
        for (i, channel) in channels.enumerated() {
            var dict = channel
            
            let localBalance = Int(dict["local_balance"] as! String)!
            let remoteBalance = Int(dict["remote_balance"] as! String)!
            if remoteBalance == 0 {
                dict["ratio"] = Float(1)
            } else {
                dict["ratio"] = Float(Double(localBalance) / Double(remoteBalance))
            }
            
            for (key, value) in dict {
                switch key {
                case "local_balance":
                    dict["to_us_msat"] = "\(localBalance * 1000)"
                    dict["spendable_msatoshi"] = Int(value as! String)! * 1000
                case "capacity":
                    dict["total_msat"] = "\(remoteBalance * 1000)"
                case "remote_balance":
                    dict["receivable_msatoshi"] = remoteBalance * 1000
                default:
                    break
                }
            }
                        
            self.channels.append(dict)
            
            if i + 1 == channels.count {
                load()
            }
        }
    }
    
    private func parseCLPeers(_ peers: NSArray) {
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
                                            channels[channels.count - 1]["peerId"] = peerDict["id"] as! String
                                        }
                                    } else {
                                        if state != "CHANNELD_NORMAL" && state != "CHANNELD_AWAITING_LOCKIN" {
                                            channels.append(dict)
                                            channels[channels.count - 1]["peerId"] = peerDict["id"] as! String
                                        }
                                    }
                                }
                            }
                        }
                    }
                    if i + 1 == peers.count {
                        fetchLocalPeers { [weak self] _ in
                            self?.load()
                        }
                    }
                }
            }
        }
    }
    
    private func fetchLocalPeers(completion: @escaping ((Bool)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .peers) { [weak self] peers in
            guard let self = self, let peers = peers, peers.count > 0, self.channels.count > 0 else {
                completion(true)
                return
            }
            
            for (x, peer) in peers.enumerated() {
                let peerStruct = PeersStruct(dictionary: peer)
                
                for (i, p) in self.channels.enumerated() {
                    if p["peerId"] as! String == peerStruct.pubkey {
                        if peerStruct.label == "" {
                            self.channels[i]["name"] = peerStruct.alias
                        } else {
                            self.channels[i]["name"] = peerStruct.label
                        }
                    }
                    
                    if i + 1 == self.channels.count && x + 1 == peers.count {
                        completion(true)
                    }
                }
            }
        }
    }
    
    private func load() {
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
    
    // MARK: - Rebalancing
    
    private func promptToRebalanceLND() {
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Coming soon for LND.", message: "For now rebalancing only works with c-lightning.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToRebalanceCL() {
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Send circular payment to rebalance?", message: "This action depends upon the rebalance.py plugin, if you are not using the plugin then this will not work. It can take up to 60 seconds for this command to complete, it will attempt to rebalance the channel you have selected with an ideal counterpart and strive to acheive a 50/50 balance of incoming and outgoing capacity by routing a payment to yourself from one channel to another.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Rebalance", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                self.spinner.addConnectingView(vc: self, description: "rebalancing, this can take up to 60 seconds...")
                self.parseChannelsForRebalancing()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func parseChannelsForRebalancing() {
        ours.removeAll()
        theirs.removeAll()
        for (i, ch) in channels.enumerated() {
            let ourAmount = ch["to_us_msat"] as? String ?? ""
            let totalAmount = ch["total_msat"] as? String ?? ""
            let ourAmountInt = Int(ourAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let totalAmountInt = Int(totalAmount.replacingOccurrences(of: "msat", with: "")) ?? 0
            let ratio = Double(ourAmountInt) / Double(totalAmountInt)
            if ratio > 0.6 {
                ours.append(ch)
            } else if ratio < 0.4 {
                theirs.append(ch)
            }
            if i + 1 == channels.count {
                selectCounterpart()
            }
        }
    }
    
    private func selectCounterpart() {
        if selectedChannel != nil {
            for ch in ours {
                if ch["short_channel_id"] as! String == selectedChannel!["short_channel_id"] as! String {
                    chooseTheirsCounterpart()
                }
            }
            for ch in theirs {
                if ch["short_channel_id"] as! String == selectedChannel!["short_channel_id"] as! String {
                    chooseOursCounterpart()
                }
            }
        }
    }
    
    private func chooseTheirsCounterpart()  {
        if theirs.count > 0 {
            let sortedArray = theirs.sorted { $0["receivable_msatoshi"] as? Int ?? .zero < $1["receivable_msatoshi"] as? Int ?? .zero }
            let sourceShortId = selectedChannel!["short_channel_id"] as! String
            let destinationShortId = sortedArray[sortedArray.count - 1]["short_channel_id"] as! String
            rebalance(sourceShortId, destinationShortId)
        }
    }
    
    private func chooseOursCounterpart() {
        if ours.count > 0 {
            let sortedArray = ours.sorted { $0["spendable_msatoshi"] as? Int ?? .zero < $1["spendable_msatoshi"] as? Int ?? .zero }
            let sourceShortId = sortedArray[ours.count - 1]["short_channel_id"] as! String
            let destinationShortId = selectedChannel!["short_channel_id"] as! String
            rebalance(sourceShortId, destinationShortId)
        }
    }
    
    private func rebalance(_ source: String, _ destination: String) {
        LightningRPC.command(id: UUID(), method: .rebalance, param: "\"\(source)\", \"\(destination)\"") { [weak self] (id, response, errorDesc) in
            self?.refresh()
            if errorDesc != nil {
               showAlert(vc: self, title: "Error", message: errorDesc!)
            } else if let message = response as? String {
                showAlert(vc: self, title: "⚡️ Success ⚡️", message: message)
            } else {
                
                showAlert(vc: self, title: "", message: "\(String(describing: response))")
            }
        }
    }
    
    private func refresh() {
        channels.removeAll()
        ours.removeAll()
        theirs.removeAll()
        loadChannels()
        spinner.removeConnectingView()
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        if segue.identifier == "segueToChannelDetails" {
//            if let vc = segue.destination as? ChannelDetailViewController {
//                vc.selectedChannel = selectedChannel
//                vc.channels = channels
//                vc.myId = myId
//            }
//        }
//    }

}

// MARK: TODO: Rebalance without the plugin, this code is a start, good luck with that.
/*
 
 /*
 excludes = []
 # excude all own channels to prevent unwanted shortcuts [out,mid,in]
 mychannels = plugin.rpc.listchannels(source=my_node_id)['channels']
 for channel in mychannels:
     excludes += [channel['short_channel_id'] + '/0', channel['short_channel_id'] + '/1']
 */
             
              "amount_msat" = 43151000msat;
              channel = 643463x779x0;
              delay = 9;
              direction = 1;
              id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
              msatoshi = 43151000;
              style = tlv;
              
 //            routeOut = ["amount_msat":"","channel":sourceShortId,"delay":9,"direction": !(myId < source),"id":source,"msatoshi":0,"style":"tlv"]
 //            routeIn = ["amount_msat":"","channel":destinationShortId,"delay":9,"direction": !(destination < myId),"id":myId,"msatoshi":0,"style":"tlv"]
 //            LightningRPC.command(method: .invoice, param: "\(msat), \"rebalance - \(Date())\", \"FullyNoded-\(randomString(length: 5))\"") { [weak self] (response, errorDesc) in
 //                if let dict = response as? NSDictionary {
 //                    if let hash = dict["payment_hash"] as? String {
 //                        self?.paymentHash = hash
 //                        self?.getRoute(destination, msat, source)
 //                    }
 //                }
 //            }
 
 func json(from object:Any) -> String? {
         guard let data = try? JSONSerialization.data(withJSONObject: object, options: []) else {
             return nil
         }
         return String(data: data, encoding: String.Encoding.utf8)
     }
     
     private func getRoute(_ destinationId: String, _ msat: Int, _ fromId: String) {
         //getroute id msatoshi riskfactor [cltv] [fromid] [fuzzpercent] [exclude] [maxhops]
         //getroute(target, msatoshi, riskfactor=1, cltv=9, fromid=source)
         LightningRPC.command(method: .getroute, param: "\"\(destinationId)\", \(msat), 1, 9, \"\(fromId)\", 5.0, \(excludes)") { [weak self] (response, errorDesc) in
             if let dict = response as? NSDictionary {
                 if let route = dict["route"] as? NSArray {
                     for r in route {
                         if let d = r as? NSDictionary {
                             self?.routeMid = d as! [String:Any]
                         }
                         
                         //if self?.json(from: r) != nil {
 //                            var processed = ((self?.json(from: r)?.condenseWhitespace())!).replacingOccurrences(of: "\\", with: "")
 //                            processed = processed.replacingOccurrences(of: "}\"", with: "}")
 //                            processed = processed.replacingOccurrences(of: "\"{", with: "{")
                             
                         //}
                     }
                     self?.getFee(destinationId, msat)
                 }
             } else {
                 if self != nil {
                     let reduced = Int(Double(msat) / 1.1)
                     self?.getRoute(destinationId, reduced, fromId)
                 }
             }
         }
     }
     /*
      route =         (
                      {
              "amount_msat" = 501005msat;
              channel = 643969x194x0;
              delay = 23;
              direction = 0;
              id = 03c304a6a6d64771aa70b05fbe1137dbcc7b585f6150acfd27680cf82c0913e579;
              msatoshi = 501005;
              style = tlv;
          },
                      {
              "amount_msat" = 500000msat;
              channel = 643983x1159x0;
              delay = 9;
              direction = 1;
              id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
              msatoshi = 500000;
              style = tlv;
          }
      )
      */
     
     private func getFee(_ destination: String, _ amount: Int) {
         var msatoshi = amount
         var delay = 9
         let routeGroup = DispatchGroup()
         routes = [routeOut, routeMid, routeIn]
         for (i, r) in routes.reversed().enumerated() {
             routeGroup.enter()
             routes[i]["msatoshi"] = amount
             routes[i]["amount_msat"] = "\(amount)msat"
             routes[i]["delay"] = delay
             if let channel = r["channel"] as? String {
                 LightningRPC.command(method: .listchannels, param: "\"\(channel)\"") { (response, errorDesc) in
                     if let channelsResponse = response as? NSDictionary {
                         if let channels = channelsResponse["channels"] as? NSArray {
                             for channel in channels {
                                 if let d = channel as? [String:Any] {
                                     if d["destination"] as! String == r["id"] as! String {
                                         /*
                                          fee = Millisatoshi(ch['base_fee_millisatoshi'])
                                          # BOLT #7 requires fee >= fee_base_msat + ( amount_to_forward * fee_proportional_millionths / 1000000 )
                                          fee += (msatoshi * ch['fee_per_millionth'] + 10**6 - 1) // 10**6 # integer math trick to round up
                                          msatoshi += fee
                                          delay += ch['delay']
                                          */
                                         
                                         var fee = d["base_fee_millisatoshi"] as! Int
                                         let feePerMillionth = d["fee_per_millionth"] as! Int
                                         fee += Int(Double((amount * feePerMillionth)) / 1000000.0)
                                         msatoshi += fee
                                         delay += d["delay"] as! Int
                                     }
                                 }
                             }
                             routeGroup.leave()
                         }
                     }
                 }
             }
         }
         routeGroup.notify(queue: .main) { [weak self] in
             if self != nil {
                 self?.promptToRebalance(self!.routes.count, msatoshi, msatoshi - amount, amount)
             }
         }
     }
     
     private func promptToRebalance(_ nodeCount: Int, _ totalAmount: Int, _ totalFee: Int, _ originalAmount: Int) {
         DispatchQueue.main.async { [weak self] in
             var alertStyle = UIAlertController.Style.actionSheet
             if (UIDevice.current.userInterfaceIdiom == .pad) {
               alertStyle = UIAlertController.Style.alert
             }
             let alert = UIAlertController(title: "Send circular payment to rebalance?", message: "Route contains \(nodeCount) nodes, amount including the fee: \(totalAmount), total fee: \(totalFee), amount to receive: \(originalAmount)", preferredStyle: alertStyle)
             alert.addAction(UIAlertAction(title: "Send", style: .default, handler: { action in
                 self?.sendNow()
             }))
             alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
             alert.popoverPresentationController?.sourceView = self?.view
             self?.present(alert, animated: true, completion: nil)
         }
     }
     
     //var processed = ((self?.json(from: r)?.condenseWhitespace())!).replacingOccurrences(of: "\\", with: "")
     //                            processed = processed.replacingOccurrences(of: "}\"", with: "}")
     //                            processed = processed.replacingOccurrences(of: "\"{", with: "{")
     
     private func sendNow() {
         
 //        var r = "[{\"id\":\(outgoingId)}, \(routes), {\"id\":\(myId)}]"
 //        r = r.condenseWhitespace()
 //        r = r.replacingOccurrences(of: "\\", with: "")
 //        r = r.replacingOccurrences(of: "}\"", with: "}")
 //        r = r.replacingOccurrences(of: "\"{", with: "{")
         //routeOut = ["amount_msat":"","channel":sourceShortId,"delay":9,"direction": !(myId < source),"id":source,"msatoshi":0,"style":"tlv"]
         //routeIn = ["amount_msat":"","channel":destinationShortId,"delay":9,"direction": !(destination < myId),"id":myId,"msatoshi":0,"style":"tlv"]
         
         let routeOutMsat = routes[0]["amount_msat"] as! String
         let routeOutSourceShortId = routes[0]["channel"] as! String
         let routeOutDirection = (routes[0]["direction"] as! Bool) ? 1 : 0
         let routeOutId = routes[0]["id"] as! String
         let routeOutMsatoshi = routes[0]["msatoshi"] as! Int

         let routeMidMsat = routeMid["amount_msat"] as! String
         let routeMidSourceShortId = routeMid["channel"] as! String
         let routeMidDirection = (routeMid["direction"] as! Bool) ? 1 : 0
         let routeMidId = routeMid["id"] as! String
         let routeMidMsatoshi = routeMid["msatoshi"] as! Int

         let routeInMsat = routes[2]["amount_msat"] as! String
         let routeInSourceShortId = routes[2]["channel"] as! String
         let routeInDirection = (routes[2]["direction"] as! Bool) ? 1 : 0
         let routeInId = routes[2]["id"] as! String
         let routeInMsatoshi = routes[2]["msatoshi"] as! Int
         
         /*
          "amount_msat" = 43151000msat;
                         channel = 643463x779x0;
                         delay = 9;
                         direction = 1;
                         id = 022d89add5b1ec7b5993f9c814c7a5abb83d6baeeb242bffb0dbec1792dc0c7d9b;
                         msatoshi = 43151000;
                         style = tlv;
          */
         
         let processedRoutes = "[[\"msatoshi\":\(routeOutMsatoshi),\"channel\":\"\(routeOutSourceShortId)\",\"delay\":9,\"direction\":\(routeOutDirection),\"id\":\"\(routeOutId)\", \"style\":\"tlv\"], [\"msatoshi\":\(routeMidMsatoshi),\"channel\":\"\(routeMidSourceShortId)\",\"delay\":9,\"direction\":\(routeMidDirection),\"id\":\"\(routeMidId)\", \"style\":\"tlv\"], [\"msatoshi\":\(routeInMsatoshi),\"channel\":\"\(routeInSourceShortId)\",\"delay\":9,\"direction\":\(routeInDirection),\"id\":\"\(routeInId)\", \"style\":\"tlv\"]]"
         LightningRPC.command(method: .sendpay, param: "[\(processedRoutes), \"\(paymentHash)\"") { (response, errorDesc) in
             if let dict = response as? NSDictionary {
                 print("dict: \(dict)")
             }
         }
     }
 private func getChannelToPeer(peerId: String, completion: @escaping ((String?)) -> Void) {
     LightningRPC.command(method: .listpeers, param: "\"\(peerId)\"") { (response, errorDesc) in
         if let dict = response as? NSDictionary {
             print("getPeerDict: \(dict)")
         }
     }
 }
 
 */
