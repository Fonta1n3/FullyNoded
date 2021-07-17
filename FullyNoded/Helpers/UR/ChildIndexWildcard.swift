//
//  ChildIndexWildcard.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

struct ChildIndexWildcard {
    init() { }
    
    var cbor: CBOR {
        CBOR.array([])
    }
    
    init?(cbor: CBOR) {
        guard case let CBOR.array(array) = cbor else {
            return nil
        }
        guard array.isEmpty else {
            return nil
        }
        self.init()
    }
}

extension ChildIndexWildcard: CustomStringConvertible {
    var description: String {
        "*"
    }
}
