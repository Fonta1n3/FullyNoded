//
//  IncomingsTableViewController.swift
//  BitSense
//
//  Created by Peter on 22/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import NMSSH

class IncomingsTableViewController: UITableViewController, NMSSHChannelDelegate {
    
    var isPruned = Bool()
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    @IBOutlet var incomingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        incomingsTable.tableFooterView = UIView(frame: .zero)
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(),
                                                               for: UIBarMetrics.default)
        
        navigationController?.navigationBar.shadowImage = UIImage()
        
    }
    
    @IBAction func goBack(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2
        
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
                                        height: 60)
        
        explanationLabel.textColor = UIColor.darkGray
        explanationLabel.numberOfLines = 0
        explanationLabel.backgroundColor = UIColor.clear
        footerView.backgroundColor = UIColor.clear
        
        explanationLabel.font = UIFont.init(name: "HiraginoSans-W3",
                                            size: 10)
        
        if section == 0 {
            
            explanationLabel.text = "Create an invoice to receive Bitcoin to your node. Invoices are BIP21 compatible meaning you can add an optional description label and amount. Just tap the QR code or address to copy or save it."
            
        } else if section == 1 {
            
            explanationLabel.text = "Import a private key, address or xpub into your node. You can scan a QR code or type/paste the key manually. XPUBs are BIP84 and will import the first 100 addresses."
            
        }
        
        footerView.addSubview(explanationLabel)
        
        return footerView
        
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 60
        
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "invoiceCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 1 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else {
            
            let cell = UITableViewCell()
            
            return cell
            
        }
        
    }
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row,
                                                           section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                if indexPath.section == 0 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "createInvoice",
                                          sender: self)
                    }
                    
                } else if indexPath.section == 1 {
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "importPrivKey",
                                          sender: self)
                    }
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
    
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
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "createInvoice":
            
            if let vc = segue.destination as? InvoiceViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                
            }
            
        case "importPrivKey":
            
            if let vc = segue.destination as? ImportPrivKeyViewController {
                
                vc.ssh = self.ssh
                vc.makeSSHCall = self.makeSSHCall
                vc.isPruned = self.isPruned
                
            }
            
        default:
            
            break
            
        }
        
    }

}
