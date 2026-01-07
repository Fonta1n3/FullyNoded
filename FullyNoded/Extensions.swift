//
//  Extensions.swift
//  FullyNoded
//
//  Created by Fontaine on 7/9/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation
import UIKit

extension UTXO {
    var input: [String:Any] {
        return ["txid": self.txid, "vout": self.vout, "sequence": 1]
    }
}

extension UIViewController {
    /// Presents a "Are you sure?" alert and returns true if user confirms
    /// - Parameters:
    ///   - title: Optional title (default: "Are you sure?")
    ///   - message: Optional message
    ///   - confirmTitle: Title for confirm button (default: "Yes")
    ///   - cancelTitle: Title for cancel button (default: "No")
    /// - Returns: true if user taps confirm, false otherwise
    func confirmAction(
        title: String = "Are you sure?",
        message: String? = nil,
        confirmTitle: String = "Yes",
        cancelTitle: String = "No"
    ) async -> Bool {
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            let confirmAction = UIAlertAction(title: confirmTitle, style: .destructive) { _ in
                continuation.resume(returning: true)
            }
            let cancelAction = UIAlertAction(title: cancelTitle, style: .cancel) { _ in
                continuation.resume(returning: false)
            }
            
            alert.addAction(confirmAction)
            alert.addAction(cancelAction)
            
            // Optional: make confirm button bold in iOS 15+
            if #available(iOS 15.0, *) {
                alert.preferredAction = confirmAction
            }
            
            self.present(alert, animated: true)
        }
    }
    
    func topMostViewController() -> UIViewController {
        if let presented = self.presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController {
            return nav.visibleViewController?.topMostViewController() ?? nav
        }
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? tab
        }
        return self
    }
}

