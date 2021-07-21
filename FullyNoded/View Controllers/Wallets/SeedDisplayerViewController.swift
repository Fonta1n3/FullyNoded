//
//  SeedDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SeedDisplayerViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var savedOutlet: UIButton!
    @IBOutlet weak var textView: UITextView!
    var spinner = ConnectingView()
    var primDesc = ""
    var changeDesc = ""
    var name = ""
    var coinType = "0"
    var blockheight:Int64!
    var version:Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        savedOutlet.layer.cornerRadius = 8
        setCoinType()
    }
    
    private func setCoinType() {
        spinner.addConnectingView(vc: self, description: "fetching chain type...")
        
        Reducer.makeCommand(command: .getblockchaininfo, param: "") { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary,
                let chain = dict["chain"] as? String else {
                    self.showError(error: "Error getting blockchain info, please chack your connection to your node.")
                    
                    DispatchQueue.main.async {
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                    
                    return
            }
            
            if chain == "test" {
                self.coinType = "1"
            }
            
            if let blocks = dict["blocks"] as? Int {
                self.blockheight = Int64(blocks)
            }
            
            // check if version is at least 0.21.0 to use native descriptors
            guard let version = UserDefaults.standard.object(forKey: "version") as? String else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Version unknown.", message: "In order to create a wallet we need to know which version of Bitcoin Core you are running, please go the the home screen and refresh then try to create this wallet again.")
                
                return
            }
            
            self.version = version.bitcoinVersion
            self.getWords()
        }
    }
    
    @IBAction func savedAction(_ sender: Any) {
        textView.text = ""
        navigationController?.popToRootViewController(animated: true)
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            UserDefaults.standard.removeObject(forKey: "walletName")
            self.textView.text = ""
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Error", message: error)
        }
    }
    
    private func getWords() {
        spinner.addConnectingView(vc: self, description: "creating Fully Noded wallet...")
        
        guard let seed = Keys.seed() else {
            showError(error: "Error deriving seed")
            return
        }
        
        encryptSeed(words: seed) { [weak self] encryptedAndSaved in
            guard let self = self else { return }
            
            guard encryptedAndSaved else {
                self.showError(error: "Error encrypting and saving your signer.")
                return
            }
            
            self.getMasterKey(seed: seed)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.textView.text = seed
            }
        }
    }
    
    private func getMasterKey(seed: String) {
        if let masterKey = Keys.masterKey(words: seed, coinType: coinType, passphrase: "") {
            getXpubFingerprint(masterKey: masterKey)
        } else {
            showError(error: "Error deriving master key")
        }
    }
    
    private func getXpubFingerprint(masterKey: String) {
        guard let xpub = Keys.bip84AccountXpub(masterKey: masterKey, coinType: coinType, account: 0),
            let fingerprint = Keys.fingerprint(masterKey: masterKey) else {
                showError(error: "Error deriving fingerprint")
                return
        }
        
        createWallet(fingerprint: fingerprint, xpub: xpub) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                var type:WalletType
                
                if self.version >= 21 {
                    type = .descriptor
                } else {
                    type = .single
                }
                
                self.saveWallet(type: type)
            } else {
                self.showError(error: "Error creating wallet")
            }
        }
    }
    
    private func primaryDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/0/*)"
    }
    
    private func changeDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/1/*)"
    }
    
    private func createWallet(fingerprint: String, xpub: String, completion: @escaping ((Bool)) -> Void) {
        primDesc = primaryDescriptor(fingerprint, xpub)
        
        let walletName = "FullyNoded-\(Crypto.sha256hash(primDesc))"
        var param = "\"\(walletName)\", true, true, \"\", true"
        
        if self.version >= 21 {
            param += ", true, true"
        }

        Reducer.makeCommand(command: .createwallet, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }

            guard let dict = response as? NSDictionary,
                let name = dict["name"] as? String else {
                    self.showError(error: "Error creating wallet on your node: \(errorMessage ?? "unknown")")
                    return
            }
            
            if self.version >= 21 {
                self.importDescriptors(name, fingerprint, xpub, self.primDesc, completion: completion)
            } else {
                self.importKeys(name, fingerprint, xpub, self.primDesc, completion: completion)
            }
        }
    }
    
    private func importDescriptors(_ name: String, _ fingerprint: String, _ xpub: String, _ desc: String, completion: @escaping ((Bool)) -> Void) {
        self.name = name
        UserDefaults.standard.set(name, forKey: "walletName")
        
        let changeDesc = self.changeDescriptor(fingerprint, xpub)
        
        self.getDescriptorInfo(desc: desc) { completePrimDesc in
            guard let completePrimDesc = completePrimDesc else { completion(false); return }
            
            self.getDescriptorInfo(desc: changeDesc) { completeChangeDesc in
                guard let completeChangeDesc = completeChangeDesc else { completion(false); return }
                
                self.changeDesc = completeChangeDesc
                self.primDesc = completePrimDesc
                
                let params = "[{\"desc\": \"\(completePrimDesc)\", \"active\": true, \"range\": [0,2500], \"next_index\": 0, \"timestamp\": \"now\", \"internal\": false}, {\"desc\": \"\(completeChangeDesc)\", \"active\": true, \"range\": [0,2500], \"next_index\": 0, \"timestamp\": \"now\", \"internal\": true}]"
                
                Reducer.makeCommand(command: .importdescriptors, param: params) { (response, errorMessage) in
                    guard let responseArray = response as? [[String:Any]] else {
                        self.showError(error: "Error importing descriptors: \(errorMessage ?? "unknown error")")
                        
                        return
                    }
                    
                    for (i, response) in responseArray.enumerated() {
                        guard let success = response["success"] as? Bool, success else {
                            
                            if let error = response["error"] as? [String:Any], let message = error["message"] as? String {
                                self.showError(error: "Error importing descriptors: \(message)")
                            } else {
                                self.showError(error: "Error importing descriptors.")
                            }
                            
                            completion(false)
                            return
                        }
                        
                        if i + 1 == responseArray.count {
                            completion(true)
                        }
                    }
                }
            }
        }
    }
    
    private func importKeys(_ name: String, _ fingerprint: String, _ xpub: String, _ desc: String, completion: @escaping ((Bool)) -> Void) {
        self.name = name
        UserDefaults.standard.set(name, forKey: "walletName")
        
        self.importPrimaryKeys(desc: desc) { [weak self] (success, errorMessage) in
            guard let self = self else { return }
            
            if success {
                self.importChangeKeys(desc: self.changeDescriptor(fingerprint, xpub)) { (changeImported, errorDesc) in
                    
                    if changeImported {
                        completion(true)
                    } else {
                        self.showError(error: "Error importing change keys: \(errorDesc ?? "unknown error")")
                    }
                }
                
            } else {
                self.showError(error: "Error importing primary keys: \(errorMessage ?? "unknown error")")
            }
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            guard let dict = response as? NSDictionary,
                let updatedDescriptor = dict["descriptor"] as? String else {
                    completion(nil); return
            }
            completion(updatedDescriptor)
        }
    }
    
    private func importPrimaryKeys(desc: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        getDescriptorInfo(desc: desc) { [weak self] descriptor in
            guard let self = self else { return }
            
            if descriptor != nil {
                self.primDesc = descriptor!
                let params = "[{ \"desc\": \"\(descriptor!)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"Fully Noded\", \"keypool\": true, \"internal\": false }], {\"rescan\": false}"
                self.importMulti(params: params, completion: completion)
            } else {
                self.showError(error: "error getting primary descriptor info")
            }
        }
    }
    
    private func importChangeKeys(desc: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        getDescriptorInfo(desc: desc) { [weak self] descriptor in
            guard let self = self else { return }
            
            if descriptor != nil {
                self.changeDesc = descriptor!
                let params = "[{ \"desc\": \"\(descriptor!)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": true, \"internal\": true }], {\"rescan\": false}"
                self.importMulti(params: params, completion: completion)
            } else {
                self.showError(error: "error getting change descriptor info")
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            guard let result = response as? NSArray,
                result.count > 0,
                let dict = result[0] as? NSDictionary,
                let success = dict["success"] as? Bool else {
                    completion((false, errorDescription ?? "unknown error importing your keys"))
                    return
            }
            completion((success, errorDescription))
        }
    }
    
    private func encryptSeed(words: String, completion: @escaping ((Bool)) -> Void) {
        guard let encryptedWords = Crypto.encrypt(words.dataUsingUTF8StringEncoding) else {
            completion(false)
            return
        }
        
        saveSigner(encryptedSigner: encryptedWords, completion: completion)
    }
    
    private func saveSigner(encryptedSigner: Data, completion: @escaping ((Bool)) -> Void) {
        let dict = ["id":UUID(), "words":encryptedSigner] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { success in
            completion(success)
        }
    }
    
    private func saveWallet(type: WalletType) {
        var dict = [String:Any]()
        dict["id"] = UUID()
        dict["label"] = type.stringValue
        dict["changeDescriptor"] = changeDesc
        dict["receiveDescriptor"] = primDesc
        dict["type"] = type.stringValue
        dict["name"] = name
        dict["maxIndex"] = Int64(2500)
        dict["index"] = Int64(0)
        dict["blockheight"] = blockheight
        dict["account"] = 0
        
        CoreDataService.saveEntity(dict: dict, entityName: .wallets) { [weak self] success in
            guard let self = self else { return }
            
            if success {
                self.spinner.removeConnectingView()
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                }
                
                showAlert(vc: self, title: "Success! ✅", message: "You created a Fully Noded single sig wallet, make sure you save your words so you can always recover this wallet if needed!")
                
            } else {
                self.spinner.removeConnectingView()
                self.showError(error: "Error saving your wallet to the device")
            }
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
