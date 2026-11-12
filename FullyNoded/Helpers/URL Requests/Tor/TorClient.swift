//
//  TorClient.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//
//

import Foundation
import Tor

protocol OnionManagerDelegate: AnyObject {
    func torConnProgress(_ progress: Int)
    func torConnFinished()
    func torConnDifficulties()
}

class TorClient: NSObject {
    
    enum TorState {
        case none
        case started
        case connected
        case stopped
    }
    
    public var state: TorState = .none
    public var cert:Data?
    
    static let sharedInstance = TorClient()
    private var config: TorConfiguration = TorConfiguration()
    private var thread: TorThread?
    private var controller: TorController?
    private var authDirPath = ""
    /// Attached to a Tor that was put to sleep by `pause`: wake it once authenticated.
    private var isResuming = false
    let urlSessionDelegate = UserCertURLSessionDelegate()
    
    /// What a connection through Tor is for. Each purpose has its own SOCKS port, and Tor never
    /// puts streams from different ports on one circuit, so a relay or server that sees one kind
    /// of traffic can't link it to the others.
    enum Purpose: Int, CaseIterable {
        /// RPC calls to your node's onion (`session`).
        case node
        /// Exchange rates.
        case exchangeRate
        /// Payjoin requests, and checking the receiver's own onion is up.
        case payjoin
        /// Esplora requests made with URLSession (BDK's client uses the HTTP tunnel, a listener
        /// of its own and so already apart).
        case esplora
    }

    /// Tor's first local SOCKS port, for `.node`; each other purpose uses the next one up.
    static var socksPort: Int {
        #if targetEnvironment(simulator)
        return 19052 + simulatorPortOffset
        #else
        return 19050
        #endif
    }

    static func socksPort(for purpose: Purpose) -> Int { socksPort + purpose.rawValue }

    /// A URLSessionConfiguration's `connectionProxyDictionary` for `purpose`.
    static func proxy(for purpose: Purpose) -> [AnyHashable: Any] {
        [kCFProxyTypeKey: kCFProxyTypeSOCKS,
         kCFStreamPropertySOCKSProxyHost: "localhost",
         kCFStreamPropertySOCKSProxyPort: socksPort(for: purpose)]
    }

    /// Tor's proxy settings for `purpose`, with the rest of `session`'s configuration.
    func configuration(for purpose: Purpose) -> URLSessionConfiguration {
        let configuration = session.configuration
        configuration.connectionProxyDictionary = Self.proxy(for: purpose)
        configuration.httpAdditionalHeaders = Self.anonymousHeaders
        return configuration
    }

    /// Sent with every request over Tor in place of iOS's own, which name the app, its build and
    /// the iOS version, and the device's languages. The same for every Fully Noded user, and
    /// nothing a server could tell apart from many other clients.
    static let anonymousHeaders: [AnyHashable: Any] = [
        "User-Agent": "Mozilla/5.0",
        "Accept-Language": "en"
    ]

    // MARK: Onion only

    /// Onion only, automatic for a node reached at its onion: while it's active, Tor refuses
    /// every destination but onion services on its SOCKS ports, and a payjoin is only tried with
    /// receivers that have an onion. Third-party APIs are onion services in any case. A local,
    /// LAN or Nostr Connect node isn't held to it.
    static var onionOnly: Bool { MakeRPCCall.sharedInstance.activeNodeIsOnion }

    /// Whether `url` may be fetched over Tor: anything, or with onion only an onion service.
    static func allows(_ url: URL?) -> Bool {
        !onionOnly || url?.host?.lowercased().hasSuffix(".onion") == true
    }

    /// The onion only state Tor's SOCKS ports are in.
    private var appliedOnionOnly: Bool?

