//
//  ExplorerDataDecoder.swift
//  FullyNoded
//
//  Finds data embedded in a transaction and says what it is: OP_RETURN protocols (Runes, Omni,
//  Counterparty, Stacks, swap memos, merged-mining tags), inscriptions and other witness envelopes,
//  and data hidden in bare multisig keys.
//
//  All of this is untrusted bytes from the chain, so every read is bounds checked, text has its
//  control characters removed and is cut short, and images are named but never rendered.
//  A protocol's name here means the bytes match its format. Nothing checks that a token or
//  transfer is valid under that protocol's own rules.
//

import Foundation

struct ExplorerEmbeddedData: Equatable {
    enum Location: Equatable {
        case output(Int)
        case input(Int)
    }

    let location: Location
    /// "Runes", "Inscription", "OP_RETURN text"…
    let name: String
    let details: [Detail]
    /// Bytes of embedded data.
    let size: Int

    struct Detail: Equatable {
        let title: String
        let value: String
        init(_ title: String, _ value: String) {
            self.title = title
            self.value = value
        }
    }

    /// Tokens and inscriptions: what people usually mean by spam, unlike merged-mining tags,
    /// swap memos or a plain note.
    var isTokenOrInscription: Bool {
        switch name {
        case "Runes", "Bitcoin Stamp", "Counterparty", "Atomical", "Omni Layer": return true
        case "Large witness data": return false
        default:
            if case .input = location { return true }
            return false
        }
    }

    /// Longest text shown from one item.
    static let maxText = 1000
    /// A witness item this big that isn't a known envelope is still worth pointing out.
    static let largeWitnessItem = 1024

    /// Everything found in a `getrawtransaction` verbose reply.
    static func decode(raw: [String: Any]) -> [ExplorerEmbeddedData] {
        var found: [ExplorerEmbeddedData] = []
        let inputs = raw["vin"] as? [[String: Any]] ?? []
        let firstInputTxid = inputs.first?["txid"] as? String

        for output in raw["vout"] as? [[String: Any]] ?? [] {
            guard let n = RPCValue.int(output["n"]), let spk = output["scriptPubKey"] as? [String: Any],
                  let hex = spk["hex"] as? String, let script = Hex.decode(hex).map([UInt8].init) else { continue }
            switch spk["type"] as? String {
            case "nulldata":
                found.append(decodeOpReturn(script, output: n, firstInputTxid: firstInputTxid))
            case "multisig":
                if let item = decodeBareMultisig(script, output: n, firstInputTxid: firstInputTxid) { found.append(item) }
            default:
                break
            }
        }
        for (index, input) in inputs.enumerated() {
            for hex in input["txinwitness"] as? [String] ?? [] {
                // Half the hex is the size, so most items are skipped without decoding.
                guard hex.count >= 12, let bytes = Hex.decode(hex).map([UInt8].init) else { continue }
                if let items = decodeEnvelopes(bytes, input: index), !items.isEmpty {
                    found += items
                } else if bytes.count >= largeWitnessItem {
                    found.append(ExplorerEmbeddedData(location: .input(index), name: "Large witness data", details: [], size: bytes.count))
                }
            }
        }
        return found
    }

    // MARK: - OP_RETURN

