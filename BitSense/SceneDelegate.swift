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
    
    var window: UIWindow?
    private var isBooting = true
    
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
        let mgr = TorClient.sharedInstance
        if !isBooting && mgr.state != .started && mgr.state != .connected  {
            mgr.start(delegate: nil)
        } else {
            isBooting = false
        }
        
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        let mgr = TorClient.sharedInstance
        if mgr.state != .stopped {
            mgr.state = .refreshing
            mgr.resign()
        }

        // Save changes in the application's managed object context when the application transitions to the background.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }
        
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        let urlcontexts = URLContexts.first
        if let url = urlcontexts?.url {
            if url.pathExtension == "psbt" {
                let needTo = url.startAccessingSecurityScopedResource()
                do {
                    let data = try Data(contentsOf: url.absoluteURL)
                    let psbt = data.base64EncodedString()
                    presentSigner(psbt: psbt)
                } catch {
                    print(error.localizedDescription)
                }
                if needTo {
                  url.stopAccessingSecurityScopedResource()
                }
            } else if url.pathExtension == "txn" {
                let needTo = url.startAccessingSecurityScopedResource()
                do {
                    let data = try Data(contentsOf: url.absoluteURL)
                    if let txn = String(bytes: data, encoding: .utf8) {
                        presentBroadcaster(txn: txn)
                    }
                } catch {
                    
                }
                if needTo {
                  url.stopAccessingSecurityScopedResource()
                }
            } else if url.pathExtension == "json" {
                let needTo = url.startAccessingSecurityScopedResource()
                do {
                    let data = try Data(contentsOf: url.absoluteURL)
                    let dict = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                    if let p2wsh_deriv = dict["p2wsh_deriv"] as? String {
                        if p2wsh_deriv == "m/48'/0'/0'/2'" || p2wsh_deriv == "m/48'/1'/0'/2'" {
                            if let zpub = dict["p2wsh"] as? String, let fingerprint = dict["xfp"] as? String {
                                if let xpub = XpubConverter.convert(extendedKey: zpub) {
                                    presentMultisigCreator(zpub: zpub, fingerprint: fingerprint, xpub: xpub)
                                }
                            }
                        } else if let _ = dict["chain"] as? String {
                            print("coldcard single sig")
                        }
                    }
                } catch {
                    
                }
                if needTo {
                  url.stopAccessingSecurityScopedResource()
                }
            } else {
                addNode(url: "\(url)")
            }
        }
    }
    
    func addNode(url: String) {
        if let myTabBar = self.window?.rootViewController as? UITabBarController {
            let qc = QuickConnect()
            func getResult() {
                if !qc.errorBool {
                    print("success adding quick connect")
                } else {
                    print("error adding quick connect = \(qc.errorDescription)")
                }
            }
            qc.addNode(vc: myTabBar, url: url, completion: getResult)
        } else {
            print("error adding quick connect no access to tabbar")
        }
    }
    
    private func presentSigner(psbt: String) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        if let signerVc = storyBoard.instantiateViewController(identifier: "signerVc") as? SignerViewController {
            signerVc.psbt = psbt
            if let window = self.window, let rootViewController = window.rootViewController {
                var currentController = rootViewController
                while let presentedController = currentController.presentedViewController {
                    currentController = presentedController
                }
                currentController.present(signerVc, animated: true, completion: nil)
            }
        }
    }
    
    private func presentBroadcaster(txn: String) {
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        if let signerVc = storyBoard.instantiateViewController(identifier: "signerVc") as? SignerViewController {
            signerVc.txn = txn
            if let window = self.window, let rootViewController = window.rootViewController {
                var currentController = rootViewController
                while let presentedController = currentController.presentedViewController {
                    currentController = presentedController
                }
                currentController.present(signerVc, animated: true, completion: nil)
            }
        }
    }
    
    private func presentMultisigCreator(zpub: String, fingerprint: String, xpub: String) {
        //MultisigCreator
        let storyBoard = UIStoryboard(name: "Main", bundle: nil)
        if let multisigCreator = storyBoard.instantiateViewController(identifier: "MultisigCreator") as? MultiSigCreatorViewController {
            let dict = ["signer":"","fingerprint":fingerprint,"xpub":xpub,"zpub":zpub]
            multisigCreator.signers.append(dict)
            if let window = self.window, let rootViewController = window.rootViewController {
                var currentController = rootViewController
                while let presentedController = currentController.presentedViewController {
                    currentController = presentedController
                }
                multisigCreator.modalPresentationStyle = .fullScreen
                currentController.present(multisigCreator, animated: true, completion: nil)
            }
        }
    }
    
}
