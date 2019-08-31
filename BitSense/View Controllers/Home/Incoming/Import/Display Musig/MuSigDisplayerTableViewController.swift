//
//  MuSigDisplayerTableViewController.swift
//  BitSense
//
//  Created by Peter on 18/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class MuSigDisplayerTableViewController: UITableViewController {
    
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var p2sh = Bool()
    var p2shP2wsh = Bool()
    var p2wsh = Bool()
    var sigsRequired = ""
    var pubkeyArray = [String]()
    
    let qrGenerator = QRGenerator()
    let connectingView = ConnectingView()
    
    var shareRedScriptQR = UITapGestureRecognizer()
    var shareAddressQR = UITapGestureRecognizer()
    var shareRedScriptText = UITapGestureRecognizer()
    var shareAddressText = UITapGestureRecognizer()
    
    var address = ""
    var script = ""
    
    var addToKeypool = false
    var reScan = Bool()
    
    @IBAction func back(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        shareRedScriptQR = UITapGestureRecognizer(target: self, action: #selector(self.shareRedQR(_:)))
        shareAddressQR = UITapGestureRecognizer(target: self, action: #selector(self.shareAddressQR(_:)))
        shareRedScriptText = UITapGestureRecognizer(target: self, action: #selector(self.shareRedTxt(_:)))
        shareAddressText = UITapGestureRecognizer(target: self, action: #selector(self.shareAddressTxt(_:)))
        
        getSettings()
        
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
    
    func getSettings() {
        
        let userDefaults = UserDefaults.standard
        
        if userDefaults.object(forKey: "addToKeypool") != nil {
            
            addToKeypool = userDefaults.bool(forKey: "addToKeypool")
            
        }
        
        if userDefaults.object(forKey: "reScan") != nil {
            
            reScan = userDefaults.bool(forKey: "reScan")
            
        } else {
            
            reScan = false
            
        }
        
        if reScan {
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Alert",
                                              message: "You have enabled rescanning of the blockchain in settings.\n\nWhen you import a key it will take up to an hour to rescan the entire blockchain.", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: "OK",
                                              style: UIAlertAction.Style.default,
                                              handler: nil))
                
                self.present(alert,
                             animated: true,
                             completion: nil)
                
            }
            
        }
        
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.row {
            
        case 0:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell", for: indexPath)
            cell.selectionStyle = .none
            return cell
            
        case 1:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "address", for: indexPath)
            let imageView = cell.viewWithTag(1) as! UIImageView
            let textView = cell.viewWithTag(2) as! UITextView
            self.qrGenerator.textInput = address
            imageView.image = self.qrGenerator.getQRCode()
            imageView.addGestureRecognizer(shareAddressQR)
            textView.addGestureRecognizer(shareAddressText)
            textView.textColor = UIColor.green
            textView.text = address
            cell.selectionStyle = .none
            return cell
            
        default:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "redemptionScript", for: indexPath)
            let imageView = cell.viewWithTag(1) as! UIImageView
            let textView = cell.viewWithTag(2) as! UITextView
            self.qrGenerator.textInput = script
            imageView.image = self.qrGenerator.getQRCode()
            imageView.addGestureRecognizer(shareRedScriptQR)
            textView.text = script
            textView.textColor = UIColor.green
            textView.addGestureRecognizer(shareRedScriptText)
            cell.selectionStyle = .none
            return cell
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if indexPath.row == 0 {
         
            return 84
            
        } else {
         
            return 292
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.row == 0 {
            
            let cell = tableView.cellForRow(at: IndexPath.init(row: 0, section: 0))!
            
            let impact = UIImpactFeedbackGenerator()
            
            DispatchQueue.main.async {
                
                impact.impactOccurred()
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 0
                    
                }, completion: { _ in
                    
                    self.importMulti()
                    
                })
                
            }
            
        }
        
    }
    
    @objc func shareRedQR(_ sender: UITapGestureRecognizer) {
        print("share")
        
        DispatchQueue.main.async {

            self.qrGenerator.textInput = self.script
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]

            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)

            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}

        }
        
    }
    
    @objc func shareAddressQR(_ sender: UITapGestureRecognizer) {
        print("share")
        
        DispatchQueue.main.async {
            
            self.qrGenerator.textInput = self.address
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    @objc func shareRedTxt(_ sender: UITapGestureRecognizer) {
        print("share")
        
        DispatchQueue.main.async {
            
            let objectsToShare = [self.script]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    @objc func shareAddressTxt(_ sender: UITapGestureRecognizer) {
        print("share")
        
        DispatchQueue.main.async {
            
            let objectsToShare = [self.address]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    func importMulti() {
        
        connectingView.addConnectingView(vc: self,
                                         description: "Importing MultiSig")
        
        func importDescriptor() {
            
            let result = self.makeSSHCall.dictToReturn
            
            if makeSSHCall.errorBool {
                
                connectingView.removeConnectingView()
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: makeSSHCall.errorDescription)
                
            } else {
                
                let descriptor = "\"\(result["descriptor"] as! String)\""
                
                let label = "\"Imported MultiSig\""
                
                let params = "[{ \"desc\": \(descriptor), \"timestamp\": \"now\", \"watchonly\": true, \"label\": \(label), \"keypool\": \(addToKeypool), \"internal\": false }], ''{\"rescan\": \(reScan)}''"
                
                self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.importmulti,
                                           param: params)
                
            }
            
        }
        
        var descriptor = ""
        var pubkeys = (pubkeyArray.description).replacingOccurrences(of: "[", with: "")
        pubkeys = pubkeys.replacingOccurrences(of: "]", with: "")
        
        if p2sh {
            
            descriptor = "sh(multi(\(sigsRequired),\(pubkeys)))"
            
        }
        
        if p2wsh {
            
            descriptor = "wsh(multi(\(sigsRequired),\(pubkeys)))"
            
        }
        
        if p2shP2wsh {
            
            descriptor = "sh(wsh(multi(\(sigsRequired),\(pubkeys))))"
            
        }
        
        descriptor = descriptor.replacingOccurrences(of: "\"", with: "")
        descriptor = descriptor.replacingOccurrences(of: " ", with: "")
        
        makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                      method: BTC_CLI_COMMAND.getdescriptorinfo,
                                      param: "\"\(descriptor)\"", completion: importDescriptor)
        
    }
    
    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.importmulti:
                    
                    self.connectingView.removeConnectingView()
                    
                    let result = makeSSHCall.arrayToReturn
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    
                    if success {
                        
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: false,
                                     message: "MultiSig imported!")
                        
                    } else {
                        
                        let error = ((result[0] as! NSDictionary)["error"] as! NSDictionary)["message"] as! String
                        connectingView.removeConnectingView()
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: true,
                                     message: error)
                        
                    }
                    
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        
                        if warnings.count > 0 {
                            
                            for warning in warnings {
                                
                                let warn = warning as! String
                                
                                DispatchQueue.main.async {
                                    
                                    let alert = UIAlertController(title: "Warning", message: warn, preferredStyle: UIAlertController.Style.alert)
                                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
                                    self.present(alert, animated: true, completion: nil)
                                    
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
                    
                    displayAlert(viewController: self.navigationController!,
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
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "Not connected")
                
            }
            
        } else {
         
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self.navigationController!,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }

}
