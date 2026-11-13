//
//  NostrRPC.swift
//  FullyNoded
//
//  Nostr Connect client: sends Bitcoin Core RPC requests to Fully Noded Server through nostr
//  relays (see NostrConnect.swift) and returns Core's raw HTTP status and body, so MakeRPCCall
//  handles them exactly like a direct HTTP response.
//
//  It keeps a WebSocket open to every relay in the pairing link and publishes each request to
//  all connected ones; the server answers the first copy it sees and the first complete answer
//  wins.
//
//  Delivery: requests are compressed and split into small frames, sent paced. The server acks a
//  complete request; with neither an ack nor any of the answer after a few seconds the request
//  is sent again (the server ignores duplicates, or resends its stored answer). Either side asks
//  for frames missing from a stalled message, and events a relay rate-limits are retried.
//

import Foundation

final class NostrRPC: NSObject {
    static let shared = NostrRPC()

    enum Failure: Error, LocalizedError {
        case invalidLink, noRelay(String), timeout, bridge(String)

        var errorDescription: String? {
            switch self {
            case .invalidLink: return "This node's Nostr Connect details are invalid. Pair it again in Fully Noded Server."
            case .noRelay(let reason): return "Couldn't reach a Nostr Connect relay: \(reason)"
            case .timeout: return "No response from Fully Noded Server over Nostr Connect. Check that it's running and the relay is reachable."
            case .bridge(let message): return message
            }
        }
    }

    private let queue = DispatchQueue(label: "FullyNoded.NostrRPC")
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    // Current pairing (one active node at a time).
    private var uri: NostrConnectURI?
    private var keys: NostrKeys?
    private var conversationKey: Data?
    private var relays: [String: Relay] = [:]
    private let reassembler = NostrRPCReassembler()
    /// Request frames, kept until answered so missing ones can be sent again.
    private let outbox = NostrRPCOutbox()
    private var pending: [String: Pending] = [:]
    /// Requests waiting for a relay to connect.
    private var waitingForRelay: [() -> Void] = []
    /// Events sent and not yet accepted, for retrying ones a relay turns away.
    private var unconfirmed: [String: (message: [Any], relay: Relay, attempts: Int, sent: Date)] = [:]
    private var tickScheduled = false

    /// Sending the whole request again when nothing came back: this many times at most.
    private static let maxRequestResends = 3

    private struct Pending {
        let completion: (Result<(status: Int, body: Data), Error>) -> Void
        let timer: DispatchWorkItem
        /// The server confirmed it has the whole request.
        var acked = false
        var resends = 0
    }

    private final class Relay {
        let url: String
        let task: URLSessionWebSocketTask
        var open = false
        var lastError: String?
        init(url: String, task: URLSessionWebSocketTask) { self.url = url; self.task = task }
    }

    private override init() {}

