//
//  LogInViewController.swift
//  BitSense
//
//  Created by Peter on 03/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import LocalAuthentication

class LogInViewController: UIViewController, UITextFieldDelegate {

    var onDoneBlock: (() -> Void)?
    let passwordInput = UITextField()
    let lockView = UIView()
    let touchIDButton = UIButton()
    let imageView = UIImageView()
    let fingerPrintView = UIImageView()
    let nextButton = UIButton()
    let nextAttemptLabel = UILabel()
    var timeToDisable = 2.0
    var timer: Timer?
    var secondsRemaining = 2
    var tapGesture:UITapGestureRecognizer!
    var resetButton = UIButton()
    var isRessetting = false
    var initialLoad = true

    override func viewDidLoad() {
        super.viewDidLoad()

        tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)

        passwordInput.delegate = self
        passwordInput.returnKeyType = .done

        lockView.backgroundColor = .black
        lockView.alpha = 1

        imageView.image = UIImage(named: "logo_grey.png")
        imageView.alpha = 1

        passwordInput.keyboardType = .default
        passwordInput.autocapitalizationType = .none
        passwordInput.autocorrectionType = .no
        passwordInput.layer.cornerRadius = 10
        passwordInput.alpha = 0
        passwordInput.placeholder = "password"
        passwordInput.isSecureTextEntry = true
        passwordInput.returnKeyType = .go
        passwordInput.textAlignment = .center
        passwordInput.keyboardAppearance = .dark
        passwordInput.layer.borderWidth = 0.5
        passwordInput.layer.borderColor = UIColor.lightGray.cgColor

        touchIDButton.setImage(UIImage(systemName: "faceid"), for: .normal)
        touchIDButton.tintColor = .systemTeal
        touchIDButton.backgroundColor = UIColor.clear
        touchIDButton.addTarget(self, action: #selector(authenticationWithTouchID), for: .touchUpInside)
        touchIDButton.showsTouchWhenHighlighted = true

        #if !targetEnvironment(macCatalyst)
            touchIDButton.alpha = 1
        #else
            touchIDButton.alpha = 0
        #endif

        view.addSubview(lockView)

        guard let timeToDisableOnKeychain = KeyChain.getData("TimeToDisable") else {
            let _ = KeyChain.set("2.0".utf8, forKey: "TimeToDisable")
            return
        }

        guard let seconds = timeToDisableOnKeychain.utf8String, let time = Double(seconds) else { return }

        timeToDisable = time
        secondsRemaining = Int(timeToDisable)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if initialLoad {
            initialLoad = false
            lockView.addSubview(imageView)
            lockView.addSubview(passwordInput)
            passwordInput.removeGestureRecognizer(tapGesture)
            addNextButton(inputView: passwordInput)

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

            configureTimeoutLabel()

            if timeToDisable > 2.0 {
                disable()
            }
        }
    }
    
    private func addResetPassword() {
        resetButton.removeFromSuperview()
        resetButton.showsTouchWhenHighlighted = true
        resetButton.setTitle("reset app", for: .normal)
        resetButton.addTarget(self, action: #selector(promptToReset), for: .touchUpInside)
        resetButton.setTitleColor(.systemRed, for: .normal)
        view.addSubview(resetButton)
    }

    override func viewDidLayoutSubviews() {
        lockView.frame = self.view.frame
        imageView.frame = CGRect(x: self.view.center.x - 40, y: 40, width: 80, height: 80)
        passwordInput.frame = CGRect(x: 50, y: imageView.frame.maxY + 80, width: view.frame.width - 100, height: 50)
        nextButton.frame = CGRect(x: self.view.center.x - 40, y: passwordInput.frame.maxY + 15, width: 80, height: 35)
        touchIDButton.frame = CGRect(x: self.view.center.x - 30, y: self.nextButton.frame.maxY + 20, width: 60, height: 60)
        resetButton.frame = CGRect(x: self.view.center.x - 50, y: self.nextButton.frame.maxY + 100, width: 100, height: 60)
    }
    
    @objc func promptToReset() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "⚠️ Reset app password?",
                                          message: "THIS DELETES ALL DATA AND COMPLETELY WIPES THE APP! Force quit the app and reopen the app after this action.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Reset", style: .destructive, handler: { [weak self] action in
                guard let self = self else { return }
                
                self.destroy { destroyed in
                    if destroyed {
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            
                            KeyChain.removeAll()
                            self.timeToDisable = 0.0
                            self.timer?.invalidate()
                            self.secondsRemaining = 0
                            self.dismiss(animated: true) {
                                showAlert(vc: self, title: "", message: "The app has been wiped.")
                                self.onDoneBlock!()
                            }
                        }
                    } else {
                        showAlert(vc: self, title: "", message: "The app was not wiped!")
                    }
                }
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }
    
