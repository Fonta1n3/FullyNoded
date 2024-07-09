//
//  DerivationPath.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/16/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import URKit

struct DerivationPath: ExpressibleByArrayLiteral {    
    var steps: [DerivationStep]
    var sourceFingerprint: UInt32?
    var depth: UInt8?
    
    var effectiveDepth: UInt8 {
        depth ?? UInt8(steps.count)
    }
    
    init(steps: [DerivationStep], sourceFingerprint: UInt32? = nil, depth: UInt8? = nil) {
        if let sourceFingerprint = sourceFingerprint {
            assert(sourceFingerprint != 0)
        }
        self.steps = steps
        self.sourceFingerprint = sourceFingerprint
        self.depth = depth
    }
    
    // Denotes just the fingerprint of a master key.
    init(sourceFingerprint: UInt32) {
        self.init(steps: [], sourceFingerprint: sourceFingerprint)
    }
    
    init(arrayLiteral elements: DerivationStep...) {
        self.init(steps: elements)
    }
    
    var cbor: CBOR {
        var a: Map = [
            CBOR.unsigned(1): CBOR.array(steps.flatMap { $0.array })//.init(key: 1, value: CBOR.array(steps.flatMap { $0.array } ))
            
        ]
        
        if let sourceFingerprint = sourceFingerprint {
            //a.append(.init(key: 2, value: CBOR.unsignedInt(UInt64(sourceFingerprint))))
            a.insert(CBOR.unsigned(2), CBOR.unsigned(UInt64(sourceFingerprint)))
        }
        
        if let depth = depth {
            //a.append(.init(key: 3, value: CBOR.unsignedInt(UInt64(depth))))
            a.insert(CBOR.unsigned(3), CBOR.unsigned(UInt64(depth)))
        }
        
        return CBOR.map(a)
    }
    
    var taggedCBOR: CBOR {
        CBOR.tagged(.derivationPath, cbor)
    }
    
    init(cbor: CBOR) throws {
        guard case let CBOR.map(pairs) = cbor
        else {
            print("DerivationPath doesn't contain a map.")
            throw GeneralError("DerivationPath doesn't contain a map.")
        }
        
        guard
            case let CBOR.array(componentsItem) = pairs[1] ?? CBOR.null,
            componentsItem.count.isMultiple(of: 2)
        else {
            print("Invalid DerivationPath components.")
            throw GeneralError("Invalid DerivationPath components.")
        }
        
        let steps: [DerivationStep] = try stride(from: 0, to: componentsItem.count, by: 2).map { i in
            let childIndexSpec = try ChildIndexSpec.decode(cbor: componentsItem[i])
            guard let isHardened = try? BooleanLiteralType(cbor: componentsItem[i + 1]) else {
                print("Invalid path component.")
                throw GeneralError("Invalid path component.")
            }
            return DerivationStep(childIndexSpec, isHardened: isHardened)
//            guard case let CBOR.booleanLiteral(isHardened) = componentsItem[i + 1] else {
//                print("Invalid path component.")
//                throw GeneralError("Invalid path component.")
//            }
//            return DerivationStep(childIndexSpec, isHardened: isHardened)
        }
        
        let sourceFingerprint: UInt32?
        
        if let sourceFingerprintItem = pairs.get(2) {
            if case let CBOR.unsigned(sourceFingerprintValue) = sourceFingerprintItem, sourceFingerprintValue != 0, sourceFingerprintValue <= UInt32.max {
                sourceFingerprint = UInt32(sourceFingerprintValue)
            } else {
                sourceFingerprint = nil
            }
            
        } else {
            sourceFingerprint = nil
        }
        
        let depth: UInt8?
        
        if let depthItem = pairs.get(3) {
            guard
                case let CBOR.unsigned(depthValue) = depthItem,
                depthValue <= UInt8.max
            else {
                print("Invalid depth.")
                throw GeneralError("Invalid depth.")
            }
            depth = UInt8(depthValue)
        } else {
            depth = nil
        }
        
        self.init(steps: steps, sourceFingerprint: sourceFingerprint, depth: depth)
    }
    
    init(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(.derivationPath, cbor) = taggedCBOR else {
            print("DerivationPath tag (304) not found.")
            throw GeneralError("DerivationPath tag (304) not found.")
        }
        try self.init(cbor: cbor)
    }
}

extension DerivationPath: CustomStringConvertible {
    var description: String {
        var result: [String] = []
        
        if let sourceFingerprint = sourceFingerprint {
            result.append(sourceFingerprint.bigEndianData.hex)
        }
        result.append(contentsOf: steps.map({ $0.description }))
        
        return result.joined(separator: "/")
    }
}
