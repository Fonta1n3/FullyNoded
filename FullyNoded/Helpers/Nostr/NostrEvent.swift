//
//  NostrEvent.swift
//  damus
//
//  Created by William Casarin on 2022-04-11.
//
// Copied and modified by Peter Denton on 2022-10-21

import Foundation
//import CommonCrypto
import secp256k1
//import secp256k1_implementation
import CryptoKit

enum ValidationResult: Decodable {
    case ok
    case bad_id
    case bad_sig
}

struct OtherEvent {
    let event_id: String
    let relay_url: String
}

struct KeyEvent {
    let key: String
    let relay_url: String
}

struct ReferencedId: Identifiable, Hashable {
    let ref_id: String
    let relay_id: String?
    let key: String

    var id: String {
        return ref_id
    }
}

struct EventId: Identifiable, CustomStringConvertible {
    let id: String

    var description: String {
        id
    }
}

class NostrEvent: Codable, Identifiable, CustomStringConvertible, Equatable {
    static func == (lhs: NostrEvent, rhs: NostrEvent) -> Bool {
        return lhs.id == rhs.id
    }
    
    var id: String
    var sig: String
    var tags: [[String]]
    var boosted_by: String?

    // cached field for pow calc
    //var pow: Int?
    // custom flags for internal use
    var flags: Int = 0

    let pubkey: String
    let created_at: Int64
    let kind: Int
    let content: String
    
    var is_textlike: Bool {
        return kind == 1 || kind == 42
    }
    
    var too_big: Bool {
        return self.content.count > 32000
    }
    
    var should_show_event: Bool {
        return !too_big
    }
    
    var is_valid_id: Bool {
        return calculate_event_id(ev: self) == self.id
    }
    
    var is_valid: Bool {
        return validity == .ok
    }
    
    lazy var validity: ValidationResult = {
        return validate_event(ev: self)
    }()
    
//    private var _blocks: [Block]? = nil
//    func blocks(_ privkey: String?) -> [Block] {
//        if let bs = _blocks {
//            return bs
//        }
//        let blocks = parse_mentions(content: self.get_content(privkey), tags: self.tags)
//        self._blocks = blocks
//        return blocks
//    }

    lazy var inner_event: NostrEvent? = {
        // don't try to deserialize an inner event if we know there won't be one
        if self.known_kind == .boost {
            return event_from_json(dat: self.content)
        }
        return nil
    }()
    
//    private var _event_refs: [EventRef]? = nil
//    func event_refs(_ privkey: String?) -> [EventRef] {
//        if let rs = _event_refs {
//            return rs
//        }
//        let refs = interpret_event_refs(blocks: self.blocks(privkey), tags: self.tags)
//        self._event_refs = refs
//        return refs
//    }

    //var decrypted_content: String? = nil

//    func decrypted(privkey: String?) -> String? {
//        if let decrypted_content = decrypted_content {
//            return decrypted_content
//        }
//
//        guard let key = privkey else {
//            return nil
//        }
//
//        guard let our_pubkey = privkey_to_pubkey(privkey: key) else {
//            return nil
//        }
//
//        var pubkey = self.pubkey
//        // This is our DM, we need to use the pubkey of the person we're talking to instead
//        if our_pubkey == pubkey {
//            guard let refkey = self.referenced_pubkeys.first else {
//                return nil
//            }
//
//            pubkey = refkey.ref_id
//        }
//
//        let dec = decrypt_dm(key, pubkey: pubkey, content: self.content)
//        self.decrypted_content = dec
//
//        return dec
//    }

//    func get_content(_ privkey: String?) -> String {
//        if known_kind == .dm {
//            return ""//decrypted(privkey: privkey) ?? "*failed to decrypt content*"
//        }
//
//        switch validity {
//        case .ok:
//            return content
//        case .bad_id:
//            return content + "\n\n*WARNING: invalid note id, could be forged!*"
//        case .bad_sig:
//            return content + "\n\n*WARNING: invalid signature, could be forged!*"
//        }
//    }

    var description: String {
        //let p = pow.map { String($0) } ?? "?"
        return "NostrEvent { id: \(id) pubkey \(pubkey) kind \(kind) tags \(tags) content '\(content)' }"
    }

