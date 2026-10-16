//
//  URCore.swift
//  FullyNoded
//
//  Fully Noded's own CBOR, Bytewords and single-part UR (BCR-2020-005 / BCR-2020-012), in place
//  of URKit / DCBOR. Animated multi-part URs are in URFountain.swift.
//
//  The types keep URKit 14's shape (`CBOR`, `Map`, `Tag`, `UR`) so the code built on them is
//  unchanged, and encode byte for byte like it: deterministic CBOR (shortest-form integers and
//  lengths, map keys sorted by their encoded bytes, NFC text). Decoding is lenient where URKit
//  was strict (non-shortest integers, unsorted map keys), since other wallets' exports aren't
//  always canonical.
//

import Foundation

// MARK: - CBOR

indirect enum CBOR {
    case unsigned(UInt64)
    /// -1 - n.
    case negative(UInt64)
    case bytes(Data)
    case text(String)
    case array([CBOR])
    case map(Map)
    case tagged(Tag, CBOR)
    case simple(Simple)

    static let `false` = CBOR.simple(.false)
    static let `true` = CBOR.simple(.true)
    static let null = CBOR.simple(.null)

    init<T: CBOREncodable>(_ x: T) {
        self = x.cbor
    }

    /// Decodes one CBOR item that must fill `data` exactly.
    init(_ data: Data) throws {
        var reader = CBORReader([UInt8](data))
        self = try reader.item(depth: 0)
        guard reader.atEnd else { throw CBORError.unusedData(reader.remaining) }
    }
}

enum Simple: Equatable {
    case `false`
    case `true`
    case null
    case float(Double)
}

enum CBORError: LocalizedError, Equatable {
    case underrun
    case unusedData(Int)
    case unsupported(String)
    case invalidString
    case wrongType
    case tooDeep

    var errorDescription: String? {
        switch self {
        case .underrun: return "CBOR: unexpected end of data."
        case .unusedData(let n): return "CBOR: \(n) unused byte(s) at the end."
        case .unsupported(let what): return "CBOR: unsupported \(what)."
        case .invalidString: return "CBOR: invalid UTF-8 text."
        case .wrongType: return "CBOR: wrong type."
        case .tooDeep: return "CBOR: nested too deeply."
        }
    }
}

/// A CBOR tag (e.g. 303 crypto-hdkey).
struct Tag: Hashable, ExpressibleByIntegerLiteral, CustomStringConvertible {
    let value: UInt64

    init(_ value: UInt64) {
        self.value = value
    }

    init(integerLiteral value: UInt64) {
        self.value = value
    }

    var description: String { String(value) }
}

// MARK: Encoding

protocol CBOREncodable {
    var cbor: CBOR { get }
    var cborData: Data { get }
}

extension CBOREncodable {
    var cborData: Data { cbor.cborData }
}

/// A CBOR head: major type and argument, in the shortest form (RFC 8949 preferred encoding).
private func cborHead(_ major: UInt8, _ value: UInt64) -> Data {
    let type = major << 5
    switch value {
    case 0...23:
        return Data([type | UInt8(value)])
    case 24...0xFF:
        return Data([type | 24, UInt8(value)])
    case 0x100...0xFFFF:
        return Data([type | 25, UInt8(value >> 8), UInt8(value & 0xFF)])
    case 0x10000...0xFFFF_FFFF:
        return Data([type | 26] + (0..<4).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt64($0))) })
    default:
        return Data([type | 27] + (0..<8).reversed().map { UInt8(truncatingIfNeeded: value >> (8 * UInt64($0))) })
    }
}

extension CBOR: CBOREncodable {
    var cbor: CBOR { self }

