//
//  TXChain.swift
//  BitSense
//
//  Created by Peter on 29/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class TXChain {
    
    var errorBool = Bool()
    var errorDescription = ""
    
    var inputArray = [Any]()
    
    var tx = ""
    var inputAmount = Double()
    var outputAmount = Double()
    
    var prevTxID = ""
    var vout = Int()
    var outputTotalValue = Double()
    var inputTotalValue = Double()
    var inputsIndex = 0
    var inputs = ""
    
    var amount = Double()
    var processedChain = ""
    
    var chainToReturn = ""
    var linkToChainWith = ""
    
    var myLinkOutputAmount = 0.0
    
    func addALink(completion: @escaping () -> Void) {
        
        let reducer = Reducer()
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .decodepsbt:
                        
                        // verify its suitable for a TXChain, get total input amount and total output amount
                        // build another psbt with my wallet with same amounts
                        let psbtDict = reducer.dictToReturn
                        getInputOutputTotals(psbt: psbtDict)
                        
                    case .joinpsbts:
                        
                        let result = reducer.stringToReturn
                        chainToReturn = result
                        completion()
                        
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        func getInputOutputTotals(psbt: NSDictionary) {
            
            let txDict = psbt["tx"] as! NSDictionary
            let outputs = txDict["vout"] as! NSArray
            let inputs = psbt["inputs"] as! NSArray
            var prevInputAmount = Double()
            var prevOutputAmount = Double()
            
            func chainLinked() {
                
                if !reducer.errorBool {
                    
                    executeNodeCommand(method: BTC_CLI_COMMAND.joinpsbts,
                                          param: "[\"\(self.tx)\", \"\(processedChain)\"]")
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            for (index, inputDict) in inputs.enumerated() {
                
                let input = inputDict as! NSDictionary
                let witness_utxo = input["witness_utxo"] as! NSDictionary
                let inputAmount = witness_utxo["amount"] as! Double
                
                // incase more then one input check previous inputamount == current inputamount, checks all input amounts are identical, if not reject it
                
                if index != 0 {
                    
                    //first compare prev amount to current amount
                    if prevInputAmount == inputAmount {
                        
                        prevInputAmount = inputAmount
                        //inputTotalValue += inputAmount
                        
                        //the loop is finished move to check outputs
                        if index + 1 == inputs.count {
                            
                            // next step
                            self.amount = inputAmount
                            
                            for (outputIndex, outputDict) in outputs.enumerated() {
                                
                                let output = outputDict as! NSDictionary
                                let outputAmount = output["value"] as! Double
                                //self.outputTotalValue += outputAmount
                                
                                if outputIndex != 0 {
                                    
                                    //checks all outputs are the same, if not reject it
                                    if prevOutputAmount == outputAmount {
                                        
                                        if outputIndex + 1 == outputs.count {
                                            
                                            self.myLinkOutputAmount = outputAmount
                                            self.startAChain(completion: chainLinked)
                                            
                                        } else {
                                            
                                            //loop not finished
                                            prevOutputAmount = outputAmount
                                            
                                        }
                                        
                                    } else {
                                        
                                        errorBool = true
                                        errorDescription = "Output amounts are not equal, this PSBT is not suitable for a TXChain, all outputs must be identical amounts"
                                        completion()
                                        
                                    }
                                    
                                } else {
                                    
                                    // not on zero index so no need to check if outputs are the same
                                    if outputIndex + 1 == outputs.count {
                                        
                                        self.myLinkOutputAmount = outputAmount
                                        self.startAChain(completion: chainLinked)
                                        
                                    } else {
                                        
                                        //loop not finished
                                        prevOutputAmount = outputAmount
                                        
                                    }
                                    
                                }
                                
                            }
                            
                        }
                        
                    } else {
                        
                        errorBool = true
                        errorDescription = "Input amounts are not equal, this PSBT is not suitable for a TXChain, all inputs must be identical amounts"
                        completion()
                        
                    }
                    
                } else {
                    
                    // no need to compare input amounts on the first input
                    prevInputAmount = inputAmount
                    //inputTotalValue += inputAmount
                    
                    //the loop is finished move to check outputs
                    if index + 1 == inputs.count {
                        
                        for (outputIndex, outputDict) in outputs.enumerated() {
                            
                            let output = outputDict as! NSDictionary
                            let outputAmount = output["value"] as! Double
                            //self.outputTotalValue += outputAmount
                            
                            // next step
                            self.amount = inputAmount
                            
                            if outputIndex + 1 == outputs.count {
                                
                                self.myLinkOutputAmount = outputAmount
                                self.startAChain(completion: chainLinked)
                                
                            } else {
                                
                                //loop not finished
                                
                            }
                            
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
        executeNodeCommand(method: BTC_CLI_COMMAND.decodepsbt,
                              param: "\"\(tx)\"")
        
    }
    
    func startAChain(completion: @escaping () -> Void) {
        
        var initialAddress = ""
        var txid = ""
        var readyForChain = false
        
        func processInputs() {
            
            self.inputs = self.inputArray.description
            self.inputs = self.inputs.replacingOccurrences(of: "[\"", with: "[")
            self.inputs = self.inputs.replacingOccurrences(of: "\"]", with: "]")
            self.inputs = self.inputs.replacingOccurrences(of: "\"{", with: "{")
            self.inputs = self.inputs.replacingOccurrences(of: "}\"", with: "}")
            self.inputs = self.inputs.replacingOccurrences(of: "\\", with: "")
            
        }
        
        func executeNodeCommand(method: BTC_CLI_COMMAND, param: String) {
            
            let reducer = Reducer()
            
            func getResult() {
                
                if !reducer.errorBool {
                    
                    switch method {
                        
                    case .getnewaddress:
                        
                        // send specified amount to oursleves to create needed utxo as input for our new psbt
                        if !readyForChain {
                            
                            initialAddress = reducer.stringToReturn
                            
                            let param = "\"\(initialAddress)\", \(amount), \"Create TXChain Input\""
                            
                            executeNodeCommand(method: BTC_CLI_COMMAND.sendtoaddress,
                                                  param: param)
                            
                        } else {
                            
                            // will need to optimize fee
                            // hard coding tiny fee for testnet, MUST CHANGE THIS
                            let round = rounded(number: self.amount - 0.00001000)
                            var outputAmount = round
                            
                            //checking if we are adding a link or creating a new one to determine output amount
                            if self.myLinkOutputAmount != 0.0 {
                                
                                outputAmount = rounded(number: self.myLinkOutputAmount)
                                
                            }
                            
                            let param = "''\(self.inputs)'', ''[{\"\(reducer.stringToReturn)\":\(outputAmount)}]'', 0, true"
                            
                            executeNodeCommand(method: BTC_CLI_COMMAND.createpsbt,
                                                  param: param)
                        }
                        
                    case .sendtoaddress:
                        
                        txid = reducer.stringToReturn
                        
                        executeNodeCommand(method: BTC_CLI_COMMAND.getrawtransaction,
                                              param: "\"\(txid)\"")
                        
                    case .getrawtransaction:
                        
                        let raw = reducer.stringToReturn
                        
                        executeNodeCommand(method: BTC_CLI_COMMAND.decoderawtransaction,
                                              param: "\"\(raw)\"")
                        
                    case .decoderawtransaction:
                        
                        let dict = reducer.dictToReturn
                        let outputs = dict["vout"] as! NSArray
                        
                        for outputDict in outputs {
                         
                            let output = outputDict as! NSDictionary
                            let value = output["value"] as! Double
                            let scriptPubKey = output["scriptPubKey"] as! NSDictionary
                            let addresses = scriptPubKey["addresses"] as! NSArray
                            let outputAddress = addresses[0] as! String
                            
                            if value == amount && outputAddress == initialAddress {
                             
                                let vout = output["n"] as! Int
                                let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                                inputArray.append(input)
                                processInputs()
                                
                                readyForChain = true
                                
                                executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress,
                                                      param: "\"\", \"bech32\"")
                                
                            }
                            
                        }
                        
                    case .createpsbt:
                        
                        let firstChain = reducer.stringToReturn
                        print("firstChain = \(firstChain)")
                        
                        executeNodeCommand(method: BTC_CLI_COMMAND.utxoupdatepsbt,
                                              param: "\"\(firstChain)\"")
                        
                    case .utxoupdatepsbt:
                        
                        processedChain = reducer.stringToReturn
                        completion()
                        
                    default:
                        
                        break
                        
                    }
                    
                } else {
                    
                    errorBool = true
                    errorDescription = reducer.errorDescription
                    completion()
                    
                }
                
            }
            
            reducer.makeCommand(command: method,
                                param: param,
                                completion: getResult)
            
        }
        
        executeNodeCommand(method: BTC_CLI_COMMAND.getnewaddress,
                                  param: "\"\", \"bech32\"")
                    
    }
    
}
