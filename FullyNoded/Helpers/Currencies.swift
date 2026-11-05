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

    static let currenciesWithCircle:[[String:String]] = [
        ["USD": "dollarsign.circle"],
        ["GBP": "sterlingsign.circle"],
        ["EUR": "eurosign.circle"],
        ["AUD":"dollarsign.circle"],
        ["BRL": "brazilianrealsign.circle"],
        ["CAD": "dollarsign.circle"],
        ["CHF": "francsign.circle"],
        ["CLP": "dollarsign.circle"],
        ["CNY": "yensign.circle"],
        ["DKK": "k.circle"],
        ["HKD": "dollarsign.circle"],
        ["INR": "indianrupeesign.circle"],
        ["ISK": "k.circle"],
        ["JPY": "yensign.circle"],
        ["KRW": "wonsign.circle"],
        ["NZD": "dollarsign.circle"],
        ["PLN": "z.circle"],
        ["RUB": "rublesign.circle"],
        ["SEK": "k.circle"],
        ["SGD": "dollarsign.circle"],
        ["THB": "bahtsign.circle"],
        ["TRY": "turkishlirasign.circle"],
        ["TWD": "dollarsign.circle"]
    ]
}
