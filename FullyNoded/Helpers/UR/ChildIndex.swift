//
//  ChildIndex.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

struct ChildIndex: ExpressibleByIntegerLiteral {
    let value: UInt32
    init(_ value: UInt32) throws {
        guard(value & 0x80000000 == 0) else {
            throw GeneralError("Invalid child index.")
        }
        self.value = value
    }
    
    init(integerLiteral: UInt32) {
        try! self.init(integerLiteral)
    }
    
    static func ==(lhs: ChildIndex, rhs: ChildIndex) -> Bool {
        return lhs.value == rhs.value
    }
    
    static func <(lhs: ChildIndex, rhs: ChildIndex) -> Bool {
        return lhs.value < rhs.value
    }
    
    var cbor: CBOR {
        CBOR.unsigned(UInt64(value))
    }
    
    init?(cbor: CBOR) throws {
        guard case let CBOR.unsigned(value) = cbor else {
            return nil
        }
        guard value < 0x80000000 else {
            throw GeneralError("Invalid child index.")
        }
        try self.init(UInt32(value))
    }
}

extension ChildIndex: CustomStringConvertible {
    var description: String {
        String(value)
    }
}
