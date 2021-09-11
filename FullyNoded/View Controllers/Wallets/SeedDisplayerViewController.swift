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
    var version:Double = 0.0
    var dict = [String:Any]()
    
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
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
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
        
        createWallet(fingerprint: fingerprint, xpub: xpub, mk: masterKey) { [weak self] success in
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
                UserDefaults.standard.removeObject(forKey: "walletName")
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
    
    private func createWallet(fingerprint: String, xpub: String, mk: String, completion: @escaping ((Bool)) -> Void) {
        primDesc = primaryDescriptor(fingerprint, xpub)
        
        let walletName = "FullyNoded-\(Crypto.sha256hash(primDesc))"
        var param = "\"\(walletName)\", true, true, \"\", true"
        
        if self.version >= 21 {
            param += ", true, true"
        }
        
        OnchainUtils.createWallet(param: param) { [weak self] (name, message) in
            guard let self = self else { return }
            
            if let name = name {
                UserDefaults.standard.set(name, forKey: "walletName")
                
                if self.version >= 21 {
                    self.importDescriptors(name, fingerprint, xpub, self.primDesc, mk, completion: completion)
                } else {
                    self.importKeys(name, fingerprint, xpub, self.primDesc, completion: completion)
                }
            } else {
                if let message = message {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: message)
                }
            }
        }
    }
    
    private func importDescriptors(_ name: String, _ xfp: String, _ xpub: String, _ desc: String, _ mk: String, completion: @escaping ((Bool)) -> Void) {
        self.name = name
        let changeDesc = self.changeDescriptor(xfp, xpub)
        
        OnchainUtils.getDescriptorInfo(desc) { (descriptorInfo, message) in
            guard let recDescriptorInfo = descriptorInfo else { completion(false); return }
            
            OnchainUtils.getDescriptorInfo(changeDesc) { (changeDescInfo, message) in
                guard let changeDescInfo = changeDescInfo else { completion(false); return }
                
                self.changeDesc = changeDescInfo.descriptor
                self.primDesc = recDescriptorInfo.descriptor
                
                JoinMarket.descriptors(mk, xfp) { [weak self] (jMDescriptors, dict) in
                    guard let self = self else { return }
                    
                    guard let jMDescriptors = jMDescriptors, let dict = dict else { return }
                    
                    self.dict = dict
                    
                    let params = "[{\"desc\": \"\(self.primDesc)\", \"active\": true, \"range\": [0,2500], \"next_index\": 0, \"timestamp\": \"now\", \"internal\": false}, {\"desc\": \"\(self.changeDesc)\", \"active\": true, \"range\": [0,2500], \"next_index\": 0, \"timestamp\": \"now\", \"internal\": true}, \(jMDescriptors)]"
                    
                    OnchainUtils.importDescriptors(params) { [weak self] (imported, message) in
                        guard let self = self else { return }
                        
                        guard imported else {
                            UserDefaults.standard.removeObject(forKey: "walletName")
                            completion(false)
                            self.showError(error: message ?? "Unknown error importing descriptors.")
                            return
                        }
                        
                        completion(true)
                    }
                }
            }
        }
    }
    
    private func importKeys(_ name: String, _ fingerprint: String, _ xpub: String, _ desc: String, completion: @escaping ((Bool)) -> Void) {
        self.name = name
        
        self.importPrimaryKeys(desc: desc) { [weak self] (success, errorMessage) in
            guard let self = self else { return }
            
            if success {
                self.importChangeKeys(desc: self.changeDescriptor(fingerprint, xpub)) { (changeImported, errorDesc) in
                    
                    if changeImported {
                        completion(true)
                    } else {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        self.showError(error: "Error importing change keys: \(errorDesc ?? "unknown error")")
                    }
                }
                
            } else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                self.showError(error: "Error importing primary keys: \(errorMessage ?? "unknown error")")
            }
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            guard let dict = response as? NSDictionary,
                let updatedDescriptor = dict["descriptor"] as? String else {
                UserDefaults.standard.removeObject(forKey: "walletName")
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
                UserDefaults.standard.removeObject(forKey: "walletName")
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
                UserDefaults.standard.removeObject(forKey: "walletName")
                self.showError(error: "error getting change descriptor info")
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
        OnchainUtils.importMulti(params) { (imported, message) in
            if imported {
                completion((imported, message))
            } else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                completion((false, message ?? "unknown error importing your keys"))
            }
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
        dict["id"] = UUID()
        dict["label"] = "Single sig"
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
                
                showAlert(vc: self, title: "Success ✓", message: "You created a Fully Noded single sig wallet, make sure you save your words so you can always recover this wallet if needed!")
                
            } else {
                UserDefaults.standard.removeObject(forKey: "walletName")
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
