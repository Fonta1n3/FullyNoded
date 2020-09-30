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
    @IBOutlet weak var tapToImportOutlet: UIButton!
    
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
        
        impact()
        
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
    
    private func encryptedValue(_ decryptedValue: Data) -> Data? {
        return Crypto.encrypt(decryptedValue)
    }
    
    func importHDMusig() {
        
        guard let encDesc = encryptedValue(descriptor.dataUsingUTF8StringEncoding) else { return }
        
        let id = UUID()
        
        let dict = ["descriptor":encDesc,
                    "label":label,
                    "index":Int32(convertedRange[0]),
                    "range":range,
                    "id":id] as [String : Any]
        
        CoreDataService.saveEntity(dict: dict, entityName: .newHdWallets) { [unowned vc = self] success in
            
            if success {
                
                let descDict = ["descriptor":encDesc,
                                "label":vc.label,
                                "range":vc.range,
                                "id":id] as [String : Any]
                
                CoreDataService.saveEntity(dict: descDict, entityName: .newDescriptors) { success in
                    
                    if success {
                        self.connectingView.addConnectingView(vc: self,
                                                              description: "importing 2,000 BIP32 HD multisig addresses and scripts (index \(self.range)), this can take a little while, sit back and relax")
                        
                        let params = "[{ \"desc\": \(self.descriptor), \"timestamp\": \(self.timestamp), \"range\": \(self.convertedRange), \"watchonly\": true, \"label\": \"\(self.label)\" }], ''{\"rescan\": true}''"
                        
                        self.executeNodeCommand(method: .importmulti,
                                                param: params)
                        
                    } else {
                        
                        displayAlert(viewController: self, isError: true, message: "error saving descriptor")
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "error saving hd wallet")
            }
            
        }
        
    }
    
    func importExtendedKey() {
        
        var description = ""
        
        if isWatchOnly {
            
            //its an xpub
            if bip44 {
                
                description = "importing 2,000 BIP44 keys from xpub (index \(range)), this can take a little while, sit back and relax"
                
            } else if bip84 {
                
                description = "importing 2,000 BIP84 keys from xpub (index \(range)), this can take a little while, sit back and relax"
                                
            } else if bip32 {
                
                description = "importing 2,000 BIP32 keys from xpub (index \(range)), this can take a little while, sit back and relax"
                
            }
            
        } else {
            
            //its an xprv
            if bip44 {
                
                description = "importing 2,000 BIP44 keys from xprv (index \(range)), this can take a little while, sit back and relax"
                
            } else if bip84 {
                
                description = "importing 2,000 BIP84 keys from xprv (index \(range)), this can take a little while, sit back and relax"
                
            } else if bip32 {
                
                description = "importing 2,000 BIP32 keys from xprv (index \(range)), this can take a little while, sit back and relax"
                
            }
            
        }
        
        connectingView.addConnectingView(vc: self,
                                         description: description)
        
        var params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"label\": \"\(label)\", \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
        
        if isInternal {
            
            params = "[{ \"desc\": \(descriptor), \"timestamp\": \(timestamp), \"range\": \(convertedRange), \"watchonly\": \(isWatchOnly), \"keypool\": \(addToKeypool), \"internal\": \(isInternal) }], ''{\"rescan\": true}''"
            
        }
        
        guard let encDesc = encryptedValue(descriptor.dataUsingUTF8StringEncoding) else { return }
        
        let descDict = ["descriptor":encDesc,
                        "label":label,
                        "range":range,
                        "id":UUID()] as [String : Any]
        
        CoreDataService.saveEntity(dict: descDict, entityName: .newDescriptors) { success in
            
            if success {
                
                print("descriptor saved")
                
                self.executeNodeCommand(method: .importmulti,
                                        param: params)
                
            } else {
                
                print("error saving descriptor")
                
                self.connectingView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "error saving your descriptor")
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
        Reducer.makeCommand(command: .importmulti, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                if let result = response as? NSArray {
                    let success = (result[0] as! NSDictionary)["success"] as! Bool
                    if success {
                        vc.connectingView.removeConnectingView()
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.tapToImportOutlet.alpha = 0
                            vc.importSuccess()
                        }
                    } else {
                        let errorDict = (result[0] as! NSDictionary)["error"] as! NSDictionary
                        let error = errorDict["message"] as! String
                        vc.connectingView.removeConnectingView()
                        displayAlert(viewController: self, isError: true, message: error)
                    }
                    if let warnings = (result[0] as! NSDictionary)["warnings"] as? NSArray {
                        if warnings.count > 0 {
                            var warn = ""
                            for warning in warnings {
                                warn += "\(warning)"
                            }
                            vc.importWithWarning(warning: warn)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    private func importSuccess() {
        print("importSuccess")
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Keys imported successfully!", message: "If you selected a rescan date your node will now be rescanning, you will need to wait for the rescan to complete before your balances will show up. You can check the scan status in Tools > Get Wallet Info. Tap Done to go back.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    private func importWithWarning(warning: String) {
        print("importWithWarning")
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Keys imported with a warning!", message: "Warning: \(warning)\n\nIf you selected a rescan date your node will now be rescanning, you will need to wait for the rescan to complete before your balances will show up. You can check the scan status in Tools > Get Wallet Info. Tap Done to go back.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.navigationController?.popToRootViewController(animated: true)
                }
            }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
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
