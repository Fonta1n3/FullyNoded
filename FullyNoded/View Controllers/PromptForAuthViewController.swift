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
    
    @IBOutlet weak var bottomLabel: UILabel!
    
    var doneBlock : ((Data?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewDidAppear(_ animated: Bool) {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .white)
        button.frame = CGRect(x: view.center.x - 100, y: bottomLabel.frame.maxY + 8, width: 200, height: 60)
        button.addTarget(self, action: #selector(addAuth), for: .touchUpInside)
        view.addSubview(button)
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
    
    private func done(_ id: Data?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.dismiss(animated: true) {
                self.doneBlock!(id)
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        switch authorization.credential {
        case _ as ASAuthorizationAppleIDCredential:
            switch authorization.credential {
            case let appleIDCredential as ASAuthorizationAppleIDCredential:
                self.done(appleIDCredential.user.data(using: .utf8))
            default:
                break
            }
        default:
            break
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
