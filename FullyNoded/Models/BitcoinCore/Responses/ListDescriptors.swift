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
}

// MARK: - Individual descriptor
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
}
