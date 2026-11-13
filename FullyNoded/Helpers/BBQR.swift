//
//  BBQR.swift
//  FullyNoded
//
//  BBQr (https://bbqr.org): data too big for one QR split across several. Replaces the
//  bbqr-swift package (a Rust binary) with plain Swift + the system zlib.
//
//  Each part is an 8-character header and then a slice of the encoded payload:
//
//      B$ Z P 0C 03 <payload…>
//      │  │ │ │  └ part index, 2 base36 digits, from 0
//      │  │ │ └ total parts, 2 base36 digits (max 1295)
//      │  │ └ file type: P psbt, T transaction, J json, C cbor, U unicode text, B binary
//      │  └ encoding: H hex, 2 base32, Z zlib (raw deflate, 1 KB window) then base32
//      └ fixed prefix
//
//  Base32 is RFC 4648, uppercase, no padding; parts break on 8-char (5-byte) boundaries
//  so each decodes on its own (hex: 2 chars). The 1 KB window (wbits 10) is what small
//  devices such as Coldcard can decompress.
//

import Foundation
import zlib

enum BBQR {

    enum FileType: Character {
        case psbt = "P", transaction = "T", json = "J", cbor = "C", unicodeText = "U", binary = "B"
    }

    enum Encoding: Character {
        case hex = "H", base32 = "2", zlib = "Z"
    }

    enum BBQRError: Error, Equatable {
        case notBBQR
        case badHeader
        case mismatchedPart        // part from a different series (type/encoding/count)
        case badPayload
        case tooManyParts
        case compressionFailed
    }

    // MARK: - Split

    /// Splits `data` into BBQr part strings. Zlib falls back to plain base32 when
    /// compressing doesn't help (as the reference implementation does).
    /// - minParts: at least this many parts.
    /// - minVersion/maxVersion: QR versions the parts must fit (alphanumeric, ECC L).
    static func split(_ data: Data,
                      type: FileType,
                      encoding: Encoding = .zlib,
                      minParts: Int = 1,
                      minVersion: Int = 1,
                      maxVersion: Int = 40) throws -> [String] {
        var encoding = encoding
        var payload: String
        switch encoding {
        case .hex:
            payload = data.map { String(format: "%02X", $0) }.joined()
        case .base32:
            payload = base32Encode(data)
        case .zlib:
            let compressed = try deflateRaw(data)
            if compressed.count >= data.count {
                encoding = .base32
                payload = base32Encode(data)
            } else {
                payload = base32Encode(compressed)
            }
        }

        let modulus = encoding == .hex ? 2 : 8
        let count = try partCount(payloadLength: payload.count, modulus: modulus,
                                  minParts: max(1, minParts), minVersion: minVersion, maxVersion: maxVersion)

        // Even slices, each a whole number of encoding units.
        let perPart = roundUp((payload.count + count - 1) / count, to: modulus)
        var chunks: [Substring] = []
        var start = payload.startIndex
        while start < payload.endIndex {
            let end = payload.index(start, offsetBy: perPart, limitedBy: payload.endIndex) ?? payload.endIndex
            chunks.append(payload[start..<end])
            start = end
        }
        if chunks.isEmpty { chunks = [""] }

        let total = chunks.count
        guard total <= maxParts else { throw BBQRError.tooManyParts }
        return chunks.enumerated().map { index, chunk in
            "B$\(encoding.rawValue)\(type.rawValue)\(base36(total))\(base36(index))\(chunk)"
        }
    }

    /// Fewest parts that fit, then the smallest QR version for that count (reference
    /// behaviour). If even version `minVersion` needs fewer than `minParts`, use `minParts`.
    private static func partCount(payloadLength: Int, modulus: Int, minParts: Int,
                                  minVersion: Int, maxVersion: Int) throws -> Int {
        let low = max(1, min(minVersion, 40)), high = max(low, min(maxVersion, 40))
        var best: (count: Int, version: Int)?
        var smallestCount = Int.max
        for version in low...high {
            let base = alphanumericCapacity[version - 1] - headerLength
            let capacity = base - base % modulus
            guard capacity > 0 else { continue }
            let count = max(1, (payloadLength + capacity - 1) / capacity)
            smallestCount = min(smallestCount, count)
            guard count >= minParts, count <= maxParts else { continue }
            if best == nil || count < best!.count { best = (count, version) }
        }
        if let best = best { return best.count }
        // Data is small enough that every version needs fewer than minParts.
        if smallestCount < minParts { return min(minParts, max(1, payloadLength / modulus)) }
        throw BBQRError.tooManyParts
    }

    // MARK: - Join

    /// Header of one part, or nil if it isn't BBQr.
    struct Header: Equatable {
        let encoding: Encoding
        let type: FileType
        let total: Int
        let index: Int

        init?(_ part: String) {
            let chars = Array(part.prefix(headerLength))
            guard chars.count == headerLength, chars[0] == "B", chars[1] == "$",
                  let encoding = Encoding(rawValue: chars[2]),
                  let type = FileType(rawValue: chars[3]),
                  let total = Int(String(chars[4...5]), radix: 36),
                  let index = Int(String(chars[6...7]), radix: 36),
                  total > 0, index < total else { return nil }
            self.encoding = encoding
            self.type = type
            self.total = total
            self.index = index
        }
    }

    enum JoinState {
        case inProgress(received: Int, total: Int)
        case complete(type: FileType, data: Data)
    }

    /// Collects parts in any order (duplicates ignored) and decodes once all are in.
    final class Joiner {
        private var header: Header?
        private var payloads: [Int: Substring] = [:]

