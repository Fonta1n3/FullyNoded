//
//  ImportExtendedKeysViewController.swift
//  BitSense
//
//  Created by Peter on 21/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportExtendedKeysViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var dict = [String:Any]()
    var isTestnet = Bool()
    var reScan = Bool()
    var isWatchOnly = Bool()
    var desc = ""
    var importedKey = ""
    var addToKeypool = Bool()
    var isInternal = Bool()
    var range = ""
    var convertedRange = [Int]()
    var descriptor = ""
    var label = ""
    var bip44 = Bool()
    var bip84 = Bool()
    var bip32 = Bool()
    var timestamp = Int()
    @IBOutlet var keyTable: UITableView!
    var keyArray = NSArray()
    let connectingView = ConnectingView()
    var isHDMusig = Bool()
    var address = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        keyTable.delegate = self
        keyTable.dataSource = self
        keyTable.tableFooterView = UIView(frame: .zero)
        
        if let watchOnlyCheck = dict["isWatchOnly"] as? Bool {
            
            isWatchOnly = watchOnlyCheck
            
        }
        
        let str = ImportStruct(dictionary: dict)
        descriptor = str.descriptor
        print("descriptor to import = \(descriptor)")
        label = str.label
        timestamp = str.timeStamp
        isTestnet = str.isTestnet
        let derivation = str.derivation
        range = str.range
        convertedRange = str.convertedRange
        addToKeypool = str.addToKeyPool
        isInternal = str.isInternal
        
        if descriptor.contains("/84'") {
            
            bip84 = true
            bip44 = false
            bip32 = false
            
        } else if descriptor.contains("/44'") {
            
            bip44 = true
            bip84 = false
            bip32 = false
            
        } else {
            
            bip44 = false
            bip84 = false
            bip32 = true
            
        }
        
        switch derivation {
        case "BIP84": bip84 = true
        case "BIP44": bip44 = true
        case "BIP32Segwit": bip32 = true
        case "BIP32Legacy": bip32 = true
        default: break
        }
        
    }
    
    @IBAction func importNow(_ sender: Any) {
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
        }
        
        if !isHDMusig {
            
            importExtendedKey()
            
        } else {
            
            importHDMusig()
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return keyArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.selectionStyle = .none
        
        var index = Int()
        
        if indexPath.row == 0 {
            
            index = convertedRange[0]
            
        } else {
            
            index = convertedRange[0] + indexPath.row
            
        }
        
        cell.textLabel?.text = "Key #\(index):\n\n\(keyArray[indexPath.row] as! String)"
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        return 90
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                self.address = self.keyArray[indexPath.row] as! String
                self.performSegue(withIdentifier: "displayKey", sender: self)
                cell.alpha = 1
                
            })
            
        }
        
    }
    
    func importHDMusig() {
        
        let aes = AESService()
        let cd = CoreDataService()
        let encDesc = aes.encryptKey(keyToEncrypt: descriptor)
        let encLabel = aes.encryptKey(keyToEncrypt: label)
        let encIndex = aes.encryptKey(keyToEncrypt: "\(convertedRange[0])")
        let encRange = aes.encryptKey(keyToEncrypt: range)
        let id = randomString(length: 10)
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !cd.errorBool {
                
                let nodes = cd.entities
                let isActive = isAnyNodeActive(nodes: nodes)
                var nodeID = ""
                
                if isActive {
                    
                    for node in nodes {
                        
                        let active = node["isActive"] as! Bool
                        
                        if active {
                            
                            nodeID = node["id"] as! String
                            
                        }
                        
                    }
                    
                }
                
                let dict = ["descriptor":encDesc,
                            "label":encLabel,
                            "index":encIndex,
                            "range":encRange,
                            "id":id,
                            "nodeID":nodeID]
                
                cd.saveEntity(dict: dict, entityName: .hdWallets) {
                    
                    if !cd.errorBool {
                        
                        let success = cd.boolToReturn
                        
                        if success {
                            
                            let descDict = ["descriptor":encDesc,
                                            "label":encLabel,
                                            "range":encRange,
                                            "id":id,
                                            "nodeID":nodeID]
                            
                            cd.saveEntity(dict: descDict, entityName: .descriptors) {
                                
                                if !cd.errorBool {
                                    
                                    let success = cd.boolToReturn
                                    
                                    if success {
                                        
                                        print("wallet saved")
                                        
                                        self.connectingView.addConnectingView(vc: self,
                                                                              description: "importing 200 BIP32 HD multisig addresses and scripts (index \(self.range)), this can take a little while, sit back and relax 😎")
                                        
                                        let params = "[{ \"desc\": \(self.descriptor), \"timestamp\": \(self.timestamp), \"range\": \(self.convertedRange), \"watchonly\": true, \"label\": \"\(self.label)\" }], ''{\"rescan\": true}''"
                                        
                                        self.executeNodeCommand(method: .importmulti,
                                                                param: params)
                                        
                                    } else {
                                        
                                        displayAlert(viewController: self, isError: true, message: "error saving descriptor: \(cd.errorDescription)")
                                        
                                    }
                                    
                                } else {
                                    
                                    displayAlert(viewController: self, isError: true, message: "error saving descriptor: \(cd.errorDescription)")
                                    
                                }
                                
                            }
                            
                        } else {
                            
                            displayAlert(viewController: self, isError: true, message: "error saving hd wallet: \(cd.errorDescription)")
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self, isError: true, message: cd.errorDescription)
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "error getting nodes")
                
            }
            
        }
        
    }
    
    func importExtendedKey() {
        
        var description = ""
        
        if isWatchOnly {
            
            //its an xpub
            if bip44 {
                
                description = "importing 200 BIP44 keys from xpub (index \(range)), this can take a little while, sit back and relax 😎"
                
            } else if bip84 {
                
                description = "importing 200 BIP84 keys from xpub (index \(range)), this can take a little while, sit back and relax 😎"
                
            } else if bip32 {
                
                description = "importing 200 BIP32 keys from xpub (index \(range)), this can take a little while, sit back and relax 😎"
                
            }
            
        } else {
            
            //its an xprv
            if bip44 {
                
                description = "importing 200 BIP44 keys from xprv (index \(range)), this can take a little while, sit back and relax 😎"
                
            } else if bip84 {
                
                description = "importing 200 BIP84 keys from xprv (index \(range)), this can take a little while, sit back and relax 😎"
                
            } else if bip32 {
                
                description = "importing 200 BIP32 keys from xprv (index \(range)), this can take a little while, sit back and relax 😎"
                
            }
            
        }
        
        connectingView.addConnectingView(vc: self,
                                         description: description)
        
        var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"label\": \"\(label)\", \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
        
        if isInternal {
            
            params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
            
        }
        
        let aes = AESService()
        let cd = CoreDataService()
        let encDesc = aes.encryptKey(keyToEncrypt: descriptor)
        let encLabel = aes.encryptKey(keyToEncrypt: label)
        let encRange = aes.encryptKey(keyToEncrypt: range)
        let id = randomString(length: 10)
        
        cd.retrieveEntity(entityName: .nodes) {
            
            if !cd.errorBool {
                
                let nodes = cd.entities
                let isActive = isAnyNodeActive(nodes: nodes)
                var nodeID = ""
                
                if isActive {
                    
                    for node in nodes {
                        
                        let active = node["isActive"] as! Bool
                        
                        if active {
                            
                            nodeID = node["id"] as! String
                            
                        }
                        
                    }
                    
                }
                
                let descDict = ["descriptor":encDesc,
                                "label":encLabel,
                                "range":encRange,
                                "id":id,
                                "nodeID":nodeID]
                
                cd.saveEntity(dict: descDict, entityName: .descriptors) {
                    
                    if !cd.errorBool {
                        
                        let success = cd.boolToReturn
                        
                        if success {
                            
                            print("descriptor saved")
                            
                            self.executeNodeCommand(method: .importmulti,
                                                    param: params)
                            
                        } else {
                            
                            print("error saving descriptor")
                            
                            self.connectingView.removeConnectingView()
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "error saving your descriptor: \(cd.errorDescription)")
                        }
                        
                    } else {
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: "error saving your descriptor: \(cd.errorDescription)")
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "error getting your descriptor from core data")
                
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .importmulti:
                    
                    let result = reducer.arrayToReturn
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Sucessfully imported the keys!")
                        
                    } else {
                        
                        let errorDict = (result[0] as! NSDictionary)["error"] as! NSDictionary
                        let error = errorDict["message"] as! String
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self,
                                     isError: true,
                                     message: error)
                        
                    }
                    
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        
                        if warnings.count > 0 {
                            
                            for warning in warnings {
                                
                                let warn = warning as! String
                                
                                DispatchQueue.main.async {
                                    
                                    let alert = UIAlertController(title: "Warning",
                                                                  message: warn,
                                                                  preferredStyle: UIAlertController.Style.alert)
                                    
                                    alert.addAction(UIAlertAction(title: "OK",
                                                                  style: UIAlertAction.Style.default,
                                                                  handler: nil))
                                    
                                    self.present(alert,
                                                 animated: true,
                                                 completion: nil)
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "displayKey" {
            
            if let vc = segue.destination as? InvoiceViewController {
                
                vc.isHDMusig = true
                vc.addressString = self.address
                
            }
            
        }
        
    }
    
}
