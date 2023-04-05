//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Reducer {
    
    static let sharedInstance = Reducer()
    
    private init() {}
    
    func makeCommand(command: BTC_CLI_COMMAND, completion: @escaping ((response: Any?, errorMessage: String?)) -> Void) {
        let torRPC = MakeRPCCall.sharedInstance
        StreamManager.shared.onDoneBlock = { nostrResponse in
            if let errDesc = nostrResponse.errorDesc {
                if errDesc != "" {
                    handleError(errorDesc: nostrResponse.errorDesc!)
                } else {
                    if nostrResponse.response != nil {
                        completion((nostrResponse.response!, nil))
                    }
                }
            } else {
                if nostrResponse.response != nil {
                    completion((nostrResponse.response!, nil))
                }
            }
        }
                
        func makeTorCommand() {
            torRPC.executeRPCCommand(method: command) { (response, errorDesc) in
                if response != nil {
                    completion((response, nil))
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
            let param:Load_Wallet = .init(["filename": walletName])
            torRPC.executeRPCCommand(method: .loadwallet(param)) { (response, errorDesc) in
                if errorDesc == nil {
                    makeTorCommand()
                } else if errorDesc!.contains("Duplicate -wallet filename specified") {
                    makeTorCommand()
                } else if errorDesc!.contains("Wallet file verification failed") {
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    completion((nil, "Looks like your last used wallet does not exist on this node, please activate a wallet."))
                } else {
                    completion((nil, errorDesc))
                }
            }
        }
        
        makeTorCommand()
    }

}
