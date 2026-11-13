//
//  NostrConnect.swift
//  Shared by Fully Noded and Fully Noded Server (keep both copies identical).
//
//  Nostr Connect: Fully Noded talks to its node's RPC through a nostr relay instead of Tor.
//
//  • Each side has a secp256k1 key. Fully Noded Server's bridge key is long-lived; every paired
//    Fully Noded device gets its own client key, handed over once in the pairing link.
//  • Requests and responses are NIP-01 events of an ephemeral kind (relays don't store them),
//    signed with BIP340 and addressed with a "p" tag. Their content is NIP-44 v2 encrypted, so a
//    relay sees who talks to whom and when, but nothing of what is said.
//  • A JSON-RPC body is DEFLATE-compressed (when that helps) and travels base64-encoded in
//    numbered frames of ~24 KB, so each event fits the 64 KB limit of many public relays.
//  • Delivery: the bridge acks a complete request; with no ack or answer the device sends it
//    again. Either side asks for missing frames of a stalled message, which the sender keeps for
//    a while. Duplicates are ignored, and a repeated request gets the stored answer.
//
//  Pairing link:
//    nostr+fullynoded://<bridge pubkey>?relay=<ws(s) url>[&relay=…]&secret=<client privkey>
//                                      [&label=<name>][&chain=<main|test|testnet4|signet|regtest>]
//

import Foundation
import CryptoKit
import Compression
import P256K

// MARK: - Hex

enum NostrHex {
    static func encode<D: Sequence>(_ bytes: D) -> String where D.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func decode(_ hex: String) -> Data? {
        let chars = Array(hex.lowercased().utf8)
        guard chars.count % 2 == 0 else { return nil }
        var out = Data(capacity: chars.count / 2)
        var i = 0
        while i < chars.count {
            guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
            out.append(hi << 4 | lo)
            i += 2
        }
        return out
    }

    private static func nibble(_ c: UInt8) -> UInt8? {
        switch c {
        case 48...57: return c - 48
        case 97...102: return c - 87
        default: return nil
        }
    }
}

// MARK: - Keys

/// A nostr identity: 32-byte secret and its x-only public key (hex, as nostr writes it).
struct NostrKeys {
    let secret: Data
    let publicKey: String

    init?(secret: Data) {
        guard secret.count == 32,
              let key = try? P256K.Schnorr.PrivateKey(dataRepresentation: secret) else { return nil }
        self.secret = secret
        self.publicKey = NostrHex.encode(key.xonly.bytes)
    }

    init?(secretHex: String) {
        guard let data = NostrHex.decode(secretHex) else { return nil }
        self.init(secret: data)
    }

    /// A fresh random key.
    static func generate() -> NostrKeys? {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, 32, &bytes) == errSecSuccess else { return nil }
        return NostrKeys(secret: Data(bytes))
    }

    var secretHex: String { NostrHex.encode(secret) }
}

// MARK: - NIP-44 v2

enum NIP44 {
    enum Failure: Error, LocalizedError {
        case invalidKey, invalidPayload, invalidMAC, invalidPadding, messageSize

        var errorDescription: String? {
            switch self {
            case .invalidKey: return "Invalid nostr key."
            case .invalidPayload: return "Invalid encrypted payload."
            case .invalidMAC: return "Encrypted payload failed authentication."
            case .invalidPadding: return "Invalid padding in encrypted payload."
            case .messageSize: return "Message must be 1 to 65535 bytes."
            }
        }
    }

    /// HKDF-extract(salt: "nip44-v2", IKM: x of secret·Pub).
    static func conversationKey(secret: Data, publicKey: String) throws -> Data {
        guard let x = NostrHex.decode(publicKey), x.count == 32,
              let pub = try? P256K.KeyAgreement.PublicKey(dataRepresentation: Data([0x02]) + x, format: .compressed),
              let priv = try? P256K.KeyAgreement.PrivateKey(dataRepresentation: secret) else {
            throw Failure.invalidKey
        }
        let shared = priv.sharedSecretFromKeyAgreement(with: pub, format: .compressed)
        let sharedX = shared.withUnsafeBytes { Data($0) }.dropFirst()
        let prk = HMAC<CryptoKit.SHA256>.authenticationCode(for: sharedX, using: SymmetricKey(data: Data("nip44-v2".utf8)))
        return Data(prk)
    }

