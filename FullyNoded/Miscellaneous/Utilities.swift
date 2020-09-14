//
//  Utilities.swift
//  BitSense
//
//  Created by Peter on 08/08/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import UIKit

public func activeWallet(completion: @escaping ((Wallet?)) -> Void) {
    
    guard let activeWalletName = UserDefaults.standard.object(forKey: "walletName") as? String else {
        completion(nil)
        return
    }
    
    CoreDataService.retrieveEntity(entityName: .wallets) { coreDataWallets in
        guard let coreDataWallets = coreDataWallets, !coreDataWallets.isEmpty else {
            completion(nil)
            return
        }
        
        var foundWallet: Wallet?
        
        for coreDataWallet in coreDataWallets where foundWallet == nil {
            let wallet = Wallet(dictionary: coreDataWallet)
            
            if wallet.name == activeWalletName {
                foundWallet = wallet
            }
        }
        
        completion(foundWallet)
    }
}

public extension UITextView {
  func addHyperLinksToText(originalText: String, hyperLinks: [String: String]) {
    let style = NSMutableParagraphStyle()
    style.alignment = .left
    let attributedOriginalText = NSMutableAttributedString(string: originalText)
    for (hyperLink, urlString) in hyperLinks {
        let linkRange = attributedOriginalText.mutableString.range(of: hyperLink)
        let fullRange = NSRange(location: 0, length: attributedOriginalText.length)
        attributedOriginalText.addAttribute(NSAttributedString.Key.link, value: urlString, range: linkRange)
        attributedOriginalText.addAttribute(NSAttributedString.Key.paragraphStyle, value: style, range: fullRange)
        attributedOriginalText.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 17), range: fullRange)
        attributedOriginalText.addAttribute(.foregroundColor, value: UIColor.white, range: fullRange)
    }
    self.linkTextAttributes = [
        NSAttributedString.Key.foregroundColor: UIColor.systemTeal
    ]
    self.attributedText = attributedOriginalText
  }
}

public func showAlert(vc: UIViewController?, title: String, message: String) {
    if vc != nil {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in }))
            vc!.present(alert, animated: true, completion: nil)
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

