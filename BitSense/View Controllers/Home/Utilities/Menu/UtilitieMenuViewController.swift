//
//  UtilitieMenuViewController.swift
//  BitSense
//
//  Created by Peter on 12/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UtilitieMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var firstLink = ""
    var activeNode = [String:Any]()
    let connectingView = ConnectingView()
    var getBlockchainInfo = Bool()
    var getAddressInfo = Bool()
    var listAddressGroups = Bool()
    var getNetworkInfo = Bool()
    var getWalletInfo = Bool()
    var getMiningInfo = Bool()
    var decodeScript = Bool()
    var getpeerinfo = Bool()
    var getMempoolInfo = Bool()
    var listLabels = Bool()
    var getaddressesbylabel = Bool()
    var getTransaction = Bool()
    var getbestblockhash = Bool()
    var getblock = Bool()
    var goSign = Bool()
    var goVerify = Bool()
    var getUtxos = Bool()
    var getTxoutset = Bool()
    var decodeRaw = Bool()
    var decodePSBT = Bool()
    var process = Bool()
    var finalize = Bool()
    var analyze = Bool()
    var convert = Bool()
    var txChain = Bool()
    var broadcast = Bool()
    var verify = Bool()
    var combinePSBT = Bool()
    @IBOutlet weak var table: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        table.delegate = self
        table.dataSource = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        getaddressesbylabel = false
        getMiningInfo = false
        getBlockchainInfo = false
        getWalletInfo = false
        getNetworkInfo = false
        listAddressGroups = false
        getAddressInfo = false
        decodeScript = false
        getpeerinfo = false
        getMempoolInfo = false
        listLabels = false
        getTransaction = false
        getbestblockhash = false
        getblock = false
        goVerify = false
        goSign = false
        getUtxos = false
        getTxoutset = false
        verify = false
        broadcast = false
        decodeRaw = false
        decodePSBT = false
        process = false
        finalize = false
        analyze = false
        convert = false
        txChain = false
        combinePSBT = false
        firstLink = ""
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 6
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0: return 2
        case 1: return 8
        case 2: return 12
        case 3: return 7
        case 4: return 2
        case 5: return 1
        default: return 0}
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "toolsCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        switch indexPath.section {
            
        case 0:
            //Identity
            switch indexPath.row {
            case 0: label.text = "Sign Message"
            case 1: label.text = "Verify Message"
            default: break}
            
        case 1:
            
            //Blockchain
            switch indexPath.row {
            case 0: label.text = "Rescan Blockchain"
            case 1: label.text = "Abort Blockchain Rescan"
            case 2: label.text = "Get Blockchain Info"
            case 3: label.text = "Get Mempool Info"
            case 4: label.text = "Get Transaction"
            case 5: label.text = "Get Last Block"
            case 6: label.text = "Get Block"
            case 7: label.text = "Get UTXO Set Info"
            default:break}
            
        case 2:
            //Transactions
            switch indexPath.row {
            case 0: label.text = "Create Raw"
            case 1: label.text = "Sign Raw"
            case 2: label.text = "Decode Raw"
            case 3: label.text = "Verify Raw"
            case 4: label.text = "Broadcast Raw"
            case 5: label.text = "Process PSBT"
            case 6: label.text = "Finalize PSBT"
            case 7: label.text = "Join PSBT"
            case 8: label.text = "Analyze PSBT"
            case 9: label.text = "Convert Raw to PSBT"
            case 10: label.text = "Decode PSBT"
            case 11: label.text = "Combine PSBT"
            default:break}
            
        case 3:
            
            //wallet
            switch indexPath.row {
            case 0: label.text = "Get Address Info"
            case 1: label.text = "List Address Groups"
            case 2: label.text = "Get Wallet Info"
            case 3: label.text = "Decode Script"
            case 4: label.text = "List Labels"
            case 5: label.text = "Addresses By Label"
            case 6: label.text = "UTXO's By Address"
            default:break}
            
        case 4:
            
            //network
            switch indexPath.row {
            case 0: label.text = "Get Network Info"
            case 1: label.text = "Get Peer Info"
            default:break}
            
        case 5:
            
            //mining
            switch indexPath.row {
            case 0: label.text = "Get Mining Info"
            default:break}
            
        default:
            
            break
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
            
        case 0:
            //Identity
            switch indexPath.row {
            case 0: goSign = true
            case 1: goVerify = true
            default: break}
            segue(to: "goSign")
            
        case 1:
            //Blockchain
            switch indexPath.row {
            case 0:
                rescan()
                
            case 1:
                abortRescan()
                
            case 2:
                getBlockchainInfo = true
                segue(to: "goGetInfo")
                
            case 3:
                getMempoolInfo = true
                segue(to: "goGetInfo")
                
            case 4:
                getTransaction = true
                segue(to: "goGetInfo")
                
            case 5:
                getbestblockhash = true
                segue(to: "goGetInfo")
                
            case 6:
                getblock = true
                segue(to: "goGetInfo")
                
            case 7:
                getTxoutset = true
                segue(to: "goGetInfo")
                
            default:
                break
            }
            
        case 2:
            //Transactions
            switch indexPath.row {
            case 0: segue(to: "createUnsigned")//"Create Raw"
            case 1: segue(to: "signRaw")//"Sign Raw"
            case 2: decodeRaw = true; segue(to: "goDecode")//"Decode Raw"
            case 3: verify = true; segue(to: "goDecode")//"Verify Raw"
            case 4: broadcast = true; segue(to: "goDecode")//"Broadcast Raw"
            case 5: process = true; segue(to: "goDecode")//"Process PSBT"
            case 6: finalize = true; segue(to: "goDecode")//"Finalize PSBT"
            case 7: combinePSBT = false; segue(to: "joinPSBT")//"Join PSBT"
            case 8: analyze = true; segue(to: "goDecode")//"Analyze PSBT"
            case 9: convert = true; segue(to: "goDecode")//"Convert Raw to PSBT"
            case 10: decodePSBT = true; segue(to: "goDecode")//"Decode PSBT"
            case 11: combinePSBT = true; segue(to: "joinPSBT")//"Combine PSBT"
            default:break}
            
            
        case 3:
            //wallet
            switch indexPath.row {
            case 0: self.getAddressInfo = true
            case 1: self.listAddressGroups = true
            case 2: self.getWalletInfo = true
            case 3: self.decodeScript = true
            case 4: self.listLabels = true
            case 5: self.getaddressesbylabel = true
            case 6: self.getUtxos = true
            default:break}
            segue(to: "goGetInfo")
            
        case 4:
            //network
            switch indexPath.row {
            case 0: self.getNetworkInfo = true
            case 1: self.getpeerinfo = true
            default:break}
            segue(to: "goGetInfo")
            
        case 5:
            //mining
            switch indexPath.row {
            case 0:
                getMiningInfo = true
                segue(to: "goGetInfo")
            default:
                break
            }
        default:
            break
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
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        switch section {
        case 0:
            textLabel.text = "Identity"
            
        case 1:
            textLabel.text = "Blockchain"
            
        case 2:
            textLabel.text = "Transactions"
            
        case 3:
            textLabel.text = "Wallet"
            
        case 4:
            textLabel.text = "Network"
        
        case 5:
            textLabel.text = "Mining"
            
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
    
    private func rescan() {
        Reducer.makeCommand(command: .rescanblockchain, param: "") { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                displayAlert(viewController: vc, isError: false, message: "Rescanning completed")
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: "Error rescanning: \(errorMessage!)")
                }
            }
        }
    }
    
    private func abortRescan() {
        Reducer.makeCommand(command: .abortrescan, param: "") { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                displayAlert(viewController: vc, isError: false, message: "Rescan aborted")
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: "Error: \(errorMessage!)")
                }
            }
        }
    }
    
    private func segue(to: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: to, sender: vc)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "goGetInfo":
            if let vc = segue.destination as? GetInfoViewController {
                vc.getBlockchainInfo = self.getBlockchainInfo
                vc.getNetworkInfo = self.getNetworkInfo
                vc.listAddressGroups = self.listAddressGroups
                vc.getAddressInfo = self.getAddressInfo
                vc.getWalletInfo = self.getWalletInfo
                vc.getMiningInfo = self.getMiningInfo
                vc.decodeScript = self.decodeScript
                vc.getPeerInfo = self.getpeerinfo
                vc.getMempoolInfo = self.getMempoolInfo
                vc.listLabels = self.listLabels
                vc.getaddressesbylabel = self.getaddressesbylabel
                vc.getTransaction = self.getTransaction
                vc.getbestblockhash = self.getbestblockhash
                vc.getblock = self.getblock
                vc.getUtxos = self.getUtxos
                vc.getTxoutset = self.getTxoutset
            }
            
        case "goSign":
            if let vc = segue.destination as? IdentityViewController {
                vc.sign = goSign
                vc.verify = goVerify
            }
            
        case "goDecode":
            if let vc = segue.destination as? ProcessPSBTViewController {
                vc.decodePSBT = decodePSBT
                vc.decodeRaw = decodeRaw
                vc.process = process
                vc.analyze = analyze
                vc.convert = convert
                vc.finalize = finalize
                vc.txChain = txChain
                vc.firstLink = firstLink
                vc.broadcast = broadcast
                vc.verify = verify
            }
            
        case "joinPSBT":
            if let vc = segue.destination as? JoinPSBTViewController {
                vc.combinePSBT = self.combinePSBT
            }
            
        default:
            break
        }
    }
}
