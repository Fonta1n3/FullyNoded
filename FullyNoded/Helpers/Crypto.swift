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
    
    static func encryptData(dataToEncrypt: Data, completion: @escaping ((Data?)) -> Void) {
        if let key = KeyChain.getData("privateKey") {
            let k = SymmetricKey(data: key)
            if let sealedBox = try? ChaChaPoly.seal(dataToEncrypt, using: k) {
                let encryptedData = sealedBox.combined
                completion((encryptedData))
            } else {
                completion((nil))
            }
        }
    }
    
    static func decryptData(dataToDecrypt: Data, completion: @escaping ((Data?)) -> Void) {
        if let key = KeyChain.getData("privateKey") {
            do {
                let box = try ChaChaPoly.SealedBox.init(combined: dataToDecrypt)
                let k = SymmetricKey(data: key)
                let decryptedData = try ChaChaPoly.open(box, using: k)
                completion((decryptedData))
            } catch {
                completion((nil))
            }
        }
    }
    
    static func checksum(_ descriptor: String) -> String {
        let hash = SHA256.hash(data: Data(SHA256.hash(data: Base58.decode(descriptor))))
        let checksum = Data(hash).subdata(in: Range(0...3))
        let hex = checksum.hexString
        return descriptor + "#" + hex
    }
    
}
