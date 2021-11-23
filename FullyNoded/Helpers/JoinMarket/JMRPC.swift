//
//  JMRPC.swift
//  FullyNoded
//
//  Created by Peter Denton on 11/20/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

class JMRPC {
    
    static let sharedInstance = JMRPC()
    let torClient = TorClient.sharedInstance
    private var attempts = 0
    
    private init() {}
    
    func command(method: JM_REST, param: [String:Any]?, completion: @escaping ((response: Any?, errorDesc: String?)) -> Void) {
        attempts += 1
        
        CoreDataService.retrieveEntity(entityName: .newNodes) { [weak self] nodes in
            guard let self = self else { return }
            
            guard let nodes = nodes, nodes.count > 0 else {
                completion((nil, "error getting nodes from core data"))
                return
            }
            
            var activeNode: [String:Any]?
            
            for node in nodes {
                if let isActive = node["isActive"] as? Bool, let isLightning = node["isLightning"] as? Bool, !isLightning {
                    if isActive {
                        activeNode = node
                    }
                }
            }
            
            guard let active = activeNode else {
                completion((nil, "no active nodes!"))
                return
            }
            
            let node = NodeStruct(dictionary: active)
            
            guard let encAddress = node.onionAddress else {
                completion((nil, "error getting encrypted node credentials"))
                return
            }
            
//            if let encryptedCert = node.cert {
//                guard let decryptedCert = Crypto.decrypt(encryptedCert) else {
//                    completion((nil, "Error getting decrypting cert."))
//                    return
//                }
//
//                self.torClient.cert = decryptedCert.base64EncodedData()
//            }
            
            let cert = """
            MIIFojCCA4oCCQDm9KZ1lo9OYDANBgkqhkiG9w0BAQsFADCBkjELMAkGA1UEBhMC
            VVMxETAPBgNVBAgMCFZpcmdpbmlhMRcwFQYDVQQHDA5WaXJnaW5pYSBCZWFjaDEM
            MAoGA1UECgwDTi9BMQwwCgYDVQQLDANOL0ExEjAQBgNVBAMMCTEyNy4wLjAuMTEn
            MCUGCSqGSIb3DQEJARYYZm9udGFpbmVkZW50b25AZ21haWwuY29tMB4XDTIxMTEy
            MTA1NTYwOFoXDTIyMTEyMTA1NTYwOFowgZIxCzAJBgNVBAYTAlVTMREwDwYDVQQI
            DAhWaXJnaW5pYTEXMBUGA1UEBwwOVmlyZ2luaWEgQmVhY2gxDDAKBgNVBAoMA04v
            QTEMMAoGA1UECwwDTi9BMRIwEAYDVQQDDAkxMjcuMC4wLjExJzAlBgkqhkiG9w0B
            CQEWGGZvbnRhaW5lZGVudG9uQGdtYWlsLmNvbTCCAiIwDQYJKoZIhvcNAQEBBQAD
            ggIPADCCAgoCggIBAL3ZUvb/nt6/JGAJAnRACsw0HJabc3hqLcdfyGAFbPk5wH7t
            /hKlohqG+i8AMYSyxv2FVU0PEE3cKj7yFrr87NgCzZY+I0ksNlVz+umBDNkcviQW
            9QLAmrCasahGhd0S5noUJ0sk6wI4b6S61S9itGFXDkpDcqUaMyA+nvAQfuEOaCgW
            2Qy+vvO53qqkecnhxnz6JuyY7QiZELSx8ytQY2tP5mLcpes/7rT5IRHBv+TbxVoH
            xman69zLJ05kDOpejHRabPcdw5lnAsakDk6CdKlchggSth2ZKyGnGsJi3lSUNCFw
            TVfBsWQOXnk4PP2/rwSYiKcG1seZOdOvqSdK765ksG+HFDHAcqFkHKKltAIgwast
            NdipxKmjwIy8cHWcqPdu9zF76CDmQr08BwXRk+KNWF3mblV/govm3kxk2aGEWj9D
            Ze/GEzWYpXyc88IyotXco8B4WgAwADU1mr7P1bA8gKKpulwrdY62EXIkpkdRyWEH
            /jIyEfwUHLN9ZupGnxHanGjaL5aXFZaucHaAYl4vnsEAkh0YEdtia8bAYURLM3hn
            PR2DhWy3O3MG/aF0VTAs3RvZiYaTb5a7kYijgOUQzB6DmYKHuy5T0HlzOlroeHEC
            pD4IG5RUNasPXZjziWwpsk+tdklpmcI7OLKB3ZeK5FAbQcDTwNqohlmuS8JXAgMB
            AAEwDQYJKoZIhvcNAQELBQADggIBACzCs5OHfeMEb9R9oxBTWt4UckmiwkFyo8NA
            W9UxUbJVybsy7K7woSgrj28otT0Y618Gp6aUeBvMALJtPAyv9QxyMnB43bHE2Knn
            ylgDZZtYRN86hp49kJzvve7Au2s1lnUtrTz//HBWdlk/WUYVpC3vUdR6/zkgTrNJ
            tth00tg16Bdwutibn9iF4KdoSXicGfI26kvy3kiss/rN7JUoFOIU1dftlhLrjo4g
            epElImeR8NoOFoQzrKKtFVjWnVQ2M6uapntnMouqPlwZja+mkUL4nFrRiteH2ZEQ
            z79qaCf/M0zff6vv/YMQdf6VktHcdenNmFSHU5eNL51+3zlQwrTily5mjLWHYzQb
            kRyxzfZaAXb1RO/lRomF+HUYXtahDhAOZuGOeqgSrESavS92yN4Jd5UzHplOPVCv
            uMT4iVJPzzDmnuwTlOVbU7+EME8IcMGDtMiVYozzMNcDuUUixOLKIrugM3tF32HQ
            1ZbWLyzzEQh5fNBd9tYWq49NZDUbrZ96WnK1txTukbDfgDgFQpFW+V5UoWrOcXOQ
            CD1EjIZe5i9sTX3khv6w0FNKNbzMbhgPIoFnveYBWA6/++t4upkR2Do2Ra6NSLl8
            bz02FlCWlokZcZaEz553h8Pd30zIq/u0w5YcMQ9BnVT2bB8kimfix4XBJ4hfXA07
            OMyS/L1R
            """.condenseWhitespace().replacingOccurrences(of: " ", with: "")
            
            guard let certData = Data(base64Encoded: cert) else {
                print("can not convert string cert to data")
                return
            }
                        
            self.torClient.cert = certData.base64EncodedData()
            
            let onionAddress = decryptedValue(encAddress)
            
            guard onionAddress != "" else {
                completion((nil, "error decrypting node credentials"))
                return
            }
            
            let walletUrl = "https://\(onionAddress)/\(method.stringValue)"
                        
             guard let url = URL(string: walletUrl) else {
                completion((nil, "url error"))
                return
            }
            
            var request = URLRequest(url: url)
            let timeout = 10.0
            
            var httpMethod:String!
            
            switch method {
            case .walletall,
                    .session:
                httpMethod = "GET"
                
            case .lockwallet(let wallet),
                    .walletdisplay(let wallet),
                    .getaddress(jmWallet: let wallet),
                    .makerStop(jmWallet: let wallet):
                httpMethod = "GET"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                          completion((nil, "Unable to decrypt token."))
                          return
                      }
                
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                
            case .unlockwallet(jmWallet: let wallet):
                httpMethod = "POST"
                
                guard let decryptedPassword = Crypto.decrypt(wallet.password),
                      let password = decryptedPassword.utf8String else {
                          completion((nil, "Unable to decrypt password."))
                          return
                      }
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: ["password":password]) else { return }
                
                #if DEBUG
                print("JM param: \(String(describing: param))")
                #endif
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
                
            case .walletcreate:
                httpMethod = "POST"
                
            case .coinjoin(jmWallet: let wallet),
                    .makerStart(jmWallet: let wallet),
                    .configGet(jmWallet: let wallet),
                    .configSet(jmWallet: let wallet):
                httpMethod = "POST"
                
                guard let decryptedToken = Crypto.decrypt(wallet.token),
                      let token = decryptedToken.utf8String else {
                          completion((nil, "Unable to decrypt token."))
                          return
                      }
                
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            
            if let param = param {
                #if DEBUG
                print("JM param: \(param)")
                #endif
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: param) else {
                    completion((nil, "Unable to encode your params into json data."))
                    return
                }
                
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("\(jsonData.count)", forHTTPHeaderField: "Content-Length")
                request.httpBody = jsonData
                
            } else {
                request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            }
            
