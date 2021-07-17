//
//  CBORExtensions.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

extension CBOR.Tag {
    static let seed = CBOR.Tag(rawValue: 300)
    static let hdKey = CBOR.Tag(rawValue: 303)
    static let derivationPath = CBOR.Tag(rawValue: 304)
    static let useInfo = CBOR.Tag(rawValue: 305)
    static let sskrShare = CBOR.Tag(rawValue: 309)
    static let transactionRequest = CBOR.Tag(rawValue: 312)
    static let transactionResponse = CBOR.Tag(rawValue: 313)
    
    static let seedRequestBody = CBOR.Tag(rawValue: 500)
    static let keyRequestBody = CBOR.Tag(rawValue: 501)
    static let psbtSignatureRequestBody = CBOR.Tag(rawValue: 502)
}
