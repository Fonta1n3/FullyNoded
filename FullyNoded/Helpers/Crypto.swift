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
    
    static func encrypt(_ data: Data) -> Data? {
        if let key = KeyChain.getData("privateKey") {
            return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
        } else {
            // create it
            guard KeyChain.set(privateKey(), forKey: "privateKey") else { return nil }
            
            guard let key = KeyChain.getData("privateKey") else { return nil }
            
            return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
        }
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
    
    static func secret() -> Data? {
        var bytes = [UInt8](repeating: 0, count: 64) // 512 bits
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else { return nil }
        
        // Reduce to 256 bits with a single SHA-256
        return Crypto.sha256hash(Data(bytes))
    }
}