    /// Brings Tor's SOCKS ports in line with `onionOnly`: when another node becomes active (or
    /// its address changes), and once Tor is up.
    func syncOnionOnly() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let controller = self.controller, controller.isConnected else { return }
            let wanted = Self.onionOnly
            guard wanted != self.appliedOnionOnly else { return }
            self.appliedOnionOnly = wanted
            self.applySocksPorts()
        }
    }

    /// Each SocksPort's value, with OnionTrafficOnly when onion only is on.
    private static var socksPortValues: [String] {
        Purpose.allCases.map { "\(socksPort(for: $0))" + (onionOnly ? " OnionTrafficOnly" : "") }
    }

    /// Reconfigures the running Tor's SOCKS ports for the onion only setting (Tor runs once per
    /// process, so it can't be restarted with new options). Started later, it reads the setting.
    /// The ports are closed first: Tor keeps a listener whose port didn't change, flags and all.
    private func applySocksPorts() {
        guard let controller = controller else { return }
        let ports = Self.socksPortValues.map { "SocksPort=\"\($0)\"" }
        let report: (String, [NSNumber], [Data]) -> Void = { step, codes, lines in
            if codes.first?.intValue != 250 {
                print("[tor] couldn't \(step) for onion only: \(lines.compactMap { String(data: $0, encoding: .utf8) })")
            }
        }
        controller.sendCommand("SETCONF", arguments: ["SocksPort=0"], data: nil) { codes, lines, stop -> Bool in
            stop.pointee = true
            report("close the SOCKS ports", codes, lines)
            controller.sendCommand("SETCONF", arguments: ports, data: nil) { codes, lines, stop -> Bool in
                stop.pointee = true
                report("reopen the SOCKS ports", codes, lines)
                return true
            }
            return true
        }
    }
    
    /// Tor's HTTP tunnel port (BDK's Esplora client tunnels through it).
    static var httpTunnelPort: Int { 9080 + simulatorPortOffset }
    
    /// Simulators share the Mac's ports: launch a second one with `-simTorPortOffset 10` so its
    /// Tor doesn't collide with the first's.
    private static var simulatorPortOffset: Int {
        #if targetEnvironment(simulator)
        return UserDefaults.standard.integer(forKey: "simTorPortOffset")
        #else
        return 0
        #endif
    }
    
    // The tor url session configuration.
    // Start with default config as fallback.
    private lazy var sessionConfiguration: URLSessionConfiguration = .default

    // The tor client url session including the tor configuration.
    lazy var session = URLSession(configuration: sessionConfiguration)
    
    // Start the tor client.
    func start(delegate: OnionManagerDelegate?) {
        weak var weakDelegate = delegate
        state = .started
        
        sessionConfiguration.connectionProxyDictionary = Self.proxy(for: .node)
        sessionConfiguration.httpAdditionalHeaders = Self.anonymousHeaders
        
        session = URLSession(configuration: sessionConfiguration, delegate: urlSessionDelegate, delegateQueue: .main)
        
        #if targetEnvironment(macCatalyst)
            // Code specific to Mac.
        #else
            // Code to exclude from Mac.
            session.configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        #endif
        
        //add V3 auth keys to ClientOnionAuthDir if any exist
        createTorDirectory()
        authDirPath = createAuthDirectory()
        
        clearAuthKeys { [weak self] in
            guard let self = self else { return }
            
            self.addAuthKeysToAuthDirectory {
                
                self.thread = nil

                // One SocksPort per purpose (options can only hold one value per key).
                self.config.arguments = NSMutableArray(array: Self.socksPortValues.flatMap { ["--SocksPort", $0] })
                self.appliedOnionOnly = Self.onionOnly
                self.config.options = [
                    "AutomapHostsOnResolve": "1",
                    "AvoidDiskWrites": "1",
                    "ClientOnionAuthDir": "\(self.authDirPath)",
                    "LearnCircuitBuildTimeout": "1",
                    "NumEntryGuards": "8",
                    "SafeSocks": "1",
                    "LongLivedPorts": "80,443",
                    "NumCPUs": "2",
                    "DisableDebuggerAttachment": "1",
                    "SafeLogging": "1",
                    "HTTPTunnelPort": "\(Self.httpTunnelPort)",
                    // Tor saves `pause`'s dormant state and would otherwise start dormant, never
                    // connecting, when iOS ended the app while it was paused.
                    "DormantCanceledByStartup": "1"
                ]
                
                self.config.cookieAuthentication = true
                self.config.dataDirectory = URL(fileURLWithPath: self.torPath())
                self.config.controlSocket = self.config.dataDirectory?.appendingPathComponent("cp")
                
                // Tor runs once per process (a second TorThread asserts, or aborts in Tor in
                // release builds). If the last one is still running, for example because an
                // earlier start gave up on the controller too soon, attach to it instead.
                if let running = TorThread.active, !running.isFinished {
                    self.thread = running
                    self.isResuming = true
                } else {
                    self.thread = TorThread(configuration: self.config)
                    self.thread?.start()
                }
                
                // Initiate the controller.
                if self.controller == nil {
                    self.controller = TorController(socketURL: self.config.controlSocket!)
                }
                
                self.connectController(delegate: weakDelegate, attempt: 0)
            }
        }
    }
    
    /// Connects the controller and authenticates with Tor's cookie. Tor writes its control socket
    /// and cookie a moment after it starts (longer on a busy device), so this retries for a while
    /// before reporting difficulties.
    private func connectController(delegate weakDelegate: OnionManagerDelegate?, attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            // Connect Tor controller.
            do {
                if !(self.controller?.isConnected ?? false) {
                    do {
                        try self.controller?.connect()
                    } catch {
                        print("error=\(error)")
                    }
                }
                
                let cookie: Data
                do {
                    cookie = try Data(
                        contentsOf: self.config.dataDirectory!.appendingPathComponent("control_auth_cookie"),
                        options: NSData.ReadingOptions(rawValue: 0)
                    )
                } catch {
                    if attempt < 10 {
                        self.connectController(delegate: weakDelegate, attempt: attempt + 1)
                        return
                    }
                    throw error
                }
                
                self.controller?.authenticate(with: cookie) { [weak self] (success, error) in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("error = \(error.localizedDescription)")
                        return
                    }
                    
                    if self.isResuming {
                        self.isResuming = false
                        self.wake(delegate: weakDelegate)
                    }
                    
                    var progressObs: Any? = nil
                    
                    progressObs = self.controller?.addObserver(forStatusEvents: { [weak self]
                        (type: String, severity: String, action: String, arguments: [String : String]?) -> Bool in
                        guard let self = self else { return false }
                        
                        guard let arguments = arguments, let progress = arguments["PROGRESS"], let progressInt = Int(progress) else { return false }
                        
                        weakDelegate?.torConnProgress(progressInt)
                        
                        if progressInt >= 100 {
                            self.controller?.removeObserver(progressObs)
                        }
                        
                        return true
                    })
                    
                    var observer: Any? = nil
                    observer = self.controller?.addObserver(forCircuitEstablished: { [weak self] established in
                        guard let self = self, established else { return }
                        self.controller?.removeObserver(observer)
                        // `wake` may have reported it already.
                        guard self.state != .connected else { return }
                        self.state = .connected
                        self.syncOnionOnly()
                        weakDelegate?.torConnFinished()
                    })
                }
            } catch {
                weakDelegate?.torConnDifficulties()
                self.state = .none
            }
        }
    }
    
    // MARK: - Onion services (payjoin receiving)
    
    struct OnionError: LocalizedError {
        let errorDescription: String?
        init(_ message: String) { errorDescription = message }
    }
    
    /// Hosts a one-time onion service: port 80 of a new v3 onion forwards to
    /// 127.0.0.1:`localPort` in this app. The key is discarded (`DiscardPK`), so the address
    /// can never be used again once removed. Completion on the main queue with "xxxx.onion".
    func addOnionService(localPort: UInt16, completion: @escaping (Result<String, Error>) -> Void) {
        let finish: (Result<String, Error>) -> Void = { result in DispatchQueue.main.async { completion(result) } }
        guard state == .connected, let controller = controller else {
            finish(.failure(OnionError("Tor isn't connected.")))
            return
        }
        controller.sendCommand("ADD_ONION",
                               arguments: ["NEW:ED25519-V3", "Flags=DiscardPK", "Port=80,127.0.0.1:\(localPort)"],
                               data: nil) { codes, lines, stop -> Bool in
            stop.pointee = true
            let text = lines.compactMap { String(data: $0, encoding: .utf8) }
            guard codes.first?.intValue == 250,
                  let id = text.first(where: { $0.hasPrefix("ServiceID=") })?.dropFirst("ServiceID=".count) else {
                finish(.failure(OnionError("Tor couldn't create an onion service: \(text.joined(separator: " "))")))
                return true
            }
            finish(.success("\(id).onion"))
            return true
        }
    }
    
    /// Stops hosting an onion created with `addOnionService`.
    func removeOnionService(_ host: String) {
        let id = host.replacingOccurrences(of: ".onion", with: "")
        controller?.sendCommand("DEL_ONION", arguments: [id], data: nil) { _, _, stop -> Bool in
            stop.pointee = true
            return true
        }
    }
    
    /// For the app going to the background: Tor sleeps, and stays running.
    ///
    /// Tor must never be shut down while the process lives. Its shutdown (`tor_free_all`) races
    /// with its own worker threads and aborts the app: a worker releases a mutex being destroyed
    /// (seen in `tor_mutex_release` and `worker_thread_has_work`). `TORController.disconnect()`
    /// is that shutdown, it sends SIGNAL SHUTDOWN, so don't call it. Releasing the controller
    /// only closes its connection. `start` attaches to the running Tor again.
    func pause() {
        if let controller = controller {
            self.controller = nil
            // The block keeps the controller until Tor has the signal.
            controller.sendCommand("SIGNAL DORMANT", arguments: nil, data: nil) { _, _, stop -> Bool in
                _ = controller
                stop.pointee = true
                return true
            }
        }
        thread = nil
        clearAuthKeys {}
        state = .stopped
    }
    
    /// Back from `pause`: the network may have changed while asleep, so reload (which also reads
    /// the onion auth keys again) and use new circuits.
    private func wake(delegate weakDelegate: OnionManagerDelegate?) {
        controller?.sendCommand("SIGNAL ACTIVE", arguments: nil, data: nil) { _, _, stop -> Bool in
            stop.pointee = true
            return true
        }
        controller?.resetConnection(nil)
        reportCircuit(delegate: weakDelegate, attempt: 0)
    }
    
    /// A Tor that already has a circuit never sends the "established" event a fresh start waits
    /// for, so ask it.
    private func reportCircuit(delegate weakDelegate: OnionManagerDelegate?, attempt: Int) {
        controller?.sendCommand("GETINFO", arguments: ["status/circuit-established"], data: nil) { _, lines, stop -> Bool in
            stop.pointee = true
            let established = lines.contains { String(data: $0, encoding: .utf8)?.hasSuffix("=1") == true }
            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.state == .started else { return }
                if established {
                    self.state = .connected
                    self.syncOnionOnly()
                    weakDelegate?.torConnFinished()
                } else if attempt < 30 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.reportCircuit(delegate: weakDelegate, attempt: attempt + 1)
                    }
                }
            }
            return true
        }
    }
    
    private func createTorDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: self.torPath(),
                                                    withIntermediateDirectories: true,
                                                    attributes: [FileAttributeKey.posixPermissions: 0o700])
        } catch {
            print("Directory previously created.")
        }
    }
    
    private func torPath() -> String {
        #if targetEnvironment(simulator)
            let path = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true).first ?? ""
            // One data directory per simulator (they share the Mac's home folder).
            let device = ProcessInfo.processInfo.environment["SIMULATOR_UDID"].map { "-\($0)" } ?? ""
            return "\(path.split(separator: Character("/"))[0..<2].joined(separator: "/"))/.tor_tmp\(device)"
        #else
            return "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "")/tor"
        #endif
    }

    private func createAuthDirectory() -> String {
        // Create tor v3 auth directory if it does not yet exist
        let authPath = URL(fileURLWithPath: self.torPath(), isDirectory: true).appendingPathComponent("onion_auth", isDirectory: true).path
        
        do {
            try FileManager.default.createDirectory(atPath: authPath,
                                                    withIntermediateDirectories: true,
                                                    attributes: [FileAttributeKey.posixPermissions: 0o700])
        } catch {
            print("Auth directory previously created.")
        }
        
        return authPath
    }
    
    private func addAuthKeysToAuthDirectory(completion: @escaping () -> Void) {
        
        CoreDataService.retrieveEntity(entityName: .authKeys) { authKeys in
            guard let authKeys = authKeys, authKeys.count > 0 else { completion(); return }
            
            let authKeysStr = AuthKeysStruct.init(dictionary: authKeys[0])
            let authorizedKey = decryptedValue(authKeysStr.privateKey)
            
            CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
                guard let self = self, let nodes = nodes, nodes.count > 0 else { completion(); return }
                
                for (i, nodeDict) in nodes.enumerated() {
                    let nodeStruct = NodeStruct(dictionary: nodeDict)
                    
                    if nodeStruct.isActive && nodeStruct.onionAddress != nil {
                        let onionAddress = decryptedValue(nodeStruct.onionAddress!)
                        let onionAddressArray = onionAddress.components(separatedBy: ".onion:")
                        // Ensure we are actually V3 before adding auth
                        guard onionAddressArray[0].count > 55 else { completion(); return }
                        
                        let authString = onionAddressArray[0] + ":descriptor:x25519:" + authorizedKey
                        let suffix = "\(randomString(length: 10)).auth_private"
                        
                        let file = URL(fileURLWithPath: self.authDirPath, isDirectory: true).appendingPathComponent(suffix)
                        
                        try? authString.write(to: file, atomically: true, encoding: .utf8)
                        
                        try? (file as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
                    }
                    
                    if i + 1 == nodes.count {
                        completion()
                    }
                }
            }
        }
    }
    
    private func clearAuthKeys(completion: @escaping () -> Void) {
        let fileManager = FileManager.default
        let authPath = self.authDirPath
        
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: authPath)
            
            for filePath in filePaths {
                let url = URL(fileURLWithPath: authPath + "/" + filePath)
                try fileManager.removeItem(at: url)
            }
            
            completion()
        } catch {
            
            completion()
        }
    }
    
}
