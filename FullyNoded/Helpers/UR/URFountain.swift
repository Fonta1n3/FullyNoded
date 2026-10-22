//
//  URFountain.swift
//  FullyNoded
//
//  Animated (multi-part) URs: the BCR-2020-005 fountain code. A message too big for one QR is
//  split into equal fragments; parts 1...n are the fragments themselves and every part after
//  that XORs a pseudo-random subset of them, so a scanner can finish from whichever parts it
//  happens to catch. The fragment choice for each part is derived from its sequence number and
//  the message checksum (Xoshiro256** seeded with SHA-256), so encoder and decoder agree
//  without sending it. Matches URKit part for part.
//

import Foundation
import CryptoKit

// MARK: - Fountain part

struct FountainPart: Equatable {
    let seqNum: UInt32
    let seqLen: Int
    let messageLen: Int
    let checksum: UInt32
    let data: Data

    /// `[seqNum, seqLen, messageLen, checksum, data]`.
    var cborData: Data {
        CBOR.array([
            .unsigned(UInt64(seqNum)),
            .unsigned(UInt64(seqLen)),
            .unsigned(UInt64(messageLen)),
            .unsigned(UInt64(checksum)),
            .bytes(data)
        ]).cborData
    }

    init(seqNum: UInt32, seqLen: Int, messageLen: Int, checksum: UInt32, data: Data) {
        self.seqNum = seqNum
        self.seqLen = seqLen
        self.messageLen = messageLen
        self.checksum = checksum
        self.data = data
    }

    init(cborData: Data) throws {
        guard case let .array(a) = try CBOR(cborData), a.count == 5,
              case let .unsigned(seqNum) = a[0], seqNum <= UInt64(UInt32.max),
              case let .unsigned(seqLen) = a[1],
              case let .unsigned(messageLen) = a[2],
              case let .unsigned(checksum) = a[3], checksum <= UInt64(UInt32.max),
              case let .bytes(data) = a[4],
              // A scanned header can claim anything; keep the sizes sane before allocating.
              seqLen >= 1, messageLen >= 1, messageLen <= URFountain.maxMessageLen,
              !data.isEmpty, seqLen <= messageLen,
              UInt64(data.count) * seqLen >= messageLen,
              UInt64(data.count) * (seqLen - 1) < messageLen
        else { throw URError.invalidPart }
        self.init(seqNum: UInt32(seqNum), seqLen: Int(seqLen), messageLen: Int(messageLen), checksum: UInt32(checksum), data: data)
    }
}

enum URFountain {
    /// Larger than anything Fully Noded shows or expects to scan (a PSBT is far smaller).
    static let maxMessageLen: UInt64 = 10_000_000

    /// The fragment length: the smallest number of fragments whose length fits `maxFragmentLen`.
    static func fragmentLength(messageLen: Int, minFragmentLen: Int, maxFragmentLen: Int) -> Int {
        let maxFragmentCount = max(1, messageLen / minFragmentLen)
        var fragmentLen = messageLen
        for fragmentCount in 1...maxFragmentCount {
            fragmentLen = Int(ceil(Double(messageLen) / Double(fragmentCount)))
            if fragmentLen <= maxFragmentLen { break }
        }
        return fragmentLen
    }

    /// `message` in `fragmentLen` pieces, the last zero-padded.
    static func partition(_ message: Data, fragmentLen: Int) -> [Data] {
        stride(from: 0, to: message.count, by: fragmentLen).map { start in
            var fragment = Data(message[message.startIndex + start ..< message.startIndex + min(start + fragmentLen, message.count)])
            if fragment.count < fragmentLen { fragment.append(Data(count: fragmentLen - fragment.count)) }
            return fragment
        }
    }

    static func xor(_ a: Data, _ b: Data) -> Data {
        Data(zip(a, b).map { $0 ^ $1 })
    }
}

// MARK: - Fragment choice

/// xoshiro256** 1.0 (Blackman & Vigna, public domain).
private struct Xoshiro256 {
    private var s: [UInt64]

