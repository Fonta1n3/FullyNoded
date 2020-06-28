//
//  BIP39.swift
//  LibWally
//
//  Created by Sjors on 27/05/2019.
//  Copyright © 2019 Blockchain. Distributed under the MIT software
//  license, see the accompanying file LICENSE.md.
//

import Foundation
import CLibWally

let MAX_BYTES = 32 // Arbitrary, used only to determine array size in bip39_mnemonic_to_bytes

public var BIP39Words: [String] = {
    // Implementation based on Blockstream Green Development Kit
    var words: [String] = []
    var WL: OpaquePointer?
    precondition(bip39_get_wordlist(nil, &WL) == WALLY_OK)
    for i in 0..<BIP39_WORDLIST_LEN {
        var word: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(word)
        }
        precondition(bip39_get_word(WL, Int(i), &word) == WALLY_OK)
        words.append(String(cString: word!))
    }
    return words
}()

public struct BIP39Entropy : LosslessStringConvertible, Equatable {
    public var data: Data
    
    public init?(_ description: String) {
        if let data = Data(description) {
            self.data = data
        } else {
            return nil
        }
    }
    
    public init(_ data: Data) {
        self.data = data
    }
    
    public var description: String { return data.hexString }
}

public struct BIP39Seed : LosslessStringConvertible, Equatable {
    var data: Data
    
    public init?(_ description: String) {
        if let data = Data(description) {
            self.data = data
        } else {
            return nil
        }
    }
    
    init(_ data: Data) {
        self.data = data
    }
    
    public var description: String { return data.hexString }
}

public struct BIP39Mnemonic : LosslessStringConvertible, Equatable {
    public let words: [String]
    public var description: String { return words.joined(separator: " ") }

    public init?(_ words: [String]) {
        if (!BIP39Mnemonic.isValid(words)) { return nil }
        self.words = words
    }
    
    public init?(_ words: String) {
        self.init(words.components(separatedBy: " "))
    }
    
    public init?(_ entropy: BIP39Entropy) {
        precondition(entropy.data.count <= MAX_BYTES)
        var bytes = UnsafeMutablePointer<UInt8>.allocate(capacity: MAX_BYTES)
        let bytes_len = entropy.data.count
        
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        entropy.data.copyBytes(to: bytes, count: entropy.data.count)

        precondition(bip39_mnemonic_from_bytes(nil, bytes, bytes_len, &output) == WALLY_OK)
        
        if let words_c_string = output {
            let words = String(cString: words_c_string)
            self.init(words)
        } else {
            return nil
        }
        
    }
    
    public var entropy: BIP39Entropy {
        get {
            let mnemonic = words.joined(separator: " ")
            
            var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BIP39_SEED_LEN_512))
            var written = UnsafeMutablePointer<Int>.allocate(capacity: 1)
            defer {
                bytes_out.deallocate()
                written.deallocate()
            }
            precondition(bip39_mnemonic_to_bytes(nil, mnemonic, bytes_out, MAX_BYTES, written) == WALLY_OK)
            return BIP39Entropy(Data(bytes: bytes_out, count: written.pointee))
        }
    }
    
    public func seedHex(_ passphrase: String? = nil) -> BIP39Seed {
        let mnemonic = words.joined(separator: " ")
        
        var bytes_out = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(BIP39_SEED_LEN_512))
        var written = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        defer {
            bytes_out.deallocate()
            written.deallocate()
        }
        precondition(bip39_mnemonic_to_seed(mnemonic, passphrase, bytes_out, Int(BIP39_SEED_LEN_512), written) == WALLY_OK)
        return BIP39Seed(Data(bytes: bytes_out, count: written.pointee))
    }

    static func isValid(_ words: [String]) -> Bool {
        // Enforce maximum length
        if (words.count > MAX_BYTES) { return false }

        // Check that each word appears in the BIP39 dictionary:
        if (!Set(words).subtracting(Set(BIP39Words)).isEmpty) {
            return false
        }
        let mnemonic = words.joined(separator: " ")
        return bip39_mnemonic_validate(nil, mnemonic) == WALLY_OK
    }
    
    static func isValid(_ words: String) -> Bool {
        return self.isValid(words.components(separatedBy: " "))
    }

}
