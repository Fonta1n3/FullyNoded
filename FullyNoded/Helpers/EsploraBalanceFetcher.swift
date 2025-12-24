//
//  EsploraBalanceFetcher.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/6/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

import Foundation

class NodelessUtxoFetcher {
    
    static let shared = NodelessUtxoFetcher()
    
    private init() {}
    
    func fetchUtxos(for address: String, isTestnet: Bool = false) async throws -> [Esplora_Utxo] {
        let baseUrl = isTestnet
            ? "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/testnet/api/"
            : "http://explorerzydxu5ecjrkwceayqybizmpjjznk5izmitf2modhcusuqlid.onion/api/"
        
        guard let url = URL(string: "\(baseUrl)/address/\(address)/utxo") else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await TorClient.sharedInstance.session.data(from: url)
        
        // Basic response validation
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        // Decode JSON array directly into [Utxo]
        let utxos = try JSONDecoder().decode([Esplora_Utxo].self, from: data)
        
        return utxos
    }
}



