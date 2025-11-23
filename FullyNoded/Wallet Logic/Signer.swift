//
//  Signer.swift
//  BitSense
//
//  Created by Peter on 28/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Signer {
    
    static let shared = Signer()
    
    private init(){}
    
    func attemptToSignPsbt(fnWallet: Wallet, psbt: String, passphrase: String?, completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        guard let bdkNetwork = WalletLogic.shared.bdkNetwork() else {
            completion((nil, nil, "Failed getting bdkNetwork."))
            return
        }
                
        CoreDataService.retrieveEntity(entityName: .signers) { signers in
            guard let signers = signers, signers.count > 0 else {
                completion((nil, nil, "No signers."))
                return
            }
            
            for signer in signers {
                
                let signerStruct = SignerStruct(dictionary: signer)
                
                if let encryptedWords = signerStruct.words {
                    
                    guard var decryptedData = Crypto.decrypt(encryptedWords) else {
                        completion((nil, nil, "Unable to decrypt encrypted words."))
                        return
                    }
                    
                    guard var words = String(bytes: decryptedData, encoding: .utf8) else {
                        completion((nil, nil, "No signers."))
                        return
                    }
                    
                    guard let bdkMnemonic = try? WalletLogic.BDKMnemonic.fromString(mnemonic: words) else {
                        completion((nil, nil, "Failed converting words to BDKMnemonic."))
                        return
                    }
                    
                    defer {
                        decryptedData.secureZero()
                        words.secureWipe()
                    }
                    
                    WalletLogic.shared.wallet(passphrase: passphrase,
                                              network: bdkNetwork,
                                              mnemonic: bdkMnemonic,
                                              recDescStr: fnWallet.receiveDescriptor,
                                              changeDesStr: fnWallet.changeDescriptor,
                                              completion: { (bdkWallet, errorMessage) in
                        
                        guard let bdkWallet = bdkWallet else {
                            // We let this fail silently otherwise user needs to decide which signer to use which may scare people.
                            return
                        }
                        
                        let (signedPsbt, signedRawTx, errorMessage) = WalletLogic.shared.signPsbt(wallet: bdkWallet, psbtBase64: psbt)
                        
                        if signedPsbt != nil {
                            completion((signedPsbt, nil, nil))
                            return
                        } else if signedRawTx != nil {
                            completion((nil, signedRawTx, nil))
                            return
                        } else {
                            completion((nil, nil, errorMessage ?? "Unable to sign psbt."))
                            return
                        }
                    })
                }
            }
        }
    }
}

