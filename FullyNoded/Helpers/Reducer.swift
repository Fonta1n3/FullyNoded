//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

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
//            } else if errorDesc.contains("Wallet file not specified (must request wallet RPC through") {
//                DispatchQueue.main.async {
//                    let alertWindow = UIWindow(frame: UIScreen.main.bounds)
//                    alertWindow.rootViewController = UIViewController()
//                    showAlert(vc: alertWindow.rootViewController, title: "No wallet specified!", message: "Please go to your Active Wallet tab and toggle on a wallet then try this operation again, for certain commands Bitcoin Core needs to know which wallet to talk to.")
//                }
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
                DispatchQueue.main.async {
                    let alertWindow = UIWindow(frame: UIScreen.main.bounds)
                    alertWindow.rootViewController = UIViewController()
                    showAlert(vc: alertWindow.rootViewController, title: "Wallet loading..", message: "Just letting you know a loadwallet command was just issued. In certain circumstances this can take awhile, generally it should be less then 5 seconds.")
                }
                
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

}
