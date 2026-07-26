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
