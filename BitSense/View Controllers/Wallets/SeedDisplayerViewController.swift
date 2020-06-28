//
//  SeedDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SeedDisplayerViewController: UIViewController, UINavigationControllerDelegate {

    @IBOutlet weak var textView: UITextView!
    var spinner = ConnectingView()
    var primDesc = ""
    var changeDesc = ""
    var name = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        getWords()
    }
    
    @IBAction func savedAction(_ sender: Any) {
        textView.text = ""
        navigationController?.popToRootViewController(animated: true)
    }
    
    private func showError(error:String) {
        DispatchQueue.main.async { [unowned vc = self] in
            UserDefaults.standard.removeObject(forKey: "walletName")
            vc.textView.text = ""
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
    }
    
    private func getWords() {
        spinner.addConnectingView(vc: self, description: "creating Fully Noded wallet...")
        if let seed = CreateFullyNodedWallet.seed() {
            getMasterKey(seed: seed)
            DispatchQueue.main.async { [unowned vc = self] in
                vc.textView.text = seed
            }
        } else {
            showError(error: "Error deriving seed")
        }
    }
    
    private func getMasterKey(seed: String) {
        if let masterKey = CreateFullyNodedWallet.masterKey(words: seed) {
            getXpubFingerprint(masterKey: masterKey)
        } else {
            showError(error: "Error deriving master key")
        }
    }
    
    private func getXpubFingerprint(masterKey: String) {
        if let xpub = CreateFullyNodedWallet.bip84AccountXpub(masterKey: masterKey) {
            if let fingerprint = CreateFullyNodedWallet.fingerpint(masterKey: masterKey) {
                createWallet(fingerprint: fingerprint, xpub: xpub) { [unowned vc = self] success in
                    if success {
                        DispatchQueue.main.async { [unowned vc = self] in
                            vc.saveLocally(words: vc.textView.text)
                        }
                    } else {
                        vc.showError(error: "Error creating wallet")
                    }
                }
            } else {
                showError(error: "Error deriving fingerprint")
            }
        } else {
            showError(error: "Error deriving xpub")
        }
    }
    
    private func primaryDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/1h/0h]\(xpub)/0/*)"
    }
    
    private func changeDescriptor(_ fingerprint: String, _ xpub: String) -> String {
        return "wpkh([\(fingerprint)/84h/1h/0h]\(xpub)/1/*)"
    }
    
    private func createWallet(fingerprint: String, xpub: String, completion: @escaping ((Bool)) -> Void) {
        let walletName = "FullyNoded-Single-Sig-\(randomString(length: 10))"
        let param = "\"\(walletName)\", true, true, \"\", true"
        Reducer.makeCommand(command: .createwallet, param: param) { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let name = dict["name"] as? String {
                    vc.name = name
                    UserDefaults.standard.set(name, forKey: "walletName")
                    vc.importPrimaryKeys(desc: vc.primaryDescriptor(fingerprint, xpub)) { success in
                        if success {
                            vc.importChangeKeys(desc: vc.changeDescriptor(fingerprint, xpub)) { changeImported in
                                if changeImported {
                                    completion(true)
                                } else {
                                    vc.showError(error: "Error importing change keys")
                                }
                            }
                        } else {
                            vc.showError(error: "Error importing primary keys")
                        }
                    }
                } else {
                    vc.showError(error: "Error creating wallet on your node")
                }
            } else {
                vc.showError(error: "Error creating wallet on your node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    private func getDescriptorInfo(desc: String, completion: @escaping ((String?)) -> Void) {
        Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let updatedDescriptor = dict["descriptor"] as? String {
                    completion((updatedDescriptor))
                }
            }
        }
    }
    
    private func importPrimaryKeys(desc: String, completion: @escaping ((Bool)) -> Void) {
        getDescriptorInfo(desc: desc) { [unowned vc = self] descriptor in
            if descriptor != nil {
                vc.primDesc = descriptor!
                let params = "[{ \"desc\": \"\(descriptor!)\", \"timestamp\": \"now\", \"range\": [0,500], \"watchonly\": true, \"label\": \"Fully Noded\", \"keypool\": true, \"internal\": false }]"
                vc.importMulti(params: params, completion: completion)
            } else {
                vc.showError(error: "error getting primary descriptor info")
            }
        }
    }
    
    private func importChangeKeys(desc: String, completion: @escaping ((Bool)) -> Void) {
        getDescriptorInfo(desc: desc) { [unowned vc = self] descriptor in
            if descriptor != nil {
                vc.changeDesc = descriptor!
                let params = "[{ \"desc\": \"\(descriptor!)\", \"timestamp\": \"now\", \"range\": [0,500], \"watchonly\": true, \"keypool\": true, \"internal\": true }]"
                vc.importMulti(params: params, completion: completion)
            } else {
                vc.showError(error: "error getting change descriptor info")
            }
        }
    }
    
    private func importMulti(params: String, completion: @escaping ((Bool)) -> Void) {
        Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
            if let result = response as? NSArray {
                if result.count > 0 {
                    if let dict = result[0] as? NSDictionary {
                        if let success = dict["success"] as? Bool {
                            completion((success))
                        } else {
                            completion((false))
                        }
                    }
                } else {
                    completion((false))
                }
            } else {
                completion((false))
            }
        }
    }
    
    private func saveLocally(words: String) {
        Crypto.encryptData(dataToEncrypt: words.dataUsingUTF8StringEncoding) { [unowned vc = self] encryptedWords in
            if encryptedWords != nil {
                vc.saveSigner(encryptedSigner: encryptedWords!)
            }
        }
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
        CoreDataService.saveEntity(dict: dict, entityName: .wallets) { [unowned vc = self] success in
            if success {
                NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Success!", message: "You created a Fully Noded single sig wallet, make sure you save your words so you can always recover this wallet if needed!")
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
