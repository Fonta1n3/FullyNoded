//
//  FiatConverter.swift
//  BitSense
//
//  Created by Peter on 26/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

class FiatConverter {
    static let sharedInstance = FiatConverter()
    
    private init() {}
    
    let torClient = TorClient.sharedInstance
    var task: URLSessionDataTask? = nil
    
    /// Tor's proxy settings, but not torClient.session itself: its delegate trusts only the
    /// node's pinned certificate and cancels every other TLS host. These are ordinary public
    /// APIs, checked with normal certificate validation. One long-lived session: creating and
    /// tearing down a proxied session per request crashed inside CFNetwork (freeing its proxy
    /// options) during wallet refreshes. Made on first use, after Tor set its proxy settings.
    private lazy var fxSession = URLSession(configuration: torClient.session.configuration)
    
    /// A source of the BTC price: where to ask, and how to read the rate for a currency.
    private struct Source {
        let name: String
        let url: String
        /// Currencies it has (nil: all of the app's).
        let currencies: Set<String>?
        let rate: (Any, String) -> Double?
    }

    /// Ordered by how well they answer over Tor (checked October 2026): blockchain.info refuses
    /// Tor exits (HTTP 403), so it's last; mempool.space is asked at its onion, never via an exit.
    private static let sources: [Source] = [
        Source(name: "Coinbase", url: "https://api.coinbase.com/v2/exchange-rates?currency=BTC", currencies: nil) { json, currency in
            RPCValue.double(((json as? [String: Any])?["data"] as? [String: Any]).flatMap { ($0["rates"] as? [String: Any])?[currency] })
        },
        Source(name: "CoinGecko", url: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=" + Currencies.codes.joined(separator: ",").lowercased(), currencies: nil) { json, currency in
            RPCValue.double(((json as? [String: Any])?["bitcoin"] as? [String: Any])?[currency.lowercased()])
        },
        Source(name: "Yadio", url: "https://api.yadio.io/exrates/BTC", currencies: nil) { json, currency in
            RPCValue.double(((json as? [String: Any])?["BTC"] as? [String: Any])?[currency])
        },
        Source(name: "mempool.space", url: "http://mempoolhqx4isw62xs7abwphsq7ldayuidyx2v2oethdhhj6mlo2r6ad.onion/api/v1/prices",
               currencies: ["USD", "EUR", "GBP", "CAD", "CHF", "AUD", "JPY"]) { json, currency in
            RPCValue.double((json as? [String: Any])?[currency])
        },
        Source(name: "BitPay", url: "https://bitpay.com/api/rates", currencies: nil) { json, currency in
            RPCValue.double((json as? [[String: Any]])?.first { $0["code"] as? String == currency }?["rate"])
        },
        Source(name: "blockchain.info", url: "https://blockchain.info/ticker", currencies: nil) { json, currency in
            RPCValue.double(((json as? [String: Any])?[currency] as? [String: Any])?["15m"])
        }
    ]

    /// The last source that answered: asked first next time.
    private static let lastSourceKey = "fxLastSource"

    /// The rate over Tor. Waits (up to 2 minutes) for Tor to finish starting first: asked too
    /// early (e.g. when the wallet screen opens on a Nostr Connect node), the request would just
    /// fail. Then each source in turn until one answers, starting with the last one that did.
    func getFxRate(currency: String, completion: @escaping ((Double?)) -> Void) {
        whenTorConnected { [weak self] connected in
            guard let self = self else { return }
            guard connected else {
                print("[fx] Tor isn't connected: no exchange rate")
                completion(nil)
                return
            }
            let last = UserDefaults.standard.string(forKey: Self.lastSourceKey)
            let ordered = Self.sources.filter { $0.name == last } + Self.sources.filter { $0.name != last }
            self.tryNext(ordered.filter { $0.currencies?.contains(currency) ?? true }, currency: currency, completion: completion)
        }
    }

    private func tryNext(_ sources: [Source], currency: String, completion: @escaping (Double?) -> Void) {
        guard let source = sources.first else {
            print("[fx] no source answered for \(currency)")
            completion(nil)
            return
        }
        fetch(source.url) { [weak self] json in
            // A zero or negative "rate" is a broken answer, not a price.
            if let json = json, let rate = source.rate(json, currency), rate > 0 {
                UserDefaults.standard.set(source.name, forKey: Self.lastSourceKey)
                completion(rate)
                return
            }
            if json != nil { print("[fx] \(source.name) has no \(currency) rate") }
            self?.tryNext(Array(sources.dropFirst()), currency: currency, completion: completion)
        }
    }

    private func whenTorConnected(_ then: @escaping (Bool) -> Void) {
        switch torClient.state {
        case .connected:
            then(true)
        case .started, .refreshing:
            var token: NSObjectProtocol?
            var finished = false
            let finish: (Bool) -> Void = { connected in
                guard !finished else { return }
                finished = true
                if let token = token { NotificationCenter.default.removeObserver(token) }
                then(connected)
            }
            DispatchQueue.main.async {
                token = NotificationCenter.default.addObserver(forName: .torConnected, object: nil, queue: .main) { _ in finish(true) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 120) { [weak self] in finish(self?.torClient.state == .connected) }
            }
        default:
            then(false)
        }
    }

    private func fetch(_ urlString: String, completion: @escaping (Any?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        // Short enough that a slow source doesn't hold up the next one.
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        task = fxSession.dataTask(with: request) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode
            let json = status == 200 ? self?.fetchJson(data: data) : nil
            if json == nil {
                print("[fx] \(url.host ?? urlString) failed: \(status.map { "HTTP \($0)" } ?? error?.localizedDescription ?? "no data")")
            }
            completion(json)
        }
        task?.resume()
    }
    
    private func fetchJson(data: Data?) -> Any? {
        guard let data = data else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