    var cborData: Data {
        switch self {
        case .unsigned(let n):
            return cborHead(0, n)
        case .negative(let n):
            return cborHead(1, n)
        case .bytes(let data):
            return cborHead(2, UInt64(data.count)) + data
        case .text(let string):
            let utf8 = Data(string.precomposedStringWithCanonicalMapping.utf8)
            return cborHead(3, UInt64(utf8.count)) + utf8
        case .array(let items):
            return items.reduce(cborHead(4, UInt64(items.count))) { $0 + $1.cborData }
        case .map(let map):
            return map.cborData
        case .tagged(let tag, let item):
            return cborHead(6, tag.value) + item.cborData
        case .simple(let simple):
            switch simple {
            case .false: return Data([0xF4])
            case .true: return Data([0xF5])
            case .null: return Data([0xF6])
            case .float(let d):
                // Not produced by Fully Noded; written as a 64-bit float.
                return Data([0xFB]) + withUnsafeBytes(of: d.bitPattern.bigEndian) { Data($0) }
            }
        }
    }
}

extension CBOR: Equatable {
    static func == (lhs: CBOR, rhs: CBOR) -> Bool {
        switch (lhs, rhs) {
        case let (.unsigned(l), .unsigned(r)): return l == r
        case let (.negative(l), .negative(r)): return l == r
        case let (.bytes(l), .bytes(r)): return l == r
        case let (.text(l), .text(r)): return l == r
        case let (.array(l), .array(r)): return l == r
        case let (.map(l), .map(r)): return l == r
        case let (.tagged(lt, li), .tagged(rt, ri)): return lt == rt && li == ri
        case let (.simple(l), .simple(r)): return l == r
        default: return false
        }
    }
}

extension CBOR: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self = value < 0 ? .negative(UInt64(-1 - value)) : .unsigned(UInt64(value))
    }
}

extension CBOR: ExpressibleByBooleanLiteral {
    init(booleanLiteral value: Bool) {
        self = value ? .true : .false
    }
}

extension CBOR: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension CBOR: ExpressibleByArrayLiteral {
    init(arrayLiteral elements: CBOR...) {
        self = .array(elements)
    }
}

extension CBOR: CustomStringConvertible {
    var description: String {
        switch self {
        case .unsigned(let n): return String(n)
        case .negative(let n): return n == UInt64.max ? "-18446744073709551616" : "-\(n + 1)"
        case .bytes(let data): return "h'\(data.map { String(format: "%02x", $0) }.joined())'"
        case .text(let s): return "\"\(s)\""
        case .array(let items): return "[" + items.map { $0.description }.joined(separator: ", ") + "]"
        case .map(let map): return "{" + map.map { "\($0.0): \($0.1)" }.joined(separator: ", ") + "}"
        case .tagged(let tag, let item): return "\(tag)(\(item))"
        case .simple(let s):
            switch s {
            case .false: return "false"
            case .true: return "true"
            case .null: return "null"
            case .float(let d): return String(d)
            }
        }
    }
}

extension Data: CBOREncodable {
    var cbor: CBOR { .bytes(self) }
}

extension Bool: CBOREncodable {
    var cbor: CBOR { self ? .true : .false }

    init(cbor: CBOR) throws {
        switch cbor {
        case .simple(.true): self = true
        case .simple(.false): self = false
        default: throw CBORError.wrongType
        }
    }
}

extension String: CBOREncodable {
    var cbor: CBOR { .text(self) }
}

extension UInt64: CBOREncodable {
    var cbor: CBOR { .unsigned(self) }
}

extension UInt32: CBOREncodable {
    var cbor: CBOR { .unsigned(UInt64(self)) }
}

extension Int: CBOREncodable {
    var cbor: CBOR { CBOR(integerLiteral: self) }
}

// MARK: - Map

/// A CBOR map kept in deterministic order: keys sorted by their encoded bytes (as DCBOR does),
/// so a map built from a dictionary literal always encodes the same way.
struct Map: Equatable, Sequence, ExpressibleByDictionaryLiteral, CBOREncodable {
    private struct Entry: Equatable {
        let keyData: Data
        let key: CBOR
        var value: CBOR
    }
    private var entries: [Entry] = []

    init() {}

    init(dictionaryLiteral elements: (CBOREncodable, CBOREncodable)...) {
        for (k, v) in elements { insert(k, v) }
    }