    /// HKDF-expand(PRK: conversation key, info: nonce, L: 76) → ChaCha key, ChaCha nonce, HMAC key.
    static func messageKeys(conversationKey: Data, nonce: Data) -> (chachaKey: Data, chachaNonce: Data, hmacKey: Data) {
        let key = SymmetricKey(data: conversationKey)
        var okm = Data()
        var previous = Data()
        var counter: UInt8 = 1
        while okm.count < 76 {
            previous = Data(HMAC<CryptoKit.SHA256>.authenticationCode(for: previous + nonce + Data([counter]), using: key))
            okm += previous
            counter += 1
        }
        return (okm.subdata(in: 0..<32), okm.subdata(in: 32..<44), okm.subdata(in: 44..<76))
    }

    static func paddedLength(_ length: Int) -> Int {
        guard length > 32 else { return 32 }
        var nextPower = 1
        while nextPower < length { nextPower <<= 1 }
        let chunk = nextPower <= 256 ? 32 : nextPower / 8
        return chunk * ((length - 1) / chunk + 1)
    }

    static func encrypt(_ plaintext: Data, conversationKey: Data, nonce fixedNonce: Data? = nil) throws -> String {
        guard (1...65535).contains(plaintext.count) else { throw Failure.messageSize }
        let nonce: Data
        if let fixedNonce = fixedNonce {
            nonce = fixedNonce
        } else {
            var bytes = [UInt8](repeating: 0, count: 32)
            guard SecRandomCopyBytes(kSecRandomDefault, 32, &bytes) == errSecSuccess else { throw Failure.invalidKey }
            nonce = Data(bytes)
        }
        let keys = messageKeys(conversationKey: conversationKey, nonce: nonce)
        var padded = Data([UInt8(plaintext.count >> 8), UInt8(plaintext.count & 0xFF)]) + plaintext
        padded += Data(count: paddedLength(plaintext.count) - plaintext.count)
        let ciphertext = ChaCha20.xor(padded, key: keys.chachaKey, nonce: keys.chachaNonce)
        let mac = HMAC<CryptoKit.SHA256>.authenticationCode(for: nonce + ciphertext, using: SymmetricKey(data: keys.hmacKey))
        return (Data([0x02]) + nonce + ciphertext + Data(mac)).base64EncodedString()
    }

    static func decrypt(_ payload: String, conversationKey: Data) throws -> Data {
        guard !payload.hasPrefix("#"), let raw = Data(base64Encoded: payload),
              raw.count >= 99, raw.count <= 65603, raw.first == 0x02 else { throw Failure.invalidPayload }
        let nonce = raw.subdata(in: 1..<33)
        let ciphertext = raw.subdata(in: 33..<(raw.count - 32))
        let mac = raw.subdata(in: (raw.count - 32)..<raw.count)
        let keys = messageKeys(conversationKey: conversationKey, nonce: nonce)
        guard HMAC<CryptoKit.SHA256>.isValidAuthenticationCode(mac, authenticating: nonce + ciphertext, using: SymmetricKey(data: keys.hmacKey)) else {
            throw Failure.invalidMAC
        }
        let padded = ChaCha20.xor(ciphertext, key: keys.chachaKey, nonce: keys.chachaNonce)
        let length = Int(padded[padded.startIndex]) << 8 | Int(padded[padded.startIndex + 1])
        guard length > 0, padded.count == 2 + paddedLength(length) else { throw Failure.invalidPadding }
        return padded.subdata(in: (padded.startIndex + 2)..<(padded.startIndex + 2 + length))
    }
}