public extension Date {
    var displayDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM-dd-yyyy HH:mm"
        return dateFormatter.string(from: self)
    }
    
    var secondsSince: Int {
        return Int(Date().timeIntervalSince(self))
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        formatter.locale = Locale.current
        return formatter.string(from: self)
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

public extension Dictionary {
    func json() -> String? {
        guard let json = try? JSONSerialization.data(withJSONObject: self, options: []),
              let jsonString = String(data: json, encoding: .utf8) else { return nil }
        
        return jsonString
    }
}

extension Array where Element: Hashable {
    func duplicates() -> Array {
        let groups = Dictionary(grouping: self, by: {$0})
        let duplicateGroups = groups.filter {$1.count > 1}
        let duplicates = Array(duplicateGroups.keys)
        return duplicates
    }
}

public extension Array {
    func json() -> String? {
        guard let json = try? JSONSerialization.data(withJSONObject: self, options: []),
              let jsonString = String(data: json, encoding: .utf8) else { return nil }
        
        return jsonString
    }
    
    var processedInputs: String {
        var inputs = self.description
        inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
        inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
        inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
        inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
        inputs = inputs.replacingOccurrences(of: "\\", with: "")
        return inputs
    }
    
    var processedOutputs: String {
        var outputsString = self.description
        outputsString = outputsString.replacingOccurrences(of: "[", with: "")
        return outputsString.replacingOccurrences(of: "]", with: "")
    }
}

extension Array where Element == UInt8 {
    var data: Data {
        Data(self)
    }
}

public extension String {
    
    var addressExpanded: String {
        // Keeps the prefix and checksum intact and tries to split middle by 5 chars each.
        // Doesn't take into account all address types and networks, optimized for mainnet native segwit and taproot.
        if self == "Unknown address." {
            return self
        }
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = trimmed.prefix(4)
        let suffix = trimmed.suffix(6)
        
        let middle = trimmed.dropFirst(4).dropLast(6)
        
        // If no middle, just join prefix and suffix
        guard !middle.isEmpty else {
            return "\(prefix)\(suffix)"
        }
        
        // Group middle into chunks of 5 with "-"
        var groupedMiddle = ""
        var index = middle.startIndex
        while index < middle.endIndex {
            let end = middle.index(index, offsetBy: 5, limitedBy: middle.endIndex) ?? middle.endIndex
            let chunk = middle[index..<end]
            if !groupedMiddle.isEmpty {
                groupedMiddle += "-"
            }
            groupedMiddle += chunk
            index = end
        }
        
        return "\(prefix)-\(groupedMiddle)-\(suffix)"
    }
    
    /// Securely overwrites the string's memory with zeros and then clears it
    mutating func secureWipe() {
        // Get mutable access to the underlying UTF-8 bytes
        let count = self.utf8.count
        guard count > 0 else { self = ""; return }
        
        self.withMutableStrings { pointer in
            guard let base = pointer else { return }
            base.initialize(repeating: 0, count: count)  // zero-fill
        }
        
        // Final obfuscation + clear
        self = String(repeating: "X", count: min(count, 200))
        self = ""
    }
    
    // Helper to get mutable pointer to UTF-8 buffer
    func withMutableStrings<T>(_ body: (UnsafeMutablePointer<CChar>?) -> T) -> T {
        return self.withCString { cString in
            //let length = strlen(cString) + 1
            guard let mutableCopy = strdup(cString) else {
                return body(nil)
            }
            defer { free(mutableCopy) }
            return body(mutableCopy)
        }
    }
    
    var pong: String {
        return self.replacingOccurrences(of: "PING", with: "PONG")
    }
    
    var btc: String {
        return self + " btc"
    }
    
    var sats: String {
        var sats = self
        sats = sats.replacingOccurrences(of: "-", with: "")
        
        guard let dbl = Double(sats) else {
            return self + " sats"
        }
        
        if dbl < 1.0 {
            return dbl.avoidNotation + " sat"
        } else if dbl == 1.0 {
            return "1 sat"
        } else {
            if self.contains(".") || self.contains(",") {
                return "\(sats) sats"
            } else {
                return "\(sats.withCommas) sats"
            }
        }
    }
    
    var withCommas: String {
        if self.doubleValue > 1.0 {
            let dbl = Double(self)!
            let numberFormatter = NumberFormatter()
            numberFormatter.numberStyle = NumberFormatter.Style.decimal
            numberFormatter.locale = Locale(identifier: "en_US")
            return numberFormatter.string(from: NSNumber(value:dbl))!
        } else {
            return self
        }
        
    }
    
    var utf8: Data {
        return data(using: .utf8)!
    }
    
    func condenseWhitespace() -> String {
        return self.replacingOccurrences(of: " ", with: "")
    }
    
    var isAlphanumeric: Bool {
        return !isEmpty && range(of: "[^a-zA-Z0-9]", options: .regularExpression) == nil
    }
    
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
    
    var satsToBtc: Double {
        var processed = "\(self)".replacingOccurrences(of: ",", with: "")
        processed = processed.replacingOccurrences(of: ".", with: "")
        processed = processed.replacingOccurrences(of: "-", with: "")
        processed = processed.replacingOccurrences(of: "+", with: "")
        processed = processed.replacingOccurrences(of: "sats", with: "").condenseWhitespace()
        let btc = Double(processed)! / 100000000.0
        return btc
    }
    
    var sha256Hash: String {
        return Crypto.sha256hash(self)
    }
    
    var msatToSat: Double {
        return Double(self)! / 1000.0
    }
    
    var btcToSats: String {
        return (Int(self.doubleValue * 100000000.0)).avoidNotation
    }
}

extension Bool {
    var intValue: Int {
        return self ? 1 : 0
    }
}

public extension BlockchainInfo {
    var size: String {
        return "\(self.size_on_disk/1000000000) gb"
    }
    
    var progressString: String {
        if self.verificationprogress > 0.9999 {
            return "Fully verified"
        } else {
            return "\(Int(self.verificationprogress*100))% verified"
        }
    }
    
    var diffString: String {
        return "Difficulty \(Int(self.difficulty / 1000000000000).withCommas) trillion"
    }
}

public extension Notification.Name {
    static let refreshNode = Notification.Name(rawValue: "refreshNode")
    static let refreshWallet = Notification.Name(rawValue: "refreshWallet")
    static let addColdCard = Notification.Name(rawValue: "addColdcard")
    static let refreshUtxos = Notification.Name(rawValue: "refreshUtxos")
    static let importWallet = Notification.Name(rawValue: "importWallet")
    static let broadcastTxn = Notification.Name(rawValue: "broadcastTxn")
    static let signPsbt = Notification.Name(rawValue: "signPsbt")
    static let updateWalletLabel = Notification.Name(rawValue: "updateWalletLabel")
    static let startTorFromAppDelegate = Notification.Name(rawValue: "startTorFromAppDelegate")
}

public extension Descriptor {
    var addressType: String {
        var addressType = ""
        switch self {
        case _ where self.isP2TR:
            addressType = "bech32m"
        case _ where self.isP2WPKH:
            addressType = "bech32"
        case _ where self.isP2SHP2WPKH:
            addressType = "p2sh-segwit"
        case _ where self.isP2PKH:
            addressType = "legacy"
        default:
            break
        }
        return addressType
    }
}

public extension Data {
    var utf8String:String? {
        return String(bytes: self, encoding: .utf8)
    }
    
    /// A hexadecimal string representation of the bytes.
    var hexString: String {
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(count * 2)
        
        for byte in self {
            let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
        
        return String(utf16CodeUnits: hexChars, count: hexChars.count)
        
    }
    
    static func decodeUrlSafeBase64(_ value: String) throws -> Data {
        var stringtoDecode = value.condenseWhitespace()
        
        stringtoDecode = value.replacingOccurrences(of: "-", with: "+")
        stringtoDecode = stringtoDecode.replacingOccurrences(of: "_", with: "/")
        
        switch (stringtoDecode.utf8.count % 4) {
            case 2:
                stringtoDecode += "=="
            case 3:
                stringtoDecode += "="
            default:
                break
        }
        
        guard let data = Data(base64Encoded: stringtoDecode, options: [.ignoreUnknownCharacters]) else {
            
            throw NSError(domain: "decodeUrlSafeBase64", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Can't decode base64 string"])
        }
        
        return data
    }
    
    static func random(_ len: Int) -> Data {
        let values = (0 ..< len).map { _ in UInt8.random(in: 0 ... 255) }
        return Data(values)
    }

    var bytes: [UInt8] {
        var b: [UInt8] = []
        b.append(contentsOf: self)
        return b
    }
    
    var urlSafeB64String: String {
        return self.base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "").replacingOccurrences(of: "+", with: "-")
    }
         
}

public extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = Darwin.pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    var withCommas: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
    func withCommasNotRounded() -> String {
        let arr = "\(self)".split(separator: ".")
        let satoshis = "\(arr[1])"
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        let arr1 = (numberFormatter.string(from: NSNumber(value:self))!).split(separator: ".")
        let numberWithCommas = "\(arr1[0])"
        return numberWithCommas + "." + satoshis
    }
    
    var avoidNotation: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(for: self) ?? ""
    }
    
    var satsToBtc: String {
        var processed = "\(self)".replacingOccurrences(of: ",", with: "")
        processed = processed.replacingOccurrences(of: "-", with: "")
        processed = processed.replacingOccurrences(of: "+", with: "")
        processed = processed.replacingOccurrences(of: "sats", with: "").condenseWhitespace()
        let btc = processed.doubleValue / 100000000.0
        return btc.avoidNotation
    }
    
    var sats: String {
        let sats = self * 100000000.0
        
        if sats < 1.0 {
            return sats.avoidNotation + " sats"
        } else if sats == 1.0 {
            return "1 sat"
        } else {
            return "\(Int(sats).withCommas) sats"
        }
    }
    
    var btc: String {
        if self > 1.0 {
            return self.withCommasNotRounded() + " btc"
        } else {
            return self.avoidNotation + " btc"
        }
    }
    
    var balanceText: String {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        var symbol = "$"
        
        for curr in currencies {
            for (key, value) in curr {
                if key == currency {
                    symbol = value
                }
            }
        }
        
        var dbl = self
        
        if dbl < 0 {
            dbl = dbl * -1.0
        }
        
        if dbl < 1.0 {
            return "\(symbol)\(dbl.avoidNotation)"
        } else {
            return "\(symbol)\(dbl.rounded(toPlaces: 2).withCommas)"
        }
    }
    
    var exchangeRate: String {
        let currency = UserDefaults.standard.object(forKey: "currency") as? String ?? "USD"
        
        var symbol = "$"
        
        for curr in currencies {
            for (key, value) in curr {
                if key == currency {
                    symbol = value
                }
            }
        }
        
        return "\(symbol)\(self.withCommas) / btc"
    }
    
    var fiatString: String {
        let currencyCode = UserDefaults.standard.string(forKey: "currency") ?? "USD"
        
        var symbol = currencyCode
        
        for dict in currencies {
            if let foundSymbol = dict[currencyCode] {
                symbol = foundSymbol
                break
            }
        }
        
        // Always format to 2 decimal places using NumberFormatter for reliability
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfEven
        
        let formattedAmount = formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
        
        // Special case: some currencies have symbol AFTER the amount (rare, but e.g. CHF sometimes)
        // You can customize this list if needed
        let symbolAfter = ["CHF"]
        
        if symbolAfter.contains(currencyCode) {
            return "\(formattedAmount) \(symbol)"
        } else {
            return "\(symbol)\(formattedAmount)"
        }
    }
    
    var satsToBtcDouble: Double {
        return self / 100000000.0
    }
    
    var isWholeNumber: Bool {
        return truncatingRemainder(dividingBy: 1) == 0
    }
    
    var btcBalanceWithSpaces: String {
        if (self * 1.0).isWholeNumber {
            return "\(self)"
        }
        if self > 10 {
            return Swift.abs(self.rounded(toPlaces: 2)).avoidNotation.replacingOccurrences(of: ",", with: "")
        }
        var btcBalance = Swift.abs(self.rounded(toPlaces: 8)).avoidNotation
        btcBalance = btcBalance.replacingOccurrences(of: ",", with: "")
        
        if !btcBalance.contains(".") {
            btcBalance += ".0"
        }
        
        if self == 0.0 {
            btcBalance = "0.00 000 000"
        } else {
            var decimalLocation = 0
            var btcBalanceArray:[String] = []
            var digitsPastDecimal = 0
                        
            for (i, c) in btcBalance.enumerated() {
                btcBalanceArray.append("\(c)")
                if c == "." {
                    decimalLocation = i
                }
                if i > decimalLocation {
                    digitsPastDecimal += 1
                }
            }
            
            if digitsPastDecimal <= 7 {
                let numberOfTrailingZerosNeeded = 7 - digitsPastDecimal

                for _ in 0...numberOfTrailingZerosNeeded {
                    btcBalanceArray.append("0")
                }
            }
            
            btcBalanceArray.insert(" ", at: decimalLocation + 3)
            btcBalanceArray.insert(" ", at: decimalLocation + 7)
            btcBalance = btcBalanceArray.joined()
        }
        
        return btcBalance
    }
}

