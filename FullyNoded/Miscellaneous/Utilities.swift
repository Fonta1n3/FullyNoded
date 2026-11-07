//
//  Utilities.swift
//  BitSense
//
//  Created by Fontaine on 08/08/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation
import UIKit

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

/// Every simple "OK" alert in the app. Drawn as the themed card (SuccessView) instead of a
/// UIAlertController: success, notice or error, inferred from the text unless `kind` is given.
/// Cards queue rather than being dropped while another is showing. Safe from any thread.
public func showAlert(vc: UIViewController? = nil, title: String, message: String) {
    showAlert(vc: vc, title: title, message: message, kind: nil)
}

func showAlert(vc: UIViewController? = nil, title: String, message: String, kind: SuccessView.Kind?) {
    DispatchQueue.main.async {
        let host: UIView?
        if let vc = vc, vc.isViewLoaded, let window = vc.view.window {
            host = window
        } else {
            host = UIApplication.shared.connectedScenes
                .compactMap { ($0 as? UIWindowScene)?.windows.first { $0.isKeyWindow } }
                .first
        }

        let kind = kind ?? AlertKind.infer(title: title, message: message)
        // Many alerts pass only a message: give the card a short heading for its kind.
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AlertKind.heading(for: kind) : title
        SuccessView.show(on: host, kind: kind, title: heading, subtitle: message)
    }
}

/// Classifies the app's existing alert texts, so the call sites don't change.
enum AlertKind {
    private static let errorWords = ["error", "fail", "unable", "invalid", "can't", "cannot", "couldn't",
                                     "could not", "wrong", "missing", "unsupported", "issue", "uh oh",
                                     "denied", "not found", "mismatch", "incorrect", "not valid", "no response",
                                     "unknown", "not secure", "did not match", "not formatted", "not a valid",
                                     "not reachable", "not supported", "not a supported", "does not appear",
                                     "was not ", "not saved"]
    /// Things that just happened ("Wallet unloaded.", "Auth keys saved.").
    private static let doneWords = [" added", " saved", " updated", " deleted", " activated", " synced",
                                    " unloaded", " wiped", " increased", " set to active", " encrypted", " decrypted"]

    static func infer(title: String, message: String) -> SuccessView.Kind {
        let text = (title + " " + message).lowercased()
        if errorWords.contains(where: { text.contains($0) }) { return .error }
        if ["✓", "success", "🔐", "🔓", "thank you"].contains(where: { text.contains($0) }) { return .success }
        // "Cert deleted." is done; "No wallet activated…" / "not …" isn't.
        let negated = text.hasPrefix("no ") || text.hasPrefix(" no ") || text.contains(" not ")
        if !negated, doneWords.contains(where: { text.contains($0) }) { return .success }
        return .notice
    }

    static func heading(for kind: SuccessView.Kind) -> String {
        switch kind {
        case .success: return "Done"
        case .notice: return "Note"
        case .error: return "Something went wrong"
        }
    }
}

public func impact() {
    DispatchQueue.main.async {
        UIImpactFeedbackGenerator().impactOccurred()
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
        showAlert(vc: viewController, title: isError ? "Error" : "", message: message, kind: isError ? .error : nil)
    }
}

public func currentDate() -> String {
    return "NZdDCNBFTDqKPrUG9V80g0iVemSXLL0CuaWj12xqD00="
}

public func isWalletRPC(command: BTC_CLI_COMMAND) -> Bool {
    switch command {
    case .listdescriptors,
            .setlabel,
            .listtransactions,
            .getbalance,
            .getnewaddress,
            .getwalletinfo,
            .importmulti,
            .rescanblockchain,
            .listunspent,
            .walletprocesspsbt,
            .gettransaction,
            .getaddressinfo,
            .bumpfee,
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
        return true
    default:
        return false
    }
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
