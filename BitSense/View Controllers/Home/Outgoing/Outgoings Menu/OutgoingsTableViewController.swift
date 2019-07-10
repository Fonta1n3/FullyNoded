//
//  OutgoingsTableViewController.swift
//  BitSense
//
//  Created by Peter on 22/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class OutgoingsTableViewController: UITableViewController {

    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var makeSSHCall:SSHelper!
    var isTestnet = Bool()
    var activeNode = [String:Any]()
    var isUsingSSH = Bool()
    
    @IBOutlet var outgoingsTable: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        outgoingsTable.tableFooterView = UIView(frame: .zero)
        
        self.navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        self.navigationController?.navigationBar.shadowImage = UIImage()
        
    }
    
    @IBAction func goBack(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 6
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
        
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        
        let footerView = UIView()
        let explanationLabel = UILabel()
        
        footerView.frame = CGRect(x: 0,
                                  y: 0,
                                  width: view.frame.size.width,
                                  height: 20)
        
        explanationLabel.frame = CGRect(x: 20,
                                        y: 5,
                                        width: view.frame.size.width - 40,
                                        height: 40)
        
        explanationLabel.textColor = UIColor.darkGray
        explanationLabel.numberOfLines = 0
        explanationLabel.backgroundColor = UIColor.clear
        footerView.backgroundColor = UIColor.clear
        explanationLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 10)
        
        switch section {
        case 0: explanationLabel.text = "Create and decode a raw transaction. The transaction does NOT get broadcast to the network."
        case 1: explanationLabel.text = "See a table of your UTXOs. Manually select them to sweep them or tap the consolidate button to consolidate them. The transaction does NOT get broadcast to the network."
        case 2: explanationLabel.text = "Add a custom amount of recipients and a specific amount for each recipient in one transaction. The transaction does NOT get broadcast to the network."
        case 3: explanationLabel.text = "Create an unsigned transaction with a specified address."
        case 4: explanationLabel.text = "Sign an unsigned transaction with the nodes wallet or with a private key that resides outside of the node."
        case 5: explanationLabel.text = "Go to PSBT's"
        default: break
        }
        
        footerView.addSubview(explanationLabel)
        
        return footerView
        
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 50
        
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView()
        view.backgroundColor = UIColor.clear
        return view
        
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            
            return 20
            
        } else {
            
            return 30
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: "rawCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: "utxoCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: "multiRecipient", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        case 3:
            let cell = tableView.dequeueReusableCell(withIdentifier: "unsignedCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        case 4:
            let cell = tableView.dequeueReusableCell(withIdentifier: "signItCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        case 5:
            let cell = tableView.dequeueReusableCell(withIdentifier: "psbtCell", for: indexPath)
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            return cell
            
        }
        
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                switch indexPath.section {
                    
                case 0:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "createRawNow", sender: self)
                    }
                    
                case 1:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToUtxos", sender: self)
                    }
                    
                case 2:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToMultiOutput", sender: self)
                        
                    }
                    
                case 3:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToUnsigned", sender: self)
                        
                    }
                    
                case 4:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToSignIt", sender: self)
                        
                    }
                    
                case 5:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "goToPSBTs", sender: self)
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "createRawNow":
            
            if let vc = segue.destination as? CreateRawTxViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                vc.isUsingSSH = self.isUsingSSH
                vc.torClient = self.torClient
                vc.torRPC = self.torRPC
                
            }
            
        case "goToUtxos":
            
            if let vc = segue.destination as? UTXOViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                
            }
            
        case "goToMultiOutput":
            
            if let vc = segue.destination as? MultiOutputViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                
            }
            
        case "goToUnsigned":
            
            if let vc = segue.destination as? UnsignedViewController {
                
                vc.makeSSHCall = self.makeSSHCall
                vc.ssh = self.ssh
                
            }
            
        case "goToSignIt":
            
            if let vc = segue.destination as? SignRawViewController {
                
                vc.makeSSHCall = self.makeSSHCall
                vc.ssh = self.ssh
                vc.isTestnet = self.isTestnet
                vc.activeNode = self.activeNode
                
            }
            
        case "goToPSBTs":
            
            if let navController = segue.destination as? UINavigationController {
                
                if let childVC = navController.topViewController as? PSBTMenuTableViewController {
                    
                    childVC.ssh = self.ssh
                    childVC.makeSSHCall = self.makeSSHCall
                    childVC.activeNode = self.activeNode
                    
                }
                
            }
            
        default:
            
            break
            
        }
        
    }

}