    static func decodeOpReturn(_ script: [UInt8], output n: Int, firstInputTxid: String?) -> ExplorerEmbeddedData {
        func item(_ name: String, _ details: [Detail], size: Int) -> ExplorerEmbeddedData {
            ExplorerEmbeddedData(location: .output(n), name: name, details: details, size: size)
        }
        var reader = ScriptReader(script)
        _ = reader.next() // OP_RETURN
        // Runes: OP_RETURN OP_13, then pushes.
        if script.count > 1, script[1] == 0x5D {
            _ = reader.next()
            let payload = reader.remainingPushes()
            return item("Runes", Runestone.details(payload), size: payload.count)
        }
        let data = reader.remainingPushes()
        if data.isEmpty { return item("Empty OP_RETURN", [], size: 0) }
        if data.starts(with: [0xAA, 0x21, 0xA9, 0xED]) { return item("Witness commitment", [], size: data.count) }
        if data.starts(with: Array("RSKBLOCK:".utf8)) { return item("Rootstock merged mining", [], size: data.count) }
        if data.starts(with: Array("CORE".utf8)) { return item("Core chain tag", [], size: data.count) }
        if data.starts(with: Array("omni".utf8)) { return item("Omni Layer", omniDetails(data), size: data.count) }
        if data.starts(with: Array("X2".utf8)), data.count > 2 {
            return item("Stacks", [Detail("Operation", stacksOperation(data[2]))], size: data.count)
        }
        if let txid = firstInputTxid, let message = counterpartyMessage(data, firstInputTxid: txid) {
            return item(isStamp(message) ? "Bitcoin Stamp" : "Counterparty", counterpartyDetails(message), size: data.count)
        }
        if let text = cleanText(data) {
            let memo = ["=:", "=<:", "OUT:", "REFUND:", "TRADE+:", "TRADE-:", "SWAP:", "ADD:", "+:", "-:"].contains { text.hasPrefix($0) }
            return item(memo ? "Cross-chain swap memo" : "OP_RETURN text", [Detail("Text", text)], size: data.count)
        }
        return item("Unrecognised OP_RETURN", [Detail("Hex", hexPreview(data))], size: data.count)
    }

    private static func omniDetails(_ data: [UInt8]) -> [Detail] {
        guard data.count >= 8 else { return [] }
        let type = Int(data[6]) << 8 | Int(data[7])
        guard type == 0, data.count >= 20 else { return [Detail("Message type", "\(type)")] }
        let property = data[8..<12].reduce(0) { $0 << 8 | UInt64($1) }
        let amount = data[12..<20].reduce(0) { $0 << 8 | UInt64($1) }
        // Property 31 is USDT, with 8 decimal places. Others vary, so stay in raw units.
        if property == 31 {
            return [Detail("Simple send", String(format: "%.8f USDT", Double(amount) / 100_000_000))]
        }
        return [Detail("Simple send", "\(amount) units of property \(property)")]
    }

    private static func stacksOperation(_ byte: UInt8) -> String {
        switch byte {
        case UInt8(ascii: "["): return "Block commit"
        case UInt8(ascii: "^"): return "Leader key registration"
        default:
            let scalar = UnicodeScalar(byte)
            return scalar.isASCII && byte >= 0x20 && byte < 0x7F ? "'\(Character(scalar))'" : String(format: "0x%02x", byte)
        }
    }

    // MARK: - Counterparty and Stamps

    private static let counterpartyPrefix = Array("CNTRPRTY".utf8)

    /// RC4 with the first input's txid as the key. Bytes after the prefix, or nil if it isn't one.
    static func counterpartyMessage(_ data: [UInt8], firstInputTxid: String) -> [UInt8]? {
        guard let key = Hex.decode(firstInputTxid).map([UInt8].init), !key.isEmpty else { return nil }
        let plain = rc4(data, key: key)
        guard plain.starts(with: counterpartyPrefix) else { return nil }
        return Array(plain.dropFirst(counterpartyPrefix.count))
    }

    static func rc4(_ data: [UInt8], key: [UInt8]) -> [UInt8] {
        guard !key.isEmpty else { return data }
        var s = (0...255).map { UInt8($0) }
        var j = 0
        for i in 0...255 {
            j = (j + Int(s[i]) + Int(key[i % key.count])) & 0xFF
            s.swapAt(i, j)
        }
        var i = 0
        j = 0
        return data.map { byte in
            i = (i + 1) & 0xFF
            j = (j + Int(s[i])) & 0xFF
            s.swapAt(i, j)
            return byte ^ s[(Int(s[i]) + Int(s[j])) & 0xFF]
        }
    }

    private static func isStamp(_ message: [UInt8]) -> Bool {
        String(decoding: message, as: UTF8.self).lowercased().contains("stamp:")
    }

