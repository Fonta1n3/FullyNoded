//
//  Crypto.swift
//  BitSense
//
//  Created by Peter on 16/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import CryptoKit
import RNCryptor

enum Crypto {
    
    static func sha256hash(_ text: String) -> String {
        let digest = SHA256.hash(data: text.utf8)
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func sha256hash(_ data: Data) -> Data {
        let digest = SHA256.hash(data: data)
        
        return Data(digest)
    }
    
    static func privateKey() -> Data {
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
//    static func encryptForBackup(_ key: Data, _ data: Data) -> Data? {
//        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
//    }
//
//    static func decryptForBackup(_ key: Data, _ data: Data) -> Data? {
//        guard let box = try? ChaChaPoly.SealedBox.init(combined: data) else {
//                return nil
//        }
//
//        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
//    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
        
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
    }
    
    static func sign(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
        
        guard let privkey = try? Curve25519.Signing.PrivateKey(rawRepresentation: key.bytesNostr) else { return nil }
        
        return try! privkey.signature(for: data)
    }
    
    static func verify(_ sig: Data, data: Data) -> Bool? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
        guard let privkey = try? Curve25519.Signing.PrivateKey(rawRepresentation: key.bytesNostr) else { return nil }
        let publicKeyData = privkey.publicKey.rawRepresentation
        let pubKey = try! Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        return pubKey.isValidSignature(sig, for: data)
    }
    
    static func blindPsbt(_ psbt: Data) -> Data? {
        guard let key = KeyChain.getData("blindingKey") else {
            return nil
        }

        return try? ChaChaPoly.seal(psbt, using: SymmetricKey(data: key)).combined
    }
    
    static func decryptPsbt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("blindingKey"),
            let box = try? ChaChaPoly.SealedBox.init(combined: data) else {
                return nil
        }
        
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
    static func encryptNostr(_ content: Data, _ password: String) -> Data? {
        return RNCryptor.encrypt(data: content, withPassword: password.replacingOccurrences(of: " ", with: ""))
    }
    
    static func decryptNostr(_ content: Data, _ password: String) -> Data? {
        return try? RNCryptor.decrypt(data: content, withPassword: password.replacingOccurrences(of: " ", with: ""))
    }
    
    static func decrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey"),
            let box = try? ChaChaPoly.SealedBox.init(combined: data) else {
                return nil
        }
        
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
    static func checksum(_ descriptor: String) -> String {
        let hash = SHA256.hash(data: Data(SHA256.hash(data: Base58.decode(descriptor))))
        let checksum = Data(hash).subdata(in: Range(0...3))
        let hex = checksum.hexString
        
        return descriptor + "#" + hex
    }
    
    static func checksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: Data(SHA256.hash(data: data)))
        let checksum = Data(hash).subdata(in: Range(0...3))
        return checksum.hexString
    }
    
    static func setupinit() -> Bool {
        // Goal is to replace this with a get request to my own server behind an authenticated v3 onion
        guard KeyChain.getData("blindingKey") == nil else { return true }
        
        guard let pk = Data(base64Encoded: currentDate()) else { return false }

        return KeyChain.set(pk, forKey: "blindingKey")
    }
    
    static func secret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard result == errSecSuccess else {
            print("Problem generating random bytes")
            return nil
        }

        return Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(bytes))))
    }
    
    static func secretNick() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 16)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)

        guard result == errSecSuccess else {
            print("Problem generating random bytes")
            return nil
        }

        return Crypto.sha256hash(Crypto.sha256hash(Crypto.sha256hash(Data(bytes))))
    }
    
    // MARK: JoinMarket JWT token creation
    struct Header: Encodable {
        let alg = "HS256"
        let typ = "JWT"
    }

    struct Payload: Encodable {
        let sub = "1234567890"
        let name = "Satoshi"
        let iat = 1516239022
    }
    
    static func jwtToken() -> String? {
        guard let secret = Crypto.secret() else { return nil }
        
        let privateKey = SymmetricKey(data: secret)

        let headerJSONData = try! JSONEncoder().encode(Header())
        let headerBase64String = headerJSONData.urlSafeB64String

        let payloadJSONData = try! JSONEncoder().encode(Payload())
        let payloadBase64String = payloadJSONData.urlSafeB64String

        let toSign = (headerBase64String + "." + payloadBase64String).data(using: .utf8)!

        let signature = HMAC<SHA256>.authenticationCode(for: toSign, using: privateKey)
        let signatureBase64String = Data(signature).urlSafeB64String

        return [headerBase64String, payloadBase64String, signatureBase64String].joined(separator: ".")
    }

    static func decode(jwtToken jwt: String) throws -> [String: Any] {
        enum DecodeErrors: Error {
            case badToken
            case other
        }

        func base64Decode(_ base64: String) throws -> Data {
            let padded = base64.padding(toLength: ((base64.count + 3) / 4) * 4, withPad: "=", startingAt: 0)
            guard let decoded = Data(base64Encoded: padded) else {
                throw DecodeErrors.badToken
            }
            return decoded
        }

        func decodeJWTPart(_ value: String) throws -> [String: Any] {
            let bodyData = try base64Decode(value)
            let json = try JSONSerialization.jsonObject(with: bodyData, options: [])
            guard let payload = json as? [String: Any] else {
                throw DecodeErrors.other
            }
            return payload
        }

        let segments = jwt.components(separatedBy: ".")
        return try decodeJWTPart(segments[1])
      }
    
    
}
