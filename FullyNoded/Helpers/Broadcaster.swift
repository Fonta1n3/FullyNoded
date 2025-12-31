//
//  Broadcaster.swift
//  BitSense
//
//  Created by Peter on 03/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

class Broadcaster {
    
    static let sharedInstance = Broadcaster()
    lazy var torClient = TorClient.sharedInstance
    
    enum BroadcastResult {
        case success(txid: String)
        case failure(errorMessage: String)
    }
    
    func broadcastRawTransaction(
        rawTx: String,
        network: String = "mainnet",
        completion: @escaping (BroadcastResult) -> Void
    ) {
        let onionAddress = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion"
        
        let baseURL = network.lowercased() == "testnet" ? "\(onionAddress)/testnet" : onionAddress
        
        guard let url = URL(string: "\(baseURL)/api/tx") else {
            completion(.failure(errorMessage: "Invalid URL"))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(rawTx.utf8)
        
        let task = torClient.session.dataTask(with: request) { data, response, error in
            // Network-level error
            if let error = error {
                completion(.failure(errorMessage: "Network error: \(error.localizedDescription)"))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(errorMessage: "Invalid response"))
                return
            }
            
            // Parse response body as string (if available)
            let responseString = data.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "(no response body)"
            
            if httpResponse.statusCode == 200 {
                // Success: response body is the txid
                if responseString.isEmpty {
                    completion(.failure(errorMessage: "Success status but empty txid"))
                } else {
                    completion(.success(txid: responseString))
                }
            } else {
                // Failure: use the response body as error message (common errors like "sendrawtransaction RPC error", missing inputs, etc.)
                completion(.failure(errorMessage: "HTTP \(httpResponse.statusCode): \(responseString)"))
            }
        }
        
        task.resume()
    }    
}