    init(seed: Data) {
        let digest = Array(SHA256.hash(data: seed))
        s = (0..<4).map { i in digest[i * 8 ..< i * 8 + 8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) } }
    }

    mutating func next() -> UInt64 {
        func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 { (x << k) | (x >> (64 - k)) }
        let result = rotl(s[1] &* 5, 7) &* 9
        let t = s[1] << 17
        s[2] ^= s[0]
        s[3] ^= s[1]
        s[1] ^= s[2]
        s[0] ^= s[3]
        s[2] ^= t
        s[3] = rotl(s[3], 45)
        return result
    }

    mutating func nextDouble() -> Double {
        Double(next()) / (Double(UInt64.max) + 1)
    }

    mutating func nextInt(below count: Int) -> Int {
        Int(nextDouble() * Double(count))
    }
}

/// Walker's alias method, built exactly as the reference implementation (Vose's ordering).
private struct AliasSampler {
    private let probs: [Double]
    private let aliases: [Int]

    init(_ weights: [Double]) {
        let n = weights.count
        let sum = weights.reduce(0, +)
        var p = weights.map { $0 * Double(n) / sum }
        var small: [Int] = []
        var large: [Int] = []
        for i in (0..<n).reversed() {
            if p[i] < 1 { small.append(i) } else { large.append(i) }
        }
        var probs = [Double](repeating: 0, count: n)
        var aliases = [Int](repeating: 0, count: n)
        while !small.isEmpty && !large.isEmpty {
            let a = small.removeLast()
            let g = large.removeLast()
            probs[a] = p[a]
            aliases[a] = g
            p[g] += p[a] - 1
            if p[g] < 1 { small.append(g) } else { large.append(g) }
        }
        while let i = large.popLast() { probs[i] = 1 }
        while let i = small.popLast() { probs[i] = 1 }
        self.probs = probs
        self.aliases = aliases
    }

    func next(_ rng: inout Xoshiro256) -> Int {
        let r1 = rng.nextDouble()
        let r2 = rng.nextDouble()
        let i = Int(Double(probs.count) * r1)
        return r2 < probs[i] ? i : aliases[i]
    }
}

/// Which fragments part `seqNum` carries: fragment `seqNum - 1` for the first `seqLen` parts,
/// then a random subset whose size d is drawn with probability ∝ 1/d.
private struct FragmentChooser {
    let seqLen: Int
    let checksum: UInt32
    private let degrees: AliasSampler

    init(seqLen: Int, checksum: UInt32) {
        self.seqLen = seqLen
        self.checksum = checksum
        degrees = AliasSampler((1...seqLen).map { 1 / Double($0) })
    }

    func fragments(at seqNum: UInt32) -> Set<Int> {
        if seqNum <= seqLen { return [Int(seqNum) - 1] }
        func bigEndian(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        var rng = Xoshiro256(seed: Data(bigEndian(seqNum) + bigEndian(checksum)))
        let degree = degrees.next(&rng) + 1
        var remaining = Array(0..<seqLen)
        var chosen = Set<Int>()
        while chosen.count < degree {
            chosen.insert(remaining.remove(at: rng.nextInt(below: remaining.count)))
        }
        return chosen
    }
}

// MARK: - Encoder

/// Produces the parts of a UR: just `ur.string` if it fits in one fragment, otherwise an
/// endless sequence of `ur:<type>/<seqNum>-<seqLen>/<bytewords>` parts.
final class UREncoder {
    private let ur: UR
    private let fragments: [Data]
    private let chooser: FragmentChooser
    let messageLen: Int
    let fragmentLen: Int
    let checksum: UInt32
    private(set) var seqNum: UInt32 = 0

    var seqLen: Int { fragments.count }
    var isSinglePart: Bool { seqLen == 1 }
    /// Every fragment has been sent once (parts after this are the mixed ones).
    var isComplete: Bool { seqNum >= seqLen }

    init(_ ur: UR, maxFragmentLen: Int, minFragmentLen: Int = 10) {
        self.ur = ur
        let message = ur.cbor.cborData
        messageLen = message.count
        checksum = URCRC32.checksum(message)
        fragmentLen = URFountain.fragmentLength(messageLen: message.count, minFragmentLen: minFragmentLen, maxFragmentLen: max(maxFragmentLen, minFragmentLen))
        fragments = URFountain.partition(message, fragmentLen: fragmentLen)
        chooser = FragmentChooser(seqLen: fragments.count, checksum: checksum)
    }

