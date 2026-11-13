//
//  NostrConnectDisplay.swift
//  FullyNoded
//
//  How the app shows a Nostr Connect pairing. Kept out of NostrConnect.swift, which must stay
//  identical to Fully Noded Server's copy.
//

import Foundation

extension NostrConnectURI {
    /// "100.101.102.103:8765" from "ws://100.101.102.103:8765" (what the UI shows for a relay).
    static func displayHost(_ relay: String) -> String {
        guard let u = URL(string: relay), let host = u.host else { return relay }
        return u.port.map { "\(host):\($0)" } ?? host
    }

    /// The first relay, plus how many others: "100.101.102.103:8765 +1".
    var relaySummary: String {
        let first = relays.first.map(Self.displayHost) ?? ""
        return relays.count > 1 ? "\(first) +\(relays.count - 1)" : first
    }

    /// Network name for the chain Fully Noded Server paired on (bitcoind's chain names).
    var networkName: String? {
        switch chain {
        case "main": return "Mainnet"
        case "test": return "Testnet3"
        case "testnet4": return "Testnet4"
        case "signet": return "Signet"
        case "regtest": return "Regtest"
        default: return chain
        }
    }
}