        var received: Int { payloads.count }
        var total: Int { header?.total ?? 0 }

        func add(_ part: String) throws -> JoinState {
            let part = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let header = Header(part) else { throw BBQRError.notBBQR }

            if let existing = self.header {
                guard existing.encoding == header.encoding, existing.type == header.type,
                      existing.total == header.total else { throw BBQRError.mismatchedPart }
            } else {
                self.header = header
            }
            payloads[header.index] = part.dropFirst(headerLength)

            guard payloads.count == header.total else {
                return .inProgress(received: payloads.count, total: header.total)
            }
            let joined = (0..<header.total).compactMap { payloads[$0] }.joined()
            return .complete(type: header.type, data: try decode(joined, encoding: header.encoding))
        }

        func reset() {
            header = nil
            payloads.removeAll()
        }
    }

    /// Joins a full set of parts in one go.
    static func join(_ parts: [String]) throws -> (type: FileType, data: Data) {
        let joiner = Joiner()
        for part in parts {
            if case .complete(let type, let data) = try joiner.add(part) { return (type, data) }
        }
        throw BBQRError.badPayload
    }

    static func isBBQR(_ string: String) -> Bool { Header(string) != nil }

    private static func decode(_ payload: String, encoding: Encoding) throws -> Data {
        switch encoding {
        case .hex:
            guard let data = Data(hexString: payload.lowercased()) else { throw BBQRError.badPayload }
            return data
        case .base32:
            guard let data = base32Decode(payload) else { throw BBQRError.badPayload }
            return data
        case .zlib:
            guard let compressed = base32Decode(payload) else { throw BBQRError.badPayload }
            return try inflateRaw(compressed)
        }
    }

    // MARK: - Constants

    private static let headerLength = 8
    private static let maxParts = 1295   // "ZZ" in base36

    /// QR alphanumeric capacity at error correction L, versions 1…40.
    private static let alphanumericCapacity = [
        25, 47, 77, 114, 154, 195, 224, 279, 335, 395, 468, 535, 619, 667, 758, 854, 938, 1046, 1153, 1249,
        1352, 1460, 1588, 1704, 1853, 1990, 2132, 2223, 2369, 2520, 2677, 2840, 3009, 3183, 3351, 3537, 3729, 3927, 4087, 4296
    ]

    private static func base36(_ n: Int) -> String {
        let digits = String(n, radix: 36).uppercased()
        return digits.count < 2 ? "0" + digits : digits
    }

    private static func roundUp(_ n: Int, to m: Int) -> Int { (n + m - 1) / m * m }

    // MARK: - Base32 (RFC 4648, no padding)

    private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)

    static func base32Encode(_ data: Data) -> String {
        var out = [UInt8]()
        out.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer = 0, bits = 0
        for byte in data {
            buffer = (buffer << 8) | Int(byte)
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(base32Alphabet[(buffer >> bits) & 31])
            }
            buffer &= (1 << bits) - 1
        }
        if bits > 0 { out.append(base32Alphabet[(buffer << (5 - bits)) & 31]) }
        return String(decoding: out, as: UTF8.self)
    }

    static func base32Decode(_ string: String) -> Data? {
        var lookup = [Int](repeating: -1, count: 128)
        for (i, c) in base32Alphabet.enumerated() { lookup[Int(c)] = i }
        var out = Data()
        out.reserveCapacity(string.utf8.count * 5 / 8)
        var buffer = 0, bits = 0
        for c in string.utf8 where c != UInt8(ascii: "=") {
            guard c < 128 else { return nil }
            let v = lookup[Int(c)]
            guard v >= 0 else { return nil }
            buffer = (buffer << 5) | v
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> bits) & 0xFF))
            }
            buffer &= (1 << bits) - 1
        }
        return out
    }

    // MARK: - Raw deflate, 1 KB window

    static func deflateRaw(_ data: Data) throws -> Data {
        var stream = z_stream()
        guard deflateInit2_(&stream, Z_BEST_COMPRESSION, Z_DEFLATED, -10, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw BBQRError.compressionFailed
        }
        defer { deflateEnd(&stream) }

        var input = [UInt8](data)
        var output = [UInt8](repeating: 0, count: Int(deflateBound(&stream, uLong(input.count))) + 16)
        let status: Int32 = input.withUnsafeMutableBufferPointer { inBuf in
            output.withUnsafeMutableBufferPointer { outBuf in
                stream.next_in = inBuf.baseAddress
                stream.avail_in = uInt(inBuf.count)
                stream.next_out = outBuf.baseAddress
                stream.avail_out = uInt(outBuf.count)
                return deflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else { throw BBQRError.compressionFailed }
        return Data(output.prefix(Int(stream.total_out)))
    }

    static func inflateRaw(_ data: Data) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -15, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
            throw BBQRError.compressionFailed
        }
        defer { inflateEnd(&stream) }

        var input = [UInt8](data)
        var result = Data()
        var chunk = [UInt8](repeating: 0, count: 64 * 1024)
        var status: Int32 = Z_OK
        input.withUnsafeMutableBufferPointer { inBuf in
            stream.next_in = inBuf.baseAddress
            stream.avail_in = uInt(inBuf.count)
            repeat {
                status = chunk.withUnsafeMutableBufferPointer { outBuf in
                    stream.next_out = outBuf.baseAddress
                    stream.avail_out = uInt(outBuf.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let produced = chunk.count - Int(stream.avail_out)
                result.append(contentsOf: chunk.prefix(produced))
            } while status == Z_OK && result.count < 64 * 1024 * 1024
        }
        guard status == Z_STREAM_END else { throw BBQRError.badPayload }
        return result
    }
}
