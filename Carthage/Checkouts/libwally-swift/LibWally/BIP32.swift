//
//  BIP32.swift
//  BIP32 
//
//  Created by Sjors on 29/05/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import CLibWally

public enum Network : Equatable {
    case mainnet
    case testnet
}

public enum BIP32Error: Error {
    case invalidIndex
    case hardenedDerivationWithoutPrivateKey
    case incompatibleNetwork
    case invalidDepth
}

public enum BIP32Derivation : Equatable {
    // max 2^^31 - 1: enforced by the BIP32Path initializer
    case normal(UInt32)
    case hardened(UInt32)
    
    public var isHardened: Bool {
        switch self {
            case .normal(_):
                return false
            case .hardened(_):
                return true
        }
    }
}

public struct BIP32Path : LosslessStringConvertible, Equatable {
    public let components: [BIP32Derivation]
    let rawPath: [UInt32]
    let relative: Bool
    
    public init(_ rawPath: [UInt32], relative: Bool) throws {
        var components: [BIP32Derivation] = []
        for index in rawPath {
            if (index < BIP32_INITIAL_HARDENED_CHILD ) {
                components.append(BIP32Derivation.normal(index))
            } else {
                components.append(BIP32Derivation.hardened(index - BIP32_INITIAL_HARDENED_CHILD))
            }
        }
        try self.init(components, relative:relative)
    }
    
    public init(_ components: [BIP32Derivation], relative: Bool) throws {
        var rawPath: [UInt32] = []
        self.relative = relative

        for component in components {
            switch component {
            case .normal(let index):
                if index >= BIP32_INITIAL_HARDENED_CHILD {
                    throw BIP32Error.invalidIndex
                }
                rawPath.append(index)
            case .hardened(let index):
                if index >= BIP32_INITIAL_HARDENED_CHILD {
                    throw BIP32Error.invalidIndex
                }
                rawPath.append(BIP32_INITIAL_HARDENED_CHILD + index)
            }
        }
        self.components = components
        self.rawPath = rawPath
    }
    
    public init(_ component: BIP32Derivation, relative: Bool = true) throws {
        try self.init([component], relative: relative)
    }
    
    public init(_ index: Int, relative: Bool = true) throws {
        try self.init([.normal(UInt32(index))], relative: relative)
    }
    
    // LosslessStringConvertible does not permit this initializer to throw
    public init?(_ description: String) {
        guard description.count > 0 else {
            return nil
        }
        let relative = description.prefix(2) != "m/"
        var tmpComponents: [BIP32Derivation] = []

        for component in description.split(separator: "/") {
            if component == "m" { continue }
            let index: UInt32? = UInt32(component)
            if let i = index {
                tmpComponents.append(.normal(i))
            } else if component.suffix(1) == "h" || component.suffix(1) == "'" {
                let indexHardened: UInt32? = UInt32(component.dropLast(1))
                if let i = indexHardened {
                    tmpComponents.append(.hardened(i))
                } else {
                    return nil
                }
            } else {
                return nil
            }
        }
        
        guard tmpComponents.count > 0 else {
            return nil
        }
        do {
            try self.init(tmpComponents, relative: relative)
        } catch {
            return nil
        }
    }
    
    public var description: String {
        var pathString = self.relative ? "" : "m/"
        for (index, item) in components.enumerated() {
            switch item {
            case .normal(let index):
                pathString += String(index)
            case .hardened(let index):
                pathString += String(index) + "h"
            }
            if index < components.endIndex - 1 {
                pathString += "/"
            }
        }
        return pathString
    }
    
    public func chop(_ depth: Int) throws -> BIP32Path {
        if depth > components.count {
            throw BIP32Error.invalidDepth
        }
        var newComponents = self.components
        newComponents.removeFirst(Int(depth))
        return try BIP32Path(newComponents, relative: true)
    }
    
}

public struct HDKey {
    var wally_ext_key: ext_key
    var masterKeyFingerprint: Data? // TODO: https://github.com/ElementsProject/libwally-core/issues/164
    
    init(_ key: ext_key, masterKeyFingerprint: Data? = nil) {
        self.wally_ext_key = key
        self.masterKeyFingerprint = masterKeyFingerprint
    }

    public init?(_ description: String, masterKeyFingerprint: Data? = nil) {
        var output: UnsafeMutablePointer<ext_key>?
        defer {
            if let wally_ext_key = output {
                wally_ext_key.deallocate()
            }
        }
        let result = bip32_key_from_base58_alloc(description, &output)
        if (result == WALLY_OK) {
            precondition(output != nil)
            self.init(output!.pointee, masterKeyFingerprint: masterKeyFingerprint)
        } else {
            return nil
        }
        if self.wally_ext_key.depth == 0 {
            if self.masterKeyFingerprint == nil {
                self.masterKeyFingerprint = self.fingerprint
            } else {
                guard self.masterKeyFingerprint == self.fingerprint else {
                    return nil
                }
            }
        }

    }

