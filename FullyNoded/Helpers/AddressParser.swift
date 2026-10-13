//
//  AddressParser.swift
//  BitSense
//
//  Created by Peter on 01/05/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

// bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=50&label=Luke-Jr&message=Donation%20for%20project%20xyz
// bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?amount=20.3&label=Luke-Jr
// bitcoin:175tWpb8K1S7NmH4Zx6rewF9WQrcZv245W?sp=sp1q…     (BIP321: silent payment address, with a fallback)
// bitcoin:?sp=sp1q…                                       (BIP321: silent payment only)

class AddressParser {
    
    static let sharedInstance = AddressParser()
    
    private init() {}
        
    /// A parsed BIP21 / BIP321 payment request.
    struct PaymentRequest {
        /// The on-chain address in the path (the fallback when a silent payment address is
        /// also given). nil for `bitcoin:?sp=…`.
        var address: String?
        /// BIP321 `sp=`: a silent payment address (sp1… / tsp1…).
        var silentPayment: String?
        var amount: Double?
        var label: String?
        var message: String?
    }

    /// BIP21 / BIP321: `bitcoin:[address][?amount=…&label=…&message=…&sp=…]`, or a bare
    /// address. Scheme and keys are case-insensitive, values percent-decoded. nil if there's no
    /// usable address, or an unknown `req-` parameter (which BIP21 / 321 say must be refused).
    func parseRequest(url: String) -> PaymentRequest? {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("bitcoin:") else {
            // A bare address.
            guard let address = processedAddress(trimmed) else { return nil }
            return SilentPaymentSend.isSilentPaymentAddress(address)
                ? PaymentRequest(silentPayment: address)
                : PaymentRequest(address: address)
        }
        let body = String(trimmed.dropFirst("bitcoin:".count))
        let parts = body.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
        let path = String(parts.first ?? "").removingPercentEncoding ?? String(parts.first ?? "")

        var request = PaymentRequest()
        if !path.isEmpty {
            guard let address = processedAddress(path) else { return nil }
            if SilentPaymentSend.isSilentPaymentAddress(address) {
                request.silentPayment = address
            } else {
                request.address = address
            }
        }

        if parts.count > 1 {
            var components = URLComponents()
            components.percentEncodedQuery = String(parts[1])
            for item in components.queryItems ?? [] {
                let value = item.value ?? ""
                switch item.name.lowercased() {
                case "amount":
                    guard let amount = Double(value), amount >= 0 else { return nil }
                    request.amount = amount
                case "label":
                    request.label = value
                case "message":
                    request.message = value
                case "sp":
                    // The first valid one (a wallet may only understand some versions).
                    if request.silentPayment == nil, let sp = processedAddress(value), SilentPaymentSend.isSilentPaymentAddress(sp) {
                        request.silentPayment = sp
                    }
                case let key where key.hasPrefix("req-"):
                    return nil
                default:
                    break   // other payment instructions (lno, …) this wallet can't use
                }
            }
        }

        guard request.address != nil || request.silentPayment != nil else { return nil }
        return request
    }

    /// The single address to pay (the silent payment address if one is offered), amount,
    /// label and message. Prefer `parseRequest` to offer the choice.
    func parse(url: String) -> (address: String?, amount: Double?, label: String?, message: String?) {
        guard let request = parseRequest(url: url) else { return (nil, nil, nil, nil) }
        return (request.silentPayment ?? request.address, request.amount, request.label, request.message)
    }

    private func processedAddress(_ processed: String) -> String? {
        var address = processed.replacingOccurrences(of: "bitcoin:", with: "")
        address = address.replacingOccurrences(of: "BITCOIN:", with: "")
        switch address.lowercased() {
        case _ where address.hasPrefix("1"),
            _ where address.hasPrefix("3"),
            _ where address.lowercased().hasPrefix("tb1"),
            _ where address.lowercased().hasPrefix("bc1"),
            _ where address.hasPrefix("2"),
            _ where address.lowercased().hasPrefix("bcrt"),
            _ where address.hasPrefix("m"),
            _ where address.hasPrefix("n"),
            _ where address.lowercased().hasPrefix("sp1"),     // silent payment (mainnet)
            _ where address.lowercased().hasPrefix("tsp1"):    // silent payment (test networks)
            if address.hasPrefix("BC1") || address.hasPrefix("TB1") || SilentPaymentSend.isSilentPaymentAddress(address) {
                return address.lowercased()
            } else {
                return address
            }
        default:
            return nil
        }
    }
}
