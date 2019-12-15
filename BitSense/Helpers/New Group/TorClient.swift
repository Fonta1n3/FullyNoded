//
//  TorClient.swift
//  BitSense
//
//  Created by Peter on 12/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//  Copyright © 2018 Verge Currency.
//

import Foundation
import Tor
import UIKit

class TorClient {
    
    static let sharedInstance = TorClient()
    private var config: TorConfiguration = TorConfiguration()
    private var thread: TorThread!
    private var controller: TorController!
    private var authDirPath = ""
    private var torDirPath = ""
    private var v2Auth = ""
    var isRefreshing = false
    
    // Client status?
    private(set) var isOperational: Bool = false
    private var isConnected: Bool {
        return self.controller.isConnected
    }
    
    // The tor url session configuration.
    // Start with default config as fallback.
    private lazy var sessionConfiguration: URLSessionConfiguration = .default

    // The tor client url session including the tor configuration.
    lazy var session = URLSession(configuration: sessionConfiguration)

    // Start the tor client.
    func start(completion: @escaping () -> Void) {
        print("start")
        
        let queue = DispatchQueue(label: "com.FullyNoded.torQueue")
        
        queue.async {
            
            // If already operational don't start a new client.
            if self.isOperational || self.turnedOff() {
                print("return completion")
                return completion()
            }
            
            //add V3 auth keys to ClientOnionAuthDir if any exist
            let torDir = self.createTorDirectory()
            self.authDirPath = self.createAuthDirectory()
            
            self.clearAuthKeys {
                
                self.addAuthKeysToAuthDirectory {
                    
                    //check if it is V2 or not
                    //HidServAuth 1234567890abcdefg.onion abcdef01234567890+/K
                    
                    // Make sure we don't have a thread already.
                    if self.thread == nil {
                        
                        print("thread is nil")
                        
                        self.isOperational = true
                        
                        self.config.options = [
                            
                            "DNSPort": "12345",
                            "AutomapHostsOnResolve": "1",
                            "SocksPort": "19050",
                            "AvoidDiskWrites": "1",
                            "ClientOnionAuthDir": "\(self.authDirPath)",
                            "HidServAuth": "\(self.v2Auth)",
                            "HardwareAccel": "1",
                            "LearnCircuitBuildTimeout": "1",
                            "NumEntryGuards": "8",
                            "SafeSocks": "1",
                            "LongLivedPorts": "80,443",
                            "NumCPUs": "2"
                            
                        ]
                        
                        self.config.cookieAuthentication = true
                        self.config.dataDirectory = URL(fileURLWithPath: torDir)
                        self.config.controlSocket = self.config.dataDirectory?.appendingPathComponent("cp")
                        self.config.arguments = ["--ignore-missing-torrc"]
                        self.thread = TorThread(configuration: self.config)
                        
                    } else {
                        
                        print("thread is not nil")
                        
                    }
                    
                    // Initiate the controller.
                    self.controller = TorController(socketURL: self.config.controlSocket!)
                    
                    // Start a tor thread.
                    if self.thread.isExecuting == false {
                        
                        self.thread.start()
                        print("tor thread started")
                        
                    } else {
                        
                        print("thread isExecuting true")
                        
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        // Connect Tor controller.
                        self.connectController(completion: completion)
                    }
                    
                }
                
            }
            
        }
        
    }
    
    // Resign the tor client.
    func restart(completion: @escaping () -> Void) {
        print("restart")
        
        resign()
        
        while controller.isConnected {
            print("Disconnecting Tor...")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.start(completion: completion)
        }
        
    }
    
    func resign() {
        print("resign")
        
        isRefreshing = true
        self.controller.disconnect()
        self.isOperational = false
        self.thread = nil
        
    }
    
