//
//  shim.swift
//  BitSense
//
//  Created by Peter on 24/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

#if !compiler(>=5)
extension Data {
    func withUnsafeBytes<Result>(_ apply: (UnsafeRawBufferPointer) throws -> Result) rethrows -> Result {
        return try withUnsafeBytes {
            try apply(UnsafeRawBufferPointer(start: $0, count: count))
        }
    }
}
#endif
