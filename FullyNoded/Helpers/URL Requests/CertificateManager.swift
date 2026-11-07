//
//  CertificateManager.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/16/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation
import Security

class CertificateManager {
    
    static let shared = CertificateManager()
    
    private init() {}
    
    func certFileToBase64(fileURL: URL) -> String? {
        guard let data = try? Data(contentsOf: fileURL) else {
            #if DEBUG
            print("Failed to read file: \(fileURL.lastPathComponent)")
            #endif
            return nil
        }
        
        // For PEM and crt: extract only the base64 part between BEGIN/END
        if fileURL.pathExtension.lowercased() == "pem" || fileURL.pathExtension.lowercased() == "crt",
           let pemText = String(data: data, encoding: .utf8) {
            let base64 = pemText
                .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
                .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: " ", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return base64
        }
        
        // For DER/binary (.cer, .der): base64 of the raw bytes
        return data.base64EncodedString()
    }
    
    func base64ToCert(base64: String) -> SecCertificate? {
        // Clean and decode
        let cleanBase64 = base64
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        
        guard let data = Data(base64Encoded: cleanBase64) else {
            #if DEBUG
            print("Invalid Base64")
            #endif
            return nil
        }
        
        // Try to create certificate (works for both DER and PEM-extracted base64)
        return SecCertificateCreateWithData(kCFAllocatorDefault, data as CFData)
    }
}
