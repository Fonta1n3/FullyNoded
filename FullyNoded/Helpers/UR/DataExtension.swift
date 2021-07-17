//
//  DataExtension.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

extension Data {
    
    init<A>(of a: A) {
        let d = Swift.withUnsafeBytes(of: a) {
            Data($0)
        }
        self = d
    }
    
    func store<A>(into a: inout A) {
        precondition(MemoryLayout<A>.size >= count)
        withUnsafeMutablePointer(to: &a) {
            $0.withMemoryRebound(to: UInt8.self, capacity: count) {
                self.copyBytes(to: $0, count: count)
            }
        }
    }
    
    @inlinable func withUnsafeByteBuffer<ResultType>(_ body: (UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
        try withUnsafeBytes { rawBuf in
            try body(rawBuf.bindMemory(to: UInt8.self))
        }
    }
    
    var hex: String {
        self.reduce("", { $0 + String(format: "%02x", $1) })
    }
    
    var isAllZero: Bool {
        return allSatisfy { $0 == 0 }
    }
}

@inlinable func withUnsafeByteBuffer<T, ResultType>(of value: T, _ body: (UnsafeBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
    try withUnsafeBytes(of: value) { rawBuf in
        try body(rawBuf.bindMemory(to: UInt8.self))
    }
}

@inlinable func withUnsafeMutableByteBuffer<T, ResultType>(of value: inout T, _ body: (UnsafeMutableBufferPointer<UInt8>) throws -> ResultType) rethrows -> ResultType {
    try withUnsafeMutableBytes(of: &value) { rawBuf in
        try body(rawBuf.bindMemory(to: UInt8.self))
    }
}
