//
//  Currencies.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/2/25.
//  Copyright © 2025 Fontaine. All rights reserved.
//

import Foundation

class Currencies {
    /// The currency codes the app offers, in order.
    static var codes: [String] { currenciesWithCircle.compactMap { $0.keys.first } }

    /// Each currency's text symbol, shown before amounts ("CHF" after them, see `fiatString`).
    static let symbols: [String: String] = [
        "USD": "$",
        "GBP": "£",
        "EUR": "€",
        "AUD": "$",
        "BRL": "R$",
        "CAD": "$",
        "CHF": "CHF ",
        "CLP": "$",
        "CNY": "¥",
        "DKK": "kr",
        "HKD": "$",
        "INR": "₹",
        "ISK": "kr",
        "JPY": "¥",
        "KRW": "₩",
        "NZD": "$",
        "PLN": "zł",
        "RUB": "₽",
        "SEK": "kr",
        "SGD": "$",
        "THB": "฿",
        "TRY": "₺",
        "TWD": "NT$"
    ]

    /// The currencies mempool.space's onion has prices for (exchange rates only ever come from
    /// onion services, see FiatConverter).
    static let currenciesWithCircle:[[String:String]] = [
        ["USD": "dollarsign.circle"],
        ["GBP": "sterlingsign.circle"],
        ["EUR": "eurosign.circle"],
        ["AUD":"dollarsign.circle"],
        ["CAD": "dollarsign.circle"],
        ["CHF": "francsign.circle"],
        ["JPY": "yensign.circle"]
    ]

    /// A currency picked before the list was cut to these has no rate any more: back to USD.
    static func dropUnsupportedSelection() {
        let defaults = UserDefaults.standard
        if let currency = defaults.string(forKey: "currency"), !codes.contains(currency) {
            defaults.set("USD", forKey: "currency")
        }
    }
}
