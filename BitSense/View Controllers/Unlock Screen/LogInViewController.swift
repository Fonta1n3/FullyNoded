//
//  LogInViewController.swift
//  BitSense
//
//  Created by Peter on 03/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

//need to copy account creation to create account view controller

import UIKit
import LocalAuthentication

class LogInViewController: UIViewController, UITextFieldDelegate {

    let passwordInput = UITextField()
    let portInput = UITextField()
    let labelTitle = UILabel()
    let lockView = UIView()
    let touchIDButton = UIButton()
    let imageView = UIImageView()
    let fingerPrintView = UIImageView()
    let nextButton = UIButton()
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        passwordInput.delegate = self
        
        lockView.backgroundColor = UIColor.black
        lockView.alpha = 1
        
        imageView.image = UIImage(named: "ItunesArtwork@2x.png")
        imageView.alpha = 1
        
        passwordInput.keyboardType = UIKeyboardType.default
        passwordInput.autocapitalizationType = .none
        passwordInput.autocorrectionType = .no
        passwordInput.layer.cornerRadius = 10
        passwordInput.backgroundColor = UIColor.white
        passwordInput.alpha = 0
        passwordInput.textColor = UIColor.black
        passwordInput.placeholder = "Password"
        passwordInput.isSecureTextEntry = true
        passwordInput.returnKeyType = UIReturnKeyType.go
        passwordInput.textAlignment = .center
        passwordInput.keyboardAppearance = UIKeyboardAppearance.dark
        passwordInput.tintColor = UIColor.black
        
        labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 30)
        labelTitle.textColor = UIColor.white
        labelTitle.alpha = 0
        labelTitle.numberOfLines = 0
        labelTitle.text = "Unlock"
        labelTitle.textAlignment = .center
        
        touchIDButton.setImage(UIImage(named: "whiteFingerPrint.png"), for: .normal)
        touchIDButton.backgroundColor = UIColor.clear
        touchIDButton.alpha = 0
        touchIDButton.addTarget(self, action: #selector(authenticationWithTouchID), for: .touchUpInside)
        
        view.addSubview(lockView)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        imageView.removeFromSuperview()
        lockView.addSubview(imageView)
        
        passwordInput.removeFromSuperview()
        lockView.addSubview(passwordInput)
        
        labelTitle.removeFromSuperview()
        lockView.addSubview(labelTitle)
        
        addNextButton(inputView: self.passwordInput)
        
        let ud = UserDefaults.standard
        
        if ud.object(forKey: "bioMetricsDisabled") == nil {
            
            touchIDButton.removeFromSuperview()
            lockView.addSubview(touchIDButton)
            
        }
        
        showUnlockScreen()
        
        DispatchQueue.main.async {
            
            UIImpactFeedbackGenerator().impactOccurred()
            
        }
        
        if ud.object(forKey: "bioMetricsDisabled") == nil {
            
            authenticationWithTouchID()
            
        }
        
    }
    
    override func viewDidLayoutSubviews() {
        
        lockView.frame = self.view.frame
        imageView.frame = CGRect(x: self.view.center.x - 40, y: 40, width: 80, height: 80)
        passwordInput.frame = CGRect(x: 50, y: imageView.frame.maxY + 80, width: view.frame.width - 100, height: 50)
        labelTitle.frame = CGRect(x: self.view.center.x - ((view.frame.width - 10) / 2), y: passwordInput.frame.minY - 50, width: view.frame.width - 10, height: 50)
        nextButton.frame = CGRect(x: self.view.center.x - 40, y: passwordInput.frame.maxY + 5, width: 80, height: 55)
        touchIDButton.frame = CGRect(x: self.view.center.x - 30, y: self.nextButton.frame.maxY + 20, width: 60, height: 60)
        
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            self.passwordInput.resignFirstResponder()
            
        }
        
    }
    
    func addNextButton(inputView: UITextField) {
        
        DispatchQueue.main.async {
            self.nextButton.removeFromSuperview()
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.setTitleColor(UIColor.white, for: .normal)
            self.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
            self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.view.addSubview(self.nextButton)
            
        }
        
    }
    
    func showUnlockScreen() {
        
        UIView.animate(withDuration: 0.2, animations: {
                
            self.passwordInput.alpha = 1
            self.labelTitle.alpha = 1
            self.touchIDButton.alpha = 1
                
        })
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        self.view.endEditing(true)
        return false
        
    }
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        print("textFieldDidEndEditing")
        
        switch textField {
            
        case self.passwordInput:
            
            if self.passwordInput.text != "" {
                
                self.checkPassword(password: self.passwordInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.passwordInput)
            }
            
        default:
            
            break
            
        }
        
    }

    func checkPassword(password: String) {
        
        if let passwordData = KeyChain.getData("UnlockPassword") {
            
            let retrievedPassword = passwordData.utf8
            
            if self.passwordInput.text! == retrievedPassword {
                
                self.touchIDButton.removeFromSuperview()
                self.nextButton.removeFromSuperview()
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.passwordInput.alpha = 0
                    self.labelTitle.alpha = 0
                    
                }, completion: { _ in
                    
                    self.passwordInput.text = ""
                    self.labelTitle.text = ""
                    self.imageView.removeFromSuperview()
                    self.passwordInput.removeFromSuperview()
                    
                    DispatchQueue.main.async {
                        self.dismiss(animated: true, completion: nil)
                    }
                    
                })
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "Wrong password")
            }
            
        }
        
    }
    
    func unlock() {
        
        self.nextButton.removeFromSuperview()
        self.touchIDButton.removeFromSuperview()
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.passwordInput.alpha = 0
            self.labelTitle.alpha = 0
            
        }, completion: { _ in
            
            self.passwordInput.text = ""
            self.labelTitle.text = ""
            self.imageView.removeFromSuperview()
            self.passwordInput.removeFromSuperview()
            
            //check if user has saved username and password to node
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
            
        })
        
    }
    
    @objc func authenticationWithTouchID() {
        print("authenticationWithTouchID")
        
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Password"
        
        var authError: NSError?
        let reasonString = "To Unlock"
        
        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString) { success, evaluateError in
                
                if success {
                    print("success")
                    
                    DispatchQueue.main.async {
                        
                        self.unlock()
                        
                    }
                    
                } else {
                    
                    guard let error = evaluateError else {
                        
                        return
                        
                    }
                    
                    print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                    
                }
                
            }
            
        } else {
            
            guard let error = authError else {
                
                return
                
            }
            
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            if self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code) != "Too many failed attempts." {
                
            }
            
            print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error.code))
            
        }
        
    }
    
    
    
    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
        
        var message = ""
        
        if #available(iOS 11.0, macOS 10.13, *) {
            
            switch errorCode {
                
            case LAError.biometryNotAvailable.rawValue:
                message = "Authentication could not start because the device does not support biometric authentication."
                
            case LAError.biometryLockout.rawValue:
                message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
                
            case LAError.biometryNotEnrolled.rawValue:
                message = "Authentication could not start because the user has not enrolled in biometric authentication."
                
            default:
                message = "Did not find error code on LAError object"
            }
            
        } else {
            
            switch errorCode {
                
            case LAError.touchIDLockout.rawValue:
                message = "Too many failed attempts."
                
            case LAError.touchIDNotAvailable.rawValue:
                message = "TouchID is not available on the device"
                
            case LAError.touchIDNotEnrolled.rawValue:
                message = "TouchID is not enrolled on the device"
                
            default:
                message = "Did not find error code on LAError object"
            }
            
        }
        
        return message
        
    }
    
    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        
        var message = ""
        
        switch errorCode {
            
        case LAError.authenticationFailed.rawValue:
            message = "The user failed to provide valid credentials"
            
        case LAError.appCancel.rawValue:
            message = "Authentication was cancelled by application"
            
        case LAError.invalidContext.rawValue:
            message = "The context is invalid"
            
        case LAError.notInteractive.rawValue:
            message = "Not interactive"
            
        case LAError.passcodeNotSet.rawValue:
            message = "Passcode is not set on the device"
            
        case LAError.systemCancel.rawValue:
            message = "Authentication was cancelled by the system"
            
        case LAError.userCancel.rawValue:
            message = "The user did cancel"
            
        case LAError.userFallback.rawValue:
            message = "The user chose to use the fallback"
            
        default:
            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
        }
        
        return message
    }
    
}

extension UIViewController {
    
    func topViewController() -> UIViewController! {
        
        if self.isKind(of: UITabBarController.self) {
            
            let tabbarController =  self as! UITabBarController
            
            return tabbarController.selectedViewController!.topViewController()
            
        } else if (self.isKind(of: UINavigationController.self)) {
            
            let navigationController = self as! UINavigationController
            
            return navigationController.visibleViewController!.topViewController()
            
        } else if ((self.presentedViewController) != nil) {
            
            let controller = self.presentedViewController
            
            return controller!.topViewController()
            
        } else {
            
            return self
            
        }
        
    }

}


