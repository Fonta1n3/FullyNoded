//
//  EsploraBalanceFetcher.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/6/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

import Foundation

class NodelessBalanceFetcher {
    
    static let shared = NodelessBalanceFetcher()
    
    func fetchAddressBalance(
        address: String,
        isTestnet: Bool,
        completion: @escaping (Result<Double, Error>) -> Void
    ) {
        let torSesh = TorClient.sharedInstance.session
        let testnetUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api/"
        let mainnetUrl = "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/"
        // Select base URL
        let baseURL = isTestnet ? testnetUrl : mainnetUrl
        
        guard let url = URL(string: "\(baseURL)address/\(address)") else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create URL"])))
            return
        }
        
        print("url: \(url)")
        
        let task = torSesh.dataTask(with: url) { data, response, error in
            // Handle network errors
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "NoData", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                }
                return
            }
            
            do {
                // Decode JSON
                let decoder = JSONDecoder()
                let result = try decoder.decode(EsploraAddressResponse.self, from: data)
                
                // Calculate total balance: chain + mempool
                let chainBalance = result.chain_stats.funded_txo_sum - result.chain_stats.spent_txo_sum
                let mempoolBalance = result.mempool_stats.funded_txo_sum - result.mempool_stats.spent_txo_sum
                let totalBalance = UInt64(chainBalance + mempoolBalance)
                
                DispatchQueue.main.async {
                    completion(.success(Double(totalBalance) / 100_000_000.0))
                }
            } catch {
                if let utf8 = data.utf8String {
                    completion(.failure(NSError(domain: "", code: -2, userInfo: [NSLocalizedDescriptionKey: utf8])))
                }
            }
        }
        
        task.resume()
    }
    
    // MARK: - Supporting Structs for JSON Decoding
    struct EsploraAddressResponse: Decodable {
        let chain_stats: Stats
        let mempool_stats: Stats
        
        struct Stats: Decodable {
            let funded_txo_sum: Int64
            let spent_txo_sum: Int64
        }
    }
}



