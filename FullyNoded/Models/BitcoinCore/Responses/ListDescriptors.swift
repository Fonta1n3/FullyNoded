//
//  ListDescriptors.swift
//  FullyNoded
//
//  Created by Peter Denton on 12/7/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

struct ListDescriptorsResponse: Codable {
    let walletName: String
    let descriptors: [DescriptorItem]
    
    enum CodingKeys: String, CodingKey {
        case walletName = "wallet_name"
        case descriptors
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // An empty name never matches a real wallet, so callers that check it stay safe.
        walletName = c.lenientString(.walletName) ?? ""
        descriptors = (try? c.decode(LossyArray<DescriptorItem>.self, forKey: .descriptors))?.elements ?? []
    }
}

struct DescriptorItem: Codable {
    let desc: String
    let timestamp: Int?                // Can be null or missing in some cases
    let active: Bool
    let internal_: Bool?                // Optional: only for active descriptors
    let range: [Int]?                  // Optional: only for ranged descriptors (two ints)
    let next: Int?                     // Optional: kept for compatibility
    let nextIndex: Int?                // Optional: the actual next index
    let label: String?
    
    enum CodingKeys: String, CodingKey {
        case desc, timestamp, active, range, next, label
        case nextIndex = "next_index"
        case internal_ = "internal"
    }
    
    /// Only the descriptor itself is required.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let desc = c.lenientString(.desc), !desc.isEmpty else {
            throw DecodingError.keyNotFound(CodingKeys.desc, .init(codingPath: c.codingPath, debugDescription: "Descriptor entry has no desc."))
        }
        self.desc = desc
        timestamp = c.lenientInt(.timestamp)
        active = c.lenientBool(.active) ?? false
        internal_ = c.lenientBool(.internal_)
        range = (try? c.decodeIfPresent([Int].self, forKey: .range)) ?? nil
        next = c.lenientInt(.next)
        nextIndex = c.lenientInt(.nextIndex)
        label = c.lenientString(.label)
    }
}
