//
//  PeerInfo.swift
//  BitSense
//
//  Created by Peter on 27/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation

// MARK: - Simple GetPeerInfoResponse (for bitcoin-cli NSArray)
struct GetPeerInfoResponse {
    let peers: [PeerInfo]
    let rawData: [[String: Any]]
    
    var incomingCount: Int { peers.filter { $0.inbound }.count }
    var outgoingCount: Int { peers.filter { !$0.inbound }.count }
    
    init(from nsArray: NSArray) throws {
        guard let items = nsArray as? [Any] else {
            throw NSError(domain: "GetPeerInfo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Expected a list of peers."])
        }
        
        self.rawData = items.compactMap { $0 as? [String: Any] }
        self.peers = RPCValue.decodeEach(PeerInfo.self, from: items, context: "getpeerinfo")
    }
}

struct PeerInfo: Codable {
    let addr: String
    let version: Int
    let subver: String
    let inbound: Bool
    let connectionType: String
    let network: String
    
    enum CodingKeys: String, CodingKey {
        case addr
        case version, subver, inbound
        case connectionType = "connection_type"
        case network
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        addr = c.lenientString(.addr) ?? "unknown"
        version = c.lenientInt(.version) ?? 0
        subver = c.lenientString(.subver) ?? ""
        inbound = c.lenientBool(.inbound) ?? false
        connectionType = c.lenientString(.connectionType) ?? "unknown"
        network = c.lenientString(.network) ?? "unknown"
    }
}
