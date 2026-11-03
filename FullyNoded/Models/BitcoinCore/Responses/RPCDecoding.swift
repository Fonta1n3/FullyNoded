//
//  RPCDecoding.swift
//  FullyNoded
//
//  Created by Peter Denton on 10/30/26.
//  Copyright © 2026 Fontaine. All rights reserved.
//

import Foundation

/*
 Bitcoin Core adds, deprecates and removes RPC result fields between releases (v32 dropped
 "bip125-replaceable" from listtransactions, for example), and Knots and older nodes differ
 again. These helpers read node replies tolerantly so one changed field never breaks a whole
 screen: numbers are accepted whatever JSON type they arrive as, missing fields fall back to
 defaults, and a list keeps every entry it can read instead of failing on the first bad one.
 */

/// Tolerant readers for values in a node reply dictionary.
enum RPCValue {
    static func int(_ value: Any?) -> Int? {
        switch value {
        case let number as NSNumber: return number.intValue
        case let string as String: return Int(string) ?? Double(string).map { Int($0) }
        default: return nil
        }
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
        }
    }

    static func string(_ value: Any?) -> String? {
        switch value {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }

    static func bool(_ value: Any?) -> Bool? {
        switch value {
        case let number as NSNumber: return number.boolValue
        case let string as String: return ["true", "yes", "1"].contains(string.lowercased())
        default: return nil
        }
    }

    /// Decodes each dictionary on its own, dropping (and logging) any entry that can't be read
    /// rather than failing the whole list.
    static func decodeEach<T: Decodable>(_ type: T.Type, from items: [Any], context: String) -> [T] {
        var decoded: [T] = []
        decoded.reserveCapacity(items.count)
        for (index, item) in items.enumerated() {
            // dataWithJSONObject raises an Objective-C exception (not a Swift error) on a bare value.
            guard JSONSerialization.isValidJSONObject(item) else {
                print("[rpc] \(context): skipped entry \(index): not an object")
                continue
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: item)
                decoded.append(try JSONDecoder().decode(T.self, from: data))
            } catch {
                print("[rpc] \(context): skipped entry \(index): \(error)")
            }
        }
        return decoded
    }
}

extension KeyedDecodingContainer {
    func lenientInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return Int(value) }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return RPCValue.int(value) }
        return nil
    }

    func lenientDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return Double(value) }
        return nil
    }

    func lenientString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return String(value) }
        return nil
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        if let value = try? decodeIfPresent(String.self, forKey: key) { return RPCValue.bool(value) }
        return nil
    }
}

/// A decodable list that keeps every element it can read and drops the rest.
struct LossyArray<Element: Decodable>: Decodable {
    var elements: [Element]

    /// Reads nothing, so it accepts any element and just moves the container past it.
    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                elements.append(element)
            } else {
                print("[rpc] skipped an unreadable \(Element.self)")
                guard (try? container.decode(Skip.self)) != nil else { break }
            }
        }
        self.elements = elements
    }
}

/*
 Core 32 creates PSBT version 2 by default, and decodepsbt of a v2 PSBT has no "tx": the
 transaction is spread over "tx_version", "fallback_locktime" and per input/output fields.
 FN asks v32+ nodes for v0 (what its own signing, external signers and BIP78 payjoin read),
 and reads a v2 decode (a PSBT imported from elsewhere) into the same shape.
 */
enum PSBTVersion {
    /// Set when a node rejected psbt_version (FN's stored version was another node's); cleared
    /// when the version is read again.
    static var nodeRejectedParam = false

    /// psbt_version is only a known parameter from Core 32; older nodes reject it.
    static var mustRequestV0: Bool {
        !nodeRejectedParam && (UserDefaults.standard.object(forKey: "version") as? Int ?? 0) >= 320000
    }

    /// Request params without psbt_version (top level for walletcreatefundedpsbt / createpsbt,
    /// in options for psbtbumpfee).
    static func stripped(_ params: [String: Any]) -> [String: Any] {
        var params = params
        params["psbt_version"] = nil
        if var options = params["options"] as? [String: Any], options["psbt_version"] != nil {
            options["psbt_version"] = nil
            params["options"] = options
        }
        return params
    }

    static func sends(_ params: [String: Any]) -> Bool {
        params["psbt_version"] != nil || (params["options"] as? [String: Any])?["psbt_version"] != nil
    }

    /// "Unknown named parameter psbt_version" / "Unexpected key psbt_version".
    static func isRejection(_ error: String?) -> Bool {
        error?.contains("psbt_version") == true
    }

    /// The decodepsbt "tx" object, or one built from a v2 decode's fields (no txid or vsize,
    /// which v2 doesn't report). nil if the reply has neither.
    static func tx(from decoded: NSDictionary) -> NSDictionary? {
        if let tx = decoded["tx"] as? NSDictionary { return tx }
        guard let inputs = decoded["inputs"] as? [[String: Any]],
              let outputs = decoded["outputs"] as? [[String: Any]] else { return nil }
        var vin: [[String: Any]] = []
        for input in inputs {
            guard let txid = input["previous_txid"] as? String,
                  let vout = RPCValue.int(input["previous_vout"]) else { return nil }
            vin.append(["txid": txid, "vout": vout,
                        "sequence": RPCValue.int(input["sequence"]) ?? 0xffffffff])
        }
        var vout: [[String: Any]] = []
        for (n, output) in outputs.enumerated() {
            guard let value = RPCValue.double(output["amount"]),
                  let script = output["script"] as? [String: Any] else { return nil }
            vout.append(["value": value, "n": n, "scriptPubKey": script])
        }
        return [
            "version": RPCValue.int(decoded["tx_version"]) ?? 2,
            "locktime": RPCValue.int(decoded["fallback_locktime"]) ?? 0,
            "vin": vin,
            "vout": vout
        ] as NSDictionary
    }
}
