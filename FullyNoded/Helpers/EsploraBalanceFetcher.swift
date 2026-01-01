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
    
    enum UtxosResult {
        case success(utxos: [Esplora_Utxo])
        case failure(errorMessage: String)
    }
    
    func fetchUtxos(for address: String, network: WalletLogic.BDKNetwork) async throws -> UtxosResult {
        let baseURL: String
        switch network {
        case .testnet: baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet"
        case .testnet4: baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet4"
        case .signet: baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/signet"
        default:
            baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"
        }
        
        guard let url = URL(string: "\(baseURL)/api/address/\(address)/utxo") else {
            throw URLError(.badURL)
        }
        
        do {
            let (data, response) = try await TorClient.sharedInstance.session.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(errorMessage: "Invalid response (not HTTP)")
            }
            
            // Handle non-200 status codes
            guard httpResponse.statusCode == 200 else {
                // Try to read error message from body (mempool returns plain text on error)
                if let errorText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !errorText.isEmpty {
                    return .failure(errorMessage: errorText) // e.g., "Address belongs to wrong network"
                } else {
                    return .failure(errorMessage: "HTTP \(httpResponse.statusCode): Request failed")
                }
            }
            
            // Success: Decode JSON
            guard !data.isEmpty else {
                // Empty array is valid (no UTXOs)
                return .success(utxos: [])
            }
            
            do {
                let utxos = try JSONDecoder().decode([Esplora_Utxo].self, from: data)
                return .success(utxos: utxos)
            } catch {
                return .failure(errorMessage: "JSON decoding failed: \(error.localizedDescription)")
            }
            
        } catch {
            // Network-level errors (timeout, no connection, etc.)
            return .failure(errorMessage: "Network error: \(error.localizedDescription)")
        }
    }
}



