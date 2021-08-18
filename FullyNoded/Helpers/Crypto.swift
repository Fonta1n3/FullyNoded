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
        
        guard let pk = Data(base64Encoded: "") else { return false }

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
    
//    static func rpcAuth() {
//        guard let salt = generateRandomBytes(16),
//            let password = generateRandomBytes(32) else { return }
//
//        let encodedPassword = password.base64EncodedData()
//        let key256 = SymmetricKey(data: encodedPassword)
//        let sha256MAC = HMAC<SHA256>.authenticationCode(for: salt, using: key256)
//        let authenticationCodeData = Data(sha256MAC)
//        print("rpcauth=FullyNoded:\(salt.hexString)$\(authenticationCodeData.hexString)")
//        print("rpcpassword=\(password.urlSafeB64String)")
//    }
//
//    static func generateRandomBytes(_ bytes: Int) -> Data? {
//        var keyData = Data(count: bytes)
//        let result = keyData.withUnsafeMutableBytes {
//            SecRandomCopyBytes(kSecRandomDefault, bytes, $0.baseAddress!)
//        }
//        if result == errSecSuccess {
//            return keyData
//        } else {
//            print("Problem generating random bytes")
//            return nil
//        }
//    }
    
}

/*extension String {

    /// Encodes or decodes into a base64url safe representation
    ///
    /// - Parameter on: Whether or not the string should be made safe for URL strings
    /// - Returns: if `on`, then a base64url string; if `off` then a base64 string
    func toggleBase64URLSafe(on: Bool) -> String {
        if on {
            // Make base64 string safe for passing into URL query params
            let base64url = self.replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "=", with: "")
            return base64url
        } else {
            // Return to base64 encoding
            var base64 = self.replacingOccurrences(of: "_", with: "/")
                .replacingOccurrences(of: "-", with: "+")
            // Add any necessary padding with `=`
            if base64.count % 4 != 0 {
                base64.append(String(repeating: "=", count: 4 - base64.count % 4))
            }
            return base64
        }
    }

}*/
