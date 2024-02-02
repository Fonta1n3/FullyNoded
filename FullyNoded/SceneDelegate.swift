//
//  SceneDelegate.swift
//  BitSense
//
//  Created by Peter on 03/02/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    weak var mgr = TorClient.sharedInstance
    var window: UIWindow?
    private var isBooting = true
    private var blacked = UIView()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        self.blacked.removeFromSuperview()
        guard !isBooting else { isBooting = !isBooting; return }
        
        guard KeyChain.getData("UnlockPassword") != nil else {
            DispatchQueue.background(delay: 0.2, completion:  {
                //                MakeRPCCall.sharedInstance.connectToRelay(node: <#NodeStruct#>)
                //                MakeRPCCall.sharedInstance.eoseReceivedBlock = { _ in }
            })
            if !isBooting && mgr?.state != .started && mgr?.state != .connected  {
                mgr?.start(delegate: nil)
            } else {
                isBooting = false
            }
            return
        }
        
        if #available(iOS 14.0, *) {
            if !ProcessInfo.processInfo.isiOSAppOnMac {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                
                guard let loginVC = storyboard.instantiateViewController(identifier: "LogIn") as? LogInViewController,
                      let topVC = self.window?.rootViewController?.topViewController(),
                      topVC.restorationIdentifier != "LogIn" else {
                    return
                }
                
                DispatchQueue.main.async {
                    loginVC.modalPresentationStyle = .fullScreen
                    topVC.present(loginVC, animated: true, completion: nil)
                }
                
                loginVC.onDoneBlock = { [weak self] in
                    guard let self = self else { return }
                    
                    //            DispatchQueue.background(delay: 0.2, completion:  {
                    //                //MakeRPCCall.sharedInstance.connectToRelay(node: )
                    ////                MakeRPCCall.sharedInstance.eoseReceivedBlock = { subscribed in
                    ////                    if subscribed {
                    ////                        DispatchQueue.main.async {
                    ////                            NotificationCenter.default.post(name: .refreshNode, object: nil)
                    ////                        }
                    ////                    }
                    ////                }
                    //            })
                    
                    if !self.isBooting && self.mgr?.state != .started && self.mgr?.state != .connected  {
                        self.mgr?.start(delegate: nil)
                    } else {
                        self.isBooting = false
                    }
                }
            }
            
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
        
        MakeRPCCall.sharedInstance.connected = false
        
        if mgr?.state != .stopped && mgr?.state != TorClient.TorState.none  {
            if #available(iOS 14.0, *) {
                if !ProcessInfo.processInfo.isiOSAppOnMac {
                    mgr?.state = .refreshing
                    mgr?.resign()
                } else {
                    print("running on mac, not quitting tor.")
                }
            }
        }
        
        if let window = self.window {
            blacked.frame = window.frame
            blacked.backgroundColor = .black
            self.window?.addSubview(blacked)
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
        QuickConnect.addNode(uncleJim: false, url: url) { (success, _) in
            guard success, !url.hasPrefix("clightning-rpc") else { return }
            
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
            }
        }
    }
        
    private func presentSigner(psbt: String) {
        guard let tabBarController = self.window!.rootViewController as? UITabBarController else { return }
        
        tabBarController.selectedIndex = 1
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .signPsbt, object: nil, userInfo: ["psbt":psbt])
        }
    }
    
    private func presentBroadcaster(txn: String) {
       guard let tabBarController = self.window!.rootViewController as? UITabBarController else { return }
        
        tabBarController.selectedIndex = 1
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .broadcastTxn, object: nil, userInfo: ["txn":txn])
        }
    }
    
    private func presentMultisigCreator(cosigner: Descriptor) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let multisigCreator = storyBoard.instantiateViewController(identifier: "MultisigCreator") as? CreateMultisigViewController,
            let window = self.window,
            let rootViewController = window.rootViewController else {
            return
        }
        
        multisigCreator.cosigner = cosigner
        
        var currentController = rootViewController
        
        while let presentedController = currentController.presentedViewController {
            currentController = presentedController
        }
        
        multisigCreator.modalPresentationStyle = .fullScreen
        currentController.present(multisigCreator, animated: true, completion: nil)
    }
    
    private func presentWalletCreator(coldCard: [String:Any]) {
        guard let tabBarController = self.window!.rootViewController as? UITabBarController else { return }
        
        tabBarController.selectedIndex = 1
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .addColdCard, object: nil, userInfo: coldCard)
        }
    }
    
    private func presentWalletImporter(accountMap: [String:Any]) {
        guard let tabBarController = self.window!.rootViewController as? UITabBarController else { return }
        
        tabBarController.selectedIndex = 1
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .importWallet, object: nil, userInfo: accountMap)
        }
    }
    
}