/// ChaCha20 (RFC 8439) keystream XOR, block counter starting at 0. NIP-44 needs it without
/// Poly1305, which CryptoKit doesn't offer.
enum ChaCha20 {
    static func xor(_ input: Data, key: Data, nonce: Data) -> Data {
        let k = key.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }.map { UInt32(littleEndian: $0) }
        let n = nonce.withUnsafeBytes { Array($0.bindMemory(to: UInt32.self)) }.map { UInt32(littleEndian: $0) }
        var output = [UInt8](input)
        var counter: UInt32 = 0
        var offset = 0
        while offset < output.count {
            let block = self.block(key: k, counter: counter, nonce: n)
            for i in 0..<min(64, output.count - offset) { output[offset + i] ^= block[i] }
            offset += 64
            counter &+= 1
        }
        return Data(output)
    }

    private static func block(key: [UInt32], counter: UInt32, nonce: [UInt32]) -> [UInt8] {
        let initial: [UInt32] = [0x61707865, 0x3320646e, 0x79622d32, 0x6b206574] + key + [counter] + nonce
        var s = initial
        func quarter(_ a: Int, _ b: Int, _ c: Int, _ d: Int) {
            s[a] &+= s[b]; s[d] ^= s[a]; s[d] = (s[d] << 16) | (s[d] >> 16)
            s[c] &+= s[d]; s[b] ^= s[c]; s[b] = (s[b] << 12) | (s[b] >> 20)
            s[a] &+= s[b]; s[d] ^= s[a]; s[d] = (s[d] << 8) | (s[d] >> 24)
            s[c] &+= s[d]; s[b] ^= s[c]; s[b] = (s[b] << 7) | (s[b] >> 25)
        }
        for _ in 0..<10 {
            quarter(0, 4, 8, 12); quarter(1, 5, 9, 13); quarter(2, 6, 10, 14); quarter(3, 7, 11, 15)
            quarter(0, 5, 10, 15); quarter(1, 6, 11, 12); quarter(2, 7, 8, 13); quarter(3, 4, 9, 14)
        }
        var out = [UInt8]()
        out.reserveCapacity(64)
        for i in 0..<16 {
            let v = s[i] &+ initial[i]
            out += [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)]
        }
        return out
    }
}

// MARK: - Events (NIP-01)

struct NostrEvent: Codable, Equatable {
    var id: String
    var pubkey: String
    var created_at: Int
    var kind: Int
    var tags: [[String]]
    var content: String
    var sig: String

    /// Ephemeral kind for Fully Noded RPC traffic (relays forward it and don't store it).
    static let rpcKind = 28_388

    /// sha256 of [0, pubkey, created_at, kind, tags, content], serialized as NIP-01 requires.
    static func computeID(pubkey: String, createdAt: Int, kind: Int, tags: [[String]], content: String) -> String? {
        let array: [Any] = [0, pubkey, createdAt, kind, tags, content]
        guard let data = try? JSONSerialization.data(withJSONObject: array, options: [.withoutEscapingSlashes]) else { return nil }
        return NostrHex.encode(CryptoKit.SHA256.hash(data: data))
    }

    /// A signed event from `keys`.
    static func make(keys: NostrKeys, kind: Int, tags: [[String]], content: String, createdAt: Int = Int(Date().timeIntervalSince1970)) -> NostrEvent? {
        guard let id = computeID(pubkey: keys.publicKey, createdAt: createdAt, kind: kind, tags: tags, content: content),
              var message = NostrHex.decode(id).map(Array.init),
              let priv = try? P256K.Schnorr.PrivateKey(dataRepresentation: keys.secret) else { return nil }
        var aux = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, 32, &aux) == errSecSuccess,
              let sig = try? aux.withUnsafeMutableBytes({ try priv.signature(message: &message, auxiliaryRand: $0.baseAddress, strict: true) }) else { return nil }
        return NostrEvent(id: id, pubkey: keys.publicKey, created_at: createdAt, kind: kind, tags: tags,
                          content: content, sig: NostrHex.encode(sig.dataRepresentation))
    }

    /// The id matches the content and the signature is the author's.
    var isValid: Bool {
        guard id == Self.computeID(pubkey: pubkey, createdAt: created_at, kind: kind, tags: tags, content: content),
              let pub = NostrHex.decode(pubkey), pub.count == 32,
              let sigData = NostrHex.decode(sig), sigData.count == 64,
              var message = NostrHex.decode(id).map(Array.init),
              let signature = try? P256K.Schnorr.SchnorrSignature(dataRepresentation: sigData) else { return false }
        return P256K.Schnorr.XonlyKey(dataRepresentation: pub).isValid(signature, for: &message)
    }

    /// First value of the "p" tag.
    var recipient: String? { tags.first { $0.first == "p" && $0.count > 1 }?[1] }

    var jsonObject: [String: Any] {
        ["id": id, "pubkey": pubkey, "created_at": created_at, "kind": kind, "tags": tags, "content": content, "sig": sig]
    }

    init(id: String, pubkey: String, created_at: Int, kind: Int, tags: [[String]], content: String, sig: String) {
        self.id = id; self.pubkey = pubkey; self.created_at = created_at; self.kind = kind
        self.tags = tags; self.content = content; self.sig = sig
    }

    init?(json: Any) {
        guard let d = json as? [String: Any],
              let id = d["id"] as? String, let pubkey = d["pubkey"] as? String,
              let createdAt = (d["created_at"] as? NSNumber)?.intValue, let kind = (d["kind"] as? NSNumber)?.intValue,
              let tags = d["tags"] as? [[String]], let content = d["content"] as? String,
              let sig = d["sig"] as? String else { return nil }
        self.init(id: id, pubkey: pubkey, created_at: createdAt, kind: kind, tags: tags, content: content, sig: sig)
    }
}

