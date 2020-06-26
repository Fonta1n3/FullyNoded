//
//  SecurityCenterViewController.swift
//  BitSense
//
//  Created by Peter on 11/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class SecurityCenterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    let ud = UserDefaults.standard
    let lockView = UIView()
    let passwordInput = UITextField()
    let textInput = UITextField()
    let nextButton = UIButton()
    let alertView = UIView()
    let labelTitle = UILabel()
    var firstPassword = String()
    var secondPassword = String()
    @IBOutlet var securityTable: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        securityTable.delegate = self
        securityTable.dataSource = self
        configurePasswordManager()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 2 {
            return 4
        } else {
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "securityCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(2) as! UILabel
        let icon = cell.viewWithTag(1) as! UIImageView
        let background = cell.viewWithTag(3)!
        background.clipsToBounds = true
        background.layer.cornerRadius = 8
        
        switch indexPath.section {
        case 0:
            icon.image = UIImage(systemName: "lock.shield")
            label.text = "V3 Authentication Key"
            background.backgroundColor = .systemGreen
            
        case 1:
            if KeyChain.getData("UnlockPassword") != nil {
                label.text = "Reset"
                icon.image = UIImage(systemName: "arrow.clockwise")
            } else {
                label.text = "Set"
                icon.image = UIImage(systemName: "plus")
            }
            
            background.backgroundColor = .systemBlue
            
        case 2:
            switch indexPath.row {
            case 0: label.text = "Set Passphrase"; icon.image = UIImage(systemName: "plus"); background.backgroundColor = .systemPink
            case 1: label.text = "Change Passphrase"; icon.image = UIImage(systemName: "arrow.clockwise") ; background.backgroundColor = .systemGreen
            case 2: label.text = "Encrypt"; icon.image = UIImage(systemName: "lock.shield"); background.backgroundColor = .systemOrange
            case 3: label.text = "Decrypt"; icon.image = UIImage(systemName: "lock.open"); background.backgroundColor = .systemIndigo
            default: break}
                        
        case 3:
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                label.text = "Disabled"
                label.textColor = UIColor.darkGray
                icon.image = UIImage(systemName: "eye.slash")
            } else {
                label.text = "Enabled"
                label.textColor = .lightGray
                icon.image = UIImage(systemName: "eye")
            }
            
            background.backgroundColor = .systemPurple
            
        default:
            break
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = UIColor.clear
        header.frame = CGRect(x: 0, y: 0, width: view.frame.size.width - 32, height: 50)
        let textLabel = UILabel()
        textLabel.textAlignment = .left
        textLabel.font = UIFont.systemFont(ofSize: 20, weight: .regular)
        textLabel.textColor = .white
        textLabel.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        switch section {
        case 0:
            textLabel.text = "Tor Authentication"
            
        case 1:
            textLabel.text = "App Password"
            
        case 2:
            textLabel.text = "Wallet Encryption"
            
        case 3:
            textLabel.text = "Biometrics"
            
        default:
            break
        }
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        switch indexPath.section {
            
        case 0:
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToTorAuth", sender: vc)
            }
            
        case 1:
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "addPasswordSegue", sender: vc)
            }
            
        case 2:
            switch indexPath.row {
            case 0:
                encryptWallet()
                
            case 1:
                changePassphrase()
                
            case 2:
                executNodeCommand(method: .walletlock, param: "")
                
            case 3:
                decryptWallet()
                
            default:
                break
            }
            
        case 3:
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                ud.removeObject(forKey: "bioMetricsDisabled")
            } else {
                ud.set(true, forKey: "bioMetricsDisabled")
            }
            DispatchQueue.main.async {
                tableView.reloadSections([3], with: .fade)
            }
            
        default:
            break
        }
    }
    
    func configurePasswordManager() {
        
        textInput.delegate = self
        textInput.backgroundColor = .lightGray
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.font = UIFont.systemFont(ofSize: 17)
        labelTitle.textColor = .lightGray
        labelTitle.alpha = 0
        labelTitle.numberOfLines = 0
        labelTitle.text = "Existing password"
        labelTitle.textAlignment = .center
        
        alertView.frame = view.frame
        alertView.backgroundColor = UIColor.black
        alertView.alpha = 0
        
        lockView.frame = view.frame
        lockView.backgroundColor = UIColor.black
        lockView.alpha = 0
        
        passwordInput.frame = CGRect(x: 50,
                                     y: navigationController!.navigationBar.frame.maxY + 100,
                                     width: view.frame.width - 100,
                                     height: 50)
        
        passwordInput.keyboardType = UIKeyboardType.default
        passwordInput.autocapitalizationType = .none
        passwordInput.autocorrectionType = .no
        passwordInput.layer.cornerRadius = 10
        passwordInput.backgroundColor = .lightGray
        passwordInput.alpha = 0
        passwordInput.textColor = UIColor.black
        passwordInput.placeholder = "Password"
        passwordInput.isSecureTextEntry = true
        passwordInput.returnKeyType = UIReturnKeyType.go
        passwordInput.textAlignment = .center
        passwordInput.keyboardAppearance = UIKeyboardAppearance.dark
        passwordInput.delegate = self
        passwordInput.tintColor = UIColor.black
        
        labelTitle.frame = CGRect(x: self.view.center.x - ((view.frame.width - 10) / 2),
                                  y: passwordInput.frame.minY - 50,
                                  width: view.frame.width - 10,
                                  height: 50)
        
        nextButton.titleLabel?.font = UIFont.init(name: "HiraginoSans-W6", size: 20)
        nextButton.titleLabel?.textAlignment = .right
        nextButton.backgroundColor = UIColor.clear
        nextButton.showsTouchWhenHighlighted = true
        nextButton.setTitleColor(.lightGray, for: .normal)
        nextButton.alpha = 0
        
    }
    
    @objc func setLockPassword() {
        if textInput.text != "" {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.labelTitle.textAlignment = .center
                vc.labelTitle.text = "Please confirm the Password to ensure there were no typos."
                vc.firstPassword = vc.textInput.text!
                vc.textInput.text = ""
                vc.nextButton.setTitle("Confirm", for: .normal)
                vc.nextButton.removeTarget(vc, action: #selector(vc.setLockPassword), for: .touchUpInside)
                vc.nextButton.addTarget(vc, action: #selector(vc.confirmLockPassword), for: .touchUpInside)
            }
        } else {
            shakeAlert(viewToShake: textInput)
        }
    }
    
    @objc func confirmLockPassword() {
        if textInput.text != "" {
            secondPassword = textInput.text!
            if firstPassword == secondPassword {
                let data = secondPassword.dataUsingUTF8StringEncoding
                if KeyChain.set(data, forKey: "UnlockPassword") {
                    nextButton.removeTarget(self, action: #selector(confirmLockPassword), for: .touchUpInside)
                    textInput.text = ""
                    textInput.resignFirstResponder()
                    DispatchQueue.main.async {
                        UIView.animate(withDuration: 0.2, animations: { [unowned vc = self] in
                            vc.labelTitle.alpha = 0
                            vc.nextButton.alpha = 0
                            vc.textInput.alpha = 0
                            vc.lockView.alpha = 0
                        }) { [unowned vc = self] _ in
                            vc.textInput.text = ""
                            vc.passwordInput.text = ""
                            vc.labelTitle.text = "Unlock"
                            vc.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 30)
                            vc.labelTitle.alpha = 0
                            vc.labelTitle.textAlignment = .center
                            vc.nextButton.removeFromSuperview()
                            vc.textInput.removeFromSuperview()
                            vc.lockView.removeFromSuperview()
                            DispatchQueue.main.async { [unowned vc = self] in
                                vc.securityTable.reloadSections([1], with: .fade)
                            }
                            displayAlert(viewController: vc, isError: false, message: "Password updated")
                        }
                    }
                } else {
                    displayAlert(viewController: self, isError: true, message: "error saving password")
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Passwords did not match")
            }
        } else {
            shakeAlert(viewToShake: textInput)
        }
    }
    
    func addNextButton(inputView: UITextField) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.nextButton.removeFromSuperview()
            vc.nextButton.frame = CGRect(x: vc.view.center.x - 40, y: inputView.frame.maxY + 10, width: 80, height: 55)
            vc.nextButton.showsTouchWhenHighlighted = true
            vc.nextButton.setTitle("Next", for: .normal)
            vc.nextButton.setTitleColor(.lightGray, for: .normal)
            vc.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
            vc.nextButton.addTarget(vc, action: #selector(vc.nextButtonAction), for: .touchUpInside)
            vc.lockView.addSubview(vc.nextButton)
        }
    }
    
    func addPassword() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.textInput.placeholder = "Password"
            vc.textInput.isSecureTextEntry = true
            vc.textInput.tintColor = UIColor.black
            vc.nextButton.setTitle("Next", for: .normal)
            vc.nextButton.removeTarget(vc, action: #selector(vc.nextButtonAction), for: .touchUpInside)
            vc.nextButton.addTarget(vc, action: #selector(vc.setLockPassword), for: .touchUpInside)
            
            vc.textInput.frame = CGRect(x: 50,
                                        y: vc.labelTitle.frame.maxY + 10,
                                        width: vc.view.frame.width - 100,
                                        height: 50)
                        
            vc.nextButton.frame = CGRect(x: vc.view.center.x - 40,
                                           y: vc.textInput.frame.maxY + 10,
                                           width: 80,
                                           height: 50)
            
            vc.labelTitle.text = "Please create a new password"
            vc.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
            vc.view.addSubview(vc.alertView)
            vc.lockView.addSubview(vc.labelTitle)
            vc.lockView.addSubview(vc.textInput)
            vc.lockView.addSubview(vc.nextButton)
            
            UIView.animate(withDuration: 0.2, animations: { [unowned vc = self] in
                vc.labelTitle.alpha = 1
                vc.textInput.alpha = 1
                vc.nextButton.alpha = 1
            }, completion: { [unowned vc = self] _ in
                vc.textInput.becomeFirstResponder()
            })
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if textField == passwordInput {
            if passwordInput.text != "" {
                checkPassword(password: passwordInput.text!)
            } else {
                shakeAlert(viewToShake: passwordInput)
            }
        }
    }
    
    @objc func nextButtonAction() {
        view.endEditing(true)
    }
    
    func showUnlockScreen() {
        if KeyChain.getData("UnlockPassword") != nil {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.view.addSubview(vc.lockView)
                vc.lockView.addSubview(vc.passwordInput)
                vc.lockView.addSubview(vc.labelTitle)
                vc.addNextButton(inputView: vc.passwordInput)
                UIImpactFeedbackGenerator().impactOccurred()
            }
            UIView.animate(withDuration: 0.2, animations: { [unowned vc = self] in
                vc.lockView.alpha = 1
                vc.passwordInput.alpha = 1
                vc.labelTitle.alpha = 1
                vc.nextButton.alpha = 1
            })
            passwordInput.becomeFirstResponder()
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.view.addSubview(vc.lockView)
                vc.lockView.addSubview(vc.passwordInput)
                vc.lockView.addSubview(vc.labelTitle)
                vc.addNextButton(inputView: vc.passwordInput)
                UIImpactFeedbackGenerator().impactOccurred()
            }
            UIView.animate(withDuration: 0.2, animations: { [unowned vc = self] in
                vc.lockView.alpha = 1
                vc.passwordInput.alpha = 1
                vc.labelTitle.alpha = 1
                vc.nextButton.alpha = 1
            })
            passwordInput.becomeFirstResponder()
            addPassword()
        }
    }
    
    func checkPassword(password: String) {
        if let data = KeyChain.getData("UnlockPassword") {
            if let retrievedPassword = String(bytes: data, encoding: .utf8) {
                if passwordInput.text! == retrievedPassword {
                    nextButton.removeFromSuperview()
                    UIView.animate(withDuration: 0.2, animations: { [unowned vc = self] in
                        vc.passwordInput.alpha = 0
                        vc.labelTitle.alpha = 0
                    }, completion: { [unowned vc = self] _ in
                        vc.passwordInput.removeFromSuperview()
                        vc.labelTitle.removeFromSuperview()
                        vc.addPassword()
                    })
                } else {
                    displayAlert(viewController: self, isError: true, message: "Wrong password")
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "error getting password")
            }
            
        } else {
            displayAlert(viewController: self, isError: true, message: "error getting password")
        }
    }
    
    func executNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        let connectingView = ConnectingView()
        connectingView.addConnectingView(vc: self, description: "")
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .encryptwallet:
                    connectingView.removeConnectingView()
                    if let result = response as? String {
                        showAlert(vc: self, title: "", message: result)
                    }
                    
                case .walletlock:
                    displayAlert(viewController: self, isError: false, message: "Wallet encrypted")
                    connectingView.removeConnectingView()
                    
                case .walletpassphrase:
                    displayAlert(viewController: self, isError: false, message: "Wallet decrypted for 10 minutes only")
                    connectingView.removeConnectingView()
                    
                case .walletpassphrasechange:
                    displayAlert(viewController: self, isError: false, message: "Passphrase updated")
                    connectingView.removeConnectingView()
                    
                default:
                    break
                }
            } else {
                connectingView.removeConnectingView()
                displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
            }
        }
    }
    
    func encryptWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            let title = "Encrypt Wallet"
            let message = "Please choose a passphrase\n\nYOU MUST REMEMBER THIS PASSPHRASE\n\nwithout it you will not be able to spend your bitcoin"
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            let encrypt = UIAlertAction(title: "Encrypt", style: .default) { [unowned vc = self] (alertAction) in
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                if textField1 != "" && textField2 != "" && textField1 == textField2 {
                    vc.executNodeCommand(method: .encryptwallet, param: "\"\(textField1!)\"")
                    
                } else {
                    alert.dismiss(animated: true, completion: {
                        DispatchQueue.main.async { [unowned vc = self] in
                            displayAlert(viewController: vc, isError: true, message: "Passphrases did not match, wallet encryption failed")
                        }
                    })
                }
            }
            alert.addTextField { (textField) in
                textField.placeholder = "Add a Passphrase"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addTextField { (textField) in
                textField.placeholder = "Confirm Passphrase"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addAction(encrypt)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            vc.present(alert, animated:true, completion: nil)
        }
    }
    
    func decryptWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            let title = "Decrypt Wallet"
            let message = "Enter your passphrase\n\nThis will decrypt your wallet for 10 minutes\n\nAfter 10 minutes you will need to decrypt it again"
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            let decrypt = UIAlertAction(title: "Decrypt", style: .default) { [unowned vc = self] (alertAction) in
                let textField = (alert.textFields![0] as UITextField).text
                if textField != "" {
                    vc.executNodeCommand(method: .walletpassphrase, param: "\"\(textField!)\", 600")
                }
            }
            alert.addTextField { (textField) in
                textField.placeholder = "Add a Passphrase"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addAction(decrypt)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            vc.present(alert, animated:true, completion: nil)
        }
    }
    
    func changePassphrase() {
        DispatchQueue.main.async { [unowned vc = self] in
            let title = "Change Passphrase"
            let message = "Enter your existing passphrase and then your new one"
            let style = UIAlertController.Style.alert
            let alert = UIAlertController(title: title, message: message, preferredStyle: style)
            let update = UIAlertAction(title: "Update", style: .default) { [unowned vc = self] (alertAction) in
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                let textField3 = (alert.textFields![2] as UITextField).text
                if textField1 != "" && textField2 != "" && textField3 != "" && textField2 == textField3 {
                    vc.executNodeCommand(method: .walletpassphrasechange, param: "\"\(textField1!)\", \"\(textField3!)\"")
                } else {
                    alert.dismiss(animated: true, completion: {
                        DispatchQueue.main.async { [unowned vc = self] in
                            displayAlert(viewController: vc, isError: true, message: "Passphrases did not match, update failed")
                        }
                    })
                }
            }
            alert.addTextField { (textField) in
                textField.placeholder = "existing passphrase"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addTextField { (textField) in
                textField.placeholder = "new passphrase"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addTextField { (textField) in
                textField.placeholder = "confirm new passpharse"
                textField.isSecureTextEntry = true
                textField.keyboardAppearance = .dark
            }
            alert.addAction(update)
            let cancel = UIAlertAction(title: "Cancel", style: .default) { (alertAction) in }
            alert.addAction(cancel)
            vc.present(alert, animated:true, completion: nil)
        }
    }
}
