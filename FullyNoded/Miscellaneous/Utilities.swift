//
//  Utilities.swift
//  BitSense
//
//  Created by Peter on 08/08/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import UIKit

public func isLndNode(completion: @escaping (Bool) -> Void) {
    CoreDataService.retrieveEntity(entityName: .newNodes) { nodes in
        guard let nodes = nodes, nodes.count > 0 else { completion(false); return }
        
        var isLnd = false
        
        for (i, node) in nodes.enumerated() {
            let nodeStr = NodeStruct(dictionary: node)
            
            if nodeStr.isLightning && nodeStr.isActive {
                if nodeStr.macaroon != nil {
                    isLnd = true
                }
            }
            
            if i + 1 == nodes.count {
                completion(isLnd)
            }
        }
    }
}

public func decryptedValue(_ encryptedValue: Data) -> String {
    guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
    
    return decrypted.utf8String ?? ""
}

/// Call this method to retrive active wallet. This method seaches the device's storage. NOT the node.
/// - Parameter completion: Active wallet
public func activeWallet(completion: @escaping ((Wallet?)) -> Void) {
    guard let activeWalletName = UserDefaults.standard.object(forKey: "walletName") as? String else {
        completion(nil)
        return
    }
    
    CoreDataService.retrieveEntity(entityName: .wallets) { walletDictionaries in
        guard let walletDictionaries = walletDictionaries, !walletDictionaries.isEmpty else {
            completion(nil)
            return
        }
        
        var foundWallet: Wallet?
        
        for walletDictionary in walletDictionaries where foundWallet == nil {
            if walletDictionary["id"] != nil {
                let wallet = Wallet(dictionary: walletDictionary)
                
                if wallet.name == activeWalletName {
                    foundWallet = wallet
                }
            }
        }
        
        completion(foundWallet)
    }
}

public func showAlert(vc: UIViewController?, title: String, message: String) {
    if let vc = vc {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true, completion: nil)
        }
    }
}

public func exportPsbtToURL(data: Data) -> URL? {
    let documents = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first
    guard let path = documents?.appendingPathComponent("/FullyNodedPSBT.psbt") else {
        return nil
    }
    do {
        try data.write(to: path, options: .atomicWrite)
        return path
    } catch {
        print(error.localizedDescription)
        return nil
    }
}

public func exportMultisigWalletToURL(data: Data) -> URL? {
    let documents = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first
    guard let path = documents?.appendingPathComponent("/FullyNodedMultisig.txt") else {
        return nil
    }
    do {
        try data.write(to: path, options: .atomicWrite)
        return path
    } catch {
        print(error.localizedDescription)
        return nil
    }
}

public func exportWalletJson(name: String, data: Data) -> URL? {
    let documents = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    ).first
    guard let path = documents?.appendingPathComponent("/\(name).json") else {
        return nil
    }
    do {
        try data.write(to: path, options: .atomicWrite)
        return path
    } catch {
        print(error.localizedDescription)
        return nil
    }
}

public func impact() {
    if #available(iOS 10.0, *) {
        let impact = UIImpactFeedbackGenerator()
        DispatchQueue.main.async {
            impact.impactOccurred()
        }
    } else {
        // Fallback on earlier versions
    }
}

public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0...length-1).map{ _ in letters.randomElement()! })
}

public func rounded(number: Double) -> Double {
    return Double(round(100000000*number)/100000000)
    
}

public func displayAlert(viewController: UIViewController?, isError: Bool, message: String) {
    if viewController != nil {
        showAlert(vc: viewController, title: "Error", message: message)
    }
}

public func hexStringToUIColor(hex:String) -> UIColor {
    var cString:String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

    if (cString.hasPrefix("#")) {
        cString.remove(at: cString.startIndex)
    }

    if ((cString.count) != 6) {
        return UIColor.gray
    }

    var rgbValue:UInt64 = 0
    Scanner(string: cString).scanHexInt64(&rgbValue)

    return UIColor(
        red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
        green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
        blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
        alpha: CGFloat(1.0)
    )
}

public func currentDate() -> String {
    return "NZdDCNBFTDqKPrUG9V80g0iVemSXLL0CuaWj12xqD00="
}

public var authTimeout: Int {
    return 360
}

public let currencies:[[String:String]] = [
    ["USD": "$"],
    ["GBP": "£"],
    ["EUR": "€"],
    ["AUD":"$"],
    ["BRL": "R$"],
    ["CAD": "$"],
    ["CHF": "CHF "],
    ["CLP": "$"],
    ["CNY": "¥"],
    ["DKK": "kr"],
    ["HKD": "$"],
    ["INR": "₹"],
    ["ISK": "kr"],
    ["JPY": "¥"],
    ["KRW": "₩"],
    ["NZD": "$"],
    ["PLN": "zł"],
    ["RUB": "₽"],
    ["SEK": "kr"],
    ["SGD": "$"],
    ["THB": "฿"],
    ["TRY": "₺"],
    ["TWD": "NT$"]
]

public func isWalletRPC(command: BTC_CLI_COMMAND) -> Bool {
    var boolToReturn = Bool()
    
    switch command {
    case .listtransactions,
         .getbalance,
         .getnewaddress,
         .getwalletinfo,
         .getrawchangeaddress,
         .importmulti,
         .importprivkey,
         .rescanblockchain,
         //.fundrawtransaction,
         .listunspent,
         .walletprocesspsbt,
         .gettransaction,
         .getaddressinfo,
         .bumpfee,
         //.signrawtransactionwithwallet,
         .listaddressgroupings,
         .listlabels,
         .getaddressesbylabel,
         .listlockunspent,
         .lockunspent,
         .abortrescan,
         .walletcreatefundedpsbt,
         .encryptwallet,
         .walletpassphrase,
         .walletpassphrasechange,
         .walletlock,
         .psbtbumpfee,
         .importdescriptors:
         //.signmessage:
        boolToReturn = true
        
    default:
        boolToReturn = false
    }
    
    return boolToReturn
}

public func shakeAlert(viewToShake: UIView) {
    let animation = CABasicAnimation(keyPath: "position")
    animation.duration = 0.07
    animation.repeatCount = 4
    animation.autoreverses = true
    animation.fromValue = NSValue(cgPoint: CGPoint(x: viewToShake.center.x - 10, y: viewToShake.center.y))
    animation.toValue = NSValue(cgPoint: CGPoint(x: viewToShake.center.x + 10, y: viewToShake.center.y))
    
    DispatchQueue.main.async {
        viewToShake.layer.add(animation, forKey: "position")
    }
}

public func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
