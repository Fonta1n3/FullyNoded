//
//  DataExtension.swift
//  DataExtension
//
//  Created by Sjors on 28/05/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import CLibWally

public extension Data {

    init?(_ hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }

    init?(base58 strBase58: String) {
        var len = strBase58.count + Int(BASE58_CHECKSUM_LEN) // base58 has more characters than the number of bytes we need
        var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
        var written = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            bytes_out.deallocate()
            written.deallocate()
        }
        guard wally_base58_to_bytes(strBase58, UInt32(BASE58_FLAG_CHECKSUM), bytes_out, len, written) == WALLY_OK else {
            return nil
        }
        self = Data(bytes: bytes_out, count: written.pointee)
    }

    var hexString: String {
        return self.reduce("", { $0 + String(format: "%02x", $1) })
    }

    var base58: String {
        let bytes_len = self.count
        var bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes_len)
        self.copyBytes(to: bytes, count: Int(bytes_len))
        var output: UnsafeMutablePointer<Int8>?
        defer {
            bytes.deallocate()
            wally_free_string(output)
        }
        precondition(wally_base58_from_bytes(bytes, bytes_len, UInt32(BASE58_FLAG_CHECKSUM), &output) == WALLY_OK)
        precondition(output != nil)
        return String(cString: output!)
    }
}
