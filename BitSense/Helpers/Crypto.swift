//
//  Crypto.swift
//  BitSense
//
//  Created by Peter on 16/05/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import CryptoKit

class Crypto {
    
    class func privateKey() -> Data {
        return P256.Signing.PrivateKey().rawRepresentation
    }
    
    class func encryptData(dataToEncrypt: Data, completion: @escaping ((Data?)) -> Void) {
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
    
    class func decryptData(dataToDecrypt: Data, completion: @escaping ((Data?)) -> Void) {
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
    
    class func checksum(_ descriptor: String) -> String {
        let hash = SHA256.hash(data: Data(SHA256.hash(data: Base58.decode(descriptor))))
        let checksum = Data(hash).subdata(in: Range(0...3))
        let hex = checksum.hexString
        return descriptor + "#" + hex
    }
    
}
