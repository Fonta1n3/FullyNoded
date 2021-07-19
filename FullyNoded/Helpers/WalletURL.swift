//
//  WalletURL.swift
//  FullyNoded
//
//  Created by Peter on 11/10/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class WalletURL {
    
    class func url(wallet: Wallet, completion: @escaping ((String?)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
            guard let nodes = nodes, nodes.count > 0 else { completion(nil); return }
            
            var activeNode: [String:Any]?
            
            for node in nodes {
                if let isActive = node["isActive"] as? Bool, let isLightning = node["isLightning"] as? Bool {
                    if isActive, !isLightning {
                        activeNode = node
                    }
                }
            }
            
            guard let active = activeNode else { completion(nil); return }
            
            let node = NodeStruct(dictionary: active)
            
            guard let encAddress = node.onionAddress, let encUser = node.rpcuser, let encPassword = node.rpcpassword else {
                completion(nil); return
            }
            
            let address = decryptedValue(encAddress)
            let rpcusername = decryptedValue(encUser)
            let rpcpassword = decryptedValue(encPassword)
            
            guard address != "", rpcusername != "", rpcpassword != "" else {
                completion(nil); return
            }
            
            var walletUrl = "http://\(rpcusername):\(rpcpassword)@\(address)"
            
            #if targetEnvironment(macCatalyst)
            let macName = UIDevice.current.name
            
            if address.contains("127.0.0.1") || address.contains("localhost") || address.contains(macName) {
                
                guard var hostname = TorClient.sharedInstance.hostname() else { completion(nil); return }
                
                hostname = hostname.replacingOccurrences(of: "\n", with: "")
                walletUrl = "btcrpc://\(rpcusername):\(rpcpassword)@\(hostname):11221"
            }
            #endif
            
            let primDesc = processedDesc(wallet.receiveDescriptor)
            var watching = [String]()
            
            if wallet.watching != nil {
                for desc in wallet.watching! {
                    watching.append(processedDesc(desc))
                }
            }
            
            let dict = ["descriptor":"\(primDesc)", "blockheight":Int(wallet.blockheight),"label":wallet.label,"watching":watching, "quickConnect":walletUrl] as [String : Any]
                        
            completion(dict.json())
        }
        
    }
    
    class private func processedDesc(_ desc: String) -> String {
        let processedDesc = desc.replacingOccurrences(of: "'", with: "h")
        let arr = processedDesc.split(separator: "#")
        
        return "\(arr[0])"
    }
    
}