// MARK: - Pairing link

struct NostrConnectURI: Equatable {
    static let scheme = "nostr+fullynoded"

    let bridgePubkey: String
    let relays: [String]
    let clientSecret: String
    let label: String?
    let chain: String?
    /// SHA-256 (hex) of this Mac's relay's self-signed TLS certificate, pinned for its wss:// relays.
    let certSHA256: String?

    var string: String {
        var c = URLComponents()
        c.scheme = Self.scheme
        c.host = bridgePubkey
        var items = relays.map { URLQueryItem(name: "relay", value: $0) }
        items.append(URLQueryItem(name: "secret", value: clientSecret))
        if let label = label, !label.isEmpty { items.append(URLQueryItem(name: "label", value: label)) }
        if let chain = chain { items.append(URLQueryItem(name: "chain", value: chain)) }
        if let certSHA256 = certSHA256 { items.append(URLQueryItem(name: "cert", value: certSHA256)) }
        c.queryItems = items
        // "+" in values would read back as a space; relay URLs and labels may contain one.
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return c.string ?? ""
    }

    init(bridgePubkey: String, relays: [String], clientSecret: String, label: String?, chain: String?, certSHA256: String? = nil) {
        self.bridgePubkey = bridgePubkey.lowercased()
        self.relays = relays
        self.clientSecret = clientSecret.lowercased()
        self.label = label
        self.chain = chain
        self.certSHA256 = certSHA256?.lowercased()
    }

    init?(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = URLComponents(string: s), c.scheme?.lowercased() == Self.scheme,
              let host = c.host?.lowercased(), host.count == 64, NostrHex.decode(host) != nil else { return nil }
        let items = c.queryItems ?? []
        let relays = items.filter { $0.name == "relay" }.compactMap { $0.value }
            .filter { $0.lowercased().hasPrefix("ws://") || $0.lowercased().hasPrefix("wss://") }
        guard !relays.isEmpty,
              let secret = items.first(where: { $0.name == "secret" })?.value?.lowercased(),
              NostrKeys(secretHex: secret) != nil else { return nil }
        let cert = items.first { $0.name == "cert" }?.value?.lowercased()
        guard cert == nil || (cert!.count == 64 && NostrHex.decode(cert!) != nil) else { return nil }
        self.init(bridgePubkey: host, relays: relays, clientSecret: secret,
                  label: items.first { $0.name == "label" }?.value,
                  chain: items.first { $0.name == "chain" }?.value,
                  certSHA256: cert)
    }
}

// MARK: - TLS

/// Trust for a relay's TLS connection: a certificate that validates normally (public relays), or
/// exactly the one pinned in the pairing link (this Mac's relay, self-signed). Nothing else.
enum NostrTLS {
    /// SHA-256 (hex) of a certificate's DER bytes.
    static func fingerprint(_ certificate: SecCertificate) -> String {
        NostrHex.encode(SHA256.hash(data: SecCertificateCopyData(certificate) as Data))
    }

