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
    
    /// The rate over Tor. Waits (up to 2 minutes) for Tor to finish starting first: asked too
    /// early (e.g. when the wallet screen opens on a Nostr Connect node), the request would just
    /// fail. blockchain.info first, then mempool.space if that doesn't answer.
    func getFxRate(currency: String, completion: @escaping ((Double?)) -> Void) {
        whenTorConnected { [weak self] connected in
            guard let self = self else { return }
            guard connected else {
                print("[fx] Tor isn't connected: no exchange rate")
                completion(nil)
                return
            }
            self.fetchBlockchainInfo(currency: currency) { rate in
                if let rate = rate { completion(rate); return }
                self.fetchMempoolSpace(currency: currency, completion: completion)
            }
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

    private func fetchBlockchainInfo(currency: String, completion: @escaping (Double?) -> Void) {
        fetch("https://blockchain.info/ticker") { json in
            completion((json?[currency] as? [String: Any])?["15m"] as? Double)
        }
    }

    /// mempool.space's prices (USD, EUR, GBP, CAD, CHF, AUD, JPY).
    private func fetchMempoolSpace(currency: String, completion: @escaping (Double?) -> Void) {
        fetch("https://mempool.space/api/v1/prices") { json in
            completion((json?[currency] as? NSNumber)?.doubleValue)
        }
    }

    private func fetch(_ urlString: String, completion: @escaping ([String: Any]?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        task = torClient.session.dataTask(with: url) { [weak self] data, response, error in
            let json = self?.fetchJson(data: data)
            if json == nil {
                let status = (response as? HTTPURLResponse)?.statusCode
                print("[fx] \(url.host ?? urlString) failed: \(status.map { "HTTP \($0)" } ?? error?.localizedDescription ?? "no data")")
            }
            completion(json)
        }
        task?.resume()
    }
    
    private func fetchJson(data: Data?) -> [String: Any]? {
        guard let urlContent = data, let json = try? JSONSerialization.jsonObject(with: urlContent, options: [.mutableContainers]) as? [String : Any] else {
            return nil
        }
        return json
    }
}
