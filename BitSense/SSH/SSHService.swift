//
//  SSHService.swift
//  BitSense
//
//  Created by Peter on 10/12/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import NMSSH
import AES256CBC
import SwiftKeychainWrapper

public enum BTC_COMMAND: String {
    case sendrawtransaction = "sendrawtransaction"
    case decoderawtransaction = "decoderawtransaction"
    case getaccountaddress = "getaccountaddress"
    case getnewaddress = "getnewaddress"
    case getinfo = "getinfo"
    case getbalance = "getbalance"
    case getblockchaininfo = "getblockchaininfo"
    case getunconfirmedbalance = "getunconfirmedbalance"
    case getwalletinfo = "getwalletinfo"
    case listunspent = "listunspent"
    case listaccounts = "listaccounts"
    case listreceivedbyaccount = "listreceivedbyaccount"
    case listreceivedbyaddress = "listreceivedbyaddress"
    case listtransactions = "listtransactions"
    case getrawchangeaddress = "getrawchangeaddress"
    case createrawtransaction = "createrawtransaction"
    case signrawtransaction = "signrawtransactionwithwallet"
    case bumpfee = "bumpfee"
    case getrawtransaction = "getrawtransaction"
}

class SSHService {
    
    let userDefaults = UserDefaults.standard
    var user:String?
    var host:String?
    var password:String?
    var session: NMSSHSession?
    static let sharedInstance = SSHService()
    
    private init() {
        
        print("SSHService")
        
       func decryptSSHKey(keyToDecrypt: String) -> String {
            print("decryptSSHKey")
            let pw = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let decryptedkey = AES256CBC.decryptString(keyToDecrypt, password: pw)!
            print("decryptedkey = \(decryptedkey)")
            return decryptedkey
        }
        
        func decryptKey(keyToDecrypt:String) -> String {
            print("decryptKey")
            let pw = KeychainWrapper.standard.string(forKey: "AESPassword")!
            let decryptedKey = AES256CBC.decryptString(keyToDecrypt, password: pw)!
            return decryptedKey
        }
        
        if UserDefaults.standard.string(forKey: "sshPassword") != nil {
            
            user = decryptKey(keyToDecrypt: UserDefaults.standard.string(forKey: "NodeUsername")!)
            host = decryptKey(keyToDecrypt: UserDefaults.standard.string(forKey: "NodeIPAddress")!)
            password = decryptSSHKey(keyToDecrypt: UserDefaults.standard.string(forKey: "sshPassword")!)
            
        } else {
            
            user = ""
            host = ""
            password = ""
            
        }
        
 
        
        
   }
    
    func connect(success: @escaping((success:Bool, error:String?)) -> ()) {
        guard user != nil, host != nil, password != nil else {
            success((success:false, error:"Error"))
            return
        }
        session = NMSSHSession.connect(toHost: host!, withUsername: user!)
        if session?.isConnected == true {
            print(password!)
            session?.authenticate(byPassword: password!)
            if session?.isAuthorized == true {
                success((success:true, error:nil))
                print("success")
            } else {
                success((success:false, error:"Error"))
                print("fail")
                print("\(String(describing: session?.lastError))")
            }
        } else {
            print("Session not connected")
        }
    }
    
    func disconnect() {
        session?.disconnect()
    }
    
    func execute(command: BTC_COMMAND, params: String, response: @escaping((dictionary:Any?, error:String?)) -> ()) {
        
        do {
            
            var error: NSErrorPointer?
            
            do {
               
                let responseString:String? = try session?.channel.execute("bitcoin-cli \(command.rawValue) \(params)", error: error ?? nil)
                
                print("responseString = \(String(describing: responseString))")
                
                guard let responseData = responseString?.data(using: .utf8) else { return }
                
                do {
                    
                    if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? Any {
                        
                        response((dictionary:json, error:nil))
                        
                    }
                    
                } catch {
                    
                    response((dictionary:nil, error:"JSON ERROR: \(error)"))
                    
                    
                }
                
            } catch {
                
                print("error getting response string")
            }
            
        } catch {
            
            response((dictionary:nil, error:"RESPONSE ERROR: \(error)"))
            
        }
        
    }
    
    func executeStringResponse(command: BTC_COMMAND, params: String, response: @escaping((string:String?, error:String?)) -> ()) {
        var error: NSErrorPointer?
        do {
            let responseString:String? = try session?.channel.execute("bitcoin-cli \(command.rawValue) \(params)", error: error ?? nil).replacingOccurrences(of: "\n", with: "")
            print("responseString = \(String(describing: responseString))")
            response((string: responseString, error:nil))
        } catch {
            print("error getting response string")
            response((string: "", error:"ERROR: \(error)"))
        }
    }
    
    
    /*
    func getaccountaddress(response: @escaping((address:String?, error:String?)) -> ()) {
        do {
            let responseString:String? = try session?.channel.execute("bitcoin-cli \(BTC_COMMAND.getaccountaddress.rawValue) \"\"", error: error ?? nil)
            guard let responseData = responseString?.data(using: .utf8) else { response((address:nil, error:"JSON ERROR")); return }
            // TODO: There is a "/n" at the end of this address.  Test...
            let myAddress: String = (String(data: responseData, encoding: .utf8)?.replacingOccurrences(of: "\n", with: ""))!
            print(myAddress)
            response((address:myAddress, error:nil))
        } catch {
            response((address:nil, error:"RESPONSE ERROR: \(error)"))
        }
    }
    
    func listtransactions(arrJson: @escaping([[String:Any]]) -> ()) {
        do {
            let responseString:String? = try session?.channel.execute("bitcoin-cli \(BTC_COMMAND.listtransactions.rawValue)", error: error ?? nil)
            guard let responseData = responseString?.data(using: .utf8) else { return }
            do {
                let json = try JSONSerialization.jsonObject(with: responseData, options: []) as! [[String:Any]]
                arrJson(json)
            } catch {
                print("JSON ERROR: \(error)")
            }
        } catch {
            print("RESPONSE ERROR: \(error)")
        }
    }*/
    
}