    var known_kind: NostrKind? {
        return NostrKind.init(rawValue: kind)
    }

    private enum CodingKeys: String, CodingKey {
        case id, sig, tags, pubkey, created_at, kind, content
    }

//    private func get_referenced_ids(key: String) -> [ReferencedId] {
//        return damus.get_referenced_ids(tags: self.tags, key: key)
//    }

    public func is_root_event() -> Bool {
        for tag in tags {
            if tag.count >= 1 && tag[0] == "e" {
                return false
            }
        }
        return true
    }

//    public func direct_replies(_ privkey: String?) -> [ReferencedId] {
//        return event_refs(privkey).reduce(into: []) { acc, evref in
//            if let direct_reply = evref.is_direct_reply {
//                acc.append(direct_reply)
//            }
//        }
//    }

    public func last_refid() -> ReferencedId? {
        var mlast: Int? = nil
        var i: Int = 0
        for tag in tags {
            if tag.count >= 2 && tag[0] == "e" {
                mlast = i
            }
            i += 1
        }

        guard let last = mlast else {
            return nil
        }

        return tag_to_refid(tags[last])
    }

    public func references(id: String, key: String) -> Bool {
        for tag in tags {
            if tag.count >= 2 && tag[0] == key {
                if tag[1] == id {
                    return true
                }
            }
        }

        return false
    }

//    func is_reply(_ privkey: String?) -> Bool {
//        return event_is_reply(self, privkey: privkey)
//    }
//
//    public var referenced_ids: [ReferencedId] {
//        return get_referenced_ids(key: "e")
//    }

    public func count_ids() -> Int {
        return count_refs("e")
    }

    public func count_refs(_ type: String) -> Int {
        var count: Int = 0
        for tag in tags {
            if tag.count >= 2 && tag[0] == "e" {
                count += 1
            }
        }
        return count
    }

//    public var referenced_pubkeys: [ReferencedId] {
//        return get_referenced_ids(key: "p")
//    }

    /// Make a local event
    public static func local(content: String, pubkey: String) -> NostrEvent {
        let ev = NostrEvent(content: content, pubkey: pubkey)
        ev.flags |= 1
        return ev
    }

    public var is_local: Bool {
        return (self.flags & 1) != 0
    }

    init(content: String, pubkey: String, kind: Int = 1, tags: [[String]] = []) {
        self.id = ""
        self.sig = ""

        self.content = content
        self.pubkey = pubkey
        self.kind = kind
        self.tags = tags
        self.created_at = Int64(Date().timeIntervalSince1970)
    }

    init(from: NostrEvent, content: String? = nil) {
        self.id = from.id
        self.sig = from.sig

        self.content = content ?? from.content
        self.pubkey = from.pubkey
        self.kind = from.kind
        self.tags = from.tags
        self.created_at = from.created_at
    }

    func calculate_id() {
        self.id = calculate_event_id(ev: self)
        //self.pow = count_hash_leading_zero_bits(self.id)
    }

    // TODO: timeout
    /*
    func mine_id(pow: Int, done: @escaping (String) -> ()) {
        let nonce_ind = self.ensure_nonce_tag()
        let nonce: Int64 = 0
        DispatchQueue.global(qos: .background).async {
            while
        }
    }
     */

    private func ensure_nonce_tag() -> Int {
        for (i, tags) in self.tags.enumerated() {
            for tag in tags {
                if tags.count == 2 && tag == "nonce" {
                    return i
                }
            }
        }

        self.tags.append(["nonce", "0"])
        return self.tags.count - 1
    }

    func sign(privkey: String) {
        self.sig = sign_event(privkey: privkey, ev: self)
    }
}

func sign_event(privkey: String, ev: NostrEvent) -> String {
    let priv_key_bytes = try! privkey.bytes
    let key = try! secp256k1.Signing.PrivateKey(rawRepresentation: priv_key_bytes)

    // Extra params for custom signing
    var aux_rand = random_bytes(count: 64)
    var digest = try! ev.id.bytes

    // API allows for signing variable length messages
    let signature = try! key.schnorr.signature(message: &digest, auxiliaryRand: &aux_rand)

    return hex_encode(signature.rawRepresentation)
}

