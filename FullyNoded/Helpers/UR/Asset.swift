//
//  Asset.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/22/21.
//

import SwiftUI

enum Asset: UInt32, Identifiable, CaseIterable {
    // Values from [SLIP44] with high bit turned off
    case btc = 0
    
    var cbor: CBOR {
        CBOR.unsigned(UInt64(rawValue))
    }
    
    init(cbor: CBOR) throws {
        guard
            case let CBOR.unsigned(r) = cbor,
            let a = Asset(rawValue: UInt32(r)) else {
            throw GeneralError("Invalid Asset.")
        }
        self = a
    }

    var id: String {
        "asset-\(description)"
    }

    var name: String {
        switch self {
        case .btc:
            return "Bitcoin"
        }
    }
}

extension Asset: CustomStringConvertible {
    var description: String {
        switch self {
        case .btc:
            return "btc"
        }
    }
}
