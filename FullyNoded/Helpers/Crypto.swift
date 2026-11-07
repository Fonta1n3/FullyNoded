//
//  Crypto.swift
//  BitSense
//
//  Created by Peter on 16/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import CryptoKit
import Foundation

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
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }
    
    /// Name of the master encryption key in the keychain.
    private static let keyName = "privateKey"
    
    /// The master encryption key, created ONLY if the keychain reports it doesn't exist.
    ///
    /// If the keychain can't be read (e.g. errSecInteractionNotAllowed while the device
    /// is locked) this returns nil and changes nothing. Replacing the key would make every
    /// stored seed and credential undecryptable, so an existing key is never deleted or
    /// overwritten (add-only write).
    static func encryptionKey() -> Data? {
        switch KeyChain.read(keyName) {
        case .found(let key):
            return key
            
        case .error(let status):
            #if DEBUG
            print("Keychain unavailable (\(status)); not touching the encryption key.")
            #endif
            return nil
            
        case .notFound:
            // First run: create it. errSecDuplicateItem means another caller created it
            // meanwhile, which is fine: re-read so everyone uses the same stored key.
            let status = KeyChain.add(privateKey(), forKey: keyName)
            guard status == errSecSuccess || status == errSecDuplicateItem else { return nil }
            if case .found(let key) = KeyChain.read(keyName) { return key }
            return nil
        }
    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = encryptionKey() else { return nil }
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
    }
    
    static func decrypt(_ data: Data) -> Data? {
        // Decrypt never creates a key: a missing key can't decrypt anything anyway.
        guard case .found(let key) = KeyChain.read(keyName),
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
    
    static func secret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 64) // 512 bits
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return nil }
        
        // Reduce to 256 bits with a single SHA-256
        return Crypto.sha256hash(Data(bytes))
    }
}
