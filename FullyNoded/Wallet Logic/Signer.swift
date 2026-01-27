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
    
    func attemptToSignPsbt(fnWallet: Wallet,
                           psbt: String,
                           passphrase: String?,
                           utxoParentDesc: String,
                           completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        
        guard let bdkNetwork = WalletLogic.shared.bdkNetwork() else {
            completion((nil, nil, "Failed getting bdkNetwork."))
            return
        }
                
        CoreDataService.retrieveEntity(entityName: .signers) { [weak self] signers in
            guard let self = self else { return }
            
            guard let signers = signers, signers.count > 0 else {
                completion((nil, nil, "No signers."))
                return
            }
            
            #if DEBUG
            print("utxoParentDesc: \(utxoParentDesc)")
            #endif
            
            var signerArray: [SignerStruct] = []
            for (i, signer) in signers.enumerated() {
                let signerStr = SignerStruct(dictionary: signer)
                if let _ = signerStr.words {
                        if let encryptedXfp = signerStr.xfp, let decryptedXfp = Crypto.decrypt(encryptedXfp), let utf8Xfp = decryptedXfp.utf8String {
                            let fnDesc = Descriptor(utxoParentDesc)
                            if fnDesc.fingerprint.contains(utf8Xfp) {
                                signerArray.append(signerStr)
                            }
                        }
                }
                if i + 1 == signers.count {
                    sign(fnWallet: fnWallet, psbt: psbt, passphrase: passphrase, signers: signerArray, network: bdkNetwork, parentDesc: utxoParentDesc, completion: completion)
                }
            }
        }
    }
    
    // need to create individual BDKWallets using the timelocked descriptor
    func sign(fnWallet: Wallet,
              psbt: String,
              passphrase: String?,
              signers: [SignerStruct],
              network: WalletLogic.BDKNetwork,
              parentDesc: String,
              completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        
        var psbtToReturn: String?
        var rawTxToReturn: String?
        var errorToReturn: String?
        
        for (i, signerStruct) in signers.enumerated() {
                        
            if var encryptedWords = signerStruct.words {
                
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
                    encryptedWords.secureZero()
                }
                                
                var changeDesc = fnWallet.changeDescriptor
                
                // if its change the parent desc will be the change desc...
                if parentDesc.contains("/1/") {
                    changeDesc = fnWallet.receiveDescriptor
                }
                
                WalletLogic.shared.wallet(passphrase: passphrase,
                                          network: network,
                                          mnemonic: bdkMnemonic,
                                          recDescStr: parentDesc,
                                          changeDesStr: changeDesc,
                                          completion: { (bdkWallet, errorMessage) in
                    
                    guard let bdkWallet = bdkWallet else {
                        // We let this fail silently otherwise user needs to decide which signer to use which may scare people.
                        #if DEBUG
                        print("bdkWallet creation failed")
                        #endif
                        return
                    }                    
                    
                    let (signedPsbt, signedRawTx, errorMessage) = WalletLogic.shared.signPsbt(wallet: bdkWallet, psbtBase64: psbt)
                    #if DEBUG
                    print("rawTx: \(signedRawTx ?? "")")
                    #endif
                    
                    
                    if signedRawTx != nil {
                        rawTxToReturn = signedRawTx
                    } else if signedPsbt != nil {
                        psbtToReturn = signedPsbt
                    } else {
                        errorToReturn = errorMessage
                    }
                })
            }
            
            if i + 1 == signers.count {
                completion((psbtToReturn, rawTxToReturn, errorToReturn))
            }
        }
    }
}