public extension Int {
    
    var avoidNotation: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.maximumFractionDigits = 8
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(for: self) ?? ""
    }
    
    var satsToBtcDouble: Double {
        return Double(self) / 100000000.0
    }
    
    var withCommas: String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        numberFormatter.locale = Locale(identifier: "en_US")
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
    var dateFromUnixTimestampInt: String {
        // 1. Create a Date object from the Unix epoch timestamp.
        // The Unix epoch is in seconds, so cast the Int to TimeInterval.
        let date = Date(timeIntervalSince1970: TimeInterval(self))
        
        // 2. Create a DateFormatter instance.
        let dateFormatter = DateFormatter()
        
        // 3. Set the date style and time style to use the device's locale defaults.
        // This will automatically adapt the format to the user's regional settings.
        dateFormatter.dateStyle = .medium // Or .short, .long, .full
        dateFormatter.timeStyle = .medium // Or .short, .long, .full
        
        // 4. Optionally, set the locale explicitly if you need a specific locale,
        // otherwise, it defaults to the user's current locale.
        // dateFormatter.locale = Locale(identifier: "en_US")
        
        // 5. Convert the Date object to a string using the formatter.
        return dateFormatter.string(from: date)
    }
    
}

public extension Encodable {

    /// Encode into JSON and return `Data`
    func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

public extension UIView {
    #if targetEnvironment(macCatalyst)
    @objc(_focusRingType)
    var focusRingType: UInt {
        return 1 //NSFocusRingTypeNone
    }
    #endif
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

public var timestampData: String {
    return "blindingKey"
}

public extension ContiguousBytes {
    @inlinable var bytes: [UInt8] {
        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
    }
}

public extension Data {
    /// Securely zeroizes the memory of this Data instance
    mutating func secureZero() {
        guard !isEmpty else { return }
        withUnsafeMutableBytes { bytes in
            bytes.baseAddress?.assumingMemoryBound(to: UInt8.self).initialize(repeating: 0, count: bytes.count)
        }
        // Force deallocation if possible
        self = Data()
    }
//    @inlinable var bytesNostr: [UInt8] {
//        withUnsafeBytes { bytesPtr in Array(bytesPtr) }
//    }

    func copyToUnsafeMutableBytes<T>(of value: inout T) {
        _ = Swift.withUnsafeMutableBytes(of: &value) { ptr in
            ptr.copyBytes(from: self.prefix(ptr.count))
        }
    }
    
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
}

extension Int32 {
    var boolValue: Bool {
        Bool(truncating: NSNumber(value: self))
    }
}