    private static func counterpartyDetails(_ message: [UInt8]) -> [Detail] {
        guard let first = message.first else { return [] }
        // One byte, or four when the first is zero.
        let type: Int
        if first != 0 {
            type = Int(first)
        } else if message.count >= 4 {
            type = message[0..<4].reduce(0) { $0 << 8 | Int($1) }
        } else {
            return []
        }
        let names = [0: "Send", 2: "Enhanced send", 4: "Sweep", 10: "Order", 11: "BTC pay", 12: "Dispenser", 13: "Dispense",
                     20: "Issuance", 21: "Subasset issuance", 22: "Issuance", 23: "Subasset issuance", 30: "Broadcast",
                     40: "Bet", 50: "Dividend", 70: "Cancel"]
        var details = [Detail("Message", names[type] ?? "Type \(type)")]
        // A Stamp's description, or a broadcast's text.
        if let range = String(decoding: message, as: UTF8.self).range(of: "stamp:", options: .caseInsensitive) {
            let text = String(String(decoding: message, as: UTF8.self)[range.lowerBound...])
            if let tokens = tokenDetails(fromJSON: String(text.dropFirst("stamp:".count)), protocolKey: "p") {
                details += tokens
            } else if let clean = cleanText(Array(text.utf8)) {
                details.append(Detail("Text", clean))
            }
        }
        return details
    }

    /// Stamps and Counterparty's older encoding: data in the fake keys of a bare 1-of-n multisig.
    static func decodeBareMultisig(_ script: [UInt8], output n: Int, firstInputTxid: String?) -> ExplorerEmbeddedData? {
        var reader = ScriptReader(script)
        var keys: [[UInt8]] = []
        var required: Int?
        var total: Int?
        while let op = reader.next() {
            switch op {
            case .push(let bytes) where bytes.count == 33 || bytes.count == 65:
                keys.append(bytes)
            case .number(let value):
                if required == nil { required = value } else { total = value }
            default:
                break
            }
        }
        guard let m = required, let t = total, keys.count == t, keys.count >= 2 else { return nil }
        // The last key is the sender's real one.
        let chunk = keys.dropLast().filter { $0.count == 33 }.flatMap { $0[1..<32] }
        if let txid = firstInputTxid, let key = Hex.decode(txid).map([UInt8].init), !chunk.isEmpty {
            let plain = rc4(Array(chunk), key: key)
            // A length byte, then the message.
            if let length = plain.first, plain.count > Int(length), plain.count > 8 {
                let body = Array(plain[1..<(1 + Int(length))])
                if body.starts(with: counterpartyPrefix) {
                    let message = Array(body.dropFirst(counterpartyPrefix.count))
                    return ExplorerEmbeddedData(location: .output(n), name: isStamp(message) ? "Bitcoin Stamp" : "Counterparty",
                                                details: counterpartyDetails(message) + [Detail("Carried in", "Bare multisig keys")],
                                                size: chunk.count)
                }
            }
        }
        // Real multisig is usually hidden in P2SH or P2WSH these days, but this isn't proof either way.
        return ExplorerEmbeddedData(location: .output(n), name: "Bare multisig",
                                    details: [Detail("Script", "\(m)-of-\(t). Sometimes used to store data in fake keys. No known format found.")],
                                    size: 0)
    }

    // MARK: - Witness envelopes

    private static let ordMarker: [UInt8] = [0x00, 0x63, 0x03] + Array("ord".utf8)
    private static let atomicalMarker: [UInt8] = [0x00, 0x63, 0x04] + Array("atom".utf8)

    /// Inscriptions and Atomicals in one witness item. nil if there are none.
    static func decodeEnvelopes(_ bytes: [UInt8], input: Int) -> [ExplorerEmbeddedData]? {
        if firstIndex(of: atomicalMarker, in: bytes, from: 0) != nil {
            return [ExplorerEmbeddedData(location: .input(input), name: "Atomical", details: [], size: bytes.count)]
        }
        var items: [ExplorerEmbeddedData] = []
        var from = 0
        while let start = firstIndex(of: ordMarker, in: bytes, from: from) {
            let (item, end) = decodeInscription(bytes, markerEnd: start + ordMarker.count, input: input)
            if let item = item { items.append(item) }
            from = max(end, start + ordMarker.count)
        }
        return items.isEmpty ? nil : items
    }