    public init?(_ seed: BIP39Seed, _ network: Network = .mainnet) {
        var bytes_in = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BIP39_SEED_LEN_512))
        var output: UnsafeMutablePointer<ext_key>?
        defer {
            bytes_in.deallocate()
            if let wally_ext_key = output {
                wally_ext_key.deallocate()
            }
        }
        seed.data.copyBytes(to: bytes_in, count: Int(BIP39_SEED_LEN_512))
        var flags: UInt32 = 0
        switch network {
        case .mainnet:
            flags = UInt32(BIP32_VER_MAIN_PRIVATE)
        case .testnet:
            flags = UInt32(BIP32_VER_TEST_PRIVATE)
        }
        let result = bip32_key_from_seed_alloc(bytes_in, Int(BIP32_ENTROPY_LEN_512), flags, 0, &output)
        if (result == WALLY_OK) {
            precondition(output != nil)
            self.init(output!.pointee)
        } else {
            // From libwally-core docs:
            // The entropy passed in may produce an invalid key. If this happens, WALLY_ERROR will be returned
            // and the caller should retry with new entropy.
            return nil
        }
        self.masterKeyFingerprint = self.fingerprint
    }
    
    public var network: Network {
        switch self.wally_ext_key.version {
        case UInt32(BIP32_VER_MAIN_PRIVATE), UInt32(BIP32_VER_MAIN_PUBLIC):
            return .mainnet
        case UInt32(BIP32_VER_TEST_PRIVATE), UInt32(BIP32_VER_TEST_PUBLIC):
            return .testnet
        default:
            precondition(false)
            return .mainnet
        }
    }
    
    public var description: String {
        return isNeutered ? xpub : xpriv!
    }
    
    public var isNeutered: Bool {
        return self.wally_ext_key.version == BIP32_VER_MAIN_PUBLIC || self.wally_ext_key.version == BIP32_VER_TEST_PUBLIC
    }
    
    public var xpub: String {
        var hdkey = UnsafeMutablePointer<ext_key>.allocate(capacity: 1)
        var output: UnsafeMutablePointer<Int8>?
        defer {
            hdkey.deallocate()
            wally_free_string(output)
        }
        hdkey.initialize(to: self.wally_ext_key)
        
        precondition(bip32_key_to_base58(hdkey, UInt32(BIP32_FLAG_KEY_PUBLIC), &output) == WALLY_OK)
        precondition(output != nil)
        return String(cString: output!)
    }
    
    public var pubKey: PubKey {
        var tmp = self.wally_ext_key.pub_key
        let pub_key = [UInt8](UnsafeBufferPointer(start: &tmp.0, count: Int(EC_PUBLIC_KEY_LEN)))
        return PubKey(Data(pub_key), self.network, compressed: true)!
    }
    
    public var privKey: Key? {
        if self.isNeutered {
           return nil
        }
        var tmp = self.wally_ext_key.priv_key
        // skip prefix byte 0
        let priv_key = [UInt8](UnsafeBufferPointer(start: &tmp.1, count: Int(EC_PRIVATE_KEY_LEN)))
        return Key(Data(priv_key), self.network, compressed: true)
    }
    
    public var xpriv: String? {
        if self.isNeutered {
            return nil
        }
        var hdkey = UnsafeMutablePointer<ext_key>.allocate(capacity: 1)
        var output: UnsafeMutablePointer<Int8>?
        defer {
            hdkey.deallocate()
            wally_free_string(output)
        }
        hdkey.initialize(to: self.wally_ext_key)
        
        precondition(bip32_key_to_base58(hdkey, UInt32(BIP32_FLAG_KEY_PRIVATE), &output) == WALLY_OK)
        precondition(output != nil)
        return String(cString: output!)
    }
    
    public var fingerprint: Data {
        var hdkey = UnsafeMutablePointer<ext_key>.allocate(capacity: 1)
        var output: UnsafeMutablePointer<Int8>?
        defer {
            hdkey.deallocate()
        }
        hdkey.initialize(to: self.wally_ext_key)
        
        var fingerprint_bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(FINGERPRINT_LEN))
        defer {
            fingerprint_bytes.deallocate()
        }
        
        precondition(bip32_key_get_fingerprint(hdkey, fingerprint_bytes, Int(FINGERPRINT_LEN)) == WALLY_OK)
        return Data(bytes: fingerprint_bytes, count: Int(FINGERPRINT_LEN))
    }
    
    public func derive (_ path: BIP32Path) throws -> HDKey {
        let depth = self.wally_ext_key.depth
        var tmpPath = path
        if (!path.relative) {
            tmpPath = try path.chop(Int(depth))
        }

        if self.isNeutered && tmpPath.components.first(where: { $0.isHardened }) != nil {
            throw BIP32Error.hardenedDerivationWithoutPrivateKey
        }
        
        var hdkey = UnsafeMutablePointer<ext_key>.allocate(capacity: 1)
        hdkey.initialize(to: self.wally_ext_key)
        
        var output: UnsafeMutablePointer<ext_key>?
        defer {
            hdkey.deallocate()
            if let wally_ext_key = output {
                wally_ext_key.deallocate()
            }
        }
        
        precondition(bip32_key_from_parent_path_alloc(hdkey, tmpPath.rawPath, tmpPath.rawPath.count, UInt32(self.isNeutered ? BIP32_FLAG_KEY_PUBLIC : BIP32_FLAG_KEY_PRIVATE), &output) == WALLY_OK)
        precondition(output != nil)
        return HDKey(output!.pointee, masterKeyFingerprint: self.masterKeyFingerprint)
    }
}
