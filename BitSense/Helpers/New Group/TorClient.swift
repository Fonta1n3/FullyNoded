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
import UIKit

protocol OnionManagerDelegate: class {

    func torConnProgress(_ progress: Int)

    func torConnFinished()

    func torConnDifficulties()
}

class TorClient {
    
    enum TorState {
        case none
        case started
        case connected
        case stopped
        case refreshing
    }
    
    public var state = TorState.none
    static let sharedInstance = TorClient()
    private var config: TorConfiguration = TorConfiguration()
    private var thread: TorThread?
    private var controller: TorController?
    private var authDirPath = ""
    private var torDirPath = ""
    var isRefreshing = false
    
    // The tor url session configuration.
    // Start with default config as fallback.
    private lazy var sessionConfiguration: URLSessionConfiguration = .default

    // The tor client url session including the tor configuration.
    lazy var session = URLSession(configuration: sessionConfiguration)

    // Start the tor client.
    func start(delegate: OnionManagerDelegate?) {
        print("start")
        
        weak var weakDelegate = delegate
        state = .started
        
        sessionConfiguration.connectionProxyDictionary = [kCFProxyTypeKey: kCFProxyTypeSOCKS, kCFStreamPropertySOCKSProxyHost: "localhost", kCFStreamPropertySOCKSProxyPort: 19050]
        session = URLSession(configuration: sessionConfiguration)
        session.configuration.urlCache = URLCache(memoryCapacity: 0, diskCapacity: 0, diskPath: nil)
        
        //add V3 auth keys to ClientOnionAuthDir if any exist
        let torDir = createTorDirectory()
        authDirPath = createAuthDirectory()
        
        clearAuthKeys {
            
            self.addAuthKeysToAuthDirectory {
                
                //check if it is V2 or not
                //HidServAuth 1234567890abcdefg.onion abcdef01234567890+/K
                
                self.thread = nil
                                        
                    self.config.options = [
                        
                        "DNSPort": "12345",
                        "AutomapHostsOnResolve": "1",
                        "SocksPort": "19050 OnionTrafficOnly",
                        "AvoidDiskWrites": "1",
                        "ClientOnionAuthDir": "\(self.authDirPath)",
                        "LearnCircuitBuildTimeout": "1",
                        "NumEntryGuards": "8",
                        "SafeSocks": "1",
                        "LongLivedPorts": "80,443",
                        "NumCPUs": "2",
                        "DisableDebuggerAttachment": "1",
                        "SafeLogging": "1",
                        "ExcludeExitNodes": "1",
                        "StrictNodes": "1"
                        
                    ]
                    
                    self.config.cookieAuthentication = true
                    self.config.dataDirectory = URL(fileURLWithPath: torDir)
                    self.config.controlSocket = self.config.dataDirectory?.appendingPathComponent("cp")
                    self.config.arguments = ["--ignore-missing-torrc"]
                    self.thread = TorThread(configuration: self.config)
                
                // Initiate the controller.
                if self.controller == nil {
                    self.controller = TorController(socketURL: self.config.controlSocket!)
                }
                
                // Start a tor thread.
                self.thread?.start()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    // Connect Tor controller.
                    
                    do {
                        
                        if !(self.controller?.isConnected ?? false) {
                            
                            do {
                                
                                try self.controller?.connect()
                                
                            } catch {
                                
                                print("error=\(error)")
                                
                            }
                            
                        }
                        
                        let cookie = try Data(
                            contentsOf: self.config.dataDirectory!.appendingPathComponent("control_auth_cookie"),
                            options: NSData.ReadingOptions(rawValue: 0)
                        )
                        print("getcookie")
                        
                        self.controller?.authenticate(with: cookie) { (success, error) in
                            
                            if let error = error {
                                
                                print("error = \(error.localizedDescription)")
                                return
                                
                            }
                            
                            var progressObs: Any?
                            progressObs = self.controller?.addObserver(forStatusEvents: {
                                (type: String, severity: String, action: String, arguments: [String : String]?) -> Bool in
                                
                                if arguments != nil {
                                    
                                    if arguments!["PROGRESS"] != nil {
                                        let progress = Int(arguments!["PROGRESS"]!)!
                                        weakDelegate?.torConnProgress(progress)
                                        if progress >= 100 {
                                            //self.controller?.removeObserver(progressObs)
                                        }
                                        
                                        return true
                                        
                                    }
                                    
                                }
                                
                                return false
                                
                            })
                            
                            var observer: Any? = nil
                            observer = self.controller?.addObserver(forCircuitEstablished: { established in
                                
                                if established {
                                    
                                    print("established")
                                    self.state = .connected
                                    weakDelegate?.torConnFinished()
                                    self.controller?.removeObserver(observer)
                                    
                                } else if self.state == .refreshing {
                                    
                                    self.state = .connected
                                    weakDelegate?.torConnFinished()
                                    self.controller?.removeObserver(observer)
                                    
                                }
                                
                            })
                            
                        }
                        
                    } catch {
                        
                        weakDelegate?.torConnDifficulties()
                        self.state = .none
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func resign() {
        print("resign")
        
        controller?.disconnect()
        controller = nil
        thread?.cancel()
        thread = nil
        clearAuthKeys {}
        state = .stopped
        
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
        cd.retrieveEntity(entityName: .newNodes) {
            
            if !cd.errorBool {
                
                let nodes = cd.entities
                let aes = AESService()
                
                for nodeDict in nodes {
                    
                    let str = NodeStruct(dictionary: nodeDict)
                    let id = str.id
                    
                    if str.isActive && str.authKey != nil && str.onionAddress != nil {
                        
                        func decryptedValue(_ encryptedValue: Data) -> String {
                            var decryptedValue = ""
                            Crypto.decryptData(dataToDecrypt: encryptedValue) { decryptedData in
                                if decryptedData != nil {
                                    decryptedValue = decryptedData!.utf8
                                }
                            }
                            return decryptedValue
                        }
                        
                        let authorizedKey = decryptedValue(str.authKey!)
                        let onionAddress = decryptedValue(str.onionAddress!)
                        let onionAddressArray = onionAddress.components(separatedBy: ".onion:")
                        let authString = onionAddressArray[0] + ":descriptor:x25519:" + authorizedKey
                        let file = URL(fileURLWithPath: authPath, isDirectory: true).appendingPathComponent("\(randomString(length: 10)).auth_private")
                        
                        do {
                            
                            try authString.write(to: file, atomically: true, encoding: .utf8)
                            
                            print("successfully wrote authkey to file")
                            
                            do {
                                
                                if #available(iOS 9.0, *) {
                                    
                                    try (file as NSURL).setResourceValue(URLFileProtection.complete, forKey: .fileProtectionKey)
                                    
                                    print("success setting file protection")
                                    
                                } else {
                                    
                                    print("error setting file protection")
                                    
                                }
                                
                            } catch {
                                
                               print("error setting file protection")
                                
                            }
                                                
                        } catch {
                            
                            print("failed writing auth key")
                            //completion()
                        }
                        
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
