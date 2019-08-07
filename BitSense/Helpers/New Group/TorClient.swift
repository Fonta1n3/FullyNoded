//
//  TorClient.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import Tor

class TorClient {
    
    static let sharedInstance = TorClient()
    private var config: TorConfiguration = TorConfiguration()
    private var thread: TorThread!
    private var controller: TorController!
    
    // Client status?
    private(set) var isOperational: Bool = false
    private var isConnected: Bool {
        return self.controller.isConnected
    }
    
    // The tor url session configuration.
    // Start with default config as fallback.
    private var sessionConfiguration: URLSessionConfiguration = .default
    
    // The tor client url session including the tor configuration.
    var session: URLSession {
        return URLSession(configuration: sessionConfiguration)
    }
    
    private func setupThread() {
        
        config.options = [
            "DNSPort": "12345",
            "AutomapHostsOnResolve": "1",
            "AvoidDiskWrites": "1"
        ]
        config.cookieAuthentication = true
        config.dataDirectory = URL(fileURLWithPath: self.createTorDirectory())
        config.controlSocket = config.dataDirectory?.appendingPathComponent("cp")
        config.arguments = [
            "--allow-missing-torrc",
            "--ignore-missing-torrc",
            "--clientonly", "1",
            "--socksport", "39050",
            "--controlport", "127.0.0.1:39060",
        ]
        
        thread = TorThread(configuration: config)
    }
    
    // Start the tor client.
    func start(completion: @escaping () -> Void) {
        // If already operational don't start a new client.
        if isOperational || turnedOff() {
            return completion()
        }
        
        // Make sure we don't have a thread already.
        if thread == nil {
            setupThread()
        }
        
        // Initiate the controller.
        controller = TorController(socketURL: config.controlSocket!)
        //controller = TorController(socketHost: "127.0.0.1", port: 39060)
        
        // Start a tor thread.
        if thread.isExecuting == false {
            thread.start()
            
            //NotificationCenter.default.post(name: .didStartTorThread, object: self)
            print("tor thread started")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // Connect Tor controller.
            self.connectController(completion: completion)
        }
    }
    
    // Resign the tor client.
    func restart() {
        resign()
        
        if !isOperational {
            return
        }
        
        while controller.isConnected {
            print("Disconnecting Tor...")
        }
        
        //NotificationCenter.default.post(name: .didResignTorConnection, object: self)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.start {
                //NotificationCenter.default.post(name: .didConnectTorController, object: self)
                print("tor controller connected")
            }
        }
    }
    
    func resign() {
        if !isOperational {
            return
        }
        
        self.controller.disconnect()
        
        self.isOperational = false
        self.thread = nil
        self.sessionConfiguration = .default
        
        //NotificationCenter.default.post(name: .didTurnOffTor, object: self)
    }
    
    private func connectController(completion: @escaping () -> Void) {
        do {
            if !self.controller.isConnected {
                try self.controller?.connect()
                //NotificationCenter.default.post(name: .didConnectTorController, object: self)
                print("tor controller connected")
            }
            
            try self.authenticateController {
                print("Tor tunnel started! 🤩")
                //TORInstallEventLogging()
                //TORInstallTorLogging()
                //NotificationCenter.default.post(name: .didEstablishTorConnection, object: self)
                
                completion()
            }
        } catch {
            //NotificationCenter.default.post(name: .errorDuringTorConnection, object: error)
            print("error connecting tor controller")
            
            completion()
        }
    }
    
    private func authenticateController(completion: @escaping () -> Void) throws -> Void {
        let cookie = try Data(
            contentsOf: config.dataDirectory!.appendingPathComponent("control_auth_cookie"),
            options: NSData.ReadingOptions(rawValue: 0)
        )
        
        self.controller?.authenticate(with: cookie) { success, error in
            if let error = error {
                return print(error.localizedDescription)
            }
            
            var observer: Any? = nil
            observer = self.controller?.addObserver(forCircuitEstablished: { established in
                guard established else {
                    return
                }
                
                self.controller?.getSessionConfiguration() { sessionConfig in
                    self.sessionConfiguration = sessionConfig!
                    
                    self.isOperational = true
                    completion()
                }
                
                self.controller?.removeObserver(observer)
            })
        }
    }
    
    private func createTorDirectory() -> String {
        
        let torPath = self.getTorPath()
        
        do {
            
            try FileManager.default.createDirectory(atPath: torPath, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.posixPermissions: 0o700
                ])
            
        } catch {
            
            print("Directory previously created. 🤷‍♀️")
            
        }
        
        return torPath
    }
    
    private func getTorPath() -> String {
        
        var torDirectory = ""
        
        #if targetEnvironment(simulator)
        print("is simulator")
        
        let path = NSSearchPathForDirectoriesInDomains(.applicationDirectory, .userDomainMask, true).first ?? ""
        torDirectory = "\(path.split(separator: Character("/"))[0..<2].joined(separator: "/"))/.tor_tmp"
        
        #else
        print("is device")
        
        //torDirectory = "\(NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first ?? "")/t"
        torDirectory = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "")/tor"
        
        #endif
        
        return torDirectory
        
    }
    
    func turnedOff() -> Bool {
        return false//!self.applicationRepository.useTor
    }
}