    mutating func insert(_ key: CBOREncodable, _ value: CBOREncodable) {
        let keyData = key.cborData
        if let i = entries.firstIndex(where: { $0.keyData == keyData }) {
            entries[i].value = value.cbor
            return
        }
        let index = entries.firstIndex(where: { !$0.keyData.lexicographicallyPrecedes(keyData) }) ?? entries.count
        entries.insert(Entry(keyData: keyData, key: key.cbor, value: value.cbor), at: index)
    }

    @discardableResult
    mutating func remove(_ key: CBOREncodable) -> CBOR? {
        let keyData = key.cborData
        guard let i = entries.firstIndex(where: { $0.keyData == keyData }) else { return nil }
        return entries.remove(at: i).value
    }

    func get(_ key: CBOREncodable) -> CBOR? {
        let keyData = key.cborData
        return entries.first { $0.keyData == keyData }?.value
    }

    subscript(key: CBOR) -> CBOR? {
        get { get(key) }
        set {
            if let newValue = newValue { insert(key, newValue) } else { remove(key) }
        }
    }

    var count: Int { entries.count }

    func makeIterator() -> AnyIterator<(CBOR, CBOR)> {
        var iterator = entries.makeIterator()
        return AnyIterator { iterator.next().map { ($0.key, $0.value) } }
    }

    var cbor: CBOR { .map(self) }

    var cborData: Data {
        entries.reduce(cborHead(5, UInt64(entries.count))) { $0 + $1.keyData + $1.value.cborData }
    }
}

// MARK: - Decoding

private struct CBORReader {
    private let bytes: [UInt8]
    private var i = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    var atEnd: Bool { i == bytes.count }
    var remaining: Int { bytes.count - i }

    private mutating func byte() throws -> UInt8 {
        guard i < bytes.count else { throw CBORError.underrun }
        defer { i += 1 }
        return bytes[i]
    }

    private mutating func take(_ n: Int) throws -> [UInt8] {
        guard n >= 0, n <= bytes.count - i else { throw CBORError.underrun }
        defer { i += n }
        return Array(bytes[i..<i + n])
    }

    private mutating func uint(_ width: Int) throws -> UInt64 {
        try take(width).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    }

    /// The head's argument (1, 2, 4 or 8 following bytes, or the value itself).
    private mutating func argument(_ info: UInt8) throws -> UInt64 {
        switch info {
        case 0...23: return UInt64(info)
        case 24: return try uint(1)
        case 25: return try uint(2)
        case 26: return try uint(4)
        case 27: return try uint(8)
        default: throw CBORError.unsupported("indefinite length or reserved value (\(info))")
        }
    }

    private mutating func length(_ info: UInt8) throws -> Int {
        let n = try argument(info)
        guard n <= UInt64(bytes.count - i) || n <= 1 << 20 else { throw CBORError.underrun }
        return Int(n)
    }

    mutating func item(depth: Int) throws -> CBOR {
        guard depth < 64 else { throw CBORError.tooDeep }
        let head = try byte()
        let major = head >> 5
        let info = head & 0x1F
        switch major {
        case 0:
            return .unsigned(try argument(info))
        case 1:
            return .negative(try argument(info))
        case 2:
            return .bytes(Data(try take(length(info))))
        case 3:
            guard let s = String(bytes: try take(length(info)), encoding: .utf8) else { throw CBORError.invalidString }
            return .text(s)
        case 4:
            let n = try length(info)
            var items: [CBOR] = []
            for _ in 0..<n { items.append(try item(depth: depth + 1)) }
            return .array(items)
        case 5:
            let n = try length(info)
            var map = Map()
            for _ in 0..<n {
                let key = try item(depth: depth + 1)
                let value = try item(depth: depth + 1)
                map.insert(key, value)
            }
            return .map(map)
        case 6:
            let tag = try argument(info)
            return .tagged(Tag(tag), try item(depth: depth + 1))
        default:
            switch info {
            case 20: return .false
            case 21: return .true
            case 22: return .null
            case 25: return .simple(.float(Double(Self.half(UInt16(try uint(2))))))
            case 26: return .simple(.float(Double(Float(bitPattern: UInt32(try uint(4))))))
            case 27: return .simple(.float(Double(bitPattern: try uint(8))))
            default: throw CBORError.unsupported("simple value \(info)")
            }
        }
    }

