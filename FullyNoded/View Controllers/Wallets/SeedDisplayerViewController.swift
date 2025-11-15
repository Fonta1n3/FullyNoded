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
    var dict = [String:Any]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.delegate = self
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.textColor = .systemGreen
        savedOutlet.layer.cornerRadius = 8
        setCoinType()
    }
    
    private func setCoinType() {
        if let chain = UserDefaults.standard.object(forKey: "chain") as? String,
            let blockheight = UserDefaults.standard.object(forKey: "blockheight") as? Int {
            if chain != "main" {
                self.coinType = "1"
            }
            
            self.blockheight = Int64(blockheight)
            
        } else {
            spinner.addConnectingView(vc: self, description: "fetching chain type...")
            
            OnchainUtils.getBlockchainInfo { [weak self] (blockchainInfo, message) in
                guard let self = self else { return }
                
                guard let blockchainInfo = blockchainInfo else {
                        self.showError(error: "Error getting blockchain info, please chack your connection to your node.")
                        
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            self.navigationController?.popToRootViewController(animated: true)
                        }
                        
                        return
                }
                
                if blockchainInfo.chain != "main" {
                    self.coinType = "1"
                }
                
                self.blockheight = Int64(blockchainInfo.blocks)
            }
        }
        
        // check if version is at least 0.21.0 to use native descriptors
        guard let version = UserDefaults.standard.object(forKey: "version") as? Int else {
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Version unknown.", message: "In order to create a wallet we need to know which version of Bitcoin Core you are running, please go the the home screen and refresh then try to create this wallet again.")
            
            return
        }
        
        self.version = version
        getWords()
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
            
            getMasterKey(seed: seed)
            
            var wordsToShow = ""
            let wordArray = seed.components(separatedBy: " ")
            
            for (i, word) in wordArray.enumerated() {
                wordsToShow += "\(i + 1). \(word)  "
            }
            
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                textView.text = wordsToShow
            }
        }
    }
        
    private func importAccountMap(_ accountMap: [String:Any]) {
        ImportWallet.accountMap(accountMap) { (success, errorDescription) in
            if success {
                self.spinner.removeConnectingView()
                
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                }
                
                showAlert(vc: self, title: "Success ✓", message: "You created a Fully Noded single sig wallet, make sure you save your words so you can always recover this wallet if needed!")
            } else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                self.showError(error: "Error creating wallet: \(errorDescription ?? "Unknown error.")")
            }
        }
    }
    
    private func getMasterKey(seed: String) {
        if let masterKey = Keys.masterKey(words: seed, coinType: coinType, passphrase: "") {
            getSegwitData(masterKey: masterKey)
        } else {
            showError(error: "Error deriving master key")
        }
    }
        
    private func getSegwitData(masterKey: String) {
        guard let xpub = Keys.bip84AccountXpub(masterKey: masterKey, coinType: coinType, account: 0),
              let fingerprint = Keys.fingerprint(masterKey: masterKey) else {
            showError(error: "Error deriving xpub or fingerprint.")
            return
        }
        
        createSegwitWallet(fingerprint: fingerprint, xpub: xpub, mk: masterKey) { [weak self] (success, error) in
            guard let self = self else { return }
            
            if success {
                var type:WalletType
                
                if self.version >= 210100 {
                    type = .descriptor
                } else {
                    type = .single
                }
                
                self.saveWallet(type: type)
            } else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                self.showError(error: "Error creating wallet: \(error ?? "Unknown error.")")
            }
        }
    }
    
    private func primarySegwitDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/0/*)"
    }
    
    private func changeSegwitDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/1/*)"
    }
    
    private func createSegwitWallet(fingerprint: String, xpub: String, mk: String, completion: @escaping ((success: Bool, message: String?)) -> Void) {
        primDesc = primarySegwitDescriptor(fingerprint, xpub)
        changeDesc = changeSegwitDescriptor(fingerprint, xpub)
        let walletName = "FullyNoded-\(Crypto.sha256hash(primDesc))"
        let param:Create_Wallet_Param = .init([
            "wallet_name": walletName,
            "avoid_reuse": true,
            "descriptors": true,
            "load_on_startup": true,
            "disable_private_keys": true,
            "passphrase": ""
        ] as [String:Any])
        
        OnchainUtils.createWallet(param: param) { [weak self] (name, message) in
            guard let self = self else { return }
            
            if let name = name {
                UserDefaults.standard.set(name, forKey: "walletName")
                
                if self.version >= 210100 {
                    self.importDescriptors(name, fingerprint, self.primDesc, self.changeDesc, mk, completion: completion)
                } else {
                    showAlert(vc: self, title: "", message: "Fully Noded requires at least Bitcoin Core v21, please update and try again.")
                }
                
            } else {
                if let message = message {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: message)
                }
            }
        }
    }
    
    private func importDescriptors(_ name: String,
                                   _ xfp: String,
                                   _ descPrim: String,
                                   _ descChange: String,
                                   _ mk: String,
                                   completion: @escaping ((success: Bool, message: String?)) -> Void) {
        self.name = name
        let param:Get_Descriptor_Info = .init(["descriptor":descPrim])
        
        OnchainUtils.getDescriptorInfo(param) { (descriptorInfo, message) in
            guard let recDescriptorInfo = descriptorInfo else { completion((false, message)); return }
            
            let change_param:Get_Descriptor_Info = .init(["descriptor":descChange])
            OnchainUtils.getDescriptorInfo(change_param) { (changeDescInfo, message) in
                guard let changeDescInfo = changeDescInfo else { completion((false, message)); return }
                
                self.changeDesc = changeDescInfo.descriptor
                self.primDesc = recDescriptorInfo.descriptor
                
                let params:Import_Descriptors = .init([
                    "requests": [
                        [
                            "desc": self.primDesc,
                            "active": true,
                            "range": [0,999],
                            "next_index": 0,
                            "timestamp": "now",
                            "internal": false
                        ],
                        [
                            "desc": self.changeDesc,
                            "active": true,
                            "range": [0,999],
                            "next_index": 0,
                            "timestamp": "now",
                            "internal": true
                        ]
                    ]
                ] as [String:Any])
                
                OnchainUtils.importDescriptors(params) { [weak self] (imported, message) in
                    guard let self = self else { return }
                    
                    guard imported else {
                        UserDefaults.standard.removeObject(forKey: "walletName")
                        completion((false, message))
                        self.showError(error: message ?? "Unknown error importing descriptors.")
                        return
                    }
                    
                    completion((true, nil))
                }
            }
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((String?)) -> Void) {
        let param:Get_Descriptor_Info = .init(["descriptor":desc])
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getdescriptorinfo(param: param)) { (response, errorMessage) in
            guard let dict = response as? NSDictionary,
                let updatedDescriptor = dict["descriptor"] as? String else {
                UserDefaults.standard.removeObject(forKey: "walletName")
                    completion(nil); return
            }
            completion(updatedDescriptor)
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
        let dict = ["id":UUID(), "words":encryptedSigner, "added": Date(), "label": "Single Sig"] as [String:Any]
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
        dict["maxIndex"] = Int64(999)
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