    static func evaluate(_ challenge: URLAuthenticationChallenge, pin: String?) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else { return (.performDefaultHandling, nil) }
        if let pin = pin, let leaf = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first,
           fingerprint(leaf) == pin.lowercased() {
            return (.useCredential, URLCredential(trust: trust))
        }
        if SecTrustEvaluateWithError(trust, nil) {
            return (.useCredential, URLCredential(trust: trust))
        }
        return (.cancelAuthenticationChallenge, nil)
    }
}

// MARK: - RPC framing

/// One piece of a request or response, the plaintext of one NIP-44 message. Also carries the
/// two control messages (no data): `ack` and `resend`.
struct NostrRPCFrame: Codable {
    /// Request id; a response reuses it.
    let id: String
    /// 0-based position and number of frames (0 for control messages).
    let seq: Int
    let total: Int
    /// Requests: the RPC path ("" or "/wallet/<name>") and a timeout in seconds.
    var path: String?
    var timeout: Double?
    /// Responses: Bitcoin Core's HTTP status (0 = the bridge couldn't reach it).
    var status: Int?
    /// Responses with status 0: why.
    var error: String?
    /// This frame's slice of the base64 body.
    let data: String
    /// The body is raw DEFLATE (RFC 1951) compressed; every frame of the message says so.
    var deflate: Bool?
    /// The body's size before compression (decompression stops there).
    var size: Int?
    /// Control, bridge → device: the whole request arrived (sent again for a duplicate).
    var ack: Bool?
    /// Control, either way: please send these frames of message `id` again.
    var resend: [Int]?

    var isControl: Bool { ack == true || resend != nil }

    /// Base64 characters per frame. With NIP-44's padding, encryption and the event around it
    /// a frame's event stays under ~40 KB, inside the 64 KB event limit of many public relays.
    static let sliceSize = 24_000
    /// Largest body accepted (before or after compression).
    static let maxBodySize = 64 * 1024 * 1024

    /// Splits `body` into frames, DEFLATE-compressing it first when that makes it smaller.
    static func frames(id: String, body: Data, path: String? = nil, timeout: Double? = nil,
                       status: Int? = nil, error: String? = nil) -> [NostrRPCFrame] {
        let compressed = NostrDeflate.compress(body)
        let payload = compressed ?? body
        let chars = Array(payload.base64EncodedString().utf8)
        let total = max(1, (chars.count + sliceSize - 1) / sliceSize)
        return (0..<total).map { i in
            let slice = chars.isEmpty ? "" : String(decoding: chars[(i * sliceSize)..<min(chars.count, (i + 1) * sliceSize)], as: UTF8.self)
            return NostrRPCFrame(id: id, seq: i, total: total, path: path, timeout: timeout,
                                 status: status, error: error, data: slice,
                                 deflate: compressed == nil ? nil : true, size: compressed == nil ? nil : body.count)
        }
    }

    static func ack(id: String) -> NostrRPCFrame {
        NostrRPCFrame(id: id, seq: 0, total: 0, data: "", ack: true)
    }

    static func resend(id: String, seqs: [Int]) -> NostrRPCFrame {
        NostrRPCFrame(id: id, seq: 0, total: 0, data: "", resend: seqs)
    }
}

/// Raw DEFLATE with Apple's Compression library (bounded on the way back in).
enum NostrDeflate {
    /// nil unless compressing actually saves space.
    static func compress(_ data: Data) -> Data? {
        guard data.count > 256 else { return nil }
        var output = Data(count: data.count)
        let written = output.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_encode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, data.count,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written > 0, written < data.count else { return nil }
        output.count = written
        return output
    }

