//
//  PromptForAuthViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/30/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit
import AuthenticationServices

class PromptForAuthViewController: UIViewController, UINavigationControllerDelegate, ASAuthorizationControllerPresentationContextProviding, ASAuthorizationControllerDelegate {
    
    @IBOutlet weak var upperLabel: UILabel!
    @IBOutlet weak var bottomLabel: UILabel!
    
    var doneBlock : ((Data?) -> Void)?
    var authenticated: ((Bool) -> Void)?
    var authenticating = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if !authenticating {
            upperLabel.text = "Enable \"Sign in with Apple\" as a form of two factor authentication?"
        } else {
            upperLabel.text = "\"Sign in with Apple\" to authenticate."
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !authenticating {
            let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
            button.frame = CGRect(x: view.center.x - 100, y: bottomLabel.frame.maxY + 8, width: 200, height: 60)
            button.addTarget(self, action: #selector(addAuth), for: .touchUpInside)
            view.addSubview(button)
        } else {
            addAuth()
        }
    }
    
    @IBAction func closeAction(_ sender: Any) {
        done(nil, false)
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        return self.view.window!
    }
    
    @objc func addAuth() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }
    
    private func done(_ id: Data?, _ result: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if !self.authenticating {
                self.dismiss(animated: true) {
                    self.doneBlock?(id)
                }
            } else {
                self.dismiss(animated: true) {
                    self.authenticated?(result)
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if !authenticating {
            switch authorization.credential {
            case _ as ASAuthorizationAppleIDCredential:
                switch authorization.credential {
                case let appleIDCredential as ASAuthorizationAppleIDCredential:
                    self.done(appleIDCredential.user.data(using: .utf8), false)
                default:
                    break
                }
            default:
                break
            }
        } else {
            switch authorization.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                let authorizationProvider = ASAuthorizationAppleIDProvider()
                if let usernameData = KeyChain.getData("userIdentifier") {
                    if let username = String(data: usernameData, encoding: .utf8) {
                        if username == appleIDCredential.user {
                            authorizationProvider.getCredentialState(forUserID: username) { [weak self] (state, error) in
                                guard let self = self else { return }
                                
                                switch state {
                                case .authorized:
                                    UserDefaults.standard.setValue(Date(), forKey: "LastAuthenticated")
                                    self.done(nil, true)
                                case .notFound:
                                    self.done(nil, false)
                                case .revoked:
                                    self.done(nil, false)
                                case .transferred:
                                    self.done(nil, false)
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
