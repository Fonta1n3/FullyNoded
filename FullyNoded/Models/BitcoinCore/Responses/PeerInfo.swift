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

/// One `getpeerinfo` entry. Core adds and drops fields between releases, so everything but the
/// basics is optional and screens only show what's there.
struct PeerInfo: Codable {
    let id: Int?
    let addr: String
    let addrBind: String?
    let addrLocal: String?
    let version: Int
    let subver: String
    let inbound: Bool
    let connectionType: String
    let network: String
    let transport: String?
    let services: [String]
    let permissions: [String]
    let relaysTransactions: Bool?
    let relaysAddresses: Bool?
    let highBandwidthTo: Bool?
    let highBandwidthFrom: Bool?
    /// Unix times; 0 means never.
    let connectedAt: Int?
    let lastSend: Int?
    let lastReceive: Int?
    let lastBlock: Int?
    let lastTransaction: Int?
    let bytesSent: Int?
    let bytesReceived: Int?
    /// Seconds.
    let ping: Double?
    let minPing: Double?
    let pingWait: Double?
    let startingHeight: Int?
    let syncedHeaders: Int?
    let syncedBlocks: Int?
    /// BTC/kvB.
    let minFeeFilter: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, addr
        case addrBind = "addrbind"
        case addrLocal = "addrlocal"
        case version, subver, inbound
        case connectionType = "connection_type"
        case network
        case transport = "transport_protocol_type"
        case services = "servicesnames"
        case permissions
        case relaysTransactions = "relaytxes"
        case relaysAddresses = "addr_relay_enabled"
        case highBandwidthTo = "bip152_hb_to"
        case highBandwidthFrom = "bip152_hb_from"
        case connectedAt = "conntime"
        case lastSend = "lastsend"
        case lastReceive = "lastrecv"
        case lastBlock = "last_block"
        case lastTransaction = "last_transaction"
        case bytesSent = "bytessent"
        case bytesReceived = "bytesrecv"
        case ping = "pingtime"
        case minPing = "minping"
        case pingWait = "pingwait"
        case startingHeight = "startingheight"
        case syncedHeaders = "synced_headers"
        case syncedBlocks = "synced_blocks"
        case minFeeFilter = "minfeefilter"
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientInt(.id)
        addr = c.lenientString(.addr) ?? "unknown"
        addrBind = c.lenientString(.addrBind)
        addrLocal = c.lenientString(.addrLocal)
        version = c.lenientInt(.version) ?? 0
        subver = c.lenientString(.subver) ?? ""
        inbound = c.lenientBool(.inbound) ?? false
        connectionType = c.lenientString(.connectionType) ?? "unknown"
        network = c.lenientString(.network) ?? "unknown"
        transport = c.lenientString(.transport)
        services = (try? c.decodeIfPresent([String].self, forKey: .services)) ?? []
        permissions = (try? c.decodeIfPresent([String].self, forKey: .permissions)) ?? []
        relaysTransactions = c.lenientBool(.relaysTransactions)
        relaysAddresses = c.lenientBool(.relaysAddresses)
        highBandwidthTo = c.lenientBool(.highBandwidthTo)
        highBandwidthFrom = c.lenientBool(.highBandwidthFrom)
        connectedAt = c.lenientInt(.connectedAt)
        lastSend = c.lenientInt(.lastSend)
        lastReceive = c.lenientInt(.lastReceive)
        lastBlock = c.lenientInt(.lastBlock)
        lastTransaction = c.lenientInt(.lastTransaction)
        bytesSent = c.lenientInt(.bytesSent)
        bytesReceived = c.lenientInt(.bytesReceived)
        ping = c.lenientDouble(.ping)
        minPing = c.lenientDouble(.minPing)
        pingWait = c.lenientDouble(.pingWait)
        startingHeight = c.lenientInt(.startingHeight)
        syncedHeaders = c.lenientInt(.syncedHeaders)
        syncedBlocks = c.lenientInt(.syncedBlocks)
        minFeeFilter = c.lenientDouble(.minFeeFilter)
    }
    
    /// "1.2.3.4:8333", "[2001:db8::1]:8333" or "abc.onion:8333" without the port, as setban wants it.
    static func host(of addr: String) -> String {
        if addr.hasPrefix("["), let end = addr.firstIndex(of: "]") {
            return String(addr[addr.index(after: addr.startIndex)..<end])
        }
        // More than one colon is a bare IPv6 address, which has no port.
        let parts = addr.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count == 2 ? String(parts[0]) : addr
    }
    
    /// A peer that comes in through a local proxy (inbound Tor shows as 127.0.0.1): banning its
    /// address would ban every peer using that proxy.
    var isLocalAddress: Bool {
        let host = Self.host(of: addr)
        return host.hasPrefix("127.") || host == "::1" || host == "localhost"
    }
    
    /// "Satoshi:32.1.0" from "/Satoshi:32.1.0/".
    var clientName: String {
        let name = subver.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return name.isEmpty ? "Unknown client" : name
    }
    
    var networkName: String {
        switch network {
        case "ipv4": return "IPv4"
        case "ipv6": return "IPv6"
        case "onion": return "Tor"
        case "i2p": return "I2P"
        case "cjdns": return "CJDNS"
        case "not_publicly_routable": return "Local"
        default: return network
        }
    }
    
    var connectionName: String {
        switch connectionType {
        case "outbound-full-relay": return "Full relay"
        case "block-relay-only": return "Block relay"
        case "manual": return "Manual"
        case "addr-fetch": return "Address fetch"
        case "feeler": return "Feeler"
        case "inbound": return "Inbound"
        default: return connectionType
        }
    }
    
    var transportName: String? {
        switch transport {
        case "v2": return "Encrypted (BIP324)"
        case "v1": return "Not encrypted (v1)"
        case "detecting": return "Detecting"
        default: return transport
        }
    }
}
