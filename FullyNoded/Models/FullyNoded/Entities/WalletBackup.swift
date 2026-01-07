//
//  WalletBackup.swift
//  FullyNoded
//
//  Created by Peter Denton on 1/6/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import Foundation

// MARK: - RangeValue

enum RangeValue: Codable {
    case single(Int)
    case range(start: Int, end: Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            self = .single(int)
        } else if let array = try? container.decode([Int].self) {
            guard array.count == 2 else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Range must be single Int or [Int, Int]")
            }
            self = .range(start: array[0], end: array[1])
        } else {
            throw DecodingError.typeMismatch(RangeValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected Int or [Int, Int]"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let value):
            try container.encode(value)
        case .range(let start, let end):
            try container.encode([start, end])
        }
    }
}

// MARK: - Timestamp

enum Timestamp: Codable {
    case now
    case time(Int)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self), str.lowercased() == "now" {
            self = .now
        } else if let int = try? container.decode(Int.self) {
            self = .time(int)
        } else {
            throw DecodingError.typeMismatch(Timestamp.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected 'now' or Int"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .now:
            try container.encode("now")
        case .time(let value):
            try container.encode(value)
        }
    }
}

// MARK: - BackupItem

struct BackupItem: Codable {
    let desc: String
    var active: Bool
    var range: RangeValue?
    var nextIndex: Int?
    let timestamp: Timestamp?
    var `internal`: Bool?
    var label: String
    
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
         range: RangeValue?,
         nextIndex: Int,
         timestamp: Timestamp?,
         internal: Bool?,
         label: String = "") {
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
