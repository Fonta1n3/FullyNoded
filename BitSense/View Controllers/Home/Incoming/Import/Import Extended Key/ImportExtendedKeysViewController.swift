//
//  ImportExtendedKeysViewController.swift
//  BitSense
//
//  Created by Peter on 21/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ImportExtendedKeysViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
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
    var fingerprint = ""
    var descriptor = ""
    var label = ""
    var bip44 = Bool()
    var bip84 = Bool()
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
        
        if !isHDMusig {
            
            descriptor = dict["descriptor"] as! String
            label = dict["label"] as! String
            timestamp = dict["rescanDate"] as! Int
            
            if importedKey.hasPrefix("t") {
                
                isTestnet = true
                
            } else {
                
                isTestnet = false
                
            }
            
            if importedKey.hasPrefix("tpub") || importedKey.hasPrefix("xpub") {
                
                isWatchOnly = true
                
            } else {
                
                isWatchOnly = false
                
            }
            
            let derivation = dict["derivation"] as! String
            
            if derivation == "BIP84" {
                
                bip84 = true
                bip44 = false
                
            } else {
                
                bip84 = false
                bip44 = true
                
            }
            
            range = dict["range"] as! String
            convertedRange = dict["convertedRange"] as! [Int]
            fingerprint = dict["fingerprint"] as! String
            addToKeypool = dict["addToKeypool"] as! Bool
            isInternal = dict["addAsChange"] as! Bool
            
        } else {
         
            range = dict["range"] as! String
            convertedRange = dict["convertedRange"] as! [Int]
            descriptor = dict["descriptor"] as! String
            label = dict["label"] as! String
            timestamp = dict["rescanDate"] as! Int
            addToKeypool = false
            isInternal = false
            
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
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
        
        // descriptor and range, encrypt save here
        
        let aes = AESService()
        let cd = CoreDataService()
        let encDesc = aes.encryptKey(keyToEncrypt: descriptor)
        let encLabel = aes.encryptKey(keyToEncrypt: label)
        let encIndex = aes.encryptKey(keyToEncrypt: "\(convertedRange[0])")
        let encRange = aes.encryptKey(keyToEncrypt: range)
        let id = randomString(length: 10)
        
        let dict = ["descriptor":encDesc,
                    "label":encLabel,
                    "index":encIndex,
                    "range":encRange,
                    "id":id]
        
        let walletSaved = cd.saveHDWalletToCoreData(vc: self, walletInfo: dict)
        
        if walletSaved {
            
            print("wallet saved")
            
        } else {
            
            print("error saving wallet")
            
        }
     
        connectingView.addConnectingView(vc: self,
                                         description: "importing 200 HD multisig addresses and scripts (index \(range)), this can take a little while, sit back and relax 😎")
        
        let params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": true, \"label\": \"\(label)\" }], ''{\"rescan\": true}''"
        
        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                   param: params)
        
    }
    
    func importExtendedKey() {
        
        if isWatchOnly {
            
            //its an xpub
            if bip44 {
                
                connectingView.addConnectingView(vc: self,
                                                 description: "importing 200 BIP44 keys from xpub (index \(range)), this can take a little while, sit back and relax 😎")
                
            } else if bip84 {
                
                connectingView.addConnectingView(vc: self,
                                                 description: "importing 200 BIP84 keys from xpub (index \(range)), this can take a little while, sit back and relax 😎")
                
            }
            
        } else {
            
            //its an xprv
            if bip44 {
                
                connectingView.addConnectingView(vc: self,
                                                 description: "importing 200 BIP44 keys from xprv (index \(range)), this can take a little while, sit back and relax 😎")
                
            } else if bip84 {
                
                connectingView.addConnectingView(vc: self,
                                                 description: "importing 200 BIP84 keys from xprv (index \(range)), this can take a little while, sit back and relax 😎")
                
            }
            
        }
        
        var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"label\": \"\(label)\", \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
        
        if isInternal {
            
            params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
            
        }
        
        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                   param: params)
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.importmulti:
                    
                    let result = makeSSHCall.arrayToReturn
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
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh != nil {
         
            if self.ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
         
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Not connected")
            
        }
        
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