func decode_nostr_event(txt: String) -> NostrResponse? {
    return decode_data(Data(txt.utf8))
}

func encode_json<T: Encodable>(_ val: T) -> String? {
    let encoder = JSONEncoder()
    return (try? encoder.encode(val)).map { String(decoding: $0, as: UTF8.self) }
}

func decode_json<T: Decodable>(_ val: String) -> T? {
    return try? JSONDecoder().decode(T.self, from: Data(val.utf8))
}

func decode_data<T: Decodable>(_ data: Data) -> T? {
    let decoder = JSONDecoder()
    do {
        return try decoder.decode(T.self, from: data)
    } catch {
        print("decode_data failed for \(T.self): \(error)")
    }

    return nil
}

func event_commitment(ev: NostrEvent, tags: String) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let str_data = try! encoder.encode(ev.content)
    let content = String(decoding: str_data, as: UTF8.self)
    let commit = "[0,\"\(ev.pubkey)\",\(ev.created_at),\(ev.kind),\(tags),\(content)]"
    //print("COMMIT", commit)
    return commit
}

func calculate_event_commitment(ev: NostrEvent) -> Data {
    let tags_encoder = JSONEncoder()
    tags_encoder.outputFormatting = .withoutEscapingSlashes
    let tags_data = try! tags_encoder.encode(ev.tags)
    let tags = String(decoding: tags_data, as: UTF8.self)

    let target = event_commitment(ev: ev, tags: tags)
    let target_data = target.data(using: .utf8)!
    return target_data
}

func calculate_event_id(ev: NostrEvent) -> String {
    let commitment = calculate_event_commitment(ev: ev)
    let hash = sha256(commitment)

    return hex_encode(hash)
}

func sha256(_ data: Data) -> Data {
    return Crypto.sha256hash(data)
}

func hexchar(_ val: UInt8) -> UInt8 {
    if val < 10 {
        return 48 + val;
    }
    if val < 16 {
        return 97 + val - 10;
    }
    assertionFailure("impossiburu")
    return 0
}


func hex_encode(_ data: Data) -> String {
    var str = ""
    for c in data {
        let c1 = hexchar(c >> 4)
        let c2 = hexchar(c & 0xF)

        str.append(Character(Unicode.Scalar(c1)))
        str.append(Character(Unicode.Scalar(c2)))
    }
    return str
}



func random_bytes(count: Int) -> Data {
    var data = Data(count: count)
    _ = data.withUnsafeMutableBytes { mutableBytes in
        SecRandomCopyBytes(kSecRandomDefault, count, mutableBytes)
    }
    return data
}

func refid_to_tag(_ ref: ReferencedId) -> [String] {
    var tag = [ref.key, ref.ref_id]
    if let relay_id = ref.relay_id {
        tag.append(relay_id)
    }
    return tag
}

func tag_to_refid(_ tag: [String]) -> ReferencedId? {
    if tag.count == 0 {
        return nil
    }
    if tag.count == 1 {
        return nil
    }

    var relay_id: String? = nil
    if tag.count > 2 {
        relay_id = tag[2]
    }

    return ReferencedId(ref_id: tag[1], relay_id: relay_id, key: tag[0])
}

func get_referenced_ids(tags: [[String]], key: String) -> [ReferencedId] {
    return tags.reduce(into: []) { (acc, tag) in
        if tag.count >= 2 && tag[0] == key {
            var relay_id: String? = nil
            if tag.count >= 3 {
                relay_id = tag[2]
            }
            acc.append(ReferencedId(ref_id: tag[1], relay_id: relay_id, key: key))
        }
    }
}

func get_referenced_id_set(tags: [[String]], key: String) -> Set<ReferencedId> {
    return tags.reduce(into: Set()) { (acc, tag) in
        if tag.count >= 2 && tag[0] == key {
            var relay_id: String? = nil
            if tag.count >= 3 {
                relay_id = tag[2]
            }
            acc.insert(ReferencedId(ref_id: tag[1], relay_id: relay_id, key: key))
        }
    }
}

