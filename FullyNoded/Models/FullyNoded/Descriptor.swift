//
//  DescriptorStruct.swift
//  FullyNoded2
//
//  Created by Peter on 15/02/20.
//  Copyright © 2020 Blockchain Commons, LLC. All rights reserved.
//
import Foundation

public struct Descriptor: CustomStringConvertible {
    
    let isCosigner: Bool
    let scriptType: String
    let format: String
    let isHot: Bool
    let mOfNType: String
    let chain: String
    let isMulti: Bool
    let isBIP67: Bool
    let isBIP49: Bool
    let isBIP84: Bool
    let isBIP48: Bool
    let isBIP44: Bool
    let isP2WPKH: Bool
    let isP2PKH: Bool
    let isP2SHP2WPKH: Bool
    let isP2TR: Bool
    let multiSigKeys: [String]
    let multiSigPaths: [String]
    let sigsRequired: UInt
    let accountXpub: String
    let accountXprv: String
    let derivation: String
    let derivationArray: [String]
    let isSpecter: Bool
    let isHD: Bool
    let keysWithPath: [String]
    let scriptPath: String
    let internalKey: String
    let isAccount: Bool
    let fingerprint: String
    let prefix: String
    let pubkey: String
    let isTaproot: Bool
    let index: Int?
    let isInternal: Bool
    let isTimelocked: Bool
    let string: String
    let expiry: String
    let hasRange: Bool
    
    // MARK: - Shared parsing

