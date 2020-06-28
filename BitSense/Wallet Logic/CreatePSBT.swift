//
//  CreatePSBT.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class CreatePSBT {
    
    class func create(outputs: String, completion: @escaping ((psbt: String?, rawTx: String?, errorMessage: String?)) -> Void) {
        let feeTarget = UserDefaults.standard.object(forKey: "feeTarget") as! Int
        //let output = "[{\"\(receiver)\":\(amount)}]"
        let param = "[], ''{\(outputs)}'', 0, {\"includeWatching\": true, \"replaceable\": true, \"conf_target\": \(feeTarget)}, true"
        Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
            if let result = response as? NSDictionary {
                let psbt = result["psbt"] as! String
                Signer.sign(psbt: psbt) { (psbt, rawTx, errorMessage) in
                    completion((psbt, rawTx, errorMessage))
                }
            }
        }
        
//        let reducer = Reducer()
//
//        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
//
//            func getResult() {
//
//                if !reducer.errorBool {
//
//                    switch method {
//
//                    case .listunspent:
//
//                        let resultArray = reducer.arrayToReturn
//                        parseUnspent(utxos: resultArray)
//
//                    case .createpsbt:
//
//                        psbt = reducer.stringToReturn
//                        completion()
//
//                    default:
//
//                        break
//
//                    }
//
//                } else {
//
//                    errorBool = true
//                    errorDescription = reducer.errorDescription
//                    completion()
//
//                }
//
//            }
//
//            reducer.makeCommand(command: method,
//                                param: param,
//                                completion: getResult)
//
//        }
//
//        func parseUnspent(utxos: NSArray) {
//
//            if utxos.count > 0 {
//
//                var loop = true
//                self.inputArray.removeAll()
//
//                var sumOfUtxo = 0.0
//
//                for utxoDict in utxos {
//
//                    let utxo = utxoDict as! NSDictionary
//
//                    if loop {
//
//                        let amountAvailable = utxo["amount"] as! Double
//                        sumOfUtxo = sumOfUtxo + amountAvailable
//
//                        if sumOfUtxo < self.amount {
//
//                            self.utxoTxId = utxo["txid"] as! String
//                            self.utxoVout = utxo["vout"] as! Int
//                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
//                            self.inputArray.append(input)
//
//                        } else {
//
//                            loop = false
//                            self.utxoTxId = utxo["txid"] as! String
//                            self.utxoVout = utxo["vout"] as! Int
//                            let input = "{\"txid\":\"\(self.utxoTxId)\",\"vout\": \(self.utxoVout),\"sequence\": 1}"
//                            self.inputArray.append(input)
//                            self.processInputs()
//
//                            self.changeAmount = sumOfUtxo - (self.amount + miningFee)
//                            self.changeAmount = Double(round(100000000*self.changeAmount)/100000000)
//
//                            let param = "''\(self.inputs)'', ''[{\"\(self.addressToPay)\":\(self.amount)}, {\"\(self.changeAddress)\":\(self.changeAmount)}]'', 0, true"
//
//                            executeNodeCommand(method: BTC_CLI_COMMAND.createpsbt,
//                                               param: param)
//
//                        }
//
//                    }
//
//                }
//
//            } else {
//
//                errorBool = true
//                errorDescription = "No UTXO's"
//                completion()
//
//            }
//
//        }
//
//        let miningFeeCheck = UserDefaults.standard.object(forKey: "miningFee") as! String
//        var miningFeeString = ""
//        miningFeeString = miningFeeCheck
//        miningFeeString = miningFeeString.replacingOccurrences(of: ",", with: "")
//        let fee = (Double(miningFeeString)!) / 100000000
//        miningFee = fee
//
//        executeNodeCommand(method: BTC_CLI_COMMAND.listunspent,
//                           param: "1, 9999999, [\"\(self.spendingAddress)\"]")
//
//    }
//
//    func processInputs() {
//
//        self.inputs = self.inputArray.description
//        self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
//        self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
//        self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
//        self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
//        self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
//
//    }
    }
    
}
