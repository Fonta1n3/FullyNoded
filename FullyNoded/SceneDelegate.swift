//
//  SceneDelegate.swift
//  BitSense
//
//  Created by Fontaine on 03/02/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    weak var mgr = TorClient.sharedInstance
    var window: UIWindow?
    private var isBooting = true
    private var blacked = UIView()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        let tabBarController = Self.makeTabBarController()
        // Cypherpunk tab bar (WalletTheme in ActiveWalletViewController.swift).
        WalletTheme.styleTabBar(tabBarController)
        window.rootViewController = tabBarController
        self.window = window
        window.makeKeyAndVisible()
    }
    
    /// Home, Wallet, Signers and Settings, each in its own navigation controller. The tabs
    /// are icons only, with the names as their accessibility labels.
    private static func makeTabBarController() -> UITabBarController {
        let tabs: [(root: UIViewController, symbol: String, label: String)] = [
            (MainMenuViewController(), "desktopcomputer", "Home"),
            (ActiveWalletViewController(), "bitcoinsign.square", "Wallet"),
            (SignersViewController(), "signature", "Signers"),
            (SettingsViewController(), "gear", "Settings")
        ]
        let tabBarController = UITabBarController()
        tabBarController.tabBar.barStyle = .black
        tabBarController.viewControllers = tabs.enumerated().map { index, tab in
            let navigationController = UINavigationController(rootViewController: tab.root)
            let item = UITabBarItem(title: nil, image: UIImage(systemName: tab.symbol), tag: index)
            item.accessibilityLabel = tab.label
            navigationController.tabBarItem = item
            return navigationController
        }
        return tabBarController
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.blacked.removeFromSuperview()
        guard !isBooting else { isBooting = !isBooting; return }
        
        guard AppAuthentication.hasAppPassword else {
            startTorIfNeeded()
            return
        }
        
        // On a Mac the app isn't locked when it comes back.
        guard !ProcessInfo.processInfo.isiOSAppOnMac,
              let topVC = self.window?.rootViewController?.topViewController(),
              topVC.restorationIdentifier != "LogIn" else {
            return
        }
        let loginVC = LogInViewController()
        loginVC.onDoneBlock = { [weak self] in
            self?.startTorIfNeeded()
        }
        
        DispatchQueue.main.async {
            loginVC.modalPresentationStyle = .fullScreen
            topVC.present(loginVC, animated: true, completion: nil)
        }
    }
    
    private func startTorIfNeeded() {
        if !isBooting && mgr?.state != .started && mgr?.state != .connected {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .startTorFromAppDelegate, object: nil, userInfo: nil)
            }
        } else {
            isBooting = false
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        
        // On a Mac Tor stays awake in the background.
        if mgr?.state != .stopped && mgr?.state != TorClient.TorState.none && !ProcessInfo.processInfo.isiOSAppOnMac {
            mgr?.pause()
        }
        
        if let window = self.window {
            // Privacy cover for the app switcher: the brand mark on the app's dark background.
            blacked.frame = window.bounds
            blacked.backgroundColor = WalletTheme.bg
            if blacked.subviews.isEmpty {
                let mark = BrandLockup(logoSize: 96)
                mark.translatesAutoresizingMaskIntoConstraints = false
                blacked.addSubview(mark)
                NSLayoutConstraint.activate([
                    mark.centerXAnchor.constraint(equalTo: blacked.centerXAnchor),
                    mark.centerYAnchor.constraint(equalTo: blacked.centerYAnchor, constant: -30)
                ])
            }
            window.addSubview(blacked)
        }
    }
        
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let urlcontexts = URLContexts.first
        guard let url = urlcontexts?.url else { return }
        
        if url.pathExtension == "psbt" {
            parsePsbt(url)
        } else if url.pathExtension == "txn" {
            parseTxn(url)
        } else if url.pathExtension == "json" {
            parseJsonFile(url)
        } else {
            addNode(url: "\(url)")
        }
    }
    
    private func parsePsbt(_ url: URL) {
        let needTo = url.startAccessingSecurityScopedResource()
        
        guard let data = try? Data(contentsOf: url.absoluteURL) else { return }
        
        let psbt = data.base64EncodedString()
        presentSigner(psbt: psbt)
        
        if needTo {
            url.stopAccessingSecurityScopedResource()
        }
    }
    
    private func parseTxn(_ url: URL) {
        let needTo = url.startAccessingSecurityScopedResource()
        
        guard let data = try? Data(contentsOf: url.absoluteURL), let txn = String(bytes: data, encoding: .utf8) else { return }
        
        presentBroadcaster(txn: txn)
        
        if needTo {
          url.stopAccessingSecurityScopedResource()
        }
    }
    
    private func parseJsonFile(_ url: URL) {
        let needTo = url.startAccessingSecurityScopedResource()
        
        guard let data = try? Data(contentsOf: url.absoluteURL),
            let dict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:Any] else {
                return
        }
        
        if let p2wsh_deriv = dict["p2wsh_deriv"] as? String {
            guard p2wsh_deriv == "m/48'/0'/0'/2'" || p2wsh_deriv == "m/48'/1'/0'/2'",
                let zpub = dict["p2wsh"] as? String,
                let fingerprint = dict["xfp"] as? String,
                let xpub = XpubConverter.convert(extendedKey: zpub) else {
                    return
            }
            
            let origin = p2wsh_deriv.replacingOccurrences(of: "m", with: fingerprint)
            let descriptor = "wsh([\(origin)]\(xpub)/0/*)"
            let cosigner = Descriptor(descriptor)
            
            presentMultisigCreator(cosigner: cosigner)
            
        } else if let _ = dict["chain"] as? String {
            presentWalletCreator(coldCard: dict)
            
        } else if let _ = dict["descriptor"] as? String {
            presentWalletImporter(accountMap: dict)
            
        }
        
        if needTo {
          url.stopAccessingSecurityScopedResource()
        }
    }
    
    private func addNode(url: String) {
        QuickConnect.addNode(url: url) { (success, _) in
            guard success else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
            }
        }
    }
        
    private func presentSigner(psbt: String) {
        showWalletTab(posting: .signPsbt, userInfo: ["psbt": psbt])
    }
    
    private func presentBroadcaster(txn: String) {
        showWalletTab(posting: .broadcastTxn, userInfo: ["txn": txn])
    }
    
    private func presentMultisigCreator(cosigner: Descriptor) {
        guard let topViewController = window?.rootViewController?.topViewController() else { return }
        let multisigCreator = CreateMultisigViewController()
        multisigCreator.cosigner = cosigner
        
        // In a navigation controller, for its title, close button and pushed screens.
        let navigationController = UINavigationController(rootViewController: multisigCreator)
        navigationController.modalPresentationStyle = .fullScreen
        topViewController.present(navigationController, animated: true, completion: nil)
    }
    
    private func presentWalletCreator(coldCard: [String:Any]) {
        showWalletTab(posting: .addColdCard, userInfo: coldCard)
    }
    
    private func presentWalletImporter(accountMap: [String:Any]) {
        showWalletTab(posting: .importWallet, userInfo: accountMap)
    }
    
    /// Switches to the Wallet tab, which handles `name`.
    private func showWalletTab(posting name: Notification.Name, userInfo: [String: Any]) {
        guard let tabBarController = window?.rootViewController as? UITabBarController else { return }
        
        tabBarController.selectedIndex = 1
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }
}
