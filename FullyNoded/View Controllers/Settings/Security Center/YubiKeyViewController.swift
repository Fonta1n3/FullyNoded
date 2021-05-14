//
//  YubiKeyViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 5/13/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit
import YubiKit

class YubiKeyViewController: UIViewController, YKFManagerDelegate, YKFFIDO2SessionKeyStateDelegate {

    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var labelOutlet: UILabel!
    @IBOutlet weak var registerOutlet: UIButton!
    @IBOutlet weak var deleteOutlet: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
    
    override func viewWillAppear(_ animated: Bool) {
        statusView = view.presentStatusView()
        statusView?.state = .hidden
        
        if KeyChain.getData("YubikeyUsername") != nil {
            deleteOutlet.alpha = 1
        } else {
            deleteOutlet.alpha = 0
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        YubiKitManager.shared.delegate = self
        
        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.startAccessoryConnection()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if YubiKitDeviceCapabilities.supportsMFIAccessoryKey {
            YubiKitManager.shared.stopAccessoryConnection()
        }
    }
    
    @IBAction func deleteAction(_ sender: Any) {
        if KeyChain.remove(key: "YubikeyUsername") {
            showAlert(vc: self, title: "Deleted ✓", message: "You will no longer be prompted for Yubikey 2FA.")
        } else {
            showAlert(vc: self, title: "", message: "There was an error deleting your registration.")
        }
    }
    
    
    @IBAction func registerAction(_ sender: Any) {
        view.endEditing(true)
        
        register()
    }
    
    // MARK: - Yubikey
    var statusView: StatusView?
    
    func keyStateChanged(_ keyState: YKFFIDO2SessionKeyState) {
        if keyState == .touchKey {
            self.statusView?.state = .touchKey
        }
    }
    
    enum ConnectionType {
        case nfc
        case accessory
    }
    
    enum Action {
        case register
        case authenticate
    }
    
    var nfcConnection: YKFNFCConnection?

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
        
    var accessoryConnection: YKFAccessoryConnection?
    
    func didConnectAccessory(_ connection: YKFAccessoryConnection) {
        accessoryConnection = connection
    }
    
    func didDisconnectAccessory(_ connection: YKFAccessoryConnection, error: Error?) {
        accessoryConnection = nil
        session = nil
    }
    
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
    
    func connection(completion: @escaping (_ connection: YKFConnectionProtocol) -> Void) {
        if let connection = accessoryConnection {
            completion(connection)
        } else {
            connectionCallback = completion
            if #available(iOS 13.0, *) {
                if YubiKitDeviceCapabilities.supportsISO7816NFCTags {
                    YubiKitManager.shared.startNFCConnection()
                }
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
    
    func register() {
        let username = randomString(length: 32)
        
        guard let password = KeyChain.getData("UnlockPassword")?.hexString else {
            showAlert(vc: self, title: "No unlock password!", message: "Please go back and add an App Password before registering a Yubikey.")
            return
        }
        
        statusView?.state = .message("Creating user...")
        // 1. Begin WebAuthn registration
        beginWebAuthnRegistration(username: username, password: password) { result in
            switch result {
            case .success(let response):
                // 2. Create credential on Yubikey
                self.makeCredentialOnKey(response: response) { result in
                    if #available(iOS 13.0, *) {
                        #if !targetEnvironment(macCatalyst)
                        YubiKitManager.shared.stopNFCConnection()
                        #endif
                    }
                    switch result {
                    case .success(let response):
                        self.statusView?.state = .message("Finalising registration...")
                        // 3. Finalize WebAuthn registration
                        self.finalizeWebAuthnRegistration(response: response) { result in
                            switch result {
                            case .success:
                                if KeyChain.set(username.utf8, forKey: "YubikeyUsername") {
                                    self.statusView?.dismiss(message: "User successfully registrered", accessory: .checkmark, delay: 5.0)
                                } else {
                                    self.statusView?.dismiss(message: "There was an issue saving your username...", accessory: .error, delay: 5.0)
                                }
                                
                            case .failure(let error):
                                self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 5.0)
                            }
                        }
                    case .failure(let error):
                        self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 5.0)
                    }
                }
            case .failure(let error):
                self.statusView?.dismiss(message: "Error: \(error.localizedDescription)", accessory: .error, delay: 5.0)
            }
        }
    }
    
    func beginWebAuthnRegistration(username: String, password: String, completion: @escaping (Result<(BeginWebAuthnRegistrationResponse), Error>) -> Void) {
        let webauthnService = WebAuthnService()
        let createRequest = WebAuthnUserRequest(username: username, password: password, type: .create)
        webauthnService.createUserWith(request: createRequest) { (createUserResponse, error) in
            guard error == nil else { completion(.failure(error!)); return }
            guard let createUserResponse = createUserResponse else { fatalError() }
            let uuid = createUserResponse.uuid
            let registerBeginRequest = WebAuthnRegisterBeginRequest(uuid: uuid)
            webauthnService.registerBeginWith(request: registerBeginRequest) { (registerBeginResponse, error) in
                guard error == nil else { completion(.failure(error!)); return }
                guard let registerBeginResponse = registerBeginResponse else { fatalError() }
                let result = BeginWebAuthnRegistrationResponse(uuid: uuid,
                                                               requestId: registerBeginResponse.requestId,
                                                               challenge: registerBeginResponse.challenge,
                                                               rpId: registerBeginResponse.rpId,
                                                               rpName: registerBeginResponse.rpName,
                                                               userId: registerBeginResponse.userId,
                                                               userName: registerBeginResponse.username,
                                                               pubKeyAlg: registerBeginResponse.pubKeyAlg,
                                                               residentKey: registerBeginResponse.residentKey)
                completion(.success(result))
            }
        }
    }

