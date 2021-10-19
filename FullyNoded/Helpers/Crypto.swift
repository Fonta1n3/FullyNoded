//
//  Crypto.swift
//  BitSense
//
//  Created by Peter on 16/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import CryptoKit

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
    
    static func encryptForBackup(_ key: Data, _ data: Data) -> Data? {
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
    }
    
    static func decryptForBackup(_ key: Data, _ data: Data) -> Data? {
        guard let box = try? ChaChaPoly.SealedBox.init(combined: data) else {
                return nil
        }
        
        return try? ChaChaPoly.open(box, using: SymmetricKey(data: key))
    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
        
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
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
    
}
