//
//  Signer.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import LibWally

class Signer {
    
    class func sign(psbt: String, passphrase: String?, completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        var seedsToSignWith = [[String:Any]]()
        var xprvsToSignWith = [HDKey]()
        var psbtToSign:PSBT!
        var chain:Network!
        var coinType:String!
        
        func reset() {
            seedsToSignWith.removeAll()
            xprvsToSignWith.removeAll()
            psbtToSign = nil
            chain = nil
        }
        
        func finalize() {
            //            if psbtToSign.inputs.count < 4 {
            /// reproducable bug when finalizing segwit msig psbts with more then 3 inputs.
            //                guard let finalizedPsbt = try? psbtToSign.finalized() else {
            //                    reset()
            //                    completion((psbtToSign.description, nil, nil))
            //                    return
            //                }
            //
            //                guard let hex = finalizedPsbt.transactionFinal else {
            //                    reset()
            //                    completion((finalizedPsbt.description, nil, nil))
            //                    return
            //                }
            //
            //                reset()
            //                completion((nil, hex.description, nil))
            //
            //            } else {
            let param:Finalize_Psbt = .init(["psbt": psbtToSign.description])
            Reducer.sharedInstance.makeCommand(command: .finalizepsbt(param)) { (object, errorDescription) in
                if let result = object as? NSDictionary {
                    if let complete = result["complete"] as? Bool {
                        if complete {
                            let hex = result["hex"] as! String
                            let psbt = psbtToSign.description
                            reset()
                            // Now always return the non finalized psbt as exporting signed psbt's can be useful.
                            completion((psbt, hex, nil))
                        } else {
                            let psbt = result["psbt"] as! String
                            reset()
                            completion((psbt, nil, nil))
                        }
                    } else {
                        reset()
                        completion((nil, nil, errorDescription))
                    }
                } else {
                    reset()
                    completion((nil, nil, errorDescription))
                }
            }
            //}
        }
        
        func processWithActiveWallet() {
            let param: Wallet_Process_PSBT = .init(["psbt": psbtToSign.description])
            Reducer.sharedInstance.makeCommand(command: .walletprocesspsbt(param: param)) { (object, errorDescription) in
                if let dict = object as? NSDictionary {
                    if let processedPsbt = dict["psbt"] as? String {
                        do {
                            psbtToSign = try PSBT(psbt: processedPsbt, network: chain)
                            if xprvsToSignWith.count > 0 {
                                attemptToSignLocally()
                            } else {
                                finalize()
                            }
                        } catch {
                            if xprvsToSignWith.count > 0 {
                                attemptToSignLocally()
                            } else {
                                finalize()
                            }
                        }
                    }
                } else {
                    reset()
                    completion((nil, nil, errorDescription))
                }
            }
        }
        
        func attemptToSignLocally() {
            /// Need to ensure similiar seeds do not sign mutliple times. This can happen if a user adds the same seed multiple times.
            var xprvStrings = [String]()
            
            for xprv in xprvsToSignWith {
                xprvStrings.append(xprv.description)
            }
            
            xprvsToSignWith.removeAll()
            var uniqueXprvs = Array(Set(xprvStrings))
            
            for uniqueXprv in uniqueXprvs {
                if let xprv = try? HDKey(base58: uniqueXprv) {
                    xprvsToSignWith.append(xprv)
                }
            }
            
            if xprvsToSignWith.count > 0 {
                var signableKeys = [String]()
                
                for (i, key) in xprvsToSignWith.enumerated() {
                    let inputs = psbtToSign.inputs
                    for (x, input) in inputs.enumerated() {
                        /// Create an array of child keys that we know can sign our inputs.
                        if let origins: [PubKey : KeyOrigin] = input.canSignOrigins(with: key) {
                            for origin in origins {
                                if let childKey = try? key.derive(using: origin.value.path) {
                                    if let privKey = childKey.privKey {
                                        precondition(privKey.pubKey == origin.key)
                                        signableKeys.append(privKey.wif)
                                    }
                                }
                            }
                        } else {
                            // Libwally does not like signing with direct decendants of m (e.g. m/0/0), so if above fails we can try and fall back on this, deriving child keys directly from root xprv.
                            if let origins = input.origins {
                                for origin in origins {
                                    if let path = try? BIP32Path(string: origin.value.path.description.replacingOccurrences(of: "m/", with: "")) {
                                        if var childKey = try? key.derive(using: path) {
                                            if var privKey = childKey.privKey {
                                                signableKeys.append(privKey.wif)
                                                // Overwrite vars with dummies for security
                                                privKey = try! Key(wif: "KwfUAErbeHJCafVr37aRnYcobent1tVV1iADD2k3T8VV1pD2qpWs", network: .mainnet)
                                                childKey = try! HDKey(base58: "xpub6FETvV487Sr4VSV9Ya5em5ZAug4dtnFwgnMG7TFAfkJDHoQ1uohXft49cFenfpJHbPueMnfyxtBoAuvSu7XNL9bbLzcM1QJCPwtofqv3dqC")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        /// Once the above loops complete we remove an duplicate signing keys from the array then sign the psbt with each unique key.
                        if i + 1 == xprvsToSignWith.count && x + 1 == inputs.count {
                            var uniqueSigners = Array(Set(signableKeys))
                            if uniqueSigners.count > 0 {
                                for (s, signer) in uniqueSigners.enumerated() {
                                    if var signingKey = try? Key(wif: signer, network: chain) {
                                        psbtToSign = try? psbtToSign.signed(with: signingKey)//psbtToSign.sign(signingKey)
                                        signingKey = try! Key(wif: "KwfUAErbeHJCafVr37aRnYcobent1tVV1iADD2k3T8VV1pD2qpWs", network: .mainnet)
                                        /// Once we completed the signing loop we finalize with our node.
                                        if s + 1 == uniqueSigners.count {
                                            xprvsToSignWith.removeAll()
                                            xprvStrings.removeAll()
                                            uniqueXprvs.removeAll()
                                            uniqueSigners.removeAll()
                                            signableKeys.removeAll()
                                            finalize()
                                        }
                                    }
                                }
                            } else {
                                xprvsToSignWith.removeAll()
                                xprvStrings.removeAll()
                                uniqueXprvs.removeAll()
                                uniqueSigners.removeAll()
                                signableKeys.removeAll()
                                finalize()
                            }
                        }
                    }
                }
            } else {
                finalize()
            }
        }
        
        /// Fetch keys to sign with
        func getKeysToSignWith() {
            xprvsToSignWith.removeAll()
            
            for (i, s) in seedsToSignWith.enumerated() {
                let signerStruct = SignerStruct(dictionary: s)
                
                if let encryptedSeed = signerStruct.words {
                    guard var seed = Crypto.decrypt(encryptedSeed) else {
                        reset()
                        completion((nil, nil, "Unable to decrypt your seed!"))
                        return
                    }
                    
                    if var words = String(data: seed, encoding: .utf8) {
                        seed = Data()
                        
                        if let providedPassphrase = passphrase {
                            if var masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: providedPassphrase) {
                                words = ""
                                if var hdkey = try? HDKey(base58: masterKey) {
                                    masterKey = ""
                                    xprvsToSignWith.append(hdkey)
                                    hdkey = try! HDKey(base58: "xpub6FETvV487Sr4VSV9Ya5em5ZAug4dtnFwgnMG7TFAfkJDHoQ1uohXft49cFenfpJHbPueMnfyxtBoAuvSu7XNL9bbLzcM1QJCPwtofqv3dqC")
                                    if i + 1 == seedsToSignWith.count {
                                        seedsToSignWith.removeAll()
                                        processWithActiveWallet()
                                    }
                                }
                            }
                            
                        } else if let encryptedPassphrase = signerStruct.passphrase {
                            guard let decryptedPassphrase = Crypto.decrypt(encryptedPassphrase) else {
                                reset()
                                completion((nil, nil, "Unable to decrypt your seed!"))
                                return
                            }
                            
                            if let passphrase = String(data: decryptedPassphrase, encoding: .utf8) {
                                if var masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: passphrase) {
                                    words = ""
                                    if var hdkey = try? HDKey(base58: masterKey) {
                                        masterKey = ""
                                        xprvsToSignWith.append(hdkey)
                                        hdkey = try! HDKey(base58: "xpub6FETvV487Sr4VSV9Ya5em5ZAug4dtnFwgnMG7TFAfkJDHoQ1uohXft49cFenfpJHbPueMnfyxtBoAuvSu7XNL9bbLzcM1QJCPwtofqv3dqC")
                                        if i + 1 == seedsToSignWith.count {
                                            seedsToSignWith.removeAll()
                                            processWithActiveWallet()
                                        }
                                    }
                                }
                            }
                        } else {
                            if var masterKey = Keys.masterKey(words: words, coinType: coinType, passphrase: "") {
                                words = ""
                                if var hdkey = try? HDKey(base58: masterKey) {
                                    masterKey = ""
                                    xprvsToSignWith.append(hdkey)
                                    hdkey = try! HDKey(base58: "xpub6FETvV487Sr4VSV9Ya5em5ZAug4dtnFwgnMG7TFAfkJDHoQ1uohXft49cFenfpJHbPueMnfyxtBoAuvSu7XNL9bbLzcM1QJCPwtofqv3dqC")
                                    if i + 1 == seedsToSignWith.count {
                                        seedsToSignWith.removeAll()
                                        processWithActiveWallet()
                                    }
                                }
                            }
                        }
                    }
                } else if i + 1 == seedsToSignWith.count {
                    seedsToSignWith.removeAll()
                    processWithActiveWallet()
                }
            }
        }
        
        /// Fetch wallets on the same network
        func getSeeds() {
            seedsToSignWith.removeAll()
            CoreDataService.retrieveEntity(entityName: .signers) { seeds in
                guard let seeds = seeds, seeds.count > 0 else { processWithActiveWallet(); return }
                for (i, seed) in seeds.enumerated() {
                    seedsToSignWith.append(seed)
                    if i + 1 == seeds.count {
                        getKeysToSignWith()
                    }
                }
            }
        }
        
        let network = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
        if network == "main" {
            chain = .mainnet
            coinType = "0"
        } else {
            chain = .testnet
            coinType = "1"
        }
        do {
            psbtToSign = try PSBT(psbt: psbt, network: chain)
            if psbtToSign.isComplete {
                finalize()
            } else {
                getSeeds()
            }
        } catch {
            completion((nil, nil, "Error converting that psbt"))
        }
        
    }
}

