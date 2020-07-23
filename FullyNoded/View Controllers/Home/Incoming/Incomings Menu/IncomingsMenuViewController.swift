//
//  IncomingsMenuViewController.swift
//  BitSense
//
//  Created by Peter on 29/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class IncomingsMenuViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var isSingleKey = Bool()
    var isPrivKey = Bool()
    var isPruned = Bool()
    var isTestnet = Bool()
    var isExtendedKey = Bool()
    let cd = CoreDataService()
    var descriptors = [[String:Any]]()
    @IBOutlet var incomingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        incomingsTable.tableFooterView = UIView(frame: .zero)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        descriptors.removeAll()
        isPrivKey = false
        isSingleKey = false
        showAlert(vc: self, title: "Warning!", message: "Extreme care should be taken when importing public keys (xpubs, ypubs, zpubs) into your node and then using the addresses your node creates to receive funds to. If you do not absolutely know and understand what you are doing then do not do it. When importing keys Fully Noded always displays the addresses for you to confirm before it imports them, if the addresses to do not match what you expect them to then do not import them!")
    }
    
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2//4
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        var numberOfRows = 0
        switch section {
        case 0: numberOfRows = 7//2
        case 1: numberOfRows = 1//7
        //case 2: numberOfRows = 1
        //case 3: numberOfRows = 3
        default:
            break
        }
        
        return numberOfRows
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "importCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        var labelString = ""
        
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:labelString = "Address"
            case 1:labelString = "Public key"
            case 2:labelString = "Private key"
            case 3:labelString = "XPUB"
            case 4:labelString = "XPRV"
            case 5:labelString = "Multisig"
            case 6:labelString = "Descriptor"
            default:
                break
            }
            label.text = labelString
            
        case 1:
            switch indexPath.row {
            case 0:labelString = "Descriptors"
            default:
                break
            }
            label.text = labelString
            
        default:
            break
        }
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
            
        case 0:
            
            DispatchQueue.main.async {
                
                var segueString = ""
                
                switch indexPath.row {
                    
                case 2:
                    
                    segueString = "importAKey"
                    self.isPrivKey = true
                    self.isSingleKey = true
                    
                case 3, 4:
                    
                    segueString = "goImportExtendedKeys"
                    
                case 5:
                    
                    segueString = "importMultiSig"
                    
                case 6:
                    
                    segueString = "importDescriptor"
                    
                default:
                    
                    segueString = "importAKey"
                    self.isSingleKey = true
                    
                }
                
                self.performSegue(withIdentifier: segueString,
                                  sender: self)
            }
            
        case 1:
            
            CoreDataService.retrieveEntity(entityName: .newDescriptors) { descs in
                if descs != nil {
                    self.descriptors = descs!
                    if self.descriptors.count > 0 {
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "showDescriptors",
                                              sender: self)
                            
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "no xpubs, xprvs or multisig wallets imported yet")
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self, isError: true, message: "error getting descriptors from core data")
                    
                }
                
            }
            
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
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
            textLabel.text = "Import"
            
        case 1:
            textLabel.text = "Export"
            
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "importAKey":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isSingleKey = isSingleKey
                vc.isPrivKey = isPrivKey
            }
            
        case "importMultiSig":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isSingleKey = false
                vc.isPrivKey = false
                vc.isMultisig = true
            }
            
        case "showDescriptors":
            
            if let vc = segue.destination as? DescriptorsViewController {
                
                vc.descriptors = descriptors
                
            }
            
        case "importDescriptor":
            
            if let vc = segue.destination as? AddLabelViewController {
                
                vc.isDescriptor = true
                vc.isSingleKey = false
                vc.isMultisig = false
                
            }
            
        default:
            
            break
            
        }
        
    }
    
}