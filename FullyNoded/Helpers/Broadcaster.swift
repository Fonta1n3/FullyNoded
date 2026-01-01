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
    
    enum BroadcastResult {
        case success(txid: String)
        case failure(errorMessage: String)
    }
    
    func broadcastRawTransaction(rawTx: String, network: WalletLogic.BDKNetwork) async throws -> BroadcastResult {
        let baseURL: String
        switch network {
        case .testnet:   baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet"
        case .testnet4:  baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/testnet4"
        case .signet:    baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/signet"
        default:
            baseURL = "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion"
        }
        
        guard let url = URL(string: "\(baseURL)/api/tx") else {
            return .failure(errorMessage: "Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = rawTx.data(using: .utf8)
        
        do {
            let (data, response) = try await TorClient.sharedInstance.session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure(errorMessage: "Invalid response")
            }
            
            if httpResponse.statusCode == 200,
               let txid = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !txid.isEmpty {
                return .success(txid: txid)
            }
            
            let errorMsg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown error"
            return .failure(errorMessage: errorMsg)
            
        } catch {
            return .failure(errorMessage: error.localizedDescription)
        }
    }
}
