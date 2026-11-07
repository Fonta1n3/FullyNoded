//
//  NodeStruct.swift
//  BitSense
//
//  Created by Peter on 18/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

public struct NodeStruct: CustomStringConvertible {
    
    
    let id:UUID?
    let label:String
    let isActive:Bool
    let onionAddress:Data?
    let rpcpassword:Data?
    let rpcuser:Data?
    let cert:Data?
    /// Nostr Connect pairing link (encrypted). Set for nodes reached through Fully Noded Server's
    /// nostr relay instead of RPC over Tor / HTTP.
    let nostrConnect:Data?
    
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as? UUID
        label = dictionary["label"] as? String ?? ""
        isActive = dictionary["isActive"] as? Bool ?? false
        onionAddress = dictionary["onionAddress"] as? Data
        rpcpassword = dictionary["rpcpassword"] as? Data
        rpcuser = dictionary["rpcuser"] as? Data
        cert = dictionary["cert"] as? Data
        nostrConnect = dictionary["nostrConnect"] as? Data
    }

    var isNostrConnect: Bool {
        nostrConnect != nil
    }

    /// The decrypted Nostr Connect pairing, nil for Tor / HTTP nodes.
    var nostrConnectURI: NostrConnectURI? {
        guard let nostrConnect,
              let link = Crypto.decrypt(nostrConnect)?.utf8String else { return nil }
        return NostrConnectURI(link)
    }

    public var description: String {
        return "A struct for node credentials saved fully encrypted in Core Data."
    }
    
}

