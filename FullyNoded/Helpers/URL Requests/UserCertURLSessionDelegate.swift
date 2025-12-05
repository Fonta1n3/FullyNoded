//
//  UserCertURLSessionDelegate.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/16/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

class UserCertURLSessionDelegate: NSObject, URLSessionDelegate {
    
    var cert: SecCertificate?
    var onTrustError: ((String) -> Void)?
    
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        let host = challenge.protectionSpace.host
        
        let whitelistedHosts = [
            "blockchain.info"
        ]
        
        if whitelistedHosts.contains(host) {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let serverTrust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // Trust ONLY the user's cert
        guard let cert = cert else {
            onTrustError?("No SSL cert.")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        SecTrustSetAnchorCertificates(serverTrust, [cert] as CFArray)
        SecTrustSetAnchorCertificatesOnly(serverTrust, true)
        
        var error: CFError?
        let isTrusted = SecTrustEvaluateWithError(serverTrust, &error)
        
        if isTrusted {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            if let error = error {
                onTrustError?("Trust error: \(error.localizedDescription)")
            } else {
                onTrustError?("Unknown error: cert was rejected.")
            }
            
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}


