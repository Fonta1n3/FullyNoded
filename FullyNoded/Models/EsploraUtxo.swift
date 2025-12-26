//
//  EsploraUtxo.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/24/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

struct Esplora_Utxo: Codable {
    let txid: String
    let vout: Int
    let value: Int64 // satoshis
    let status: Status
    var address: String?
    var lastUpdated: Date?
    var id: UUID?
    
    struct Status: Codable {
        let confirmed: Bool
        let blockHeight: Int? // nil if unconfirmed
        let blockHash: String?
        let blockTime: Int64?
        
        private enum CodingKeys: String, CodingKey {
            case confirmed
            case blockHeight = "block_height"
            case blockHash = "block_hash"
            case blockTime = "block_time"
        }
    }
}