    /// Sends one JSON-RPC body. Completion runs on a background queue.
    func send(body: Data, path: String, timeout: TimeInterval, link: String,
              completion: @escaping (Result<(status: Int, body: Data), Error>) -> Void) {
        queue.async {
            guard self.configure(link: link), self.keys != nil, self.uri != nil, self.conversationKey != nil else {
                completion(.failure(Failure.invalidLink))
                return
            }
            let id = UUID().uuidString
            let timer = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.log("request \(id.prefix(8)) timed out\(self.pending[id]?.acked == true ? " (the server had it)" : "")")
                self.finish(id, .failure(Failure.timeout))
            }
            self.pending[id] = Pending(completion: completion, timer: timer)
            self.queue.asyncAfter(deadline: .now() + timeout + 5, execute: timer)

            let frames = NostrRPCFrame.frames(id: id, body: body, path: path, timeout: timeout)
            self.outbox.store(id, frames)
            self.log("request \(id.prefix(8)): \(body.count) bytes in \(frames.count) frame\(frames.count == 1 ? "" : "s")\(frames.first?.deflate == true ? " (compressed)" : "")")

            self.whenConnected { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.finish(id, .failure(Failure.noRelay(error)))
                    return
                }
                self.publish(frames)
                self.checkAck(id, after: 4 + Double(frames.count) * 0.05)
                self.scheduleTick()
            }
        }
    }

    /// Drops connections, e.g. when the active node changes.
    func reset() {
        queue.async {
            self.relays.values.forEach { $0.task.cancel(with: .normalClosure, reason: nil) }
            self.relays.removeAll()
            self.unconfirmed.removeAll()
            self.uri = nil
            self.keys = nil
            self.conversationKey = nil
        }
    }

    // MARK: Private (on `queue`)

    private func configure(link: String) -> Bool {
        if let uri = uri, uri.string == link || NostrConnectURI(link) == uri { return true }
        relays.values.forEach { $0.task.cancel(with: .normalClosure, reason: nil) }
        relays.removeAll()
        guard let parsed = NostrConnectURI(link), let keys = NostrKeys(secretHex: parsed.clientSecret),
              let ck = try? NIP44.conversationKey(secret: keys.secret, publicKey: parsed.bridgePubkey) else {
            uri = nil
            return false
        }
        uri = parsed
        self.keys = keys
        conversationKey = ck
        return true
    }

    /// Encrypts and publishes frames to every open relay, paced a little after the first few so
    /// a public relay doesn't rate-limit the burst. Each publish is a fresh event, so a relay
    /// that remembers event ids won't swallow a resend.
    private func publish(_ frames: [NostrRPCFrame]) {
        for (i, frame) in frames.enumerated() {
            let send = { [weak self] in
                guard let self = self, let keys = self.keys, let uri = self.uri, let conversationKey = self.conversationKey,
                      let json = try? JSONEncoder().encode(frame),
                      let content = try? NIP44.encrypt(json, conversationKey: conversationKey),
                      let event = NostrEvent.make(keys: keys, kind: NostrEvent.rpcKind,
                                                  tags: [["p", uri.bridgePubkey]], content: content) else { return }
                let message: [Any] = ["EVENT", event.jsonObject]
                for relay in self.relays.values where relay.open {
                    self.unconfirmed[event.id] = (message, relay, 0, Date())
                    self.write(message, to: relay)
                }
            }
            if i < 8 {
                send()
            } else {
                queue.asyncAfter(deadline: .now() + Double(i - 7) * 0.05, execute: send)
            }
        }
    }

    /// No ack and no answer yet: send the whole request again (a few times, backing off).
    private func checkAck(_ id: String, after delay: TimeInterval) {
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, var p = self.pending[id], !p.acked, !self.reassembler.hasStarted(id) else { return }
            guard p.resends < Self.maxRequestResends else { return }
            p.resends += 1
            self.pending[id] = p
            let frames = self.outbox.frames(id)
            self.log("no ack for \(id.prefix(8)) after \(Int(delay)) s, sending it again (\(p.resends)/\(Self.maxRequestResends))")
            self.whenConnected { [weak self] error in
                guard let self = self, error == nil else { return }
                self.publish(frames)
            }
            self.checkAck(id, after: delay * 2)
        }
    }

    /// Once a second while requests are pending: ask for frames missing from stalled answers.
    private func scheduleTick() {
        guard !tickScheduled else { return }
        tickScheduled = true
        queue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            self.tickScheduled = false
            for stalled in self.reassembler.stalled(after: 2) where self.pending[stalled.id] != nil {
                self.log("answer to \(stalled.id.prefix(8)) stalled, asking for \(stalled.missing.count) missing frame(s)")
                self.publish([.resend(id: stalled.id, seqs: stalled.missing)])
            }
            let now = Date()
            self.unconfirmed = self.unconfirmed.filter { now.timeIntervalSince($0.value.sent) < 120 }
            if !self.pending.isEmpty { self.scheduleTick() }
        }
    }

    /// Runs `action` once at least one relay is open (opening them if needed), or with an error
    /// after a few seconds without one.
    private func whenConnected(_ action: @escaping (String?) -> Void) {
        if relays.values.contains(where: { $0.open }) {
            action(nil)
            return
        }
        guard let uri = uri else { action("no pairing"); return }
        for url in uri.relays where relays[url] == nil {
            guard let u = URL(string: url) else { continue }
            let task = session.webSocketTask(with: u)
            task.maximumMessageSize = 8 * 1024 * 1024
            let relay = Relay(url: url, task: task)
            relays[url] = relay
            task.resume()
            receive(relay)
        }
        var done = false
        waitingForRelay.append {
            guard !done else { return }
            done = true
            action(nil)
        }
        queue.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self = self, !done else { return }
            done = true
            let reasons = self.relays.values.compactMap { $0.lastError.map { "\($0)" } }
            action(reasons.first ?? "timed out connecting to \(uri.relays.joined(separator: ", "))")
        }
    }

    private func didOpen(_ relay: Relay) {
        relay.open = true
        relay.lastError = nil
        log("relay open: \(relay.url)")
        guard let uri = uri, let keys = keys else { return }
        let filter: [String: Any] = ["kinds": [NostrEvent.rpcKind], "authors": [uri.bridgePubkey],
                                     "#p": [keys.publicKey], "since": Int(Date().timeIntervalSince1970) - 60]
        write(["REQ", "fn-rpc", filter], to: relay)
        let waiting = waitingForRelay
        waitingForRelay.removeAll()
        waiting.forEach { $0() }
    }

    private func didClose(_ relay: Relay, _ reason: String) {
        if relay.open { log("relay closed: \(relay.url) (\(reason))") }
        relay.open = false
        relay.lastError = reason
        if relays[relay.url] === relay { relays[relay.url] = nil }
    }

    private func write(_ message: [Any], to relay: Relay) {
        guard let data = try? JSONSerialization.data(withJSONObject: message, options: [.withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return }
        relay.task.send(.string(text)) { [weak self] error in
            guard let self = self, let error = error else { return }
            self.queue.async { self.didClose(relay, error.localizedDescription) }
        }
    }

    private func receive(_ relay: Relay) {
        relay.task.receive { [weak self] result in
            guard let self = self else { return }
            self.queue.async {
                switch result {
                case .failure(let error):
                    self.didClose(relay, error.localizedDescription)
                case .success(let message):
                    var data: Data?
                    switch message {
                    case .string(let s): data = s.data(using: .utf8)
                    case .data(let d): data = d
                    @unknown default: break
                    }
                    if let data = data, let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                        self.handle(array)
                    }
                    self.receive(relay)
                }
            }
        }
    }

    private func handle(_ message: [Any]) {
        if message.first as? String == "OK" {
            handleOK(message)
            return
        }
        guard message.first as? String == "EVENT", message.count >= 3,
              let event = NostrEvent(json: message[2]), let uri = uri, let keys = keys,
              let conversationKey = conversationKey,
              event.kind == NostrEvent.rpcKind, event.pubkey == uri.bridgePubkey,
              event.recipient == keys.publicKey, event.isValid,
              let plaintext = try? NIP44.decrypt(event.content, conversationKey: conversationKey),
              let frame = try? JSONDecoder().decode(NostrRPCFrame.self, from: plaintext),
              pending[frame.id] != nil else { return }

        if frame.ack == true {
            if pending[frame.id]?.acked == false { log("server has request \(frame.id.prefix(8))") }
            pending[frame.id]?.acked = true
            return
        }
        if let seqs = frame.resend {
            log("server asked again for \(seqs.count) frame(s) of \(frame.id.prefix(8))")
            publish(outbox.frames(frame.id, seqs: seqs))
            return
        }

        // Any of the answer means the server had the request.
        pending[frame.id]?.acked = true
        guard let (first, body) = reassembler.add(frame) else { return }
        log("answer to \(first.id.prefix(8)): \(body.count) bytes in \(first.total) frame\(first.total == 1 ? "" : "s")\(first.deflate == true ? " (compressed)" : "")")
        if first.status == 0 || first.status == nil {
            finish(first.id, .failure(Failure.bridge(first.error ?? "Fully Noded Server couldn't reach Bitcoin Core.")))
        } else {
            finish(first.id, .success((first.status ?? 0, body)))
        }
    }

    /// A relay's answer to a published event: retry the ones it turned away for now.
    private func handleOK(_ message: [Any]) {
        guard message.count >= 3, let id = message[1] as? String, let accepted = message[2] as? Bool else { return }
        guard !accepted, let entry = unconfirmed[id] else {
            unconfirmed[id] = nil
            return
        }
        let reason = message.count > 3 ? (message[3] as? String ?? "") : ""
        let transient = reason.hasPrefix("rate-limited") || reason.hasPrefix("error")
        guard transient, entry.attempts < 3 else {
            unconfirmed[id] = nil
            log("relay \(entry.relay.url) rejected an event: \(reason)")
            return
        }
        unconfirmed[id] = (entry.message, entry.relay, entry.attempts + 1, entry.sent)
        let delay = Double(1 << entry.attempts)
        log("relay \(entry.relay.url) said \"\(reason)\", retrying in \(Int(delay)) s")
        queue.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, entry.relay.open else { return }
            self.write(entry.message, to: entry.relay)
        }
    }

    private func finish(_ id: String, _ result: Result<(status: Int, body: Data), Error>) {
        guard let p = pending.removeValue(forKey: id) else { return }
        p.timer.cancel()
        outbox.forget(id)
        reassembler.forget(id)
        p.completion(result)
    }

    /// Console log for Nostr Connect (debug builds only).
    private func log(_ message: @autoclosure () -> String) {
        #if DEBUG
        print("[nostr-rpc] \(message())")
        #endif
    }
}

extension NostrRPC: URLSessionWebSocketDelegate {
    /// Public relays: normal TLS validation. Fully Noded Server's own relay: exactly the
    /// self-signed certificate pinned in the pairing link.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let pin = queue.sync { uri?.certSHA256 }
        let (disposition, credential) = NostrTLS.evaluate(challenge, pin: pin)
        if disposition == .cancelAuthenticationChallenge { log("TLS refused for \(challenge.protectionSpace.host): certificate not trusted or not the pinned one") }
        completionHandler(disposition, credential)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        queue.async { [weak self] in
            guard let self = self, let relay = self.relays.values.first(where: { $0.task === webSocketTask }) else { return }
            self.didOpen(relay)
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        queue.async { [weak self] in
            guard let self = self, let relay = self.relays.values.first(where: { $0.task === webSocketTask }) else { return }
            self.didClose(relay, "closed by the relay")
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        queue.async { [weak self] in
            guard let self = self, let relay = self.relays.values.first(where: { $0.task === task }) else { return }
            self.didClose(relay, error?.localizedDescription ?? "disconnected")
        }
    }
}
