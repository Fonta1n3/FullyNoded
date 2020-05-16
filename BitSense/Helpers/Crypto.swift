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
    
    // MARK: - New encryption
    
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
    
}
