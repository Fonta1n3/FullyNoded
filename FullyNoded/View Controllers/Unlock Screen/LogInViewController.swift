//
//  LogInViewController.swift
//  BitSense
//
//  Created by Peter on 03/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import LocalAuthentication
import YubiKit

class LogInViewController: UIViewController, UITextFieldDelegate, YKFManagerDelegate, YKFFIDO2SessionKeyStateDelegate {

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

        guard let seconds = timeToDisableOnKeychain.utf8, let time = Double(seconds) else { return }

        timeToDisable = time
        secondsRemaining = Int(timeToDisable)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        statusView = view.presentStatusView()
        statusView?.state = .hidden
    }

    override func viewDidAppear(_ animated: Bool) {
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
        
        YubiKitManager.shared.delegate = self
        
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.startAccessoryConnection()
        }
    }

    override func viewDidLayoutSubviews() {
        lockView.frame = self.view.frame
        imageView.frame = CGRect(x: self.view.center.x - 40, y: 40, width: 80, height: 80)
        passwordInput.frame = CGRect(x: 50, y: imageView.frame.maxY + 80, width: view.frame.width - 100, height: 50)
        nextButton.frame = CGRect(x: self.view.center.x - 40, y: passwordInput.frame.maxY + 15, width: 80, height: 35)
        touchIDButton.frame = CGRect(x: self.view.center.x - 30, y: self.nextButton.frame.maxY + 20, width: 60, height: 60)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.stopAccessoryConnection()
        }
    }

    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async {
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
                
                if KeyChain.getData("YubikeyUsername") != nil {
                    self.authenticate()
                } else {
                    DispatchQueue.main.async {
                        self.dismiss(animated: true) {
                            self.onDoneBlock!()
                        }
                    }
                }
            })
        }
    }

    func checkPassword(password: String) {
        guard let passwordData = KeyChain.getData("UnlockPassword") else { return }

        let retrievedPassword = passwordData.utf8

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
        localAuthenticationContext.localizedFallbackTitle = "Use Password"
        var authError: NSError?
        let reasonString = "To Unlock"

        if localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &authError) {
            localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reasonString) { success, evaluateError in
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
    
    // MARK: - Authenticate User
    
    enum ConnectionType {
        case nfc
        case accessory
    }
    
    var statusView: StatusView?
    var nfcConnection: YKFNFCConnection?
    var accessoryConnection: YKFAccessoryConnection?
    var connectionCallback: ((_ connection: YKFConnectionProtocol) -> Void)?
    
    var connectionType: ConnectionType? {
        get {
            if nfcConnection != nil {
                return .nfc
            } else if accessoryConnection != nil {
                return .accessory
            } else {
                return nil
            }
        }
    }
    
    func didConnectNFC(_ connection: YKFNFCConnection) {
        nfcConnection = connection
        if let callback = connectionCallback {
            callback(connection)
        }
    }
    
    func didDisconnectNFC(_ connection: YKFNFCConnection, error: Error?) {
        nfcConnection = nil
        session = nil
    }
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        session = nil
    }
    
    func keyStateChanged(_ keyState: YKFFIDO2SessionKeyState) {
        if keyState == .touchKey {
            self.statusView?.state = .touchKey
        }
    }
    
    func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if #available(iOS 13.0, *) {
                #if !targetEnvironment(macCatalyst)
                YubiKitManager.shared.startNFCConnection()
                #endif
            } else {
                
                // Fallback on earlier versions
            }
        }
    }
    
    var session: YKFFIDO2Session?
    
    func session(completion: @escaping (_ session: YKFFIDO2Session?, _ error: Error?) -> Void) {
        if let session = session {
            completion(session, nil)
            return
        }
        connection { connection in
            connection.fido2Session { session, error in
                self.session = session
                session?.delegate = self
                completion(session, error)
            }
        }
    }
    func authenticate() {
        guard let username = KeyChain.getData("YubikeyUsername")?.utf8 else { return }
        guard let password = KeyChain.getData("UnlockPassword")?.hexString else { return }

        statusView?.state = .message("Requesting authenticator challenge...")

        // 1. Begin WebAuthn authentication
        beginWebAuthnAuthentication(username: username, password: password) { result in
            switch result {
            case .success(let response):
                // 2. Assert on Yubikey
                self.assertOnKey(response: response) { result in
                    switch result {
                    case .success(let response):
                        self.statusView?.state = .message("Authenticating...")
                        // 3. Finalize WebAuthn authentication
                        self.finalizeWebAuthnAuthentication(response: response) { result in
                            switch result {
                            case .success:
                                self.statusView?.dismiss(message: "User successfully authenticated", accessory: .checkmark, delay: 7.0)
                                
                                DispatchQueue.main.async { [weak self] in
                                    guard let self = self else { return }
                                    
                                    self.dismiss(animated: true) {
                                        self.onDoneBlock!()
                                    }
                                }
                                
                            case .failure(let error):
                                self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 7.0)
                            }
                        }
                    case .failure(let error):
                        self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 7.0)
                    }
                }
            case .failure(let error):
                self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 7.0)
            }
        }
    }
    
    func beginWebAuthnAuthentication(username: String, password: String, completion: @escaping (Result<(BeginWebAuthnAuthenticationResponse), Error>) -> Void) {
        let webauthnService = WebAuthnService()
        let authenticationRequest = WebAuthnUserRequest(username: username, password: password, type: .login)
        webauthnService.loginUserWith(request: authenticationRequest) { (authenticationUserResponse, error) in
            guard error == nil else { completion(.failure(error!)); return }
            guard let authenticationUserResponse = authenticationUserResponse else { fatalError() }
            let uuid = authenticationUserResponse.uuid
            let authenticationBeginRequest = WebAuthnAuthenticateBeginRequest(uuid: uuid)
            webauthnService.authenticateBeginWith(request: authenticationBeginRequest) { (authenticationBeginResponse, error) in
                guard error == nil else { completion(.failure(error!)); return }
                guard let authenticationBeginResponse = authenticationBeginResponse else { fatalError() }
                let result = BeginWebAuthnAuthenticationResponse(uuid: uuid,
                                                                 requestId: authenticationBeginResponse.requestId,
                                                                 challenge: authenticationBeginResponse.challenge,
                                                                 rpId: authenticationBeginResponse.rpID,
                                                                 allowCredentials: authenticationBeginResponse.allowCredentials)
                completion(.success(result))
            }
        }
    }
    
    struct BeginWebAuthnAuthenticationResponse {
        let uuid: String
        let requestId: String
        let challenge: String
        let rpId: String
        let allowCredentials: [String]
    }
    
    func assertOnKey(response: BeginWebAuthnAuthenticationResponse, completion: @escaping (Result<AssertOnKeyAuthenticationResponse, Error>) -> Void) {
        session { session, error in
            guard let session = session else { completion(.failure(error!)); return }
            let challengeData = Data(base64Encoded: response.challenge)!
            let clientData = YKFWebAuthnClientData(type: .get, challenge: challengeData, origin: WebAuthnService.origin)!

            let clientDataHash = clientData.clientDataHash!

            let rpId = response.rpId
            let options = [YKFFIDO2OptionUP: true]

            var allowList = [YKFFIDO2PublicKeyCredentialDescriptor]()
            for credentialId in response.allowCredentials {
                let credentialDescriptor = YKFFIDO2PublicKeyCredentialDescriptor()
                credentialDescriptor.credentialId = Data(base64Encoded: credentialId)!
                let credType = YKFFIDO2PublicKeyCredentialType()
                credType.name = "public-key"
                credentialDescriptor.credentialType = credType
                allowList.append(credentialDescriptor)
            }

            session.getAssertionWithClientDataHash(clientDataHash,
                                                   rpId: rpId,
                                                   allowList: allowList,
                                                   options: options) { assertionResponse, error in
                if self.connectionType == .nfc, #available(iOS 13.0, *) {
                    YubiKitManager.shared.stopNFCConnection()
                }
                guard error == nil else {
                    completion(.failure(error!))
                    return
                }
                guard let assertionResponse = assertionResponse else { fatalError() }
                let result = AssertOnKeyAuthenticationResponse(uuid: response.uuid,
                                                               requestId: response.requestId,
                                                               credentialId: assertionResponse.credential!.credentialId,
                                                               authenticatorData: assertionResponse.authData,
                                                               clientDataJSON: clientData.jsonData!,
                                                               signature: assertionResponse.signature)
                completion(.success(result))
            }
        }
    }
    
    struct AssertOnKeyAuthenticationResponse {
        let uuid: String
        let requestId: String
        let credentialId: Data
        let authenticatorData: Data
        let clientDataJSON: Data
        let signature: Data
    }
    
    func finalizeWebAuthnAuthentication(response: AssertOnKeyAuthenticationResponse, completion: @escaping (Result<WebAuthnAuthenticateFinishResponse, Error>) -> Void) {

        let webauthnService = WebAuthnService()
        let authenticateFinishRequest = WebAuthnAuthenticateFinishRequest(uuid: response.uuid,
                                                                          requestId: response.requestId,
                                                                          credentialId: response.credentialId,
                                                                          authenticatorData: response.authenticatorData,
                                                                          clientDataJSON: response.clientDataJSON,
                                                                          signature: response.signature)

        webauthnService.authenticateFinishWith(request: authenticateFinishRequest) { (response, error) in
            guard error == nil else { completion(.failure(error!)); return }
            guard let response = response else { fatalError() }
            completion(.success(response))
        }
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
