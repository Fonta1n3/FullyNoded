//
//  WalletBackup.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/6/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import Foundation

// MARK: - BackupItem

struct BackupItem: Codable {
    let desc: String
    var active: Bool
    var range: [Int]?
    var nextIndex: Int?
    let timestamp: Int?
    var `internal`: Bool?
    var label: String?
    
    enum CodingKeys: String, CodingKey {
        case desc
        case active
        case range
        case nextIndex = "next_index"
        case timestamp
        case `internal`
        case label
    }
    
    // Default values applied here
    init(desc: String,
         active: Bool,
         range: [Int]?,
         nextIndex: Int,
         timestamp: Int?,
         internal: Bool?,
         label: String?) {
        self.desc = desc
        self.active = active
        self.range = range
        self.nextIndex = nextIndex
        self.timestamp = timestamp
        self.`internal` = `internal`
        self.label = label
    }
}

// MARK: - WalletBackup

struct WalletBackup: Codable {
    let lastUpdate: Date
    let descriptors: [BackupItem]
    
    enum CodingKeys: String, CodingKey {
        case lastUpdate = "lastUpdate"
        case descriptors
    }
    
    // Convenience initializer – this is what fixes your error
    init(lastUpdate: Date = Date(), descriptors: [BackupItem]) {
        self.lastUpdate = lastUpdate
        self.descriptors = descriptors
    }
    
    // Custom decoding (handles lastUpdate as timestamp Double)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let timestamp = try container.decode(Double.self, forKey: .lastUpdate)
        self.lastUpdate = Date(timeIntervalSince1970: timestamp)
        self.descriptors = try container.decode([BackupItem].self, forKey: .descriptors)
    }
    
    // Custom encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(lastUpdate.timeIntervalSince1970, forKey: .lastUpdate)
        try container.encode(descriptors, forKey: .descriptors)
    }
}

// MARK: - Creating and restoring backups

extension BackupItem {
    /// From one `listdescriptors` entry. Older Core reports the next index as `next` only.
    init(listed d: DescriptorItem) {
        var range: [Int]?
        if let r = d.range, r.count == 2 || r.count == 1 { range = r }
        self.init(desc: d.desc,
                  active: d.active,
                  range: range,
                  nextIndex: d.nextIndex ?? d.next ?? 0,
                  timestamp: d.timestamp,
                  internal: d.internal_,
                  label: d.label)
    }

    /// The descriptor without its "#checksum".
    var checksumless: String { String(desc.split(separator: "#")[0]) }

    /// One `importdescriptors` request. A missing timestamp becomes 0 (scan from genesis):
    /// slow, but a recovery must never skip funds. Core rejects labels on ranged or
    /// internal descriptors, so a label is only sent for plain external ones.
    var importRequest: [String: Any] {
        var request: [String: Any] = [
            "desc": desc,
            "active": active,
            "internal": `internal` ?? false,
            "timestamp": timestamp ?? 0
        ]
        if let range = range { request["range"] = range }
        if let nextIndex = nextIndex, range != nil { request["next_index"] = nextIndex }
        if range == nil, `internal` != true, let label = label { request["label"] = label }
        return request
    }
}

extension WalletBackup {
    /// The wallet's receive / change pair: the first active external HD descriptor, and the
    /// active internal one that matches it (same descriptor on the /1/* branch). Core's
    /// default wallets have several active types (pkh, sh-wpkh, wpkh, tr); pairing keeps
    /// receive and change the same type. nil if there's no active external HD descriptor.
    func walletDescriptors() -> (receive: String, change: String)? {
        let active = descriptors.filter { $0.active && $0.range != nil }
        guard let receive = active.first(where: { $0.internal != true }) else { return nil }
        let expectedChange = receive.checksumless.replacingOccurrences(of: "/0/*", with: "/1/*")
        let change = active.first { $0.internal == true && $0.checksumless == expectedChange }
            ?? active.first { $0.internal == true }
        return (receive.desc, change?.desc ?? "")
    }

    /// Earliest descriptor timestamp (the wallet's birthday), if any were recorded.
    var birthday: Int? { descriptors.compactMap { $0.timestamp }.min() }

    /// Import requests for the descriptors the node's wallet doesn't already have.
    func missingImportRequests(existing: [String]) -> [[String: Any]] {
        let have = Set(existing.map { String($0.split(separator: "#")[0]) })
        return descriptors.filter { !have.contains($0.checksumless) }.map { $0.importRequest }
    }

    /// Hex of the JSON, the format all three exports (QR, text, file) use.
    func hexEncoded() throws -> String { try jsonData().hexString }

    /// Reads a hex backup (whitespace / newlines ignored, any case).
    static func decode(hex: String) -> WalletBackup? {
        let compact = hex.filter { !$0.isWhitespace }
        guard compact.isValidHex, let data = Data(hexString: compact.lowercased()) else { return nil }
        return try? JSONDecoder().decode(WalletBackup.self, from: data)
    }
}