    private func destroy(completion: @escaping ((Bool)) -> Void) {
        
        let entities:[ENTITY] = [.authKeys,
                                 .newNodes,
                                 .peers,
                                 .signers,
                                 .transactions,
                                 .utxos,
                                 .wallets]
        
        for entity in entities {
            deleteEntity(entity: entity) { success in
                completion(success)
            }
        }
    }
    
    private func deleteEntity(entity: ENTITY, completion: @escaping ((Bool)) -> Void) {
        CoreDataService.deleteAllData(entity: entity) { success in
            completion((success))
        }
    }
    
    @objc func present2fa() {
        self.promptToReset()
    }

    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.passwordInput.resignFirstResponder()
        }
    }

    func addNextButton(inputView: UITextField) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.nextButton.removeFromSuperview()
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("next", for: .normal)
            self.nextButton.setTitleColor(.systemTeal, for: .normal)
            self.nextButton.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.nextButton.backgroundColor = #colorLiteral(red: 0.1215686275, green: 0.1294117647, blue: 0.1411764706, alpha: 1)
            self.nextButton.clipsToBounds = true
            self.nextButton.layer.cornerRadius = 8
            self.view.addSubview(self.nextButton)
        }
    }

    func showUnlockScreen() {
        UIView.animate(withDuration: 0.2, animations: {
            self.passwordInput.alpha = 1
            #if !targetEnvironment(macCatalyst)
                self.touchIDButton.alpha = 1
            #endif
        })
    }

    @objc func nextButtonAction() {
        guard passwordInput.text != "" else {
            shakeAlert(viewToShake: passwordInput)
            return
        }

        passwordInput.resignFirstResponder()
        checkPassword(password: passwordInput.text!)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard passwordInput.text != "" else {
            shakeAlert(viewToShake: passwordInput)
            return true
        }
        
        checkPassword(password: passwordInput.text!)
        
        return true
    }

    private func unlock() {
        let _ = KeyChain.set("2.0".dataUsingUTF8StringEncoding, forKey: "TimeToDisable")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.touchIDButton.removeFromSuperview()
            self.nextButton.removeFromSuperview()
            
            UIView.animate(withDuration: 0.2, animations: {
                self.passwordInput.alpha = 0
                
            }, completion: { _ in
                self.passwordInput.text = ""
                self.imageView.removeFromSuperview()
                self.passwordInput.removeFromSuperview()
                
                DispatchQueue.main.async {
                    self.dismiss(animated: true) {
                        self.onDoneBlock!()
                    }
                }
            })
        }
    }

    func checkPassword(password: String) {
        guard let passwordData = KeyChain.getData("UnlockPassword") else { return }

        let retrievedPassword = passwordData.utf8String

        let hashedPassword = Crypto.sha256hash(password)

        guard let hexData = Data(hexString: hashedPassword) else { return }

        /// Overwrite users password with the hash of the password, sorry I did not do this before...
        if password == retrievedPassword {
            let _ = KeyChain.set(hexData, forKey: "UnlockPassword")
            unlock()

        } else {
            if hexData.hexString == passwordData.hexString {
                unlock()

            } else {
                timeToDisable = timeToDisable * 2.0
                
                if timeToDisable > 4.0 {
                    addResetPassword()
                }

                guard KeyChain.set("\(timeToDisable)".dataUsingUTF8StringEncoding, forKey: "TimeToDisable") else {
                    showAlert(vc: self, title: "Unable to set timeout", message: "This means something is very wrong, the device has probably been jailbroken or is corrupted")
                    return
                }

                secondsRemaining = Int(timeToDisable)

                disable()
            }
        }
    }

    private func configureTimeoutLabel() {
        nextAttemptLabel.textColor = .lightGray
        nextAttemptLabel.frame = CGRect(x: 0, y: view.frame.maxY - 50, width: view.frame.width, height: 50)
        nextAttemptLabel.textAlignment = .center
        nextAttemptLabel.text = ""
        view.addSubview(nextAttemptLabel)
    }

    private func disable() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.passwordInput.alpha = 0
            self.passwordInput.isUserInteractionEnabled = false
            self.nextButton.removeTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.nextButton.alpha = 0
        }

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if self.secondsRemaining == 0 {
                    self.timer?.invalidate()
                    self.nextAttemptLabel.text = ""
                    self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
                    self.nextButton.alpha = 1
                    self.passwordInput.alpha = 1
                    self.passwordInput.isUserInteractionEnabled = true
                } else {
                    self.secondsRemaining -= 1
                    self.nextAttemptLabel.text = "try again in \(self.secondsRemaining) seconds"
                }
            }
        }

        showAlert(vc: self, title: "Wrong password", message: "")
    }
    
    @objc func authenticationWithTouchID() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use passcode"
        var authError: NSError?
        let reasonString = "To unlock"

        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString) { success, evaluateError in
                if success {
                    DispatchQueue.main.async {
                        self.unlock()
                    }
                } else {
                    guard let error = evaluateError else { return }

                    print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                }
            }

        } else {

            guard let error = authError else { return }

            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            if self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code) != "Too many failed attempts." {

            }
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
