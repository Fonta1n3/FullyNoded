//
//  Reducer.swift
//  BitSense
//
//  Created by Peter on 20/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

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
    
    static func lock(_ utxo: UTXO, completion: @escaping (Result<Void, MakeRPCCallError>) -> Void) {
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
    
    static func unlock(_ utxo: UTXO, completion: @escaping (Result<Void, MakeRPCCallError>) -> Void) {
        let param = "true, ''[{\"txid\":\"\(utxo.txid)\",\"vout\":\(utxo.vout)}]''"
        makeCommand(command: .lockunspent, param: param) { (response, errorDescription) in
            
            guard errorDescription == nil else {
                completion(.failure(.description(errorDescription!)))
                return
            }
            
            guard let response = response as? Int else {
                completion(.failure(.description("Unable to unlock that UTXO. Unable to cast response to Double")))
                return
            }
            
            guard response == 1 else {
                completion(.failure(.description("Unable to unlock that UTXO")))
                return
            }
            
            completion(.success(()))
        }
    }
    
    // TODO: Move out of here into UtxosService class
    private struct ListUnspentResult: Decodable {
        let utxos: [UTXO]?
        let error: Error?
        
        enum CodingKeys: String, CodingKey {
            case utxos = "result"
            case error
        }
        
        struct Error: Decodable {
            let message: String
        }
    }
    
    // TODO: Move out of here into UtxosService class
    static func listUnspentUTXOs(completion: @escaping (Result<[UTXO], MakeRPCCallError>) -> Void) {
        retry(20, task: { completion in
            MakeRPCCall.sharedInstance.executeCommand(method: .listunspent, param: "0", completion: completion)
        }) { result in
            switch result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    let decodedResult = try decoder.decode(ListUnspentResult.self, from: data)

                    if let errorMessage = decodedResult.error?.message {
                        completion(.failure(.description(errorMessage)))
                    } else if let utxos = decodedResult.utxos {
                        completion(.success(utxos))
                    } else {
                        completion(.failure(.description("JSON's result and error values are null.")))
                    }
                } catch let error {
                    completion(.failure(.description("Decoding Error: \(error)")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    static func listLockedUTXOs(completion: @escaping (Result<[UTXO], MakeRPCCallError>) -> Void) {
        retry(20, task: { completion in
            MakeRPCCall.sharedInstance.executeCommand(method: .listlockunspent, param: "", completion: completion)
        }) { result in
            switch result {
            case .success(let data):
                do {
                    let decoder = JSONDecoder()
                    let decodedResult = try decoder.decode(ListUnspentResult.self, from: data)

                    if let errorMessage = decodedResult.error?.message {
                        completion(.failure(.description(errorMessage)))
                    } else if let utxos = decodedResult.utxos {
                        completion(.success(utxos))
                    } else {
                        completion(.failure(.description("JSON's result and error values are null.")))
                    }
                } catch let error {
                    completion(.failure(.description("Decoding Error: \(error)")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    private static func retry<T>(_ attempts: Int, task: @escaping (_ completion: @escaping (Result<T, MakeRPCCallError>) -> Void) -> Void, completion: @escaping (Result<T, MakeRPCCallError>) -> Void) {

        task { result in
            switch result {
            case .success(_):
                completion(result)
            case .failure(let error):
                print("""
                    Attempts left: \(attempts).
                    Error: \(error)
                    """)
                if attempts > 1 {
                    self.retry(attempts - 1, task: task, completion: completion)
                } else {
                    completion(result)
                }
            }
        }
    }
}