            request.timeoutInterval = timeout
            request.httpMethod = httpMethod
            request.url = url
            
            #if DEBUG
            print("url = \(url)")
            #endif
            
            var sesh = URLSession(configuration: .default)
            
            if onionAddress.contains("onion") {
                sesh = self.torClient.session
            }
            
            let task = sesh.dataTask(with: request as URLRequest) { [weak self] (data, response, error) in
                guard let self = self else { return }
                                
                guard let urlContent = data else {
                    
                    guard let error = error else {
                        if self.attempts < 20 {
                            self.command(method: method, param: param, completion: completion)
                        } else {
                            self.attempts = 0
                            completion((nil, "Unknown error, ran out of attempts"))
                        }
                        
                        return
                    }
                    
                    if self.attempts < 20 {
                        self.command(method: method, param: param, completion: completion)
                    } else {
                        self.attempts = 0
                        #if DEBUG
                        print("error: \(error.localizedDescription)")
                        #endif
                        completion((nil, error.localizedDescription))
                    }
                    
                    return
                }
                
                self.attempts = 0
                
                guard let json = try? JSONSerialization.jsonObject(with: urlContent, options: .mutableLeaves) as? NSDictionary else {
                    if let httpResponse = response as? HTTPURLResponse {
                        switch httpResponse.statusCode {
                        case 401:
                            completion((nil, "Looks like your rpc credentials are incorrect, please double check them. If you changed your rpc creds in your bitcoin.conf you need to restart your node for the changes to take effect."))
                        case 403:
                            completion((nil, "The bitcoin-cli \(method) command has not been added to your rpcwhitelist, add \(method) to your bitcoin.conf rpcwhitelsist, reboot Bitcoin Core and try again."))
                        default:
                            completion((nil, "Unable to decode the response from your node, http status code: \(httpResponse.statusCode)"))
                        }
                    } else {
                        completion((nil, "Unable to decode the response from your node..."))
                    }
                    return
                }
                
                #if DEBUG
                print("json: \(json)")
                #endif
                
                guard let errorCheck = json["message"] as? String else {
                    completion((json, nil))
                    return
                }
                
                completion((nil, errorCheck))
            }
            
            task.resume()
        }
    }
}