    private static func decodeInscription(_ bytes: [UInt8], markerEnd: Int, input: Int) -> (ExplorerEmbeddedData?, Int) {
        var reader = ScriptReader(bytes, at: markerEnd)
        var contentType: String?
        var metaprotocol: String?
        var inBody = false
        var body: [UInt8] = []
        var pendingTag: Int?
        reading: while let op = reader.next() {
            if inBody {
                switch op {
                case .push(let data): body += data
                case .empty: break
                default: break reading // OP_ENDIF
                }
                continue
            }
            switch op {
            case .empty where pendingTag == nil:
                inBody = true
            case .empty:
                pendingTag = nil
            case .number(let value) where pendingTag == nil:
                pendingTag = value
            case .push(let data) where pendingTag == nil:
                pendingTag = data.count == 1 ? Int(data[0]) : -1
            case .push(let data):
                if pendingTag == 1 { contentType = cleanText(data) }
                if pendingTag == 7 { metaprotocol = cleanText(data) }
                pendingTag = nil
            case .number:
                pendingTag = nil
            case .other:
                break reading // OP_ENDIF, with no body
            }
        }

        let type = contentType ?? "unknown"
        var details = [Detail("Type", type), Detail("Size", ByteCountFormatter.string(fromByteCount: Int64(body.count), countStyle: .binary))]
        if let metaprotocol = metaprotocol { details.append(Detail("Protocol", metaprotocol)) }
        var name = "Inscription"
        let lower = type.lowercased()
        if lower.hasPrefix("image/") || lower.hasPrefix("video/") || lower.hasPrefix("audio/") {
            details.append(Detail("Content", "Not shown: Fully Noded only displays text from the chain."))
        } else if lower.hasPrefix("text/") || lower.contains("json") {
            // BRC-20 and friends are JSON in a text inscription.
            let text = String(decoding: body, as: UTF8.self)
            if let tokens = tokenDetails(fromJSON: text, protocolKey: "p") {
                name = tokens.first?.value.uppercased() ?? name
                details += tokens.dropFirst()
            } else if let clean = cleanText(body) {
                details.append(Detail("Text", clean))
            }
        }
        return (ExplorerEmbeddedData(location: .input(input), name: name, details: details, size: body.count), reader.offset)
    }

    /// BRC-20, SRC-20 and the like: {"p":"brc-20","op":"mint","tick":"ordi","amt":"1000"}.
    /// The first detail holds the protocol's name.
    static func tokenDetails(fromJSON text: String, protocolKey: String) -> [Detail]? {
        guard let data = text.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json[protocolKey] as? String, let clean = cleanText(Array(name.utf8)) else { return nil }
        var details = [Detail("Protocol", clean)]
        for (key, title) in [("op", "Operation"), ("tick", "Ticker"), ("amt", "Amount"), ("max", "Supply"), ("lim", "Limit")] {
            if let value = (json[key] as? String) ?? (json[key] as? NSNumber)?.stringValue,
               let text = cleanText(Array(value.utf8), minLength: 1) {
                details.append(Detail(title, text))
            }
        }
        return details
    }

    // MARK: - Helpers

    private static func firstIndex(of pattern: [UInt8], in bytes: [UInt8], from: Int) -> Int? {
        guard !pattern.isEmpty, bytes.count >= pattern.count, from >= 0, from <= bytes.count - pattern.count else { return nil }
        for i in from...(bytes.count - pattern.count) where bytes[i] == pattern[0] {
            if bytes[i..<(i + pattern.count)].elementsEqual(pattern) { return i }
        }
        return nil
    }