    func nextPart() -> String {
        seqNum &+= 1
        if isSinglePart { return ur.string }
        let indexes = chooser.fragments(at: seqNum)
        let data = indexes.count == 1
            ? fragments[indexes.first!]
            : indexes.reduce(Data(count: fragmentLen)) { URFountain.xor($0, fragments[$1]) }
        let part = FountainPart(seqNum: seqNum, seqLen: seqLen, messageLen: messageLen, checksum: checksum, data: data)
        return "ur:\(ur.type)/\(seqNum)-\(seqLen)/" + Bytewords.encode(part.cborData, style: .minimal)
    }
}

// MARK: - Decoder

/// Collects scanned parts (in any order, with repeats and misses) until the UR is complete.
/// A single-part UR completes it at once.
///
/// Each part is an equation "XOR of these fragments = data". Rather than peeling parts one
/// fragment at a time, the decoder keeps them in row-echelon form over GF(2), so it finishes
/// the moment the parts scanned so far determine every fragment, and knows exactly how close
/// it is.
final class URDecoder {
    private(set) var result: Result<UR, Error>?
    private(set) var expectedType: String?
    /// Parts accepted so far (repeats included).
    private(set) var processedPartsCount = 0

    private var first: FountainPart?
    private var chooser: FragmentChooser?
    /// Independent equations, keyed by their lowest fragment index (the pivot).
    private var rows: [Int: (fragments: Set<Int>, data: Data)] = [:]

    var expectedFragmentCount: Int? { first?.seqLen }

    /// Fragments' worth of information received, out of all of them.
    var estimatedPercentComplete: Double {
        if result != nil { return 1 }
        guard let n = expectedFragmentCount else { return 0 }
        return min(0.99, Double(rows.count) / Double(n))
    }

    init() {}

    /// False if the part was rejected (malformed, from a different UR, or after completion).
    @discardableResult
    func receivePart(_ string: String) -> Bool {
        guard result == nil else { return false }
        let lower = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lower.hasPrefix("ur:") else { return false }
        let components = lower.dropFirst(3).split(separator: "/").map(String.init)
        guard components.count == 2 || components.count == 3,
              UR.isValidType(components[0]),
              expectedType == nil || expectedType == components[0]
        else { return false }

        if components.count == 2 {
            guard let ur = try? UR(urString: lower) else { return false }
            expectedType = ur.type
            result = .success(ur)
            return true
        }

        let seq = components[1].split(separator: "-", omittingEmptySubsequences: false)
        guard seq.count == 2, let seqNum = UInt32(seq[0]), let seqLen = Int(seq[1]), seqNum >= 1, seqLen >= 1,
              let body = try? Bytewords.decode(components[2], style: .minimal),
              let part = try? FountainPart(cborData: body),
              part.seqNum == seqNum, part.seqLen == seqLen
        else { return false }

        if let first = first {
            guard part.seqLen == first.seqLen, part.messageLen == first.messageLen,
                  part.checksum == first.checksum, part.data.count == first.data.count
            else { return false }
        } else {
            first = part
            chooser = FragmentChooser(seqLen: part.seqLen, checksum: part.checksum)
        }
        expectedType = components[0]
        processedPartsCount += 1

        add(chooser!.fragments(at: part.seqNum), part.data)
        if rows.count == part.seqLen {
            result = solve(part).flatMap { message in
                Result { try UR(type: components[0], cbor: CBOR(message)) }
            }
        }
        return true
    }

    /// Reduces the equation by the rows already held; keeps it if anything new is left.
    private func add(_ fragments: Set<Int>, _ data: Data) {
        var fragments = fragments
        var data = data
        // Each step clears the lowest index and only introduces higher ones, so this ends.
        while let pivot = fragments.min() {
            guard let row = rows[pivot] else {
                rows[pivot] = (fragments, data)
                return
            }
            fragments.formSymmetricDifference(row.fragments)
            data = URFountain.xor(data, row.data)
        }
    }

    /// Back-substitutes from the highest pivot down, then checks the joined message.
    private func solve(_ part: FountainPart) -> Result<Data, Error> {
        var solved = [Data?](repeating: nil, count: part.seqLen)
        for pivot in (0..<part.seqLen).reversed() {
            guard let row = rows[pivot] else { return .failure(URError.invalidPart) }
            solved[pivot] = row.fragments.reduce(row.data) { data, i in
                i == pivot ? data : URFountain.xor(data, solved[i]!)
            }
        }
        let message = Data(solved.flatMap { $0! }.prefix(part.messageLen))
        guard URCRC32.checksum(message) == part.checksum else { return .failure(URError.invalidChecksum) }
        return .success(message)
    }
}
