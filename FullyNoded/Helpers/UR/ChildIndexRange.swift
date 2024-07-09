//
//  ChildIndexRange.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

struct ChildIndexRange {
    let low: ChildIndex
    let high: ChildIndex
    init(low: ChildIndex, high: ChildIndex) throws {
        guard low < high else {
            throw GeneralError("Invalid child index range.")
        }
        self.low = low
        self.high = high
    }
    
    var cbor: CBOR {
        CBOR.array([
            CBOR.unsigned(UInt64(low.value)),
            CBOR.unsigned(UInt64(high.value))
        ])
    }
    
    init?(cbor: CBOR) throws {
        guard case let CBOR.array(array) = cbor else {
            return nil
        }
        guard array.count == 2 else {
            return nil
        }
        guard
            case let CBOR.unsigned(low) = array[0],
            case let CBOR.unsigned(high) = array[1]
        else {
            return nil
        }
        try self.init(
            low: ChildIndex(UInt32(low)),
            high: ChildIndex(UInt32(high))
        )
    }
}

extension ChildIndexRange: CustomStringConvertible {
    var description: String {
        "\(low)-\(high)"
    }
}
