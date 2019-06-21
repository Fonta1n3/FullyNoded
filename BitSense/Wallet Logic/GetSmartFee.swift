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
    var errorBool = Bool()
    var errorDescription = ""
    var dictToReturn = NSDictionary()
    var rawSigned = ""
    var txSize = Int()
    var vc = UIViewController()
    
    func getSmartFee() {
        
        func getSmartFeeSSH(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    switch method {
                        
                    case BTC_CLI_COMMAND.estimatesmartfee:
                        
                        let dict = makeSSHCall.dictToReturn
                        displayFeeAlert(dict: dict, vsize: txSize)
                        
                    case BTC_CLI_COMMAND.decoderawtransaction:
                        
                        let dict = makeSSHCall.dictToReturn
                        txSize = dict["vsize"] as! Int
                        getSmartFeeSSH(method: BTC_CLI_COMMAND.estimatesmartfee,
                                            param: "6")
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = makeSSHCall.errorDescription
                    
                }
                
            }
            
            if ssh.session.isConnected {
                
                makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                              method: method,
                                              param: param,
                                              completion: getResult)
                
            } else {
                
                errorBool = true
                errorDescription = "Not connected"
                
            }
            
        }
        
        getSmartFeeSSH(method: BTC_CLI_COMMAND.decoderawtransaction,
                       param: "\"\(self.rawSigned)\"")
        
    }
    
    func displayFeeAlert(dict: NSDictionary, vsize: Int) {
        
        let miningFeeString = UserDefaults.standard.object(forKey: "miningFee") as! String
        let txSize = Double(vsize)
        
        var btcPerKbyte = Double()
        
        if let btcPerKbyteCheck = dict["feerate"] as? Double {
            
            btcPerKbyte = btcPerKbyteCheck
            
        } else {
            
            btcPerKbyte = 0.00000100
            
            displayAlert(viewController: vc,
                         isError: true,
                         message: "There was an issue getting the fee estimate, we have manually set it for you. This may happen when running the node in regtest.")
            
        }
        
        let btcPerByte = btcPerKbyte / 1000
        let satsPerByte = btcPerByte * 100000000
        let optimalFeeForSixBlocks = satsPerByte * txSize
        let nocommas = miningFeeString.replacingOccurrences(of: ",", with: "")
        let actualFeeInSats = Double(nocommas)!
        let diff = optimalFeeForSixBlocks - actualFeeInSats
        
        if diff < 0 {
            
            //overpaying
            let percentageDifference = Int(((actualFeeInSats / optimalFeeForSixBlocks) * 100)).avoidNotation
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""),
                                              message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% higher then necessary.\n\nWe suggest going to settings and lowering your mining fee to the suggested amount.", preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                              style: .default,
                                              handler: { (action) in }))
                
                self.vc.present(alert, animated: true)
                
            }
            
        } else {
            
            //underpaying
            let percentageDifference = Int((((optimalFeeForSixBlocks - actualFeeInSats) / optimalFeeForSixBlocks) * 100)).avoidNotation
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: NSLocalizedString("Fee Alert", comment: ""),
                                              message: "The optimal fee to get this tx included in the next 6 blocks is \(Int(optimalFeeForSixBlocks)) satoshis.\n\nYou are currently paying a fee of \(Int(actualFeeInSats)) satoshis which is \(percentageDifference)% lower then necessary.\n\nWe suggest going to settings and raising your mining fee to the suggested amount, however RBF is enabled by default, you can always tap an unconfirmed tx in the home screen to bump the fee.",
                    preferredStyle: UIAlertController.Style.alert)
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                              style: .default,
                                              handler: { (action) in }))
                
                self.vc.present(alert, animated: true)
                
            }
            
        }
        
    }
    
}
