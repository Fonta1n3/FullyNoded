//
//  PSBTMenuTableViewController.swift
//  BitSense
//
//  Created by Peter on 10/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class PSBTMenuTableViewController: UITableViewController {
    
    var activeNode = [String:Any]()
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    @IBOutlet var psbtMenuTable: UITableView!
    
    
    @IBAction func goBack(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        print("ssh is connected = \(self.ssh.session.isConnected)")
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "createPSBT", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 1 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "processPSBT", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 2 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "finalizePSBT", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "default", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
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
                
                if indexPath.section == 0 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "createPSBT", sender: self)
                        
                    }
                    
                } else if indexPath.section == 1 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "processPSBT", sender: self)
                        
                    }
                    
                } else if indexPath.section == 2 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "finalizePSBT", sender: self)
                        
                    }
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
        
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
        
        if section == 0 {
            
            explanationLabel.text = "Create a PSBT"
            
        } else if section == 1 {
            
            explanationLabel.text = "Process a PSBT"
            
        } else if section == 2 {
            
            explanationLabel.text = "Finalize a PSBT"
            
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
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "createPSBT":
            
            if let vc = segue.destination as? CreatePSBTViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                vc.activeNode = self.activeNode
                
            }
            
        case "processPSBT":
            
            if let vc = segue.destination as? ProcessPSBTViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                
            }
            
        case "finalizePSBT":
            
            if let vc = segue.destination as? FinalizePSBTViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                
            }
            
        default:
            
            break
            
        }
        
    }

}
