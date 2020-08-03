//
//  ImportWallet.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class ImportWallet {
        
    class func accountMap(_ accountMap: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        var wallet = [String:Any]()
        var keypool = Bool()
        let descriptorParser = DescriptorParser()
        var primDescriptor = accountMap["descriptor"] as! String
        let blockheight = accountMap["blockheight"] as! Int
        let label = accountMap["label"] as! String
        wallet["label"] = label
        wallet["id"] = UUID()
        wallet["blockheight"] = Int64(blockheight)
        wallet["maxIndex"] = 2500
        wallet["index"] = 0
        let descStruct = descriptorParser.descriptor(primDescriptor)
        if descStruct.isMulti {
            wallet["type"] = "Multi-Sig"
            keypool = false
        } else {
            wallet["type"] = "Single-Sig"
            keypool = true
        }
        primDescriptor = primDescriptor.replacingOccurrences(of: "'", with: "h")
        let arr = primDescriptor.split(separator: "#")
        primDescriptor = "\(arr[0])"
        
        func getDescriptorInfo(desc: String, completion: @escaping ((desc: String?, errorMessage: String?)) -> Void) {
            Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(desc)\"") { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let updatedDescriptor = dict["descriptor"] as? String {
                        completion((updatedDescriptor, nil))
                    }
                } else {
                    completion((nil, errorMessage ?? "error getting descriptor info"))
                }
            }
        }
        
        func importMulti(params: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
            Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
                if let result = response as? NSArray {
                    if result.count > 0 {
                        if let dict = result[0] as? NSDictionary {
                            if let success = dict["success"] as? Bool {
                                completion((success, nil))
                            } else {
                                completion((false, errorDescription ?? "unknown error importing your keys"))
                            }
                        }
                    } else {
                        completion((false, errorDescription ?? "unknown error importing your keys"))
                    }
                } else {
                    completion((false, errorDescription ?? "unknown error importing your keys"))
                }
            }
        }
        
        func saveLocally() {
            CoreDataService.saveEntity(dict: wallet, entityName: .wallets) { (success) in
                if success {
                    completion((true, nil))
                } else {
                    completion((false, "error saving wallet locally"))
                }
            }
        }
        
        func rescan() {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let pruned = dict["pruned"] as? Bool {
                        if pruned {
                            if let pruneHeight = dict["pruneheight"] as? Int {
                                Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { (response, errorMessage) in
                                    saveLocally()
                                }
                            } else {
                                completion((false, errorMessage ?? "error getting prune height"))
                            }
                        } else {
                            Reducer.makeCommand(command: .rescanblockchain, param: "") { (response, errorMessage) in
                                saveLocally()
                            }
                        }
                    } else {
                        completion((false, errorMessage ?? "error getting prune info"))
                    }
                } else {
                     completion((false, errorMessage ?? "error getting blockchain info"))
                }
            }
        }
        
        func createWallet(_ recDesc: String, _ changeDesc: String) {
            let walletName = "FullyNoded-Import-\(randomString(length: 10))"
            let param = "\"\(walletName)\", true, true, \"\", true"
            Reducer.makeCommand(command: .createwallet, param: param) { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let name = dict["name"] as? String {
                        wallet["name"] = name
                        UserDefaults.standard.set(name, forKey: "walletName")
                        let recParams = "[{ \"desc\": \"\(recDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(keypool), \"internal\": false }], {\"rescan\": false}"
                        importMulti(params: recParams) { (success, errorMessage) in
                            if success {
                                let changeParams = "[{ \"desc\": \"\(changeDesc)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": \(keypool), \"internal\": true }], {\"rescan\": false}"
                                importMulti(params: changeParams) { (changeImported, errorMessage) in
                                    if success {
                                        rescan()
                                    } else {
                                        completion((false, errorMessage ?? "error importing change keys"))
                                    }
                                }
                            } else {
                                completion((false, errorMessage ?? "error importing keys"))
                            }
                        }
                    } else {
                        completion((false, errorMessage ?? "error getting wallet name"))
                    }
                } else {
                   completion((false, errorMessage ?? "error creating wallet"))
                }
            }
        }
        
        getDescriptorInfo(desc: primDescriptor) { (recDesc, errorMessage) in
            if recDesc != nil {
                wallet["receiveDescriptor"] = recDesc!
                getDescriptorInfo(desc: primDescriptor.replacingOccurrences(of: "/0/*", with: "/1/*")) { (changeDesc, errorMessage) in
                    if changeDesc != nil {
                        wallet["changeDescriptor"] = changeDesc!
                        createWallet(recDesc!, changeDesc!)
                    } else {
                        completion((false, errorMessage ?? "error getting change descriptor info"))
                    }
                }
            } else {
                completion((false, errorMessage ?? "error getting descriptor info"))
            }
        }
        
    }
    
    class func coldcard(dict: [String:Any], completion: @escaping ((success: Bool, errorDescription: String?)) -> Void) {
        /*
         ["xfp": 0F056943, "bip49": {
             "_pub" = upub5DMRSsh6mNaeiTXEzarZLvZezWp4cGhaDHjMz9iineDN8syqep2XHncDKFVtTUXY4fyKp12qDVVwdfq5rKkw2CDf5fy2gEHyh5NoTC6fiwm;
             deriv = "m/49'/1'/0'";
             first = 2NCAJ5wD4GvmW32GFLVybKPNphNU8UYoEJv;
             name = "p2wpkh-p2sh";
             xfp = FD3E8548;
             xpub = tpubDCDqt7XXvhAYY9HSwrCXB7BXqYM4RXB8WFtKgtTXGa6u3U6EV1NJJRFTcuTRyhSY5Vreg1LP8aPdyiAPQGrDJLikkHoc7VQg6DA9NtUxHtj;
         }, "xpub": tpubD6NzVbkrYhZ4XzL5Dhayo67Gorv1YMS7j8pRUvVMd5odC2LBPLAygka9p7748JtSq82FNGPppFEz5xxZUdasBRCqJqXvUHq6xpnsMcYJzeh, "bip44": {
             deriv = "m/44'/1'/0'";
             first = mtHSVByP9EYZmB26jASDdPVm19gvpecb5R;
             name = p2pkh;
             xfp = 92B53FD2;
             xpub = tpubDCiHGUNYdRRBPNYm7CqeeLwPWfeb2ZT2rPsk4aEW3eUoJM93jbBa7hPpB1T9YKtigmjpxHrB1522kSsTxGm9V6cqKqrp1EDaYaeJZqcirYB;
         }, "bip84": {
             "_pub" = vpub5Y5a91QvDT3yog4bmgbqFo7GPXpRpozogzQeDArSPzsY8SKGHTgjSswhxhGkRonUQ9tyo9ZSQ1ecLKkVUyewWEUJZdwgUQycvG86FV7sdhZ;
             deriv = "m/84'/1'/0'";
             first = tb1qupyd58ndsh7lut0et0vtrq432jvu9jtdyws9n9;
             name = p2wpkh;
             xfp = AB82D43E;
             xpub = tpubDC7jGaaSE66Pn4dgtbAAstde4bCyhSUs4r3P8WhMVvPByvcRrzrwqSvpF9Ghx83Z1LfVugGRrSBko5UEKELCz9HoMv5qKmGq3fqnnbS5E9r;
         }, "chain": XTN, "account": 0]
         */
        var wallet = [String:Any]()
        wallet["type"] = "Single-Sig"
        wallet["label"] = "Coldcard"
        wallet["id"] = UUID()
        wallet["blockheight"] = 0
        wallet["maxIndex"] = 2500
        wallet["index"] = 0
        
        var watching:[String] = []
        let fingerprint = dict["xfp"] as! String
        
        let bip49 = dict["bip49"] as! NSDictionary
        let bipr49deriv = (bip49["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip49Xpub = (bip49["xpub"] as! String)
        let bip49DescPrim = "sh(wpkh([\(bipr49deriv)]\(bip49Xpub)/0/*))"
        let bip49DescChange = "sh(wpkh([\(bipr49deriv)]\(bip49Xpub)/1/*))"
        
        let bip44 = dict["bip44"] as! NSDictionary
        let bipr44deriv = (bip44["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip44Xpub = (bip44["xpub"] as! String)
        let bip44DescPrim = "pkh([\(bipr44deriv)]\(bip44Xpub)/0/*)"
        let bip44DescChange = "pkh([\(bipr44deriv)]\(bip44Xpub)/1/*)"
        
        let bip84 = dict["bip84"] as! NSDictionary
        let bipr84deriv = (bip84["deriv"] as! String).replacingOccurrences(of: "m", with: fingerprint)
        let bip84Xpub = (bip84["xpub"] as! String)
        let bip84DescPrim = "wpkh([\(bipr84deriv)]\(bip84Xpub)/0/*)"
        let bip84DescChange = "wpkh([\(bipr84deriv)]\(bip84Xpub)/1/*)"
        
        func saveLocally() {
            CoreDataService.saveEntity(dict: wallet, entityName: .wallets) { (success) in
                if success {
                    completion((true, nil))
                } else {
                    completion((false, "error saving wallet locally"))
                }
            }
        }
        
        func rescan() {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let pruned = dict["pruned"] as? Bool {
                        if pruned {
                            if let pruneHeight = dict["pruneheight"] as? Int {
                                Reducer.makeCommand(command: .rescanblockchain, param: "\(pruneHeight)") { (response, errorMessage) in
                                    saveLocally()
                                }
                            } else {
                                completion((false, errorMessage ?? "error getting prune height"))
                            }
                        } else {
                            Reducer.makeCommand(command: .rescanblockchain, param: "") { (response, errorMessage) in
                                saveLocally()
                            }
                        }
                    } else {
                        completion((false, errorMessage ?? "error getting prune info"))
                    }
                } else {
                     completion((false, errorMessage ?? "error getting blockchain info"))
                }
            }
        }
        
        func getDescriptorInfo(descriptor: String, completion: @escaping ((desc: String?, errorMessage: String?)) -> Void) {
            Reducer.makeCommand(command: .getdescriptorinfo, param: "\"\(descriptor)\"") { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let updatedDescriptor = dict["descriptor"] as? String {
                        completion((updatedDescriptor, nil))
                    }
                } else {
                    completion((nil, errorMessage ?? "error getting descriptor info"))
                }
            }
        }
        
        func importMulti(isChange: Bool, isKeypool: Bool, label: String, descriptor: String, completion: @escaping ((success: Bool, errorMessage: String?)) -> Void) {
            getDescriptorInfo(descriptor: descriptor) { (desc, errorMessage) in
                if desc != nil {
                    var params = "[{ \"desc\": \"\(desc!)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"label\": \"\(label)\", \"keypool\": \(isKeypool), \"internal\": \(isChange) }], {\"rescan\": false}"
                    
                    if isChange {
                        params = "[{ \"desc\": \"\(desc!)\", \"timestamp\": \"now\", \"range\": [0,2500], \"watchonly\": true, \"keypool\": \(isKeypool), \"internal\": \(isChange) }], {\"rescan\": false}"
                        wallet["changeDescriptor"] = desc!
                    }
                    
                    if isKeypool && !isChange {
                        wallet["receiveDescriptor"] = desc!
                    } else if !isKeypool && !isChange {
                        watching.append(desc!)
                    }
                    
                    Reducer.makeCommand(command: .importmulti, param: params) { (response, errorDescription) in
                        if let result = response as? NSArray {
                            if result.count > 0 {
                                if let dict = result[0] as? NSDictionary {
                                    if let success = dict["success"] as? Bool {
                                        completion((success, nil))
                                    } else {
                                        completion((false, errorDescription ?? "unknown error importing your keys"))
                                    }
                                }
                            } else {
                                completion((false, errorDescription ?? "unknown error importing your keys"))
                            }
                        } else {
                            completion((false, errorDescription ?? "unknown error importing your keys"))
                        }
                    }
                }
            }
            
        }
        
        func createWallet() {
            let walletName = "Coldcard-\(randomString(length: 10))"
            let param = "\"\(walletName)\", true, true, \"\", true"
            Reducer.makeCommand(command: .createwallet, param: param) { (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let name = dict["name"] as? String {
                        wallet["name"] = name
                        UserDefaults.standard.set(name, forKey: "walletName")
                        importMulti(isChange: false, isKeypool: true, label: "Coldcard-bip84", descriptor: bip84DescPrim) { (success, errorMessage) in
                            if success {
                                importMulti(isChange: true, isKeypool: true, label: "", descriptor: bip84DescChange) { (changeImported, errorMessage) in
                                    if success {
                                        importMulti(isChange: false, isKeypool: false, label: "Coldcard-bip44-receive", descriptor: bip44DescPrim) { (success, errorMessage) in
                                            if success {
                                                importMulti(isChange: false, isKeypool: false, label: "Coldcard-bip44-change", descriptor: bip44DescChange) { (success, errorMessage) in
                                                    if success {
                                                        importMulti(isChange: false, isKeypool: false, label: "Coldcard-bip49-receive", descriptor: bip49DescPrim) { (success, errorMessage) in
                                                            if success {
                                                                importMulti(isChange: false, isKeypool: false, label: "Coldcard-bip49-change", descriptor: bip49DescChange) { (success, errorMessage) in
                                                                    if success {
                                                                        wallet["watching"] = watching
                                                                        rescan()
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    } else {
                                        completion((false, errorMessage ?? "error importing change keys"))
                                    }
                                }
                            } else {
                                completion((false, errorMessage ?? "error importing keys"))
                            }
                        }
                    } else {
                        completion((false, errorMessage ?? "error getting wallet name"))
                    }
                } else {
                   completion((false, errorMessage ?? "error creating wallet"))
                }
            }
        }
        
        createWallet()
        
    }
    
}
