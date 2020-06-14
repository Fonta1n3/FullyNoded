//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class Reducer {
    
    let torRPC = MakeRPCCall.sharedInstance
    var dictToReturn = NSDictionary()
    var doubleToReturn = Double()
    var arrayToReturn = NSArray()
    var stringToReturn = String()
    var boolToReturn = Bool()
    var errorBool = Bool()
    var errorDescription = ""
    
    var method = ""
    
    func makeCommand(command: BTC_CLI_COMMAND, param: Any, completion: @escaping () -> Void) {
        
        method = command.rawValue
        
        func parseResponse(response: Any) {
            
            if let str = response as? String {
                
                self.stringToReturn = str
                completion()
                
            } else if let doub = response as? Double {
                
                self.doubleToReturn = doub
                completion()
                
            } else if let arr = response as? NSArray {
                
                self.arrayToReturn = arr
                completion()
                
            } else if let dic = response as? NSDictionary {
                
                self.dictToReturn = dic
                completion()
                
            } else {
                
                if command == .unloadwallet {
                    
                    self.stringToReturn = "Wallet unloaded"
                    completion()
                    
                } else if command == .importprivkey {
                    
                    self.stringToReturn = "Imported key success"
                    completion()
                    
                } else if command == .walletpassphrase {
                    
                    self.stringToReturn = "Wallet decrypted"
                    completion()
                    
                } else if command == .walletpassphrasechange {
                    
                    self.stringToReturn = "Passphrase updated"
                    completion()
                    
                } else if command == .walletlock {
                    
                    self.stringToReturn = "Wallet encrypted"
                    completion()
                    
                }
                
            }
            
        }
        
        func torCommand() {
            
            func getResult() {
                if !torRPC.errorBool {
                    let response = torRPC.objectToReturn
                    parseResponse(response: response as Any)
                } else {
                    if torRPC.errorDescription.contains("Requested wallet does not exist or is not loaded") {
                        if let walletName = UserDefaults.standard.object(forKey: "walletName") as? String {
                            torRPC.executeRPCCommand(method: .loadwallet, param: "\"\(walletName)\"") { [unowned vc = self] in
                                if !vc.torRPC.errorBool || vc.torRPC.errorDescription.contains("Duplicate -wallet filename specified") {
                                    vc.torRPC.executeRPCCommand(method: command, param: param) { [unowned vc = self] in
                                        if !vc.torRPC.errorBool {
                                            let response = vc.torRPC.objectToReturn
                                            parseResponse(response: response as Any)
                                        } else {
                                            vc.errorBool = true
                                            vc.errorDescription = vc.torRPC.errorDescription
                                            completion()
                                        }
                                    }
                                } else {
                                    vc.errorBool = true
                                    vc.errorDescription = vc.torRPC.errorDescription
                                    completion()
                                }
                            }
                        }
                        
                    } else {
                        errorBool = true
                        errorDescription = torRPC.errorDescription
                        completion()
                    }
                }
            }
            
            torRPC.executeRPCCommand(method: command, param: param, completion: getResult)
        }
        
        torRPC.errorBool = false
        torRPC.errorDescription = ""
        torCommand()
    }
}
