//
//  CBORExtensions.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

extension Tag {
    static let seed = Tag(300)
    static let hdKey = Tag(303)
    static let derivationPath = Tag(304)
    static let useInfo = Tag(305)
    static let sskrShare = Tag(309)
    static let transactionRequest = Tag(312)
    static let transactionResponse = Tag(313)
    static let seedRequestBody = Tag(500)
    static let keyRequestBody = Tag(501)
    static let psbtSignatureRequestBody = Tag(502)
}