    /// Valid UTF-8 that reads as text, without control or formatting characters (which include
    /// the right-to-left overrides that can make text look like something else). nil otherwise.
    static func cleanText(_ bytes: [UInt8], minLength: Int = 3) -> String? {
        guard bytes.count >= minLength, let text = String(bytes: bytes, encoding: .utf8) else { return nil }
        var clean = String.UnicodeScalarView()
        var total = 0
        var removed = 0
        for scalar in text.unicodeScalars {
            total += 1
            switch scalar.properties.generalCategory {
            case .control where scalar == "\n" || scalar == "\r" || scalar == "\t":
                clean.append(scalar)
            case .control, .format, .privateUse, .unassigned, .surrogate:
                removed += 1
            default:
                clean.append(scalar)
            }
        }
        // More than a little of this means it's really binary.
        guard removed <= total / 20 else { return nil }
        let result = String(clean).trimmingCharacters(in: .whitespacesAndNewlines)
        guard result.count >= minLength else { return nil }
        return result.count > maxText ? String(result.prefix(maxText)) + "…" : result
    }

    private static func hexPreview(_ bytes: [UInt8]) -> String {
        let shown = Hex.encode(bytes.prefix(40))
        return bytes.count > 40 ? shown + "…" : shown
    }
}

/// Walks a script's operations without ever reading past its end.
struct ScriptReader {
    enum Op: Equatable {
        case empty              // OP_0
        case push([UInt8])
        case number(Int)        // OP_1...OP_16
        case other(UInt8)
    }

    private let bytes: [UInt8]
    private(set) var offset: Int

    init(_ bytes: [UInt8], at offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    mutating func next() -> Op? {
        guard offset < bytes.count else { return nil }
        let op = bytes[offset]
        offset += 1
        switch op {
        case 0x00:
            return .empty
        case 0x01...0x4B:
            return take(Int(op))
        case 0x4C, 0x4D, 0x4E:
            let width = op == 0x4C ? 1 : op == 0x4D ? 2 : 4
            guard offset + width <= bytes.count else {
                offset = bytes.count
                return nil
            }
            var length = 0
            for i in 0..<width { length |= Int(bytes[offset + i]) << (8 * i) }
            offset += width
            return take(length)
        case 0x51...0x60:
            return .number(Int(op) - 0x50)
        default:
            return .other(op)
        }
    }

    /// nil, and at the end, if the script claims more bytes than it has.
    private mutating func take(_ count: Int) -> Op? {
        guard count >= 0, count <= bytes.count - offset else {
            offset = bytes.count
            return nil
        }
        defer { offset += count }
        return .push(Array(bytes[offset..<(offset + count)]))
    }

    /// All remaining pushes joined together, stopping at the first thing that isn't one.
    mutating func remainingPushes() -> [UInt8] {
        var data: [UInt8] = []
        while let op = next() {
            switch op {
            case .push(let bytes): data += bytes
            case .empty: continue
            default: return data
            }
        }
        return data
    }
}

/// Reads a Runes OP_RETURN: varint pairs of tag and value, then edicts.
enum Runestone {
    /// Runes' integers are 128 bits.
    struct UInt128Value: Equatable {
        var high: UInt64
        var low: UInt64

        init(high: UInt64 = 0, low: UInt64 = 0) {
            self.high = high
            self.low = low
        }

        var isZero: Bool { high == 0 && low == 0 }

        mutating func divide(by divisor: UInt64) -> UInt64 {
            let (quotientHigh, remainderHigh) = high.quotientAndRemainder(dividingBy: divisor)
            let (quotientLow, remainder) = divisor.dividingFullWidth((remainderHigh, low))
            high = quotientHigh
            low = quotientLow
            return remainder
        }

        mutating func subtractOne() {
            if low == 0 { high &-= 1 }
            low &-= 1
        }

        var decimal: String {
            if isZero { return "0" }
            var value = self
            var digits: [Character] = []
            while !value.isZero { digits.append(Character(String(value.divide(by: 10)))) }
            return String(digits.reversed())
        }
    }