    struct BeginWebAuthnRegistrationResponse {
        let uuid: String
        let requestId: String
        let challenge: String
        let rpId: String
        let rpName: String
        let userId: String
        let userName: String
        let pubKeyAlg: Int
        let residentKey: Bool
    }
        
    func makeCredentialOnKey(response: BeginWebAuthnRegistrationResponse,  completion: @escaping (Result<MakeCredentialOnKeyRegistrationResponse, Error>) -> Void) {
        let challengeData = Data(base64Encoded: response.challenge)!
        let clientData = YKFWebAuthnClientData(type: .create, challenge: challengeData, origin: WebAuthnService.origin)!
        
        let clientDataHash = clientData.clientDataHash!
        
        let rp = YKFFIDO2PublicKeyCredentialRpEntity()
        rp.rpId = response.rpId
        rp.rpName = response.rpName
        
        let user = YKFFIDO2PublicKeyCredentialUserEntity()
        user.userId = Data(base64Encoded: response.userId)!
        user.userName = response.userName
        
        let param = YKFFIDO2PublicKeyCredentialParam()
        param.alg = response.pubKeyAlg
        let pubKeyCredParams = [param]
        
        let options = [YKFFIDO2OptionRK: response.residentKey]
        
        session { session, error in
            guard let session = session else { completion(.failure(error!)); return }
            session.makeCredential(withClientDataHash:clientDataHash,
                                   rp: rp,
                                   user: user,
                                   pubKeyCredParams: pubKeyCredParams,
                                   excludeList: nil,
                                   options: options)  { [self] keyResponse, error in
                guard error == nil else {
                    if let error = error as NSError?, error.code == YKFFIDO2ErrorCode.PIN_REQUIRED.rawValue {
                        handlePINCode() {
                            makeCredentialOnKey(response: response, completion: completion)
                        }
                        return
                    }
                    completion(.failure(error!))
                    return
                }
                
                guard let keyResponse = keyResponse else { fatalError() }
                let result = MakeCredentialOnKeyRegistrationResponse(uuid: response.uuid,
                                                                     requestId: response.requestId,
                                                                     clientDataJSON: clientData.jsonData!,
                                                                     attestationObject: keyResponse.webauthnAttestationObject)
                completion(.success(result))
            }
        }
    }
    
    struct MakeCredentialOnKeyRegistrationResponse {
        let uuid: String
        let requestId: String
        let clientDataJSON: Data
        let attestationObject: Data
    }
    
    func finalizeWebAuthnRegistration(response: MakeCredentialOnKeyRegistrationResponse, completion: @escaping (Result<WebAuthnRegisterFinishResponse, Error>) -> Void) {
        let webauthnService = WebAuthnService()
        // Send back the response to the server.
        let registerFinishRequest = WebAuthnRegisterFinishRequest(uuid: response.uuid,
                                                                  requestId: response.requestId,
                                                                  clientDataJSON: response.clientDataJSON,
                                                                  attestationObject: response.attestationObject)
        webauthnService.registerFinishWith(request: registerFinishRequest) { (response, error) in
            guard error == nil else { completion(.failure(error!)); return }
            guard let response = response else { fatalError() }
            DispatchQueue.main.async {
                completion(.success(response))
            }
        }
    }

    func handlePINCode(completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            self.statusView?.state = .hidden
            let alert = UIAlertController(pinInputCompletion: { pin in
                guard let pin = pin else {
                    self.statusView?.dismiss(message: "No pin, exiting...", accessory: .error, delay: 5.0)
                    return
                }
                self.session { session, error in
                    guard let session = session else {
                        self.statusView?.dismiss(message: error!.localizedDescription, accessory: .error, delay: 5.0)
                        return
                    }
                    session.verifyPin(pin) { error in
                        guard error == nil else {
                            self.statusView?.dismiss(message: "Wrong PIN", accessory: .error, delay: 5.0)
                            return
                        }
                        completion()
                    }
                }
            })
            self.present(alert, animated: true)
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

extension UIAlertController {
    convenience init(pinInputCompletion:  @escaping (String?) -> Void) {
        self.init(title: "PIN verification required", message: "Enter the key PIN", preferredStyle: UIAlertController.Style.alert)
        addTextField { (textField) in
            textField.placeholder = "PIN"
            textField.isSecureTextEntry = true
        }
        addAction(UIAlertAction(title: "Verify", style: .default, handler: { (action) in
            let pin = self.textFields![0].text
            pinInputCompletion(pin)
        }))
        addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) in
            pinInputCompletion(nil)
        }))
    }
}

// Wrap the fido2Session() Objective-C method in a more easy to use Swift version
extension YKFConnectionProtocol {
    func fido2Session(_ completion: @escaping ((_ result: Result<YKFFIDO2Session, Error>) -> Void)) {
        self.fido2Session { session, error in
            guard error == nil else { completion(.failure(error!)); return }
            guard let session = session else { fatalError() }
            completion(.success(session))
        }
    }
}
