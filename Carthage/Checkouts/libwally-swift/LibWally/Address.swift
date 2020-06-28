//
//  Address.swift
//  Address 
//
//  Created by Sjors on 14/06/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md

import Foundation
import CLibWally

public enum AddressType {
    case payToPubKeyHash // P2PKH (legacy)
    case payToScriptHashPayToWitnessPubKeyHash // P2SH-P2WPKH (wrapped SegWit)
    case payToWitnessPubKeyHash // P2WPKH (native SegWit)
}

public protocol AddressProtocol : LosslessStringConvertible {
    var scriptPubKey: ScriptPubKey { get }
}

public struct Address : AddressProtocol {
    public var network: Network
    public var scriptPubKey: ScriptPubKey
    var address: String
    
    public init?(_ description: String) {
        self.address = description

        // base58 and bech32 use more bytes in string form, so description.count should be safe:
        var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: description.count)
        var written = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            bytes_out.deallocate()
            written.deallocate()
        }
        
        // Try if this is a bech32 Bitcoin mainnet address:
        var family: String = "bc"
        var result = wally_addr_segwit_to_bytes(description, family, 0, bytes_out, description.count, written)
        self.network = .mainnet

        if (result != WALLY_OK) {
            // Try if this is a bech32 Bitcoin testnet address:
            family = "tb"
            result = wally_addr_segwit_to_bytes(description, family, 0, bytes_out, description.count, written)
            self.network = .testnet
        }
        
        if (result != WALLY_OK) {
            // Try if this is a base58 addresses (P2PKH or P2SH)
            result = wally_address_to_scriptpubkey(description, UInt32(WALLY_NETWORK_BITCOIN_MAINNET), bytes_out, description.count, written)
            self.network = .mainnet
        }
        
        if (result != WALLY_OK) {
            // Try if this is a testnet base58 addresses (P2PKH or P2SH)
            result = wally_address_to_scriptpubkey(description, UInt32(WALLY_NETWORK_BITCOIN_TESTNET), bytes_out, description.count, written)
            self.network = .testnet
        }
        
        if (result != WALLY_OK) {
            return nil
        }
        
        self.scriptPubKey = ScriptPubKey(Data(bytes: bytes_out, count: written.pointee))
    }
    
    init(_ hdKey: HDKey, _ type: AddressType) {
        let wally_type: Int32 = {
            switch type {
            case .payToPubKeyHash:
                return WALLY_ADDRESS_TYPE_P2PKH
            case .payToScriptHashPayToWitnessPubKeyHash:
                return WALLY_ADDRESS_TYPE_P2SH_P2WPKH
            case .payToWitnessPubKeyHash:
                return WALLY_ADDRESS_TYPE_P2WPKH
            }
        }()
        
        var key = UnsafeMutablePointer<ext_key>.allocate(capacity: 1)
        key.initialize(to: hdKey.wally_ext_key)
        var output: UnsafeMutablePointer<Int8>?
        defer {
            key.deallocate()
            wally_free_string(output)
        }
        
        if (wally_type == WALLY_ADDRESS_TYPE_P2PKH || wally_type == WALLY_ADDRESS_TYPE_P2SH_P2WPKH) {
            var version: UInt32
            switch hdKey.network {
            case .mainnet:
                version = wally_type == WALLY_ADDRESS_TYPE_P2PKH ? 0x00 : 0x05
            case .testnet:
                version = wally_type == WALLY_ADDRESS_TYPE_P2PKH ? 0x6F : 0xC4
            }
            precondition(wally_bip32_key_to_address(key, UInt32(wally_type), version, &output) == WALLY_OK)
            precondition(output != nil)
        } else {
            precondition(wally_type == WALLY_ADDRESS_TYPE_P2WPKH)
            var family: String
            switch hdKey.network {
            case .mainnet:
                family = "bc"
            case .testnet:
                family = "tb"
            }
            precondition(wally_bip32_key_to_addr_segwit(key, family, 0, &output) == WALLY_OK)
            precondition(output != nil)
        }
        
        let address = String(cString: output!)
        
        // TODO: get scriptPubKey directly from libwally (requires a new function) instead parsing the string
        self.init(address)! // libwally generated this string, so it's safe to force unwrap
    }
    
    public init?(_ scriptPubKey: ScriptPubKey, _ network: Network) {
        self.network = network
        self.scriptPubKey = scriptPubKey
        switch self.scriptPubKey.type {
        case .payToPubKeyHash, .payToScriptHash:
            let bytes_len = self.scriptPubKey.bytes.count
            var bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes_len)
            var output: UnsafeMutablePointer<Int8>?
            defer {
                wally_free_string(output)
            }
            self.scriptPubKey.bytes.copyBytes(to: bytes, count: bytes_len)
            precondition(wally_scriptpubkey_to_address(bytes, bytes_len, UInt32(network == .mainnet ? WALLY_NETWORK_BITCOIN_MAINNET : WALLY_NETWORK_BITCOIN_TESTNET), &output) == WALLY_OK)
            precondition(output != nil)
            self.address = String(cString: output!)
        case .payToWitnessPubKeyHash, .payToWitnessScriptHash:
            var family: String
            switch network {
            case .mainnet:
              family = "bc"
            case .testnet:
              family = "tb"
            }
            let bytes_len = self.scriptPubKey.bytes.count
            var bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes_len)
            var output: UnsafeMutablePointer<Int8>?
            defer {
                wally_free_string(output)
            }
            self.scriptPubKey.bytes.copyBytes(to: bytes, count: bytes_len)
            precondition(wally_addr_segwit_from_bytes(bytes, bytes_len, family, 0, &output) == WALLY_OK)
            precondition(output != nil)
            self.address = String(cString: output!)
        case .multiSig:
            var family: String
            switch network {
            case .mainnet:
                family = "bc"
            case .testnet:
                family = "tb"
            }
            let witness_program_len = self.scriptPubKey.witnessProgram.count
            var witness_program = UnsafeMutablePointer<UInt8>.allocate(capacity: witness_program_len)
            var output: UnsafeMutablePointer<Int8>?
            defer {
                wally_free_string(output)
            }
            self.scriptPubKey.witnessProgram.copyBytes(to: witness_program, count: witness_program_len)
            precondition(wally_addr_segwit_from_bytes(witness_program, witness_program_len, family, 0, &output) == WALLY_OK)

            if let words_c_string = output {
                self.address = String(cString: words_c_string)
            } else {
                return nil
            }
        default:
            return nil
        }
    }
    
    public var description: String {
        return address
    }

}

