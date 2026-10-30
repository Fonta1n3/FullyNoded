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
