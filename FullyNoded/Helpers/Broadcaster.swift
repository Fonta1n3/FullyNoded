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
    
    /// Through Esplora (BDK's client over Tor's HTTP tunnel, see EsploraAPI).
    func broadcastRawTransaction(rawTx: String, network: WalletLogic.BDKNetwork) async throws -> BroadcastResult {
        do {
            return .success(txid: try await EsploraAPI.broadcast(rawTx: rawTx, network: network))
        } catch {
            return .failure(errorMessage: EsploraAPI.message(error))
        }
    }
}
