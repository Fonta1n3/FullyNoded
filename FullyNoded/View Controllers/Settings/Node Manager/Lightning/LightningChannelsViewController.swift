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
    var outgoingChannel:[String:Any]?
    var incomingChannel:[String:Any]?

    @IBOutlet weak var header: UILabel!
    @IBOutlet weak var channelsTable: UITableView!
    @IBOutlet weak var iconBackground: UIView!
    @IBOutlet weak var iconHeader: UIImageView!
    @IBOutlet weak var totalReceivableLabel: UILabel!
    @IBOutlet weak var totalSpendableLabel: UILabel!
    @IBOutlet weak var oursIcon: UILabel!
    @IBOutlet weak var theirsIcon: UILabel!
    @IBOutlet weak var ourBalanceLabel: UILabel!
    @IBOutlet weak var theirBalanceLabel: UILabel!
    @IBOutlet weak var rebalanceOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        channelsTable.delegate = self
        channelsTable.dataSource = self
        
        iconBackground.clipsToBounds = true
        iconBackground.layer.cornerRadius = 5
        
        oursIcon.clipsToBounds = true
        oursIcon.layer.cornerRadius = oursIcon.frame.width / 2
        
        theirsIcon.clipsToBounds = true
        theirsIcon.layer.cornerRadius = theirsIcon.frame.width / 2
        
        totalReceivableLabel.text = ""
        totalSpendableLabel.text = ""
        
        if showPending {
            rebalanceOutlet.alpha = 0
            theirBalanceLabel.alpha = 0
            ourBalanceLabel.alpha = 0
            oursIcon.alpha = 0
            theirsIcon.alpha = 0
            header.text = "Pending Channels"
            iconBackground.backgroundColor = .systemOrange
            iconHeader.image = UIImage(systemName: "hourglass")
        } else if showActive {
            header.text = "Active Channels"
            iconBackground.backgroundColor = .systemBlue
            iconHeader.image = UIImage(systemName: "slider.horizontal.3")
        } else {
            rebalanceOutlet.alpha = 0
            theirBalanceLabel.alpha = 0
            ourBalanceLabel.alpha = 0
            oursIcon.alpha = 0
            theirsIcon.alpha = 0
            header.text = "Inactive Channels"
            iconBackground.backgroundColor = .systemIndigo
            iconHeader.image = UIImage(systemName: "moon.zzz")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            self.lndNode = isLnd
            self.channels.removeAll()
            self.loadChannels()
        }
    }
    
    
    @IBAction func addChannel(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToCreateChannel", sender: self)
        }
    }
    
    @IBAction func rebalanceAction(_ sender: Any) {
        if lndNode {
            showAlert(vc: self, title: "Rebalance Channels", message: "For best results tap an outgoing channel which has a higher balance on the spendable side, when prompted tap an incoming channel where the receivable balance is higher. The goal is to get a 50/50 balance in each channel. Fully Noded will automatically determine the ideal amount to send to rebalance the channel and get your confirmation before sending funds.")
        } else {
            showAlert(vc: self, title: "Rebalance Channels", message: "This action depends upon the rebalance.py plugin. If you have the plugin installed simply tap a channel to rebalance, this command can take a bit of time.")
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
            cell.layer.borderColor = UIColor.lightGray.cgColor
            cell.layer.borderWidth = 0.5
            
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
        } else if showPending {
            let cell = tableView.dequeueReusableCell(withIdentifier: "channelCell", for: indexPath)
            cell.selectionStyle = .none
            cell.layer.borderColor = UIColor.lightGray.cgColor
            cell.layer.borderWidth = 0.5
            
            let dict = channels[indexPath.section]
            let state = dict["state"] as? String ?? dict["peerId"] as? String ?? "?"
            cell.textLabel?.text = state
            cell.textLabel?.textColor = .lightGray
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "channelCell", for: indexPath)
            cell.selectionStyle = .none
            cell.layer.borderColor = UIColor.lightGray.cgColor
            cell.layer.borderWidth = 0.5
            
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
            
            let closeButton = UIButton()
            let closeImage = UIImage(systemName: "xmark.circle")!
            closeButton.tag = section
            closeButton.tintColor = .systemTeal
            closeButton.setImage(closeImage, for: .normal)
            closeButton.addTarget(self, action: #selector(closeChannel(_:)), for: .touchUpInside)
            closeButton.frame = CGRect(x: header.frame.maxX - 50, y: 0, width: 40, height: 40)
            closeButton.center.y = textLabel.center.y
            closeButton.showsTouchWhenHighlighted = true
            header.addSubview(closeButton)
            
        } else {
            if let name = dict["name"] as? String ?? dict["peerId"] as? String {
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
        guard channels.count > 1 else {
            showAlert(vc: self, title: "You need more then 1 channel to rebalance.", message: "")
            return
        }
        
        if showActive && !lndNode {
            selectedChannel = channels[indexPath.section]
            promptToRebalanceCL()
        } else if lndNode && showActive {
            if outgoingChannel == nil {
                outgoingChannel = channels[indexPath.section]
                userSelectedOutgoing()
            } else {
                incomingChannel = channels[indexPath.section]
                userSelectedIncoming()
            }
        }
    }
    
    @objc func closeChannel(_ sender: UIButton) {
        promptToCloseChannel(channel: channels[sender.tag])
    }
    
    private func promptToCloseChannel(channel: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            let alertStyle = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: "Close channel?", message: "This action will start the process of closing this channel.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Close", style: .destructive, handler: { [weak self] action in
                guard let self = self else { return }
                
                if self.lndNode {
                    self.spinner.addConnectingView(vc: self, description: "closing...")
                    self.closeChannelLnd(channel: channel)
                } else {
                    activeWallet { [weak self] wallet in
                        guard let self = self else { return }
                        
                        guard let wallet = wallet else {
                            self.spinner.addConnectingView(vc: self, description: "closing...")
                            self.closeChannelCL(channel, nil)
                            return
                        }
                        
                        if let close_to_addr = channel["close_to_addr"] as? String {
                            if close_to_addr != "" {
                                self.spinner.addConnectingView(vc: self, description: "closing...")
                                self.closeChannelCL(channel, nil)
                            } else {
                                self.getAddress(wallet, channel)
                            }
                        } else {
                            self.getAddress(wallet, channel)
                        }
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func promptToUseClosingAddress(_ wallet: Wallet, _ address: String, _ channel: [String:Any]) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alertStyle = UIAlertController.Style.alert
            let tit = "Automatically send your channel funds to \(wallet.label)?"
            let mess = "This means funds will automatically be sent to \(wallet.label) when the channel closes. This is NOT reversible!\n\nAddress: \(address)"
            
            let alert = UIAlertController(title: tit, message: mess, preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Send to \(wallet.label)", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                self.spinner.addConnectingView(vc: self, description: "closing...")
                
                CoreDataService.update(id: wallet.id, keyToUpdate: "index", newValue: Int64(Int(wallet.index) + 1), entity: .wallets) { _ in }
                
                self.closeChannelCL(channel, address)
            }))
            
            alert.addAction(UIAlertAction(title: "Use Lightning wallet", style: .default, handler: { [weak self] action in
                guard let self = self else { return }
                self.spinner.addConnectingView(vc: self, description: "closing...")
                
                self.closeChannelCL(channel, nil)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func getAddress(_ wallet: Wallet, _ channel: [String:Any]) {
        let index = Int(wallet.index) + 1
        let param:Derive_Addresses = .init(["descriptor": wallet.receiveDescriptor, "range":[index,index]])
        Reducer.sharedInstance.makeCommand(command: .deriveaddresses(param: param)) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let addresses = response as? NSArray, let address = addresses[0] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "", message: errorMessage ?? "error getting closing address")
                return
            }
            
            self.promptToUseClosingAddress(wallet, address, channel)
        }
    }
    
    private func closeChannelCL(_ channel: [String:Any], _ address: String?) {
        let commandId = UUID()
        let channelId = channel["channel_id"] as! String
        var param:[String:Any] = [:]
        param["id"] = channelId
        if let closingAddress = address {
            param["destination"] = closingAddress
        }
        
        LightningRPC.sharedInstance.command(id: commandId, method: .close, param: param) { [weak self] (id, response, errorDesc) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard errorDesc == nil else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error disconnecting peer")
                return
            }
            
            guard let response = response as? [String:Any] else {
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error disconnecting peer")
                return
            }
            
            if let message = response["message"] as? String {
                showAlert(vc: self, title: "Error disconnecting peer.", message: message)
            } else {
                showAlert(vc: self, title: "Channel disconnected ⚡️", message: "")
                self.loadChannels()
                return
            }
        }
    }
    
    private func closeChannelLnd(channel: [String:Any]) {
        guard let channelPoint = channel["channel_point"] as? String else { return }
        
        let arr = channelPoint.split(separator: ":")
        
        guard arr.count > 0 else { return }
        
        let fundingTxid = "\(arr[0])"
        let index = Int64(arr[1])!
        
        let ext = "\(fundingTxid)/\(index)"
        LndRpc.sharedInstance.command(.closechannel, nil, ext, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            self.spinner.removeConnectingView()
            
            guard let _ = response else {
                showAlert(vc: self, title: "Error", message: "We did not get a response from your node.")
                return
            }
            
            showAlert(vc: self, title: "Channel is being closed ✓", message: "")
        }
    }
    
    private func rebalanceChannel() {
        let ourAmountOutgoing = Int(self.outgoingChannel!["local_balance"] as! String)!
        let theirAmountOutgoing = Int(self.outgoingChannel!["remote_balance"] as! String)!
        let totalOutgoingChannelBalance = ourAmountOutgoing + theirAmountOutgoing
        let targetOutgoingBalance = totalOutgoingChannelBalance / 2
        let idealOutgoingAmount = ourAmountOutgoing - targetOutgoingBalance
        
        let ourAmountIncoming = Int(self.incomingChannel!["local_balance"] as! String)!
        let theirAmountIncoming = Int(self.incomingChannel!["remote_balance"] as! String)!
        let totalIncomingChannelBalance = ourAmountIncoming + theirAmountIncoming
        let targetIncomingBalance = totalIncomingChannelBalance / 2
        let idealIncomingAmount = theirAmountIncoming - targetIncomingBalance
        
        var idealAmount = 0
        if idealOutgoingAmount < idealIncomingAmount {
            idealAmount = idealOutgoingAmount
        } else {
            idealAmount = idealIncomingAmount
        }
        
        self.promptToBalanceLndIdealAmount(amount: idealAmount)
    }
    
    private func promptToBalanceLndIdealAmount(amount: Int) {
        DispatchQueue.main.async { [weak self] in
            let alertStyle = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: "Confirm Amount", message: "The ideal amount to rebalance with is \(amount) sats.", preferredStyle: alertStyle)
            
            alert.addAction(UIAlertAction(title: "Rebalance \(amount) sats", style: .default, handler: { action in
                self?.addRebalanceInvoice(amount: amount)
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                self?.outgoingChannel = nil
                self?.incomingChannel = nil
            }))
            
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func addRebalanceInvoice(amount: Int) {
        spinner.addConnectingView(vc: self, description: "Rebalancing...")
        
        guard let preimage = secret() else { return }
        
        let hash = Crypto.sha256hash(preimage)
        let b64 = hash.base64EncodedString()
        
        let outgoingId = self.outgoingChannel!["chan_id"] as! String
        let incomingId = self.incomingChannel!["remote_pubkey"] as! String
        let incomingChanId = self.incomingChannel!["chan_id"] as! String
        
        
        guard let lastHopPubkeyData = Data(hexString: incomingId), let ourPubkey = UserDefaults.standard.object(forKey: "LightningPubkey") as? String, let destData = Data(hexString: ourPubkey) else {
            showAlert(vc: self, title: "Pubkey missing.", message: "Go back, refresh the lightning home screen and try again.")
            return
        }
        
        let lastHopPubkey = lastHopPubkeyData.base64EncodedString()
        let dest = destData.base64EncodedString()
        
        guard lastHopPubkey != "", dest != "" else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Pubkey missing.", message: "Go back, refresh the lightning home screen and try again.")
            return
        }
        
        let memo = "Fully Noded Rebalance ⚡️ - \(outgoingId) to \(incomingChanId)"
        
        let param:[String:Any] = ["memo": memo,
                                  "value": "\(amount)",
                                  "hash":b64,
                                  "r_preimage": preimage.base64EncodedString(),
                                  "is_keysend": true]
        
        LndRpc.sharedInstance.command(.addinvoice, param, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }

            guard let dict = response,
                  let invoice = dict["payment_request"] as? String,
                  let payment_addr = dict["payment_addr"] as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "we had an issue getting your lightning invoice")
                return
            }

            self.rebalanceLndNow(amount, outgoingId, lastHopPubkey, invoice, dest, b64, payment_addr, memo)
        }
    }
    
    private func rebalanceLndNow(_ amount: Int,
                                 _ outgoingId: String,
                                 _ lastHopPubkey: String,
                                 _ invoice: String,
                                 _ dest: String,
                                 _ hash: String,
                                 _ payment_addr: String,
                                 _ memo: String) {
        print("dest: \(dest)")
        let paymentParam:[String:Any] = ["allow_self_payment":true,
                                         "outgoing_chan_id": outgoingId,
                                         "last_hop_pubkey": lastHopPubkey,
                                         "payment_request": invoice,
                                         "dest": dest,
                                         "amt":"\(amount)",
                                         "payment_hash": hash,
                                         "payment_addr": payment_addr]
        
        LndRpc.sharedInstance.command(.keysend, paymentParam, nil, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response else {
                self.spinner.removeConnectingView()
                self.outgoingChannel = nil
                self.incomingChannel = nil
                showAlert(vc: self, title: "There was an issue.", message: error ?? "Unknown error when rebalancing.")
                return
            }

            if let payment_error = response["payment_error"] as? String, payment_error != "" {
                self.spinner.removeConnectingView()
                self.outgoingChannel = nil
                self.incomingChannel = nil
                showAlert(vc: self, title: "There was an issue while attempting to rebalance.", message: payment_error)
            } else {
                self.outgoingChannel = nil
                self.incomingChannel = nil
                self.decodePayreq(memo: memo, payreq: invoice, sats: amount)
            }
        }
    }
    
    private func decodePayreq(memo: String, payreq: String, sats: Int) {
        LndRpc.sharedInstance.command(.decodepayreq, nil, payreq, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let response = response, let paymentHash = response["payment_hash"] as? String else {
                return
            }
            
            self.saveTx(memo: memo, hash: paymentHash, sats: sats)
        }
    }
    
    private func saveTx(memo: String, hash: String, sats: Int) {
        FiatConverter.sharedInstance.getFxRate { [weak self] fxRate in
            guard let self = self else { return }
            
            let fiatCurrency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
            
            var dict:[String:Any] = ["txid":hash,
                                     "id":UUID(),
                                     "memo":memo,
                                     "date":Date(),
                                     "label":"Fully Noded Rebalance ⚡️",
                                     "fiatCurrency": fiatCurrency]
            
            self.spinner.removeConnectingView()
            
            let tit = "Rebalance Success ⚡️"
            
            guard let originRate = fxRate else {
                CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
                
                showAlert(vc: self, title: tit, message: "\n\(sats) sats rebalanced.")
                return
            }
            
            dict["originFxRate"] = originRate
                        
            let mess = "\n\(sats) sats / \((sats.satsToBtcDouble * originRate).balanceText) rebalanced."
            
            showAlert(vc: self, title: tit, message: mess)
            
            CoreDataService.saveEntity(dict: dict, entityName: .transactions) { _ in }
        }
    }
    
    private func secret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        
        guard result == errSecSuccess else {
            print("Problem generating random bytes")
            return nil
        }
        
        return Data(bytes)
    }
    
    private func loadChannels() {
        spinner.addConnectingView(vc: self, description: "getting channels...")
        self.channels.removeAll()
        
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
            let query:[String:Any] = ["inactive_only":showInactive,"active_only":showActive]
            
            LndRpc.sharedInstance.command(.listchannels, nil, nil, query ) { [weak self] (response, error) in
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
        LndRpc.sharedInstance.command(.listchannels, nil, "pending", nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            let waiting_close_channels = response?["waiting_close_channels"] as? NSArray ?? []
            let pending_force_closing_channels = response?["pending_force_closing_channels"] as? NSArray ?? []
            let pending_open_channels = response?["pending_open_channels"] as? NSArray ?? []
            let pending_closing_channels = response?["pending_closing_channels"] as? NSArray ?? []
            
            guard waiting_close_channels.count > 0 || pending_force_closing_channels.count > 0 || pending_open_channels.count > 0 || pending_closing_channels.count > 0 else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "No pending channels.", message: "Tap the + button to connect to a peer and start a channel.")
                return
            }
            
            var allPendingChannels:[[String:Any]] = []
            
            for channel in waiting_close_channels {
                var channelDict = (channel as! [String:Any])["channel"] as! [String:Any]
                channelDict["state"] = "waiting_close"
                allPendingChannels.append(channelDict)
            }
            
            for channel in pending_force_closing_channels {
                var channelDict = (channel as! [String:Any])["channel"] as! [String:Any]
                channelDict["state"] = "pending_force_close"
                allPendingChannels.append(channelDict)
            }
            
            for channel in pending_open_channels {
                var channelDict = (channel as! [String:Any])["channel"] as! [String:Any]
                channelDict["state"] = "pending_open"
                allPendingChannels.append(channelDict)
            }
            
            for channel in pending_closing_channels {
                var channelDict = (channel as! [String:Any])["channel"] as! [String:Any]
                channelDict["state"] = "pending_close"
                allPendingChannels.append(channelDict)
            }
            
            self.parsePendingLNDChannels(allPendingChannels)
        }
    }
    
    private func loadCLPeers() {
        let commandId = UUID()
        LightningRPC.sharedInstance.command(id: commandId, method: .listpeers, param: nil) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let peers = dict["peers"] as? NSArray else {
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
        var totalSpendable = 0
        var totalReceivable = 0
        
        for (i, channel) in channels.enumerated() {
            var dict = channel as! [String:Any]
            
            let localBalance = Int(dict["local_balance"] as! String)!
            totalSpendable += localBalance
            
            let remoteBalance = Int(dict["remote_balance"] as! String)!
            totalReceivable += remoteBalance
            
            if remoteBalance == 0 {
                dict["ratio"] = Float(1)
            } else {
                let total = Double(localBalance) + Double(remoteBalance)
                let ratio = (total - Double(remoteBalance)) / total
                dict["ratio"] = Float(ratio)
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
            
            if showInactive {
                if let active = dict["active"] as? Bool, !active {
                    self.channels.append(dict)
                }
            } else {
                self.channels.append(dict)
            }
                        
            
            
            if i + 1 == channels.count {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.totalSpendableLabel.text = "Total spendable: \(totalSpendable.withCommas) sats"
                    self.totalReceivableLabel.text = "Total receivable: \(totalReceivable.withCommas) sats"
                }
                
                fetchLocalPeers { [weak self] _ in
                    guard let self = self else { return }
                    
                    self.load()
                }
            }
        }
    }
    
    private func parsePendingLNDChannels(_ channels: [[String:Any]]) {
        for (i, channel) in channels.enumerated() {
            var dict = channel
            dict["peerId"] = dict["remote_node_pub"] as! String
            
            self.channels.append(dict)
            
            if i + 1 == channels.count {
                fetchLocalPeers { [weak self] _ in
                    self?.load()
                }
            }
        }
    }
    
    private func parseCLPeers(_ peers: NSArray) {
        var totalSpendable = 0.0
        var totalReceivable = 0.0
        
        for (i, peer) in peers.enumerated() {
            if let peerDict = peer as? [String:Any] {
                if let channls = peerDict["channels"] as? NSArray {
                    if channls.count > 0 {
                        for ch in channls {
                            if let dict = ch as? [String:Any] {
                                
                                if let spendable = dict["spendable_msatoshi"] as? Double {
                                    totalSpendable += spendable / 1000.0
                                }
                                
                                if let receivable = dict["receivable_msatoshi"] as? Double {
                                    totalReceivable += receivable / 1000.0
                                }
                                
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
                         DispatchQueue.main.async { [weak self] in
                             guard let self = self else { return }
                             
                             self.totalSpendableLabel.text = "Total spendable: \(totalSpendable.withCommas) sats"
                             self.totalReceivableLabel.text = "Total receivable: \(totalReceivable.withCommas) sats"
                         }
                         
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
                    if (p["peerId"] as? String ?? p["remote_pubkey"] as? String) == peerStruct.pubkey {
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
    
    private func userSelectedOutgoing() {
        let ourAmountOutgoing = Int(self.outgoingChannel!["local_balance"] as! String)!
        let theirAmountOutgoing = Int(self.outgoingChannel!["remote_balance"] as! String)!
        let name = self.outgoingChannel!["name"] as? String
        let fallback = self.outgoingChannel!["remote_pubkey"] as? String ?? ""
        
        guard ourAmountOutgoing > theirAmountOutgoing else {
            self.outgoingChannel = nil
            self.incomingChannel = nil
            
            showAlert(vc: self, title: "Try Again", message: "Choose an outgoing channel which has a significantly higher spendable balance then receivable.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Rebalance?", message: "We will use this channel for the outgoing payment. Now tap the channel to use for the incoming payment to continue.\n\n\(name ?? fallback)", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                self?.outgoingChannel = nil
                self?.incomingChannel = nil
            }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true, completion: nil)
        }
    }
    
    private func userSelectedIncoming() {
        let ourAmountIncoming = Int(self.incomingChannel!["local_balance"] as! String)!
        let theirAmountIncoming = Int(self.incomingChannel!["remote_balance"] as! String)!
        let name = self.incomingChannel!["name"] as? String
        let fallback = self.incomingChannel!["remote_pubkey"] as? String ?? ""
        
        guard theirAmountIncoming > ourAmountIncoming else {
            self.outgoingChannel = nil
            self.incomingChannel = nil
            
            showAlert(vc: self, title: "Try Again", message: "Choose an incoming channel which has a significantly higher receivable balance then spendable.")
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Rebalance?", message: "We will use this channel for the incoming payment.\n\n\(name ?? fallback)", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Rebalance Now", style: .default, handler: { action in
                self?.rebalanceChannel()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { [weak self] action in
                self?.outgoingChannel = nil
                self?.incomingChannel = nil
            }))
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
            let alert = UIAlertController(title: "Send circular payment to rebalance?", message: "This action depends upon the rebalance.py plugin, if you are not using the plugin then this will not work and the spinner will never go away. It can take up to 60 seconds for this command to complete.", preferredStyle: alertStyle)
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
        if selectedChannel != nil && ours.count > 0 && theirs.count > 0 {
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
        } else {
            spinner.removeConnectingView()
            showAlert(vc: self, title: "Rebalancing issue...", message: "It does not look like you have enough suitable channels to rebalance with. This can usually happen if all your channels are 100% spendable or receivable.")
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
        //outgoing_scid incoming_scid
        let p:[String:Any] = ["outgoing_scid": source, "incoming_scid": destination]
        LightningRPC.sharedInstance.command(id: UUID(), method: .rebalance, param: p) { [weak self] (id, response, errorDesc) in
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