    /// Exactly `size` bytes, or nil (corrupt, or the sender lied about the size).
    static func decompress(_ data: Data, size: Int) -> Data? {
        guard size > 0, size <= NostrRPCFrame.maxBodySize, !data.isEmpty else { return nil }
        // One byte of room past the stated size: a body that inflates to more fills it, and is refused.
        var output = Data(count: size + 1)
        let written = output.withUnsafeMutableBytes { dst in
            data.withUnsafeBytes { src in
                compression_decode_buffer(dst.bindMemory(to: UInt8.self).baseAddress!, size + 1,
                                          src.bindMemory(to: UInt8.self).baseAddress!, data.count,
                                          nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { return nil }
        output.count = size
        return output
    }
}

/// Puts frames back together, and notices messages that stall with frames missing. Not
/// thread-safe: use from one queue.
final class NostrRPCReassembler {
    private struct Partial {
        var frames: [Int: NostrRPCFrame] = [:]
        var total = 0
        let started = Date()
        var lastFrame = Date()
        var resendRequests = 0
    }

    private var partials: [String: Partial] = [:]
    /// Finished messages: late copies (another relay, a resend) are ignored.
    private var completed: [String: Date] = [:]

    /// Asking for the same missing frames this many times at most.
    static let maxResendRequests = 8

    /// The complete message (first frame for its metadata, joined body) once every frame arrived.
    func add(_ frame: NostrRPCFrame) -> (first: NostrRPCFrame, body: Data)? {
        guard !frame.isControl, frame.total > 0, frame.total <= 4_000, (0..<frame.total).contains(frame.seq),
              completed[frame.id] == nil else { return nil }
        purge()
        var partial = partials[frame.id] ?? Partial()
        partial.frames[frame.seq] = frame
        partial.total = frame.total
        partial.lastFrame = Date()
        guard partial.frames.count == frame.total else {
            partials[frame.id] = partial
            return nil
        }
        partials[frame.id] = nil
        completed[frame.id] = Date()
        let b64 = (0..<frame.total).compactMap { partial.frames[$0]?.data }.joined()
        guard let first = partial.frames[0], var body = Data(base64Encoded: b64) else { return nil }
        if first.deflate == true {
            guard let size = first.size, let inflated = NostrDeflate.decompress(body, size: size) else { return nil }
            body = inflated
        }
        guard body.count <= NostrRPCFrame.maxBodySize else { return nil }
        return (first, body)
    }

    /// Whether any frame of message `id` has arrived (or it's finished).
    func hasStarted(_ id: String) -> Bool { partials[id] != nil || completed[id] != nil }

    /// Messages that got no new frame for `after` seconds, with the frames still missing. Each
    /// is reported at most `maxResendRequests` times, `after` apart.
    func stalled(after: TimeInterval) -> [(id: String, missing: [Int])] {
        let now = Date()
        var result: [(String, [Int])] = []
        for (id, partial) in partials where now.timeIntervalSince(partial.lastFrame) >= after
            && partial.resendRequests < Self.maxResendRequests {
            let missing = (0..<partial.total).filter { partial.frames[$0] == nil }
            guard !missing.isEmpty else { continue }
            partials[id]?.resendRequests += 1
            partials[id]?.lastFrame = now
            result.append((id, missing))
        }
        return result
    }

    func forget(_ id: String) {
        partials[id] = nil
    }

    /// Drops messages still incomplete after five minutes, and finished ids after ten.
    private func purge() {
        let now = Date()
        partials = partials.filter { now.timeIntervalSince($0.value.started) < 300 }
        completed = completed.filter { now.timeIntervalSince($0.value) < 600 }
    }
}

/// Frames sent recently, kept so missing ones can be sent again. Not thread-safe.
final class NostrRPCOutbox {
    private var messages: [String: (frames: [NostrRPCFrame], sent: Date)] = [:]

    func store(_ id: String, _ frames: [NostrRPCFrame]) {
        let now = Date()
        messages = messages.filter { now.timeIntervalSince($0.value.sent) < 300 }
        messages[id] = (frames, now)
    }

    /// The frames of `id` (all of them, or just `seqs`).
    func frames(_ id: String, seqs: [Int]? = nil) -> [NostrRPCFrame] {
        guard let frames = messages[id]?.frames else { return [] }
        guard let seqs = seqs else { return frames }
        let wanted = Set(seqs)
        return frames.filter { wanted.contains($0.seq) }
    }

    func has(_ id: String) -> Bool { messages[id] != nil }

    func forget(_ id: String) { messages[id] = nil }
}