public extension Dictionary {
    func json() -> String? {
        if let json = try? JSONSerialization.data(withJSONObject: self, options: []) {
            if let jsonString = String(data: json, encoding: .utf8) {
                return jsonString
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

public extension Int {
    func withCommas() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
    }
}

extension String {
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
}

extension Notification.Name {
    public static let refreshNode = Notification.Name(rawValue: "refreshNode")
    public static let refreshWallet = Notification.Name(rawValue: "refreshWallet")
    public static let addColdCard = Notification.Name(rawValue: "addColdcard")
}

public extension Data {
    var utf8:String {
        if let string = String(bytes: self, encoding: .utf8) {
            return string
        } else {
            return ""
        }
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

public extension String {
    static let numberFormatter = NumberFormatter()
    var doubleValue: Double {
        String.numberFormatter.decimalSeparator = "."
        if let result =  String.numberFormatter.number(from: self) {
            return result.doubleValue
        } else {
            String.numberFormatter.decimalSeparator = ","
            if let result = String.numberFormatter.number(from: self) {
                return result.doubleValue
            }
        }
        return 0
    }
}

public func randomString(length: Int) -> String {
    let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    return String((0...length-1).map{ _ in letters.randomElement()! })
    
}

public func rounded(number: Double) -> Double {
    return Double(round(100000000*number)/100000000)
    
}

public extension Double {
    func withCommas() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
    }
}

public extension Double {
    func withCommasNotRounded() -> String {
        let arr = "\(self)".split(separator: ".")
        let satoshis = "\(arr[1])"
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        let arr1 = (numberFormatter.string(from: NSNumber(value:self))!).split(separator: ".")
        let numberWithCommas = "\(arr1[0])"
        return numberWithCommas + "." + satoshis
    }
}

public func displayAlert(viewController: UIViewController?, isError: Bool, message: String) {
    if viewController != nil {
        if isError {
            showAlert(vc: viewController, title: "Error", message: message)
        } else {
            DispatchQueue.main.async {
                let errorView = ErrorView()
                errorView.isUserInteractionEnabled = true
                errorView.showErrorView(vc: viewController!, text: message, isError: isError)
            }
        }
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

public func isAnyNodeActive(nodes: [[String:Any]]) -> Bool {
    
    var boolToReturn = false
    
    for node in nodes {
        
        let isActive = node["isActive"] as! Bool
        
        if isActive {
            
            boolToReturn = true
            
        }
        
    }
    
    return boolToReturn
    
}

public func isWalletRPC(command: BTC_CLI_COMMAND) -> Bool {
    
    var boolToReturn = Bool()
    
    switch command {
        
    case .listtransactions,
         .getbalance,
         .getunconfirmedbalance,
         .getnewaddress,
         .getwalletinfo,
         .getrawchangeaddress,
         .importmulti,
         .importprivkey,
         .rescanblockchain,
         .fundrawtransaction,
         .listunspent,
         .walletprocesspsbt,
         .gettransaction,
         .getaddressinfo,
         .bumpfee,
         .signrawtransactionwithwallet,
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
         .walletlock:
        
        boolToReturn = true
        
    default:
        
        boolToReturn = false
        
    }
    
    return boolToReturn
    
}

public func shakeAlert(viewToShake: UIView) {
    print("shakeAlert")
    
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
    print("getDocumentsDirectory")
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}

public extension Double {
    
    var avoidNotation: String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        return numberFormatter.string(for: self) ?? ""
        
    }
}

public extension UIDevice {
    
    static let modelName: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        func mapToDevice(identifier: String) -> String { // swiftlint:disable:this cyclomatic_complexity
            #if os(iOS)
            switch identifier {
            case "iPod5,1":                                 return "iPod Touch 5"
            case "iPod7,1":                                 return "iPod Touch 6"
            case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
            case "iPhone4,1":                               return "iPhone 4s"
            case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
            case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
            case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
            case "iPhone7,2":                               return "iPhone 6"
            case "iPhone7,1":                               return "iPhone 6 Plus"
            case "iPhone8,1":                               return "iPhone 6s"
            case "iPhone8,2":                               return "iPhone 6s Plus"
            case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
            case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
            case "iPhone8,4":                               return "iPhone SE"
            case "iPhone10,1", "iPhone10,4":                return "iPhone 8"
            case "iPhone10,2", "iPhone10,5":                return "iPhone 8 Plus"
            case "iPhone10,3", "iPhone10,6":                return "iPhone X"
            case "iPhone11,4", "iPhone11,6":                return "iPhone XS Max"
            case "iPhone12,5":                              return "iPhone 11 pro max"
            case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
            case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
            case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
            case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
            case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
            case "iPad6,11", "iPad6,12":                    return "iPad 5"
            case "iPad7,5", "iPad7,6":                      return "iPad 6"
            case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
            case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
            case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
            case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
            case "iPad6,3", "iPad6,4":                      return "iPad Pro 9.7 Inch"
            case "iPad6,7", "iPad6,8":                      return "iPad Pro 12.9 Inch"
            case "iPad7,1", "iPad7,2":                      return "iPad Pro 12.9 Inch 2. Generation"
            case "iPad7,3", "iPad7,4":                      return "iPad Pro 10.5 Inch"
            case "AppleTV5,3":                              return "Apple TV"
            case "AppleTV6,2":                              return "Apple TV 4K"
            case "AudioAccessory1,1":                       return "HomePod"
            case "i386", "x86_64":                          return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "iOS"))"
            default:                                        return identifier
            }
            #elseif os(tvOS)
            switch identifier {
            case "AppleTV5,3": return "Apple TV 4"
            case "AppleTV6,2": return "Apple TV 4K"
            case "i386", "x86_64": return "Simulator \(mapToDevice(identifier: ProcessInfo().environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "tvOS"))"
            default: return identifier
            }
            #endif
        }
        
        return mapToDevice(identifier: identifier)
    }()
    
}
