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
    @IBOutlet weak var nodeTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        nodeTable.delegate = self
        nodeTable.dataSource = self
        iconBackground.layer.cornerRadius = 5
        getInfo()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showInactive = false
        showActive = false
        showPending = false
        
        if newlyAdded {
            newlyAdded = false
            showAlert(vc: self, title: "⚡️ Lightning Node added ⚡️", message: "We are now fecthing info from your node, to view this screen from now on just tap the ⚡️ on the home screen to toggle between Lightning and onchcain.")
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
                let version = dict["version"] as? String ?? ""
                if self != nil {
                    self?.color = dict["color"] as? String ?? "03c304"
                    self?.myId = id
                    self?.tableArray.append(alias)
                    self?.tableArray.append("\(num_peers)")
                    self?.tableArray.append("\(num_active_channels)")
                    self?.tableArray.append("\(num_inactive_channels)")
                    self?.tableArray.append("\(num_pending_channels)")
                    self?.tableArray.append(feesCollected)
                    self?.tableArray.append(version)
                    self!.url = "\(id)@\(ip):\(port)"
                }
                DispatchQueue.main.async { [weak self] in
                    
                    self?.nodeTable.reloadData()
                }
                self?.spinner.removeConnectingView()
                
            } else {
                self?.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorDesc ?? "error getting info from lightning node")
            }
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
        let value = tableArray[indexPath.section]
        label.text = value
        /*
        self?.tableArray[0]["alias"] = alias
        self?.tableArray[1]["peers"] = "\(num_peers)"
        self?.tableArray[2]["activeChannels"] = "\(num_active_channels)"
        self?.tableArray[3]["inactiveChannels"] = "\(num_inactive_channels)"
        self?.tableArray[4]["pendingChannels"] = "\(num_pending_channels)"
        self?.tableArray[5]["feesCollected"] = feesCollected
        self?.tableArray[6]["version"] = version
        */
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
            textLabel.text = "Pending Channels"
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
    
    func hexStringToUIColor (hex:String) -> UIColor {
        var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        if (cString.hasPrefix("#")) {
            cString.remove(at: cString.startIndex)
        }

        if ((cString.count) != 6) {
            return UIColor.gray
        }

        var rgbValue:UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)

        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    // MARK: - Navigation
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller
        
        if segue.identifier == "segueToShareLightningUrl" {
            if let vc = segue.destination as? QRDisplayerViewController {
                vc.text = url
            }
        }
        
        if segue.identifier == "segueToLightningChannels" {
            if let vc = segue.destination as? LightningChannelsViewController {
                vc.myId = myId
                vc.showPending = showPending
                vc.showActive = showActive
                vc.showInactive = showInactive
            }
        }
    }
}