    /// LEB128. nil if it's cut off or too long for 128 bits.
    static func varints(_ bytes: [UInt8]) -> [UInt128Value]? {
        var values: [UInt128Value] = []
        var value = UInt128Value()
        var shift = 0
        var inValue = false
        for byte in bytes {
            guard shift < 128 else { return nil }
            let digit = UInt64(byte & 0x7F)
            if shift < 64 {
                value.low |= digit << UInt64(shift)
                if shift > 57 { value.high |= digit >> UInt64(64 - shift) }
            } else {
                value.high |= digit << UInt64(shift - 64)
            }
            shift += 7
            inValue = true
            if byte & 0x80 == 0 {
                values.append(value)
                value = UInt128Value()
                shift = 0
                inValue = false
            }
        }
        return inValue ? nil : values
    }

    /// A rune's name: bijective base 26, A to Z. `spacers` puts a • after the letters it flags.
    static func name(_ value: UInt128Value, spacers: UInt64 = 0) -> String {
        var remaining = value
        var letters: [Character] = []
        // Value 0 is "A", 25 is "Z", 26 is "AA".
        repeat {
            let digit = remaining.divide(by: 26)
            letters.append(Character(UnicodeScalar(UInt8(65 + digit))))
            if remaining.isZero { break }
            remaining.subtractOne()
        } while true
        let ordered = Array(letters.reversed())
        var result = ""
        for (index, letter) in ordered.enumerated() {
            result.append(letter)
            if index < 64, index < ordered.count - 1, spacers & (1 << UInt64(index)) != 0 { result.append("•") }
        }
        return result
    }

    static func details(_ payload: [UInt8]) -> [ExplorerEmbeddedData.Detail] {
        typealias Detail = ExplorerEmbeddedData.Detail
        guard let values = varints(payload) else { return [Detail("Status", "Malformed runestone")] }
        var details: [Detail] = []
        var fields: [(tag: UInt64, value: UInt128Value)] = []
        var edicts = 0
        var index = 0
        while index < values.count {
            let tag = values[index]
            // Tag 0: everything after it is edicts, four numbers each.
            if tag.isZero {
                edicts = (values.count - index - 1) / 4
                break
            }
            guard index + 1 < values.count, tag.high == 0 else {
                details.append(Detail("Status", "Malformed runestone"))
                break
            }
            fields.append((tag.low, values[index + 1]))
            index += 2
        }

        let spacers = fields.first { $0.tag == 3 }?.value.low ?? 0
        if let rune = fields.first(where: { $0.tag == 4 }) {
            details.append(Detail("Etching", name(rune.value, spacers: spacers)))
        }
        if let symbol = fields.first(where: { $0.tag == 5 }), symbol.value.high == 0,
           let scalar = UnicodeScalar(UInt32(truncatingIfNeeded: symbol.value.low)),
           !scalar.properties.isWhitespace, scalar.properties.generalCategory != .control, scalar.properties.generalCategory != .format {
            details.append(Detail("Symbol", String(Character(scalar))))
        }
        if let amount = fields.first(where: { $0.tag == 10 }) { details.append(Detail("Mint amount", amount.value.decimal)) }
        if let cap = fields.first(where: { $0.tag == 8 }) { details.append(Detail("Mint cap", cap.value.decimal)) }
        if let premine = fields.first(where: { $0.tag == 6 }) { details.append(Detail("Premine", premine.value.decimal)) }
        // Tag 20 twice: the rune's block, then its transaction.
        let mint = fields.filter { $0.tag == 20 }
        if mint.count >= 2 { details.append(Detail("Mint", "\(mint[0].value.decimal):\(mint[1].value.decimal)")) }
        if edicts > 0 { details.append(Detail("Transfers", "\(edicts)")) }
        // Odd tag, ignored by Runes: where Alkanes-style protocols keep their own messages.
        if fields.contains(where: { $0.tag == 16383 }) { details.append(Detail("Extra data", "Protostones (Alkanes style)")) }
        return details
    }
}
