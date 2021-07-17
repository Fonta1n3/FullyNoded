//
//  IntUtils.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

extension UInt32 {
    init(fromBigEndian data: Data) {
        assert(data.count == 4)
        self = withUnsafeBytes(of: data) {
            $0.bindMemory(to: UInt32.self).baseAddress!.pointee.bigEndian
        }
    }
    
    var bigEndianData: Data {
        withUnsafeByteBuffer(of: self.bigEndian) { Data($0) }
    }
}