    private func connectController(completion: @escaping () -> Void) {
        print("connectController")
        do {
            if !self.controller.isConnected {
                try self.controller?.connect()
                print("tor controller connected")
            }
            
            try self.authenticateController {
                print("authenticateController")
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
        print("authenticateController")
        
        let cookie = try Data(
            contentsOf: config.dataDirectory!.appendingPathComponent("control_auth_cookie"),
            options: NSData.ReadingOptions(rawValue: 0)
        )
        print("getcookie")
        
        self.controller?.authenticate(with: cookie) { success, error in
            
            if let error = error {
                
                print("error = \(error.localizedDescription)")
                return
                
            }
            
            var observer: Any? = nil
            observer = self.controller?.addObserver(forCircuitEstablished: { established in
                
                if established {
                    
                    print("observer added")
                    self.controller?.getSessionConfiguration() { sessionConfig in
                        print("getsessionconfig")
                        
//                        /*
//                         NSInteger socksProxyPort = 12345;
//
//                         NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
//                         config.connectionProxyDictionary = @{
//                             (NSString *)kCFProxyTypeKey: (NSString *)kCFProxyTypeSOCKS,
//                             (NSString *)kCFStreamPropertySOCKSProxyHost: @"localhost",
//                             (NSString *)kCFStreamPropertySOCKSProxyPort: [NSNumber numberWithInteger: socksProxyPort]
//                         };
//                         */
//
                        self.sessionConfiguration.connectionProxyDictionary = [kCFProxyTypeKey: kCFProxyTypeSOCKS, kCFStreamPropertySOCKSProxyHost: "localhost", kCFStreamPropertySOCKSProxyPort: 19050]
                        
                        //self.sessionConfiguration = sessionConfig!
                        //print("sessionConfig = \(sessionConfig!.connectionProxyDictionary!.description)")
                        self.session = URLSession(configuration: self.sessionConfiguration)
                        self.isOperational = true
                        completion()
                    }
                    
                    self.controller?.removeObserver(observer)
                    
                } else if self.isRefreshing {

                    print("observer added")
                    self.controller?.getSessionConfiguration() { sessionConfig in
                        print("getsessionconfig")
                        
                        print("isestablished = \(established)")

                        self.sessionConfiguration = sessionConfig!
                        self.session = URLSession(configuration: self.sessionConfiguration)
                        self.isOperational = true
                        completion()
                    }

                    self.controller?.removeObserver(observer)

                }
                
            })
            
        }
        
    }
    
    private func createTorDirectory() -> String {
        print("createTorDirectory")
        
        torDirPath = self.getTorPath()
        
        do {
            
            try FileManager.default.createDirectory(atPath: torDirPath, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.posixPermissions: 0o700
                ])
            
        } catch {
            
            print("Directory previously created.")
            
        }
        
        return torDirPath
    }
    
    private func getTorPath() -> String {
        print("getTorPath")
        
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
        print("createAuthDirectory")
        
        // Create tor v3 auth directory if it does not yet exist
        let authPath = URL(fileURLWithPath: self.torDirPath, isDirectory: true).appendingPathComponent("onion_auth", isDirectory: true).path
        
        do {
            
            try FileManager.default.createDirectory(atPath: authPath, withIntermediateDirectories: true, attributes: [
                FileAttributeKey.posixPermissions: 0o700
                ])
            
        } catch {
            
            print("Auth directory previously created.")
            
        }
        
        return authPath
        
    }
    
    private func addAuthKeysToAuthDirectory(completion: @escaping () -> Void) {
        print("addAuthKeysToAuthDirectory")
        
        let authPath = self.authDirPath
        let cd = CoreDataService()
        cd.retrieveEntity(entityName: .nodes) {
            
            if !cd.errorBool {
                
                let nodes = cd.entities
                let aes = AESService()
                
                for nodeDict in nodes {
                    
                    let str = NodeStruct(dictionary: nodeDict)
                    let id = str.id
                    
                    if str.isActive && str.authKey != "" {
                        
                        let authorizedKey = aes.decryptKey(keyToDecrypt: str.authKey)
                        let onionAddress = aes.decryptKey(keyToDecrypt: str.onionAddress)
                        let onionAddressArray = onionAddress.components(separatedBy: ".onion:")
                        let authString = onionAddressArray[0] + ":descriptor:x25519:" + authorizedKey
                        let file = URL(fileURLWithPath: authPath, isDirectory: true).appendingPathComponent("\(id).auth_private")
                        
                        do {
                            
                            try authString.write(to: file, atomically: true, encoding: .utf8)
                            
                            print("successfully wrote authkey to file")
                            //completion()
                                                
                        } catch {
                            
                            print("failed writing auth key")
                            //completion()
                        }
                        
                        
                    } else if str.isActive && str.v2password != "" {
                        
                        let onionAddress = aes.decryptKey(keyToDecrypt: str.onionAddress)
                        let onionAddressArr = onionAddress.components(separatedBy: ":")
                        let hostname = onionAddressArr[0]
                        let v2pass = aes.decryptKey(keyToDecrypt: str.v2password)
                        self.v2Auth = "\(hostname) \(v2pass)"
                        print("v2auth = \(self.v2Auth)")
                        //completion()
                        
                    }
                    
                }
                
                completion()
                
            } else {
                
                completion()
                print("error fetching nodes")
                
            }
            
        }
        
    }
    
    private func clearAuthKeys(completion: @escaping () -> Void) {
        
        //removes all authkeys
        let fileManager = FileManager.default
        let authPath = self.authDirPath
        
        do {
            
            let filePaths = try fileManager.contentsOfDirectory(atPath: authPath)
            
            for filePath in filePaths {
                
                let url = URL(fileURLWithPath: authPath + "/" + filePath)
                try fileManager.removeItem(at: url)
                print("deleted key")
                
            }
            
            completion()
            
        } catch {
            
            print("error deleting existing keys")
            completion()
            
        }
        
    }
    
    func turnedOff() -> Bool {
        return false
    }
}
