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
        
        if let seed = Keys.seed() {
            getMasterKey(seed: seed)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.textView.text = seed
            }
            
        } else {
            showError(error: "Error deriving seed")
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
                DispatchQueue.main.async {
                    self.saveLocally(words: self.textView.text)
                }
            } else {
                self.showError(error: "Error creating wallet")
            }
        }
    }
    
    private func primaryDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "combo([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/0/*)"
    }
    
    private func changeDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "combo([\(fingerprint)/84h/\(coinType)h/0h]\(xpub)/1/*)"
    }
    
    private func createWallet(fingerprint: String, xpub: String, completion: @escaping ((Bool)) -> Void) {
        primDesc = primaryDescriptor(fingerprint, xpub)
        let walletName = "FullyNoded-\(Crypto.sha256hash(primDesc))"
        let param = "\"\(walletName)\", true, true, \"\", true"
        
        Reducer.makeCommand(command: .createwallet, param: param) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary,
                let name = dict["name"] as? String else {
                    self.showError(error: "Error creating wallet on your node: \(errorMessage ?? "unknown")")
                    return
            }
            
            self.importKeys(name, fingerprint, xpub, self.primDesc, completion: completion)
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
    
    private func saveLocally(words: String) {
        guard let encryptedWords = Crypto.encrypt(words.dataUsingUTF8StringEncoding) else { return }
        
        saveSigner(encryptedSigner: encryptedWords)
    }
    
    private func saveSigner(encryptedSigner: Data) {
        let dict = ["id":UUID(), "words":encryptedSigner] as [String:Any]
        CoreDataService.saveEntity(dict: dict, entityName: .signers) { [unowned vc = self] success in
            if success {
                vc.saveWallet()
            } else {
                vc.showError(error: "error saving encrypted seed")
            }
        }
    }
    
    private func saveWallet() {
        var dict = [String:Any]()
        dict["id"] = UUID()
        dict["label"] = "Single-Sig"
        dict["changeDescriptor"] = changeDesc
        dict["receiveDescriptor"] = primDesc
        dict["type"] = "Single-Sig"
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