    /// IEEE 754 half precision → Float.
    private static func half(_ h: UInt16) -> Float {
        let sign: Float = (h & 0x8000) != 0 ? -1 : 1
        let exponent = Int((h >> 10) & 0x1F)
        let fraction = Float(h & 0x3FF)
        switch exponent {
        case 0: return sign * fraction * powf(2, -24)
        case 31: return fraction == 0 ? sign * .infinity : .nan
        default: return sign * (1 + fraction / 1024) * powf(2, Float(exponent - 15))
        }
    }
}

// MARK: - CRC32 (as used by Bytewords and UR)

enum URCRC32 {
    private static let table: [UInt32] = (0...255).map { i -> UInt32 in
        (0..<8).reduce(UInt32(i)) { c, _ in (c & 1) == 0 ? (c >> 1) : (0xEDB8_8320 ^ (c >> 1)) }
    }

    static func checksum(_ data: Data) -> UInt32 {
        ~data.reduce(~UInt32(0)) { crc, byte in (crc >> 8) ^ table[Int((crc ^ UInt32(byte)) & 0xFF)] }
    }

    /// Big-endian bytes of the checksum.
    static func bytes(_ data: Data) -> Data {
        let c = checksum(data)
        return Data([UInt8(c >> 24), UInt8((c >> 16) & 0xFF), UInt8((c >> 8) & 0xFF), UInt8(c & 0xFF)])
    }
}

// MARK: - Bytewords (BCR-2020-012)

enum Bytewords {
    enum Style {
        /// Full words separated by spaces.
        case standard
        /// Full words separated by dashes.
        case uri
        /// First and last letter of each word, no separator (what URs use).
        case minimal
    }

    enum DecodingError: LocalizedError {
        case invalidWord
        case invalidChecksum

        var errorDescription: String? {
            switch self {
            case .invalidWord: return "Invalid Bytewords word."
            case .invalidChecksum: return "Invalid Bytewords checksum."
            }
        }
    }

    private static let packed = """
    ableacidalsoapexaquaarchatomauntawayaxisbackbaldbarnbeltbetabias\
    bluebodybragbrewbulbbuzzcalmcashcatschefcityclawcodecolacookcost\
    cruxcurlcuspcyandarkdatadaysdelidicedietdoordowndrawdropdrumdull\
    dutyeacheasyechoedgeepicevenexamexiteyesfactfairfernfigsfilmfish\
    fizzflapflewfluxfoxyfreefrogfuelfundgalagamegeargemsgiftgirlglow\
    goodgraygrimgurugushgyrohalfhanghardhawkheathelphighhillholyhope\
    hornhutsicedideaidleinchinkyintoirisironitemjadejazzjoinjoltjowl\
    judojugsjumpjunkjurykeepkenokeptkeyskickkilnkingkitekiwiknoblamb\
    lavalazyleaflegsliarlimplionlistlogoloudloveluaulucklungmainmany\
    mathmazememomenumeowmildmintmissmonknailnavyneednewsnextnoonnote\
    numbobeyoboeomitonyxopenovalowlspaidpartpeckplaypluspoempoolpose\
    puffpumapurrquadquizraceramprealredorichroadrockroofrubyruinruns\
    rustsafesagascarsetssilkskewslotsoapsolosongstubsurfswantacotask\
    taxitenttiedtimetinytoiltombtoystriptunatwinuglyundouniturgeuser\
    vastveryvetovialvibeviewvisavoidvowswallwandwarmwaspwavewaxywebs\
    whatwhenwhizwolfworkyankyawnyellyogayurtzapszerozestzinczonezoom
    """

    /// The 256 words, index = byte value.
    static let words: [String] = {
        let letters = Array(packed)
        return (0..<256).map { String(letters[$0 * 4..<$0 * 4 + 4]) }
    }()

