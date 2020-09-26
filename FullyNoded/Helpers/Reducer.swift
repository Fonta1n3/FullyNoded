//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

enum ReducerError: Error {
    case description(String)
}

class Reducer {
    
    class func makeCommand(command: BTC_CLI_COMMAND, param: Any, completion: @escaping ((response: Any?, errorMessage: String?)) -> Void) {
        let torRPC = MakeRPCCall.sharedInstance
        
        func makeTorCommand() {
            torRPC.executeRPCCommand(method: command, param: param) { (response, errorDesc) in
                if response != nil {
                    completion((response!, nil))
                } else if errorDesc != nil {
                    handleError(errorDesc: errorDesc!)
                }
            }
        }
        
        func handleError(errorDesc: String) {
            if errorDesc.contains("Requested wallet does not exist or is not loaded") {
                handleWalletNotLoaded()
            } else if errorDesc.contains("Duplicate -wallet filename specified") {
                makeTorCommand()
            } else {
                completion((nil, errorDesc))
            }
        }
        
        func handleWalletNotLoaded() {
            if let walletName = UserDefaults.standard.object(forKey: "walletName") as? String {
                loadWallet(walletName: walletName)
            } else {
                completion((nil, "No active wallet, please activate a wallet first."))
            }
        }
        
        func loadWallet(walletName: String) {
            torRPC.executeRPCCommand(method: .loadwallet, param: "\"\(walletName)\"") { (response, errorDesc) in
                if errorDesc == nil {
                    makeTorCommand()
                } else if errorDesc!.contains("Duplicate -wallet filename specified") {
                    makeTorCommand()
                } else {
                    completion((nil, errorDesc))
                }
            }
        }
        makeTorCommand()
    }
    
    static func lock(_ utxo: UTXO, completion: @escaping (Result<Void, ReducerError>) -> Void) {
        let param = "false, ''[{\"txid\":\"\(utxo.txid)\",\"vout\":\(utxo.vout)}]''"
        makeCommand(command: .lockunspent, param: param) { (response, errorDescription) in
            
            guard errorDescription == nil else {
                completion(.failure(.description(errorDescription!)))
                return
            }
            
            guard let response = response as? Int else {
                completion(.failure(.description("Unable to lock that UTXO. Unable to cast response to Double")))
                return
            }
            
            guard response == 1 else {
                completion(.failure(.description("Unable to lock that UTXO")))
                return
            }
            
            completion(.success(()))
        }
    }
    
}
