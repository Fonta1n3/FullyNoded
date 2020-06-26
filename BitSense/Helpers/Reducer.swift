//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Reducer {
    
    
//    var dictToReturn = NSDictionary()
//    var doubleToReturn = Double()
//    var arrayToReturn = NSArray()
//    var stringToReturn = String()
//    var boolToReturn = Bool()
//    var errorBool = Bool()
//    var errorDescription = ""
    
    //var method = ""
    
    class func makeCommand(command: BTC_CLI_COMMAND, param: Any, completion: @escaping ((response: Any?, errorMessage: String?)) -> Void) {
        let torRPC = MakeRPCCall.sharedInstance
        //method = command.rawValue
        
//        func parseResponse(response: Any) {
//
//            if let str = response as? String {
//
//                self.stringToReturn = str
//                completion()
//
//            } else if let doub = response as? Double {
//
//                self.doubleToReturn = doub
//                completion()
//
//            } else if let arr = response as? NSArray {
//
//                self.arrayToReturn = arr
//                completion()
//
//            } else if let dic = response as? NSDictionary {
//
//                self.dictToReturn = dic
//                completion()
//
//            } else {
//
//                if command == .unloadwallet {
//
//                    self.stringToReturn = "Wallet unloaded"
//                    completion()
//
//                } else if command == .importprivkey {
//
//                    self.stringToReturn = "Imported key success"
//                    completion()
//
//                } else if command == .walletpassphrase {
//
//                    self.stringToReturn = "Wallet decrypted"
//                    completion()
//
//                } else if command == .walletpassphrasechange {
//
//                    self.stringToReturn = "Passphrase updated"
//                    completion()
//
//                } else if command == .walletlock {
//
//                    self.stringToReturn = "Wallet encrypted"
//                    completion()
//
//                }
//
//            }
//
//        }
        
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
                if errorDesc!.contains("Duplicate -wallet filename specified") {
                    //handleDuplicateError()
                    completion(("", nil))
                } else {
                    completion((nil, errorDesc))
                }
            }
        }
        
//        func handleDuplicateError() {
//            torRPC.executeRPCCommand(method: command, param: param) { (response, errorDesc) in
//                if response != nil {
//                    completion((response, nil))
//                } else {
//                    completion((nil, errorDesc))
//                }
//            }
//        }
        
//        func torCommand() {
//
//            func getResult() {
//                if !torRPC.errorBool {
//                    let response = torRPC.objectToReturn
//                    //parseResponse(response: response as Any)
//                    completion((response, nil))
//                } else {
//                    if torRPC.errorDescription.contains("Requested wallet does not exist or is not loaded") {
//                        if let walletName = UserDefaults.standard.object(forKey: "walletName") as? String {
//                            torRPC.executeRPCCommand(method: .loadwallet, param: "\"\(walletName)\"") { [unowned vc = self] in
//                                if !vc.torRPC.errorBool || vc.torRPC.errorDescription.contains("Duplicate -wallet filename specified") {
//                                    vc.torRPC.executeRPCCommand(method: command, param: param) { [unowned vc = self] in
//                                        if !vc.torRPC.errorBool {
//                                            let response = vc.torRPC.objectToReturn
//                                            //parseResponse(response: response as Any)
//                                            completion((response, nil))
//                                        } else {
//                                            //vc.errorBool = true
//                                            //vc.errorDescription = vc.torRPC.errorDescription
//                                            completion((nil, vc.torRPC.errorDescription))
//                                        }
//                                    }
//                                } else {
//                                    //vc.errorBool = true
//                                    //vc.errorDescription = vc.torRPC.errorDescription
//                                    completion((nil, vc.torRPC.errorDescription))
//                                }
//                            }
//                        }
//
//                    } else {
//                        //errorBool = true
//                        //errorDescription = torRPC.errorDescription
//                        completion((nil, torRPC.errorDescription))
//                    }
//                }
//            }
//
//            torRPC.executeRPCCommand(method: command, param: param, completion: getResult)
//        }
        
        //torRPC.errorBool = false
        //torRPC.errorDescription = ""
        //torCommand()
        makeTorCommand()
    }
}