    /// The arguments (threshold first, then the keys) of the first multi / sortedmulti / multi_a /
    /// sortedmulti_a in `descriptor`, found by matching parentheses so surrounding fragments such as
    /// `and_v(v:multi(...),after(N))` or a trailing checksum can't leak in.
    static func multisigArguments(in descriptor: String) -> [String]? {
        guard let match = descriptor.range(of: #"(sorted)?multi(_a)?\("#, options: .regularExpression) else { return nil }
        
        var depth = 1
        var index = match.upperBound
        var closing: String.Index?
        while index < descriptor.endIndex {
            if descriptor[index] == "(" { depth += 1 }
            if descriptor[index] == ")" {
                depth -= 1
                if depth == 0 { closing = index; break }
            }
            index = descriptor.index(after: index)
        }
        guard let end = closing else { return nil }
        
        var args: [String] = []
        var current = ""
        var nesting = 0
        for character in descriptor[match.upperBound..<end] {
            if character == "(" || character == "[" { nesting += 1 }
            if character == ")" || character == "]" { nesting -= 1 }
            if character == "," && nesting == 0 {
                args.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        args.append(current)
        return args.count >= 2 ? args : nil
    }
    
    /// What one pass over a descriptor learns. Every field starts at the value the matching
    /// property has when the descriptor says nothing about it.
    private struct Parsed {
        var isCosigner = false
        var format = ""
        var scriptType = ""
        var mOfNType = ""
        var chain = ""
        var isMulti = false
        var isBIP67 = false
        var isBIP49 = false
        var isBIP84 = false
        var isBIP48 = false
        var isBIP44 = false
        var isP2PKH = false
        var isP2WPKH = false
        var isP2SHP2WPKH = false
        var isHot = false
        var isHD = false
        var isSpecter = false
        var isAccount = false
        var isInternal = false
        var isTimelocked = false
        var hasRange = false
        var sigsRequired: UInt = 0
        var multiSigKeys: [String]?
        var multiSigPaths: [String]?
        var derivationArray: [String]?
        var keysWithPath: [String]?
        var accountXpub = ""
        var accountXprv = ""
        var derivation = ""
        var fingerprint = ""
        var prefix = ""
        var pubkey = ""
        var index: Int?
        var scriptPath = ""
        var internalKey = ""
        var expiry = ""
    }
    
    /// The BIP32 account paths this app recognises, and what each says about the script type.
    /// `nil` leaves a flag as it was.
    private struct AccountFlags {
        var bip44: Bool?, p2pkh: Bool?, bip84: Bool?, p2wpkh: Bool?, bip49: Bool?, p2shp2wpkh: Bool?, bip48: Bool?
        var cosigner: Bool?
        var format: String?, scriptType: String?
    }
    
    private static func apply(_ flags: AccountFlags, to p: inout Parsed) {
        if let v = flags.bip44 { p.isBIP44 = v }
        if let v = flags.p2pkh { p.isP2PKH = v }
        if let v = flags.bip84 { p.isBIP84 = v }
        if let v = flags.p2wpkh { p.isP2WPKH = v }
        if let v = flags.bip49 { p.isBIP49 = v }
        if let v = flags.p2shp2wpkh { p.isP2SHP2WPKH = v }
        if let v = flags.bip48 { p.isBIP48 = v }
        if let v = flags.cosigner { p.isCosigner = v }
        if let v = flags.format { p.format = v }
        if let v = flags.scriptType { p.scriptType = v }
        p.isAccount = true
    }
    
    /// "m/48h/1h/0h/2h" and "m/48'/1'/0'/2'" are the same path.
    private static func normalizedPath(_ derivation: String) -> String {
        derivation.replacingOccurrences(of: "h", with: "'")
    }
    
    /// Account paths as they appear on the keys of a multisig descriptor.
    private static func multisigAccountFlags(_ derivation: String) -> AccountFlags? {
        switch normalizedPath(derivation) {
        case "m/48'/0'/0'/1'", "m/48'/1'/0'/1'":
            return AccountFlags(bip44: false, p2pkh: false, bip84: false, p2wpkh: false, bip49: false, p2shp2wpkh: true, bip48: true)
        case "m/48'/0'/0'/2'", "m/48'/1'/0'/2'":
            return AccountFlags(bip44: false, p2pkh: false, bip84: false, p2wpkh: true, bip49: false, p2shp2wpkh: false, bip48: true)
        case "m/48'/0'/0'/3'", "m/48'/1'/0'/3'":
            return AccountFlags(bip44: false, p2pkh: false, bip84: false, p2wpkh: false, bip49: false, p2shp2wpkh: false, bip48: true)
        case "m/44'/0'/0'", "m/44'/1'/0'":
            return AccountFlags(bip44: true, p2pkh: true, bip84: false, p2wpkh: false, bip49: false, p2shp2wpkh: false)
        case "m/84'/0'/0'", "m/84'/1'/0'":
            return AccountFlags(bip44: false, p2pkh: false, bip84: true, p2wpkh: true, bip49: false, p2shp2wpkh: false)
        case "m/49'/0'/0'", "m/49'/1'/0'":
            return AccountFlags(bip44: false, p2pkh: false, bip84: false, p2wpkh: false, bip49: true, p2shp2wpkh: true)
        default:
            return nil
        }
    }
    
    /// A taproot multisig's keys only ever use the BIP48 script type 3'.
    private static func taprootMultisigAccountFlags(_ derivation: String) -> AccountFlags? {
        switch normalizedPath(derivation) {
        case "m/48'/0'/0'/3'", "m/48'/1'/0'/3'":
            return multisigAccountFlags(derivation)
        default:
            return nil
        }
    }
    
    /// Account paths on a single key expression.
    private static func singleSigAccountFlags(_ derivation: String) -> AccountFlags? {
        switch normalizedPath(derivation) {
        case "m/44'/0'/0'", "m/44'/1'/0'":
            return AccountFlags(bip44: true, p2pkh: true, cosigner: false)
        case "m/84'/0'/0'", "m/84'/1'/0'":
            return AccountFlags(bip84: true, p2wpkh: true, cosigner: false)
        case "m/49'/0'/0'", "m/49'/1'/0'":
            return AccountFlags(bip49: true, p2shp2wpkh: true, cosigner: false)
        case "m/86'/0'/0'", "m/86'/1'/0'":
            return AccountFlags(cosigner: false, format: "P2TR", scriptType: "Taproot single-sig")
        case "m/48'/0'/0'/3'", "m/48'/1'/0'/3'":
            return AccountFlags(bip48: true, cosigner: true, format: "P2TR", scriptType: "Taproot multi-sig")
        default:
            return nil
        }
    }
    
    /// What the keys of a multisig descriptor say, in the order they appear:
    /// `[fingerprint/path]xpub/branch/*`, or `[fingerprint/path/branch/index]pubkey`.
    private struct MultisigKeyDetails {
        var fingerprints: [String] = []
        var keys: [String] = []
        var paths: [String] = []
        var derivations: [String] = []
        /// Last component of the last key's origin path, when it is a number.
        var index: Int?
    }
    
    private static func multisigKeyDetails(_ keysWithPath: [String]) -> MultisigKeyDetails {
        var details = MultisigKeyDetails()
        
        for key in keysWithPath {
            // Only keys with an origin and a path are usable.
            guard key.contains("/"), key.contains("["), key.contains("]") else { continue }
            
            let parts = key.split(separator: "]")
            guard let origin = parts.first else { continue }
            let originComponents = origin.replacingOccurrences(of: "[", with: "").split(separator: "/")
            guard let fingerprint = originComponents.first, let last = originComponents.last else { continue }
            
            details.index = Int(last)
            details.fingerprints.append("[\(fingerprint)]")
            details.derivations.append("m" + originComponents.dropFirst().map { "/" + $0 }.joined())
            
            let remainder = parts.count > 1 ? parts[1] : ""
            var path = ""
            for item in remainder.split(separator: "/") {
                if item.contains("xpub") || item.contains("tpub") || item.contains("xprv") || item.contains("tprv") {
                    details.keys.append(item.replacingOccurrences(of: "))", with: ""))
                } else if item.hasPrefix("0") {
                    // A raw public key (a derived descriptor). "0" alone is just the receive branch.
                    let pubkey = item.contains(")") ? String(item.split(separator: ")").first ?? "") : String(item)
                    if let data = Data(hexString: pubkey), data.count == 33 || data.count == 65 {
                        details.keys.append(pubkey)
                    }
                } else if !item.contains("*") {
                    path = path.isEmpty ? String(item) : path + "/" + item
                } else {
                    details.paths.append(path)
                }
            }
        }
        return details
    }
    
    /// "[fp1], [fp2]" for the keys that have one ("[]" when none do, as callers have always seen).
    private static func fingerprintList(_ fingerprints: [String]) -> String {
        fingerprints.isEmpty ? "[]" : fingerprints.joined(separator: ", ")
    }
    
    /// The key expression of a `tr(KEY,...)` descriptor, without the `tr(` or what follows.
    private static func taprootInternalKey(of descriptor: String) -> String {
        var depth = 0
        var key = ""
        for character in descriptor.dropFirst(3) {
            if character == "(" || character == "[" { depth += 1 }
            if character == ")" || character == "]" {
                if depth == 0 { break }
                depth -= 1
            }
            if character == "," && depth == 0 { break }
            key.append(character)
        }
        return key
    }
    
    /// "Oct 6, 2026 at 16:10" for a timestamp, "block 850000" for a block height (`after(N)` is a
    /// height below 500,000,000 and a Unix time at or above it).
    private static func expiryText(_ value: String) -> String? {
        guard let number = UInt64(value) else { return value.unixTimestampToDateString() }
        return number < 500_000_000 ? "block \(number)" : value.unixTimestampToDateString()
    }
    
    // MARK: - Parsing
    
    init(_ descriptor: String) {
        string = descriptor
        var p = Parsed()
        
        p.hasRange = descriptor.contains("*")
        p.isSpecter = descriptor.contains("&")
        isTaproot = descriptor.hasPrefix("tr(")
        isP2TR = isTaproot
        
        if isTaproot {
            p.internalKey = Self.taprootInternalKey(of: descriptor)
            p.scriptPath = descriptor.split(separator: ",").dropFirst().joined(separator: ",").replacingOccurrences(of: "))", with: ")")
        }
        
        if descriptor.contains(",after(") {
            p.isTimelocked = true
            if let match = descriptor.range(of: #",after\((\d+)\)"#, options: .regularExpression) {
                let number = descriptor[match].dropFirst(7).dropLast()
                p.expiry = Self.expiryText(String(number)) ?? ""
            }
        }
        
        if descriptor.contains("/1/") {
            p.isInternal = true
        }
        
        if descriptor.contains("multi") {
            Self.parseMultisig(descriptor, into: &p)
        } else {
            Self.parseSingleSig(descriptor, into: &p)
        }
        
        if descriptor.contains("xpub") || descriptor.contains("xprv") {
            p.chain = "Mainnet"
            p.isHD = true
        } else if descriptor.contains("tpub") || descriptor.contains("tprv") {
            p.chain = "Testnet"
            p.isHD = true
        }
        
        if descriptor.contains("xprv") || descriptor.contains("tprv") {
            p.isHot = true
        }
        
        isCosigner = p.isCosigner
        format = p.format
        scriptType = p.scriptType
        mOfNType = p.mOfNType
        isHot = p.isHot
        chain = p.chain
        isMulti = p.isMulti
        isBIP67 = p.isBIP67
        isBIP49 = p.isBIP49
        isBIP84 = p.isBIP84
        isBIP48 = p.isBIP48
        isBIP44 = p.isBIP44
        isP2PKH = p.isP2PKH
        isP2WPKH = p.isP2WPKH
        isP2SHP2WPKH = p.isP2SHP2WPKH
        multiSigKeys = p.multiSigKeys ?? [""]
        multiSigPaths = p.multiSigPaths ?? [""]
        sigsRequired = p.sigsRequired
        accountXpub = p.accountXpub
        accountXprv = p.accountXprv
        derivation = p.derivation
        derivationArray = p.derivationArray ?? [""]
        isSpecter = p.isSpecter
        isHD = p.isHD
        keysWithPath = p.keysWithPath ?? [""]
        isAccount = p.isAccount
        fingerprint = p.fingerprint
        prefix = p.prefix
        pubkey = p.pubkey
        index = p.index
        scriptPath = p.scriptPath
        internalKey = p.internalKey
        isInternal = p.isInternal
        isTimelocked = p.isTimelocked
        expiry = p.expiry
        hasRange = p.hasRange
    }
    
    // MARK: Multisig
    
    private static func parseMultisig(_ descriptor: String, into p: inout Parsed) {
        p.isMulti = true
        p.isBIP67 = descriptor.contains("sortedmulti")
        
        let tokens = descriptor.split(separator: "(")
        for (i, token) in tokens.enumerated() {
            if i == 0 {
                switch token {
                case "multi":
                    p.format = "Bare-multi"
                    p.scriptType = "Bare multi-sig"
                case "wsh":
                    p.format = "P2WSH"
                    p.scriptType = "Segwit multi-sig"
                case "sh":
                    if tokens.count > 1 && tokens[1] == "wsh" {
                        p.format = "P2SH-P2WSH"
                        p.scriptType = "Nested multi-sig"
                    } else {
                        p.format = "P2SH"
                        p.scriptType = "Legacy multi-sig"
                    }
                case "tr":
                    parseTaprootMultisig(descriptor, into: &p)
                default:
                    break
                }
            }
            
            // "v:multi" is how the multisig appears inside a timelock: and_v(v:multi(...),after(N))
            switch token {
            case "multi", "sortedmulti", "v:multi", "v:sortedmulti":
                // Inside a timelock the text after the keys is "...),after(N)))": take exactly the
                // multi's own arguments so "after" isn't counted as a key.
                let arguments: [String]
                if token.hasPrefix("v:"), let matched = multisigArguments(in: descriptor) {
                    arguments = matched
                } else if i + 1 < tokens.count {
                    arguments = tokens[i + 1].split(separator: ",").map(String.init)
                } else {
                    arguments = []
                }
                guard let threshold = arguments.first else { break }
                
                let keys = Array(arguments.dropFirst())
                p.mOfNType = "\(threshold) of \(keys.count)"
                p.sigsRequired = UInt(threshold) ?? 0
                p.keysWithPath = keys
                
                let details = multisigKeyDetails(keys)
                p.index = details.index
                p.derivationArray = details.derivations
                p.multiSigKeys = details.keys
                p.multiSigPaths = details.paths
                p.fingerprint = fingerprintList(details.fingerprints)
                if let last = details.derivations.last { p.derivation = last }
                for derivation in details.derivations {
                    if let flags = multisigAccountFlags(derivation) { apply(flags, to: &p) }
                }
            default:
                break
            }
        }
    }
    
    /// `tr(INTERNAL_KEY, multi_a(m, keys...))`, optionally wrapped: and_v(v:multi_a(...),after(N)).
    private static func parseTaprootMultisig(_ descriptor: String, into p: inout Parsed) {
        p.format = "P2TR"
        p.scriptType = "Taproot multi-sig"
        
        // m and n by matching parentheses, so a wrapper or a trailing timelock can't be mistaken for keys.
        let arguments = multisigArguments(in: descriptor) ?? []
        if let threshold = arguments.first {
            p.mOfNType = "\(threshold) of \(arguments.count - 1)"
            p.sigsRequired = UInt(threshold) ?? 0
        }
        let keys = Array(arguments.dropFirst())
        p.keysWithPath = keys
        
        let details = multisigKeyDetails(keys)
        p.index = details.index
        p.derivationArray = details.derivations
        p.multiSigKeys = details.keys
        p.multiSigPaths = details.paths
        p.fingerprint = fingerprintList(details.fingerprints)
        for derivation in details.derivations {
            p.derivation = derivation
            if let flags = taprootMultisigAccountFlags(derivation) { apply(flags, to: &p) }
        }
    }
    
    // MARK: Single key
    
    private static func parseSingleSig(_ descriptor: String, into p: inout Parsed) {
        p.mOfNType = "Single Sig"
        
        // `[fingerprint/path]key/...`, whether wrapped in wpkh( ) or a bare key expression.
        if let open = descriptor.firstIndex(of: "["), descriptor.contains("]") {
            let segment = descriptor[descriptor.index(after: open)...].split(separator: "[", maxSplits: 1, omittingEmptySubsequences: false)[0]
            p.keysWithPath = ["[" + segment]
            
            let pieces = segment.split(separator: "]")
            let origin = pieces.first ?? ""
            p.prefix = "[\(origin)]"
            
            let originComponents = origin.split(separator: "/")
            if let last = originComponents.last, let first = originComponents.first {
                p.index = Int(last)
                p.fingerprint = String(first)
            }
            
            let extendedKey = (pieces.count > 1 ? pieces[1] : "").split(separator: "/").first ?? ""
            if extendedKey.contains("tpub") || extendedKey.contains("xpub") {
                p.accountXpub = extendedKey.replacingOccurrences(of: ")", with: "")
            } else if extendedKey.contains("tprv") || extendedKey.contains("xprv") {
                p.accountXprv = extendedKey.replacingOccurrences(of: ")", with: "")
                if let xpub = Keys.xpub(fromXprv: String(extendedKey)) {
                    p.accountXpub = xpub
                }
            } else {
                // A raw public key; a checksum may still be attached ("key)#checksum").
                let parts = extendedKey.split(separator: "#")
                p.pubkey = (parts.count == 2 ? String(parts[0]) : String(extendedKey)).replacingOccurrences(of: ")", with: "")
            }
            
            // The fingerprint plus at least two path components make a derivation.
            if originComponents.count >= 3 {
                let path = "m" + originComponents.dropFirst().map { "/" + $0 }.joined()
                p.derivation = path
                if let flags = singleSigAccountFlags(path) { apply(flags, to: &p) }
            }
        }
        
        if descriptor.contains("combo") {
            p.format = "Combo"
        } else {
            let tokens = descriptor.split(separator: "(")
            switch tokens.first {
            case "wsh":
                p.format = "P2WSH"
                p.scriptType = "Segwit multi-sig"
                p.isCosigner = true
            case "wpkh":
                p.format = "P2WPKH"
                p.isP2WPKH = true
                p.scriptType = "Segwit single-sig"
            case "sh":
                if tokens.count > 1 && tokens[1] == "wpkh" {
                    p.format = "P2SH-P2WPKH"
                    p.isP2SHP2WPKH = true
                    p.scriptType = "Nested single-sig"
                } else if tokens.count > 1 && tokens[1] == "wsh" {
                    p.format = "P2SH-P2WSH"
                    p.scriptType = "Segwit multi-sig"
                    p.isCosigner = true
                } else {
                    p.format = "P2SH"
                    p.scriptType = "Legacy multi-sig"
                    p.isCosigner = true
                }
            case "pk":
                p.format = "P2PK"
                p.scriptType = "Public key"
            case "pkh":
                p.format = "P2PKH"
                p.isP2PKH = true
                p.scriptType = "Legacy single-sig"
            default:
                break
            }
        }
    }
    
    public var description: String {
        return ""
    }
    
}

extension String {
    func unixTimestampToDateString() -> String? {
        guard let timestamp = Double(self) else { return nil }
        let date = Date(timeIntervalSince1970: timestamp)
        
        return date.formatted(
            .dateTime
            .month(.abbreviated)
            .day()
            .year()
            .hour().minute()
        )
    }
}


// MARK: - Checksum (BIP380)

extension Descriptor {
    private static let checksumInputCharset = Array("0123456789()[],'/*abcdefgh@:$%{}IJKLMNOPQRSTUVWXYZ&+-.;<=>?!^_|~ijklmnopqrstuvwxyzABCDEFGH`#\"\\ ")
    private static let checksumCharset = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")

    private static func checksumPolymod(_ c: UInt64, _ value: UInt64) -> UInt64 {
        let c0 = c >> 35
        var c = ((c & 0x7_ffff_ffff) << 5) ^ value
        if c0 & 1 != 0 { c ^= 0xf5_dee5_1989 }
        if c0 & 2 != 0 { c ^= 0xa9_fdca_3312 }
        if c0 & 4 != 0 { c ^= 0x1b_ab10_e32d }
        if c0 & 8 != 0 { c ^= 0x37_06b1_677a }
        if c0 & 16 != 0 { c ^= 0x64_4d62_6ffd }
        return c
    }

    /// The 8-character checksum Bitcoin Core appends after "#", computed locally over the
    /// descriptor without any existing checksum. Nil if it holds a character descriptors can't.
    static func checksum(of descriptor: String) -> String? {
        let body = descriptor.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? descriptor
        var c: UInt64 = 1
        var cls: UInt64 = 0
        var clsCount = 0
        for ch in body {
            guard let pos = checksumInputCharset.firstIndex(of: ch) else { return nil }
            c = checksumPolymod(c, UInt64(pos & 31))
            cls = cls * 3 + UInt64(pos >> 5)
            clsCount += 1
            if clsCount == 3 {
                c = checksumPolymod(c, cls)
                cls = 0
                clsCount = 0
            }
        }
        if clsCount > 0 { c = checksumPolymod(c, cls) }
        for _ in 0..<8 { c = checksumPolymod(c, 0) }
        c ^= 1
        return String((0..<8).map { checksumCharset[Int((c >> (5 * (7 - UInt64($0)))) & 31)] })
    }

    /// The checksum written on the descriptor ("…#abcd1234"), if any.
    static func statedChecksum(of descriptor: String) -> String? {
        let parts = descriptor.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
        return parts.count == 2 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }
}
