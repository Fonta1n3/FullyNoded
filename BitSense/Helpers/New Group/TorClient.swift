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
    
    // Start the tor client.
    func start(completion: @escaping () -> Void) {
        
        let queue = DispatchQueue(label: "com.FullyNoded.torQueue")
        
        queue.async {
            
            // If already operational don't start a new client.
            if self.isOperational || self.turnedOff() {
                return completion()
            }
            
            // Make sure we don't have a thread already.
            if self.thread == nil {
                
                self.config.options = ["DNSPort": "12345", "AutomapHostsOnResolve": "1", "SocksPort": "9050", "AvoidDiskWrites": "1"]
                self.config.cookieAuthentication = true
                self.config.dataDirectory = URL(fileURLWithPath: self.createTorDirectory())
                self.config.controlSocket = self.config.dataDirectory?.appendingPathComponent("cp")
                self.config.arguments = [
                    "--ignore-missing-torrc",
                    "--ClientOnionAuthDir", self.createAuthDirectory()
                    ]
                
                self.thread = TorThread(configuration: self.config)
                
            }
            
            //add V3 auth keys to ClientOnionAuthDir if any exist
            self.addAuthKeysToAuthDirectory()
            
            // Initiate the controller.
            self.controller = TorController(socketURL: self.config.controlSocket!)
            
            // Start a tor thread.
            if self.thread.isExecuting == false {
                
                self.thread.start()
                print("tor thread started")
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                // Connect Tor controller.
                self.connectController(completion: completion)
            }
            
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.start {
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
        
    }
    
    private func connectController(completion: @escaping () -> Void) {
        do {
            if !self.controller.isConnected {
                try self.controller?.connect()
                print("tor controller connected")
            }
            
            try self.authenticateController {
                print("Tor tunnel started!")
                //TORInstallEventLogging()
                //TORInstallTorLogging()
                //NotificationCenter.default.post(name: .didEstablishTorConnection, object: self)
                
                completion()
            }
        } catch {
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
            
            print("Directory previously created.")
            
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
        
        torDirectory = "\(NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first ?? "")/tor"
        
        #endif
        
        return torDirectory
        
    }
    
    private func createAuthDirectory() -> String {
        
        // Create tor v3 auth directory if it does not yet exist
        let authPath = URL(fileURLWithPath: getTorPath(), isDirectory: true).appendingPathComponent("auth", isDirectory: true).path
        
        do {
            
            try FileManager.default.createDirectory(atPath: authPath, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.posixPermissions: 0o700
                ])
            
        } catch {
            
            print("Auth directory previously created.")
            
        }
        
        return authPath
        
    }
    
    private func addAuthKeysToAuthDirectory() {
        
        clearAuthKeys()
        let authPath = createTorDirectory()
        let cd = CoreDataService()
        let nodes = cd.retrieveEntity(entityName: .nodes)
        let aes = AESService()
        
        for nodeDict in nodes {
            
            let str = NodeStruct(dictionary: nodeDict)
            let id = str.id
            
            if str.authKey != "" {
                
                //y34f3abl2bou6subajlosasumupsli2oq7chfo3oqfqznuedqhzfr5yd:descriptor:x25519:NQ2IJRNRZWPKVJNGWV7N6KJFUS235N27IP5NZ7UAXMXWUMILNLJA
                let authorizedKey = aes.decryptKey(keyToDecrypt: str.authKey)
                let onionAddress = aes.decryptKey(keyToDecrypt: str.onionAddress)
                let onionAddressArray = onionAddress.components(separatedBy: ".onion:")
                let authString = onionAddressArray[0] + ":descriptor:x25519:" + authorizedKey
                
                let file = URL(fileURLWithPath: authPath, isDirectory: true).appendingPathComponent("\(id).auth_private")
                
                do {
                    
                    try authString.write(to: file, atomically: true, encoding: .utf8)
                    
                    print("successfully wrote authkey to file")
                    print("key = \(authString)")
                    
                } catch {
                    
                    print("failed writing auth key")
                }
                
            }
            
        }
        
    }
    
    private func clearAuthKeys() {
        
        //removes all authkeys
        let fileManager = FileManager.default
        let authPath = createTorDirectory()
        
        do {
            
            let filePaths = try fileManager.contentsOfDirectory(atPath: authPath)
            
            for filePath in filePaths {
                
                try fileManager.removeItem(atPath: authPath + filePath)
                
            }
            
        } catch {
            
            print("error deleting existing keys")
            
        }
        
    }
    
    func turnedOff() -> Bool {
        return false
    }
}