func make_first_contact_event(privkey: Data, content: String) -> NostrEvent? {
    let ev = NostrEvent(content: content,
                        pubkey: Keys.privKeyToPubKey(privkey)!,
                        kind: NostrKind.replaceable.rawValue,
                        tags: [])
    ev.calculate_id()
    ev.sign(privkey: privkey.hexString)
    return ev
}

func event_from_json(dat: String) -> NostrEvent? {
    return try? JSONDecoder().decode(NostrEvent.self, from: Data(dat.utf8))
}

func event_to_json(ev: NostrEvent) -> String {
    let encoder = JSONEncoder()
    guard let res = try? encoder.encode(ev) else {
        return "{}"
    }
    guard let str = String(data: res, encoding: .utf8) else {
        return "{}"
    }
    return str
}

struct DirectMessageBase64 {
    let content: [UInt8]
    let iv: [UInt8]
}

func encode_dm_base64(content: [UInt8], iv: [UInt8]) -> String {
    let content_b64 = base64_encode(content)
    let iv_b64 = base64_encode(iv)
    return content_b64 + "?iv=" + iv_b64
}

func decode_dm_base64(_ all: String) -> DirectMessageBase64? {
    let splits = Array(all.split(separator: "?"))

    if splits.count != 2 {
        return nil
    }

    guard let content = base64_decode(String(splits[0])) else {
        return nil
    }

    var sec = String(splits[1])
    if !sec.hasPrefix("iv=") {
        return nil
    }

    sec = String(sec.dropFirst(3))
    guard let iv = base64_decode(sec) else {
        return nil
    }

    return DirectMessageBase64(content: content, iv: iv)
}

func base64_encode(_ content: [UInt8]) -> String {
    return Data(content).base64EncodedString()
}

func base64_decode(_ content: String) -> [UInt8]? {
    guard let dat = Data(base64Encoded: content) else {
        return nil
    }
    return dat.bytes
}

func validate_event(ev: NostrEvent) -> ValidationResult {
    let raw_id = sha256(calculate_event_commitment(ev: ev))
    let id = hex_encode(raw_id)
    
    if id != ev.id {
        return .bad_id
    }

    guard var sig64 = hex_decode(ev.sig)?.bytes else {
        return .bad_sig
    }
    
    guard var ev_pubkey = hex_decode(ev.pubkey)?.bytes else {
        return .bad_sig
    }

    let ctx = secp256k1.Context.raw
    var xonly_pubkey = secp256k1_xonly_pubkey.init()
    var ok = secp256k1_xonly_pubkey_parse(ctx, &xonly_pubkey, &ev_pubkey) != 0
    if !ok {
        return .bad_sig
    }
    var raw_id_bytes = raw_id.bytes

    ok = secp256k1_schnorrsig_verify(ctx, &sig64, &raw_id_bytes, raw_id.count, &xonly_pubkey) > 0
    return ok ? .ok : .bad_sig
}


func inner_event_or_self(ev: NostrEvent) -> NostrEvent {
    guard let inner_ev = ev.inner_event else {
        return ev
    }
    
    return inner_ev
}

func hex_decode(_ str: String) -> [UInt8]?
{
    if str.count == 0 {
        return nil
    }
    var ret: [UInt8] = []
    let chars = Array(str.utf8)
    var i: Int = 0
    for c in zip(chars, chars[1...]) {
        i += 1

        if i % 2 == 0 {
            continue
        }

        guard let c1 = char_to_hex(c.0) else {
            return nil
        }

        guard let c2 = char_to_hex(c.1) else {
            return nil
        }

        ret.append((c1 << 4) | c2)
    }

    return ret
}

func char_to_hex(_ c: UInt8) -> UInt8?
{
    // 0 && 9
    if (c >= 48 && c <= 57) {
        return c - 48 // 0
    }
    // a && f
    if (c >= 97 && c <= 102) {
        return c - 97 + 10;
    }
    // A && F
    if (c >= 65 && c <= 70) {
        return c - 65 + 10;
    }
    return nil;
}