public struct Key {
    public let compressed: Bool
    public let data: Data
    public let network: Network
    
    static func prefix (_ network: Network) -> UInt32 {
        switch network {
         case .mainnet:
             return UInt32(WALLY_ADDRESS_VERSION_WIF_MAINNET)
         case .testnet:
             return UInt32(WALLY_ADDRESS_VERSION_WIF_TESTNET)
         }
    }
    
    public init?(_ wif: String, _ network: Network, compressed: Bool = true) {
        var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_PRIVATE_KEY_LEN))
        defer {
          bytes_out.deallocate()
        }
        // TODO: autodetect network by trying both
        // TODO: autodetect compression with wally_wif_is_uncompressed
        let flags = UInt32(compressed ? WALLY_WIF_FLAG_COMPRESSED : WALLY_WIF_FLAG_UNCOMPRESSED)
        guard wally_wif_to_bytes(wif, Key.prefix(network), flags, bytes_out, Int(EC_PRIVATE_KEY_LEN)) == WALLY_OK else {
            return nil
        }
        self.compressed = compressed
        self.data = Data(bytes: bytes_out, count: Int(EC_PRIVATE_KEY_LEN))
        self.network = network
    }
    
    public init?(_ data: Data, _ network: Network, compressed: Bool = true) {
        guard data.count == Int(EC_PRIVATE_KEY_LEN) else {
            return nil
        }
        self.data = data
        self.network = network
        self.compressed = compressed
    }
    
    public var wif: String {
        precondition(data.count == Int(EC_PRIVATE_KEY_LEN))
        var data = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_PRIVATE_KEY_LEN))
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        self.data.copyBytes(to: data, count: Int(EC_PRIVATE_KEY_LEN))
        let flags = UInt32(compressed ? WALLY_WIF_FLAG_COMPRESSED : WALLY_WIF_FLAG_UNCOMPRESSED)
        precondition(wally_wif_from_bytes(data, Int(EC_PRIVATE_KEY_LEN), Key.prefix(network), flags, &output) == WALLY_OK)
        assert(output != nil)
        return String(cString: output!)
    }
    
    public var pubKey: PubKey {
        precondition(data.count == Int(EC_PRIVATE_KEY_LEN))
        var data = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_PRIVATE_KEY_LEN))
        var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_PUBLIC_KEY_LEN))
        defer {
          bytes_out.deallocate()
        }
        self.data.copyBytes(to: data, count: Int(EC_PRIVATE_KEY_LEN))
        precondition(wally_ec_public_key_from_private_key(data, Int(EC_PRIVATE_KEY_LEN), bytes_out, Int(EC_PUBLIC_KEY_LEN)) == WALLY_OK)
        if (!compressed) {
            var bytes_out_uncompressed = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(EC_PUBLIC_KEY_UNCOMPRESSED_LEN))
            defer {
              bytes_out_uncompressed.deallocate()
            }
            precondition(wally_ec_public_key_decompress(bytes_out, Int(EC_PUBLIC_KEY_LEN), bytes_out_uncompressed, Int(EC_PUBLIC_KEY_UNCOMPRESSED_LEN)) == WALLY_OK)
            return PubKey(Data(bytes: bytes_out_uncompressed, count: Int(EC_PUBLIC_KEY_UNCOMPRESSED_LEN)), network, compressed: false)!
        } else {
            return PubKey(Data(bytes: bytes_out, count: Int(EC_PUBLIC_KEY_LEN)), network, compressed: true)!
        }
    }
}

public struct PubKey : Equatable, Hashable {
    public let compressed: Bool
    public let data: Data
    public let network: Network

    public init?(_ data: Data, _ network: Network, compressed: Bool = true) {
        guard data.count == Int(compressed ? EC_PUBLIC_KEY_LEN : EC_PUBLIC_KEY_UNCOMPRESSED_LEN) else {
            return nil
        }
        self.data = data
        self.network = network
        self.compressed = compressed
    }
}

extension HDKey {
    public func address (_ type: AddressType) -> Address {
        return Address(self, type)
    }
}
