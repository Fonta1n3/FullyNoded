//
//  GetSmartFee.swift
//  BitSense
//
//  Created by Peter on 21/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class GetSmartFee {
    
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var isUsingSSH = Bool()
    var torRPC:MakeRPCCall!
    var torClient:TorClient!
    
    var errorBool = Bool()
    var errorDescription = ""
    
    var dictToReturn = NSDictionary()
    var rawSigned = ""
    var txSize = Int()
    var vc = UIViewController()
    var blockTarget = UserDefaults.standard.object(forKey: "feeTarget") as! Int
    var optimalFee = Double()
    
    var isUnsigned = false
    
    func getSmartFee(completion: @escaping () -> Void) {
        
        func getSmartFeeSSH(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.estimatesmartfee:
                        
                        let dict = makeSSHCall.dictToReturn
                        optimalFee = getOptimalFee(dict: dict, vsize: txSize)
                        print("optimalFee = \(optimalFee.avoidNotation)")
                        completion()
                        
                    case BTC_CLI_COMMAND.decoderawtransaction:
                        
                        let dict = makeSSHCall.dictToReturn
                        txSize = dict["vsize"] as! Int
                        
                        getSmartFeeSSH(method: BTC_CLI_COMMAND.estimatesmartfee,
                                       param: "\(blockTarget)")
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = makeSSHCall.errorDescription
                    
                }
                
            }
            
            if ssh != nil {
                
                if ssh.session.isConnected {
                    
                    makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                                  method: method,
                                                  param: param,
                                                  completion: getResult)
                    
                } else {
                    
                    errorBool = true
                    errorDescription = "Not connected"
                    
                }
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                
            }
            
        }
        
        getSmartFeeSSH(method: BTC_CLI_COMMAND.decoderawtransaction,
                       param: "\"\(self.rawSigned)\"")
        
    }
    
    func getOptimalFee(dict: NSDictionary, vsize: Int) -> Double {
        
        var size = vsize
        
        if isUnsigned {
            
            size += 100
            
        }
        
        let txSize = Double(size)
        
        var btcPerKbyte = Double()
        
        if let btcPerKbyteCheck = dict["feerate"] as? Double {
            
            btcPerKbyte = btcPerKbyteCheck
            
        } else {
            
            // Node is likely in regtest mode so fee estimation is weird
            btcPerKbyte = 0.00000100
            
        }
        
        let btcPerByte = btcPerKbyte / 1000
        let optimalFee = btcPerByte * txSize
        return optimalFee
        
    }
    
}
