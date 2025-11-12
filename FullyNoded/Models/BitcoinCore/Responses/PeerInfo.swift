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
        guard let arrayOfDicts = nsArray as? [[String: Any]] else {
            throw NSError(domain: "GetPeerInfo", code: -1, userInfo: [NSLocalizedDescriptionKey: "Expected NSArray of NSDictionary"])
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: arrayOfDicts)
        self.rawData = arrayOfDicts
        self.peers = try JSONDecoder().decode([PeerInfo].self, from: jsonData)
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
}


