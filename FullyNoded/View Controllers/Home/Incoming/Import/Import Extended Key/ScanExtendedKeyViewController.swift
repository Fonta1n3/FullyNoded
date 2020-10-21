//
//  ScanExtendedKeyViewController.swift
//  BitSense
//
//  Created by Peter on 01/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class ScanExtendedKeyViewController: UIViewController, UITextFieldDelegate {
    
    var dict = [String:Any]()
    
    let connectingView = ConnectingView()
    
    var descriptor = ""
    var label = ""
    var range = "0 to 199"
    var convertedRange = [0,199]
    var desc = "wpkh"
    var fingerprint = ""
    var isTestnet = Bool()
    var isWatchOnly = Bool()
    var isChange = Bool()
    
    var keyArray = NSArray()
    @IBOutlet weak private var nextOutlet: UIButton!
    @IBOutlet weak private var textField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        textField.delegate = self
        nextOutlet.layer.cornerRadius = 8
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard(_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @IBAction func scanQrAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.performSegue(withIdentifier: "segueToGetExtendedKey", sender: self)
        }
    }
    
    @IBAction func nextAction(_ sender: Any) {
        guard let key = textField.text, key != "" else { return }
        
        setValues(key: key)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textField.resignFirstResponder()
    }
    
    func setValues(key: String) {
        
        connectingView.addConnectingView(vc: self.navigationController!,
                                         description: "deriving keys for confirmation")
        
        let str = ImportStruct(dictionary: dict)
        
        var extendedKey = ""
        
        if key.hasPrefix("xprv") || key.hasPrefix("xpub") || key.hasPrefix("tprv") || key.hasPrefix("tpub") {
            extendedKey = key
            
        } else {
            extendedKey = XpubConverter.convert(extendedKey: key) ?? ""
            
        }
        
        if extendedKey != "" {
            
            dict["key"] = extendedKey
            isChange = dict["addAsChange"] as! Bool
            fingerprint = str.fingerprint
            range = str.range
            if extendedKey.hasPrefix("xpub") || extendedKey.hasPrefix("xprv") {
                isTestnet = false
                dict["isTestnet"] = "false"
            } else {
                isTestnet = true
                dict["isTestnet"] = "true"
            }
            label = str.label
            
            if extendedKey.hasPrefix("xprv") || extendedKey.hasPrefix("tprv") {
                
                isWatchOnly = false
                
            } else {
                
                isWatchOnly = true
                
            }
            
            dict["isWatchOnly"] = isWatchOnly
            let derivation = str.derivation
            convertedRange = convertRange()
                    
            switch derivation {
            case "BIP44": desc = "pkh"
            case "BIP84": desc = "wpkh"
            case "BIP32Segwit": desc = "wpkh"
            case "BIP32Legacy": desc = "pkh"
            case "BIP32P2SH": desc = "sh"
            case "BIP49": desc = "sh"
            default:break
            }
                    
            if !isWatchOnly {
                
                importXprv(xprv: extendedKey)
                
            } else {
                
                importXpub(xpub: extendedKey)
                
            }
            
        } else {
            
            connectingView.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "invalid key")
            
        }
        
    }
    
    func importXprv(xprv: String) {        
        var xprvDescriptor = ""
        var param = ""
        
        if fingerprint != "" {
            
            //compatible with coldcard
            if desc == "pkh" {
                
                //BIP44
                if isTestnet {
                    
                    param = "\"\(desc)([\(fingerprint)/44h/1h/0h]\(xprv)/0/*)\""
                    xprvDescriptor = "\(desc)([\(fingerprint)/44h/1h/0h]\(xprv)/0/*)"
                    
                } else {
                    
                    param = "\"\(desc)([\(fingerprint)/44h/0h/0h]\(xprv)/0/*)\""
                    xprvDescriptor = "\(desc)([\(fingerprint)/44h/0h/0h]\(xprv)/0/*)"
                    
                }
                
            } else if desc == "wpkh" {
                
                //BIP84
                if isTestnet {
                    
                    param = "\"\(desc)([\(fingerprint)/84h/1h/0h]\(xprv)/0/*)\""
                    xprvDescriptor = "\(desc)([\(fingerprint)/84h/1h/0h]\(xprv)/0/*)"
                    
                } else {
                    
                    param = "\"\(desc)([\(fingerprint)/84h/0h/0h]\(xprv)/0/*)\""
                    xprvDescriptor = "\(desc)([\(fingerprint)/84h/0h/0h]\(xprv)/0/*)"
                    
                }
                
            } else if desc == "sh" {
                
                //sh(wpkh(03fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556))
                
                if isTestnet {
                    
                    param = "\"\(desc)(wpkh([\(fingerprint)/49h/1h/0h]\(xprv)/0/*))\""
                    xprvDescriptor = "\(desc)(wpkh([\(fingerprint)/49h/1h/0h]\(xprv)/0/*))"
                    
                } else {
                    
                    param = "\"\(desc)(wpkh([\(fingerprint)/49h/0h/0h]\(xprv)/0/*))\""
                    xprvDescriptor = "\(desc)(wpkh([\(fingerprint)/49h/0h/0h]\(xprv)/0/*))"
                    
                }
                
            }
            
            if isChange {
                
                param = param.replacingOccurrences(of: "/0/*", with: "/1/*")
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")
                
            }
            
        } else {
            
            //treat the xpub as a BIP32 extended key
            
            if desc != "sh" {
                
                param = "\"\(desc)(\(xprv)/*)\""
                xprvDescriptor = "\(desc)(\(xprv)/*)"
                
            } else {
                
                param = "\"\(desc)(wpkh(\(xprv)/*))\""
                xprvDescriptor = "\(desc)(wpkh(\(xprv)/*))"
                
            }
            
        }
        
        Reducer.makeCommand(command: .getdescriptorinfo, param: param) { [unowned vc = self] (response, errorMessage) in
            if let result = response as? NSDictionary {
                let checksum = result["checksum"] as? String ?? ""
                xprvDescriptor += "#" + checksum
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "49'", with: "49'\"'\"'")
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "44'", with: "44'\"'\"'")
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "84'", with: "84'\"'\"'")
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "1'", with: "1'\"'\"'")
                xprvDescriptor = xprvDescriptor.replacingOccurrences(of: "0'", with: "0'\"'\"'")
                vc.dict["descriptor"] = "\"\(xprvDescriptor)\""
                vc.deriveAddress(param: "\"\(xprvDescriptor)\", ''\(vc.convertedRange)''")
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
            }
        }
    }
    
    func deriveAddress(param: String) {
        Reducer.makeCommand(command: .deriveaddresses, param: param) { (response, errorMessage) in
            if let addressesCheck = response as? NSArray {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.keyArray = addressesCheck
                    vc.connectingView.removeConnectingView()
                    vc.performSegue(withIdentifier: "goDisplayKeys", sender: vc)
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.connectingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func importXpub(xpub: String) {
        print("importxpub")
        
        var param = ""
        
        if fingerprint != "" {
            
            //compatible with coldcard
            if desc == "pkh" {
                
                //BIP44
                if isTestnet {
                    
                    param = "\"\(desc)([\(fingerprint)/44h/1h/0h]\(xpub)/0/*)\""
                    
                } else {
                    
                    param = "\"\(desc)([\(fingerprint)/44h/0h/0h]\(xpub)/0/*)\""
                    
                }
                
            } else if desc == "wpkh" {
                
                //BIP84
                if isTestnet {
                    
                    param = "\"\(desc)([\(fingerprint)/84h/1h/0h]\(xpub)/0/*)\""
                    
                } else {
                    
                    param = "\"\(desc)([\(fingerprint)/84h/0h/0h]\(xpub)/0/*)\""
                    
                }
                
            } else if desc == "sh" {
                           
                //sh(wpkh(03fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556))
                
                if isTestnet {
                    
                    param = "\"\(desc)(wpkh([\(fingerprint)/49h/1h/0h]\(xpub)/0/*))\""
                    
                } else {
                    
                    param = "\"\(desc)(wpkh([\(fingerprint)/49h/0h/0h]\(xpub)/0/*))\""
                    
                }
                
            }
            
            if isChange {
                
                param = param.replacingOccurrences(of: "/0/*", with: "/1/*")
                
            }
            
        } else {
            
            //treat the xpub as a BIP32 extended key
            
            if desc != "sh" {
                
                param = "\"\(desc)(\(xpub)/*)\""
                
            } else {
                
                param = "\"\(desc)(wpkh(\(xpub)/*))\""
                
            }
            
        }
        
        Reducer.makeCommand(command: .getdescriptorinfo, param: param) { [unowned vc = self] (response, errorMessage) in
            if let result = response as? NSDictionary {
                vc.descriptor = "\"\(result["descriptor"] as! String)\""
                vc.descriptor = vc.descriptor.replacingOccurrences(of: "84'", with: "84'\"'\"'")
                vc.descriptor = vc.descriptor.replacingOccurrences(of: "44'", with: "44'\"'\"'")
                vc.descriptor = vc.descriptor.replacingOccurrences(of: "49'", with: "49'\"'\"'")
                vc.descriptor = vc.descriptor.replacingOccurrences(of: "1'", with: "1'\"'\"'")
                vc.descriptor = vc.descriptor.replacingOccurrences(of: "0'", with: "0'\"'\"'")
                vc.dict["descriptor"] = vc.descriptor
                vc.deriveAddress(param: "\(vc.descriptor), ''\(vc.convertedRange)''")
            } else {
                vc.connectingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
            }
        }
    }
    
    func convertRange() -> [Int] {
        
        var arrayToReturn = [Int]()
        let newrange = range.replacingOccurrences(of: " ", with: "")
        let rangeArray = newrange.components(separatedBy: "to")
        let zero = Int(rangeArray[0])!
        let one = Int(rangeArray[1])!
        arrayToReturn = [zero,one]
        dict["convertedRange"] = arrayToReturn
        return arrayToReturn
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goDisplayKeys":
            
            if let vc = segue.destination as? ImportExtendedKeysViewController  {
                
                vc.isWatchOnly = isWatchOnly
                vc.keyArray = keyArray
                vc.dict = dict
                
            }
            
        case "segueToGetExtendedKey":
            guard let vc = segue.destination as? QRScannerViewController else { fallthrough }
            
            vc.isScanningAddress = true
            
            vc.onAddressDoneBlock = { [weak self] key in
                guard let self = self, let key = key else { return }
                                
                self.setValues(key: key)
            }
            
        default:
            break
        }
    }
    
}
