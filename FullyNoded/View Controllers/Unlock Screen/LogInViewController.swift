//
//  LogInViewController.swift
//  BitSense
//
//  Created by Peter on 03/09/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import LocalAuthentication
import Security

/// App lock. Same checks as ever (app password, duress PIN, doubling lockout, reset,
/// biometrics-only unlock); the screen itself matches the launch screen / website:
/// glowing logo, "> fully noded", a terminal status line, and inline feedback instead
/// of alerts.
class LogInViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate {

    var onDoneBlock: (() -> Void)?
    let passwordInput = UITextField()
    let touchIDButton = UIButton(type: .system)
    let nextButton = UIButton(type: .system)
    var timeToDisable = 2.0
    var timer: Timer?
    var secondsRemaining = 2
    var tapGesture:UITapGestureRecognizer!
    var resetButton = UIButton(type: .system)
    var isRessetting = false
    var initialLoad = true

    private let tint = WalletTheme.Tint.home
    private let lockup = BrandLockup(logoSize: 88)
    /// "> locked_" line: what's going on, in terminal voice.
    private let statusLabel = UILabel()
    private var cursorTimer: Timer?
    private var statusText = "locked"
    private var statusColor = WalletTheme.dim
    private var cursorVisible = true

    private var biometricsEnabled: Bool {
        UserDefaults.standard.object(forKey: "bioMetricsDisabled") == nil && AppAuthentication.biometricsSupported
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = WalletTheme.bg
        view.subviews.forEach { $0.removeFromSuperview() }   // storyboard placeholder content

        tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        self.view.addGestureRecognizer(tapGesture)

        buildLayout()

        guard let timeToDisableOnKeychain = KeyChain.getData("TimeToDisable") else {
            let _ = KeyChain.set("2.0".utf8, forKey: "TimeToDisable")
            return
        }

        guard let seconds = timeToDisableOnKeychain.utf8String, let time = Double(seconds) else { return }

        timeToDisable = time
        secondsRemaining = Int(timeToDisable)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if initialLoad {
            initialLoad = false
            showUnlockScreen()

            DispatchQueue.main.async {
                UIImpactFeedbackGenerator().impactOccurred()
            }

            // A lockout only throttles password attempts; biometrics still work, as before.
            if timeToDisable > 2.0 {
                if timeToDisable > 4.0 { addResetPassword() }
                disable()
            }
            if biometricsEnabled && Self.biometricsAvailable() {
                authenticationWithTouchID()
            } else if timeToDisable <= 2.0 {
                passwordInput.becomeFirstResponder()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        cursorTimer?.invalidate()
    }

    // MARK: Layout

    private func buildLayout() {
        passwordInput.delegate = self
        passwordInput.placeholder = "app password"
        passwordInput.isSecureTextEntry = true
        passwordInput.textContentType = .password
        passwordInput.keyboardType = .default
        passwordInput.autocapitalizationType = .none
        passwordInput.autocorrectionType = .no
        passwordInput.returnKeyType = .go
        passwordInput.textAlignment = .center
        passwordInput.font = WalletTheme.mono(17)
        WalletTheme.styleField(passwordInput, tint: tint)
        passwordInput.heightAnchor.constraint(equalToConstant: 52).isActive = true

        WalletTheme.styleHero(nextButton, title: "Unlock", systemImage: "lock.open.fill", tint: tint)
        nextButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        nextButton.addTarget(self, action: #selector(nextButtonAction), for: .touchUpInside)

        let biometry = Self.biometryName()
        touchIDButton.configuration = WalletTheme.chipConfiguration(
            title: "Use \(biometry.name)", systemImage: biometry.symbol, tint: tint,
            fontSize: 13, imageSize: 15, imagePadding: 8,
            insets: NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16),
            background: .clear)
        touchIDButton.addTarget(self, action: #selector(authenticationWithTouchID), for: .touchUpInside)
        touchIDButton.isHidden = !biometricsEnabled || !Self.biometricsAvailable()

        var reset = UIButton.Configuration.plain()
        reset.title = "Forgot password? Reset app"
        reset.baseForegroundColor = WalletTheme.danger
        reset.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var attributes = incoming
            attributes.font = WalletTheme.mono(12, weight: .semibold)
            return attributes
        }
        resetButton.configuration = reset
        resetButton.addTarget(self, action: #selector(promptToReset), for: .touchUpInside)
        resetButton.isHidden = true

        statusLabel.font = WalletTheme.mono(13, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        renderStatus()

        let biometricRow = UIStackView(arrangedSubviews: [touchIDButton])
        biometricRow.alignment = .center
        biometricRow.axis = .vertical

        let lockupRow = UIStackView(arrangedSubviews: [lockup])
        lockupRow.axis = .vertical
        lockupRow.alignment = .center

        // One column, centred in the space above the keyboard (or the safe area).
        let content = UIStackView(arrangedSubviews: [lockupRow, statusLabel, passwordInput, nextButton, biometricRow, resetButton])
        content.axis = .vertical
        content.spacing = 14
        content.setCustomSpacing(36, after: lockupRow)
        content.setCustomSpacing(16, after: statusLabel)
        content.setCustomSpacing(6, after: biometricRow)
        statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        let guide = view.safeAreaLayoutGuide
        let space = UILayoutGuide()
        view.addLayoutGuide(space)
        let centered = content.centerYAnchor.constraint(equalTo: space.centerYAnchor, constant: -10)
        centered.priority = .defaultHigh
        NSLayoutConstraint.activate([
            space.topAnchor.constraint(equalTo: guide.topAnchor),
            space.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            centered,
            content.topAnchor.constraint(greaterThanOrEqualTo: space.topAnchor, constant: 8),
            content.bottomAnchor.constraint(lessThanOrEqualTo: space.bottomAnchor, constant: -12),
            content.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            content.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32)
        ])

        startCursor()
    }

    /// Enrolled (or temporarily locked out, which the app password still covers).
    private static func biometricsAvailable() -> Bool {
        var error: NSError?
        if LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) { return true }
        return error?.code == LAError.biometryLockout.rawValue
    }

    private static func biometryName() -> (name: String, symbol: String) {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .touchID: return ("Touch ID", "touchid")
        case .faceID: return ("Face ID", "faceid")
        default:
            if #available(iOS 17.0, *), context.biometryType == .opticID { return ("Optic ID", "opticid") }
            return ("Face ID", "faceid")
        }
    }

    // MARK: Status line

    private func setStatus(_ text: String, color: UIColor = WalletTheme.dim) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.statusText = text
            self.statusColor = color
            self.renderStatus()
        }
    }

    private func renderStatus() {
        let line = NSMutableAttributedString(string: "> ", attributes: [.foregroundColor: tint.accent])
        line.append(NSAttributedString(string: statusText, attributes: [.foregroundColor: statusColor]))
        line.append(NSAttributedString(string: "_", attributes: [.foregroundColor: cursorVisible ? tint.accent : UIColor.clear]))
        statusLabel.attributedText = line
    }

    private func startCursor() {
        cursorTimer?.invalidate()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.cursorVisible.toggle()
            self.renderStatus()
        }
    }

    private func setInputEnabled(_ enabled: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.passwordInput.isEnabled = enabled
            self.nextButton.isEnabled = enabled
            UIView.animate(withDuration: 0.2) {
                self.passwordInput.alpha = enabled ? 1 : 0.4
            }
            if enabled {
                self.passwordInput.becomeFirstResponder()
            } else {
                self.passwordInput.resignFirstResponder()
            }
        }
    }

    // MARK: Reset

    private func addResetPassword() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.resetButton.isHidden else { return }
            UIView.animate(withDuration: 0.25) {
                self.resetButton.isHidden = false
            }
        }
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
        let entities: [ENTITY] = [
            .timelocks,
            .signers,
            .newNodes,
            .wallets,
            .utxos,
            .usedAddresses,
            .transactions,
            .authKeys
        ]

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

    /// Taps on the password field must not trigger the dismiss gesture, otherwise the field
    /// resigns first responder as soon as it gains it and typing goes nowhere.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touched = touch.view else { return true }
        return !touched.isDescendant(of: passwordInput)
    }

    func showUnlockScreen() {
        lockup.alpha = 0
        lockup.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        UIView.animate(withDuration: 0.45, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, options: []) {
            self.lockup.alpha = 1
            self.lockup.transform = .identity
        }
    }

    // MARK: Unlocking

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

            self.timer?.invalidate()
            self.passwordInput.resignFirstResponder()
            self.setStatus("unlocked", color: self.tint.accent)
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            UIView.animate(withDuration: 0.25, delay: 0.15, options: .curveEaseIn, animations: {
                self.lockup.transform = CGAffineTransform(scaleX: 1.06, y: 1.06)
                self.lockup.alpha = 0
            }, completion: { _ in
                self.passwordInput.text = ""
                self.cursorTimer?.invalidate()
                self.dismiss(animated: true) {
                    self.onDoneBlock!()
                }
            })
        }
    }

    func checkPassword(password: String) {
        guard let passwordData = KeyChain.getData("UnlockPassword") else { return }

        let retrievedPassword = passwordData.utf8String

        let hashedPassword = Crypto.sha256hash(password)

        guard let hexData = Data(hexString: hashedPassword) else { return }

        let duressPINHash = UserDefaults.standard.object(forKey: "DuressPIN") as? String

        if password == retrievedPassword {
            let _ = KeyChain.set(hexData, forKey: "UnlockPassword")
            unlock()

        } else if let duressPINHash = duressPINHash, hashedPassword == duressPINHash {
            destroy { [weak self] destroyed in
                guard let self = self else { return }
                guard destroyed else { return }

                unlock()
            }

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

                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.passwordInput.text = ""
                    shakeAlert(viewToShake: self.passwordInput)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
                disable(afterWrongPassword: true)
            }
        }
    }

    /// Locks input for `secondsRemaining`, counting down on the status line.
    private func disable(afterWrongPassword: Bool = false) {
        setInputEnabled(false)
        let prefix = afterWrongPassword ? "wrong password · " : "too many attempts · "
        setStatus(prefix + "retry in \(secondsRemaining)s", color: afterWrongPassword ? WalletTheme.danger : WalletTheme.pending)

        timer?.invalidate()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }

                if self.secondsRemaining <= 1 {
                    self.timer?.invalidate()
                    self.secondsRemaining = 0
                    self.setStatus("locked")
                    self.setInputEnabled(true)
                } else {
                    self.secondsRemaining -= 1
                    self.setStatus("retry in \(self.secondsRemaining)s", color: WalletTheme.pending)
                }
            }
        }
    }

    @objc func authenticationWithTouchID() {
        // Face ID / Touch ID only. If it fails, is cancelled or is locked out, the ONLY
        // fallback is the app password below, never the device passcode.
        setStatus("waiting for \(Self.biometryName().name.lowercased())")
        AppAuthentication.biometrics(reason: "To unlock") { [weak self] success, errorCode in
            guard let self = self else { return }

            if success {
                self.unlock()
                return
            }

            #if DEBUG
            if let errorCode = errorCode {
                print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: errorCode.rawValue))
            }
            #endif

            // Fall back to the app password.
            if self.passwordInput.isEnabled {
                self.setStatus(errorCode == .biometryLockout ? "biometrics locked · use your password" : "locked",
                               color: errorCode == .biometryLockout ? WalletTheme.pending : WalletTheme.dim)
                self.passwordInput.becomeFirstResponder()
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


/// App authentication shared by the unlock screen and sensitive screens (e.g. showing
/// seed words).
///
/// Biometrics use `.deviceOwnerAuthenticationWithBiometrics` with the fallback button
/// hidden, so iOS never offers the DEVICE passcode as a way in (not even after
/// Face ID / Touch ID locks out). The fallback is always the APP password.
enum AppAuthentication {

    /// Whether biometric unlock can be enforced on this device.
    ///
    /// On a Mac (iOS app running on Apple silicon, or Mac Catalyst) macOS always lets the
    /// user's LOGIN PASSWORD satisfy Touch ID prompts, including keychain items protected
    /// with `.biometryCurrentSet`. There's no way to insist on the fingerprint alone, so a
    /// "biometric" success there can't be told apart from the Mac password. Biometric
    /// unlock is therefore disabled on Mac: the app password is the only way in.
    static var biometricsSupported: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        if #available(iOS 14.0, *) {
            return !ProcessInfo.processInfo.isiOSAppOnMac
        }
        return true
        #endif
    }

    /// Keychain item that can ONLY be read after a successful Face ID / Touch ID match.
    private static let biometricService = (Bundle.main.bundleIdentifier ?? "FullyNoded") + ".biometricUnlock"
    private static let biometricAccount = "BiometricUnlockToken"

    /// Face ID / Touch ID only, enforced by the keychain rather than by the system prompt.
    ///
    /// Success means we READ a keychain item whose access control is `.biometryCurrentSet`
    /// with no passcode flag. The Secure Enclave only releases it after a biometric match,
    /// so a device passcode or Mac login password can't unlock it, even when the system
    /// sheet offers "Use Password…" (as it does for iOS apps running on a Mac). Any such
    /// fallback just fails, and the caller falls back to the APP password.
    ///
    /// Completion runs on the main queue with success, or an LAError code (nil if unknown)
    /// on failure / when biometrics aren't available.
    static func biometrics(reason: String, completion: @escaping (Bool, LAError.Code?) -> Void) {
        // Never on Mac: the login password would count as success (see biometricsSupported).
        guard biometricsSupported else {
            DispatchQueue.main.async { completion(false, .biometryNotAvailable) }
            return
        }

        // Availability / lockout check only (shows no UI).
        let probe = LAContext()
        var availabilityError: NSError?
        guard probe.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &availabilityError) else {
            let code = availabilityError.map { LAError.Code(rawValue: $0.code) } ?? nil
            DispatchQueue.main.async { completion(false, code) }
            return
        }

        // Reading a biometry-protected item blocks while the sheet is up: keep it off main.
        DispatchQueue.global(qos: .userInitiated).async {
            guard AppAuthentication.ensureBiometricToken() else {
                // Couldn't create the protected item: no biometric unlock, app password only.
                DispatchQueue.main.async { completion(false, nil) }
                return
            }

            let context = LAContext()
            context.localizedFallbackTitle = ""   // hide the fallback button where honoured
            context.localizedReason = reason

            let query: [String: Any] = [
                kSecClass as String:                     kSecClassGenericPassword,
                kSecAttrService as String:               AppAuthentication.biometricService,
                kSecAttrAccount as String:               AppAuthentication.biometricAccount,
                kSecReturnData as String:                true,
                kSecMatchLimit as String:                kSecMatchLimitOne,
                kSecUseDataProtectionKeychain as String: true,
                kSecUseAuthenticationContext as String:  context
            ]

            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            let success = status == errSecSuccess && ((result as? Data)?.count ?? 0) == 32

            var code: LAError.Code?
            switch status {
            case errSecSuccess:        code = nil
            case errSecUserCanceled:   code = .userCancel
            case errSecAuthFailed:     code = .authenticationFailed
            case errSecItemNotFound:
                // Biometric enrollment changed (.biometryCurrentSet invalidates the item).
                // Remove it; a fresh one is created next time.
                AppAuthentication.deleteBiometricToken()
                code = .authenticationFailed
            default:                   code = .authenticationFailed
            }

            DispatchQueue.main.async { completion(success, success ? nil : code) }
        }
    }

    /// Makes sure the biometry-protected item exists. Returns false if it can't be
    /// created, in which case biometric unlock is unavailable.
    private static func ensureBiometricToken() -> Bool {
        // Existence check without any UI: a protected item reports
        // errSecInteractionNotAllowed instead of prompting.
        let silent = LAContext()
        silent.interactionNotAllowed = true
        let lookup: [String: Any] = [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               biometricService,
            kSecAttrAccount as String:               biometricAccount,
            kSecUseDataProtectionKeychain as String: true,
            kSecUseAuthenticationContext as String:  silent
        ]
        let status = SecItemCopyMatching(lookup as CFDictionary, nil)
        if status == errSecSuccess || status == errSecInteractionNotAllowed {
            return true
        }
        guard status == errSecItemNotFound else { return false }

        // Only a biometric match can read it: no .devicePasscode / .userPresence flag.
        var cfError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(nil,
                                                           kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                                                           .biometryCurrentSet,
                                                           &cfError),
              let token = Crypto.secret(), token.count == 32 else {
            return false
        }

        deleteBiometricToken()
        let add: [String: Any] = [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               biometricService,
            kSecAttrAccount as String:               biometricAccount,
            kSecAttrAccessControl as String:         access,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String:                 token
        ]
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    private static func deleteBiometricToken() {
        let query: [String: Any] = [
            kSecClass as String:                     kSecClassGenericPassword,
            kSecAttrService as String:               biometricService,
            kSecAttrAccount as String:               biometricAccount,
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// True if `password` is the app password (stored as its SHA-256 in the keychain;
    /// very old installs stored it in plain text).
    static func verifyAppPassword(_ password: String) -> Bool {
        guard !password.isEmpty, let stored = KeyChain.getData("UnlockPassword") else { return false }

        if let hashed = Data(hexString: Crypto.sha256hash(password)), hashed == stored {
            return true
        }
        return stored.utf8String == password
    }

    /// Biometrics if enabled, otherwise (or if they fail) the app password in an alert.
    /// Never the device passcode. `completion(true)` only after a successful check.
    static func authenticate(from vc: UIViewController, reason: String, completion: @escaping (Bool) -> Void) {
        let biometricsEnabled = UserDefaults.standard.object(forKey: "bioMetricsDisabled") == nil
            && AppAuthentication.biometricsSupported

        guard biometricsEnabled else {
            AppAuthentication.promptForAppPassword(from: vc, completion: completion)
            return
        }

        AppAuthentication.biometrics(reason: reason) { success, _ in
            if success {
                completion(true)
            } else {
                AppAuthentication.promptForAppPassword(from: vc, completion: completion)
            }
        }
    }

    /// Asks for the app password in an alert and checks it.
    static func promptForAppPassword(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async { [weak vc] in
            guard let vc = vc else { return }

            let alert = UIAlertController(title: "App password",
                                          message: "Enter your app password to continue.",
                                          preferredStyle: .alert)
            alert.addTextField { textField in
                textField.isSecureTextEntry = true
                textField.autocorrectionType = .no
                textField.spellCheckingType = .no
                textField.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
                let ok = AppAuthentication.verifyAppPassword(alert.textFields?.first?.text ?? "")
                if !ok {
                    showAlert(vc: vc, title: "Wrong password", message: "")
                }
                completion(ok)
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completion(false)
            })
            vc.present(alert, animated: true)
        }
    }
}

/// The brand lockup from the launch screen and website: glowing logo over
/// "> fully noded". Used by the unlock screen and the app-switcher cover.
final class BrandLockup: UIView {
    init(logoSize: CGFloat, showsTitle: Bool = true) {
        super.init(frame: .zero)
        let green = UIColor(red: 61/255, green: 1, blue: 138/255, alpha: 1)

        // Two glow layers (wide + tight) like the site's box-shadow, then the clipped logo.
        let radius = logoSize * 28 / 160
        let wide = Self.glowView(size: logoSize, radius: radius, color: green, opacity: 0.30, blur: logoSize * 0.44)
        let tight = Self.glowView(size: logoSize, radius: radius, color: green, opacity: 0.45, blur: logoSize * 0.14)
        let logo = UIImageView(image: UIImage(named: "iTunesArtwork@2x.png") ?? UIImage(named: "iTunesArtwork"))
        logo.contentMode = .scaleAspectFill
        logo.layer.cornerRadius = radius
        logo.layer.cornerCurve = .continuous
        logo.clipsToBounds = true
        logo.layer.borderWidth = 1
        logo.layer.borderColor = green.withAlphaComponent(0.33).cgColor

        let logoBox = UIView()
        for v in [wide, tight, logo] {
            v.translatesAutoresizingMaskIntoConstraints = false
            logoBox.addSubview(v)
            NSLayoutConstraint.activate([
                v.centerXAnchor.constraint(equalTo: logoBox.centerXAnchor),
                v.centerYAnchor.constraint(equalTo: logoBox.centerYAnchor),
                v.widthAnchor.constraint(equalToConstant: logoSize),
                v.heightAnchor.constraint(equalToConstant: logoSize)
            ])
        }
        logoBox.translatesAutoresizingMaskIntoConstraints = false
        logoBox.widthAnchor.constraint(equalToConstant: logoSize).isActive = true
        logoBox.heightAnchor.constraint(equalToConstant: logoSize).isActive = true

        var views: [UIView] = [logoBox]
        if showsTitle {
            let title = UILabel()
            let font = UIFont.monospacedSystemFont(ofSize: 30, weight: .heavy)
            let text = NSMutableAttributedString(string: "> ", attributes: [.font: font, .foregroundColor: green, .kern: -0.6])
            text.append(NSAttributedString(string: "fully noded", attributes: [.font: font, .foregroundColor: UIColor.white, .kern: -0.6]))
            title.attributedText = text
            title.layer.shadowColor = green.cgColor
            title.layer.shadowOpacity = 0.55
            title.layer.shadowRadius = 8
            title.layer.shadowOffset = .zero
            views.append(title)
        }

        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 26
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func glowView(size: CGFloat, radius: CGFloat, color: UIColor, opacity: Float, blur: CGFloat) -> UIView {
        let view = UIView()
        view.layer.shadowColor = color.cgColor
        view.layer.shadowOpacity = opacity
        view.layer.shadowRadius = blur
        view.layer.shadowOffset = .zero
        view.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerRadius: radius).cgPath
        return view
    }
}