    private static let minimalWords: [String] = words.map { String([$0.first!, $0.last!]) }
    private static let wordIndex: [String: UInt8] = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, UInt8($0)) })
    private static let minimalIndex: [String: UInt8] = Dictionary(uniqueKeysWithValues: minimalWords.enumerated().map { ($1, UInt8($0)) })

    /// `data` followed by its CRC32, as words.
    static func encode(_ data: Data, style: Style = .standard) -> String {
        let all = data + URCRC32.bytes(data)
        switch style {
        case .standard: return all.map { words[Int($0)] }.joined(separator: " ")
        case .uri: return all.map { words[Int($0)] }.joined(separator: "-")
        case .minimal: return all.map { minimalWords[Int($0)] }.joined()
        }
    }

    /// The data, after checking and removing its CRC32.
    static func decode(_ string: String, style: Style = .standard) throws -> Data {
        let lower = string.lowercased()
        let values: [UInt8]
        switch style {
        case .standard, .uri:
            let tokens = lower.split(separator: style == .standard ? " " : "-")
            values = try tokens.map { token in
                guard let v = wordIndex[String(token)] else { throw DecodingError.invalidWord }
                return v
            }
        case .minimal:
            let chars = Array(lower)
            guard chars.count % 2 == 0 else { throw DecodingError.invalidWord }
            values = try stride(from: 0, to: chars.count, by: 2).map { i in
                guard let v = minimalIndex[String(chars[i..<i + 2])] else { throw DecodingError.invalidWord }
                return v
            }
        }
        guard values.count > 4 else { throw DecodingError.invalidChecksum }
        let message = Data(values.dropLast(4))
        guard Data(values.suffix(4)) == URCRC32.bytes(message) else { throw DecodingError.invalidChecksum }
        return message
    }
}

// MARK: - UR (single part)

enum URError: LocalizedError {
    case invalidScheme
    case invalidType
    case invalidPath
    case multiPart
    case invalidPart
    case invalidChecksum

    var errorDescription: String? {
        switch self {
        case .invalidScheme: return "Not a UR (it must start with \"ur:\")."
        case .invalidType: return "Invalid UR type."
        case .invalidPath: return "Invalid UR."
        case .multiPart: return "This is one part of an animated (multi-part) UR."
        case .invalidPart: return "Invalid animated UR part."
        case .invalidChecksum: return "The animated UR's checksum doesn't match."
        }
    }
}

/// A Uniform Resource: a type and its CBOR, written `ur:<type>/<minimal bytewords>`.
struct UR: Equatable, CustomStringConvertible {
    let type: String
    let cbor: CBOR

    init(type: String, cbor: CBOR) throws {
        guard Self.isValidType(type) else { throw URError.invalidType }
        self.type = type
        self.cbor = cbor
    }

    init<T: CBOREncodable>(type: String, untaggedCBOR: T) throws {
        try self.init(type: type, cbor: untaggedCBOR.cbor)
    }

    /// Parses a single-part UR. Animated parts (`ur:<type>/<n>-<m>/…`) are refused.
    init(urString: String) throws {
        let lower = urString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lower.hasPrefix("ur:") else { throw URError.invalidScheme }
        let components = lower.dropFirst(3).split(separator: "/").map(String.init)
        guard components.count >= 2 else { throw URError.invalidPath }
        guard components.count == 2 else { throw URError.multiPart }
        guard Self.isValidType(components[0]) else { throw URError.invalidType }
        let body = try Bytewords.decode(components[1], style: .minimal)
        try self.init(type: components[0], cbor: CBOR(body))
    }

    /// `ur:<type>/<minimal bytewords of the CBOR>`.
    var string: String {
        "ur:\(type)/" + Bytewords.encode(cbor.cborData, style: .minimal)
    }

    /// Upper case: QR codes encode it in alphanumeric mode, which is much denser.
    var qrString: String { string.uppercased() }

    var qrData: Data { Data(qrString.utf8) }

    var description: String { string }

    /// Lower-case letters, digits and "-" only.
    static func isValidType(_ type: String) -> Bool {
        !type.isEmpty && type.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" }
    }
}
