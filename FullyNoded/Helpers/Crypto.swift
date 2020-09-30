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
        let digest = SHA256.hash(data: text.dataUsingUTF8StringEncoding)
        
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    static func privateKey() -> Data {
        
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
    static func encrypt(_ data: Data) -> Data? {
        guard let key = KeyChain.getData("privateKey") else { return nil }
        
        return try? ChaChaPoly.seal(data, using: SymmetricKey(data: key)).combined
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
    
}
