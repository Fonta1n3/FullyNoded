//
//  SecurityCenterViewController.swift
//  BitSense
//
//  Created by Peter on 11/10/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import KeychainSwift

class SecurityCenterViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    let keychain = KeychainSwift()
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

        configurePasswordManager()
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 3
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 12)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 20
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 1 {
            
            return 4
            
        } else {
            
            return 1
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "securityCell", for: indexPath)
        
        cell.selectionStyle = .none
        
        let label = cell.textLabel!
        
        switch indexPath.section {
            
        case 0:
            
            if keychain.get("UnlockPassword") != nil {
                
                label.text = "Reset Password"
                
            } else {
                
                label.text = "Set a password"
                
            }
            
        case 1:
            
            switch indexPath.row {
            case 0: label.text = "Set Passphrase"
            case 1: label.text = "Change Passphrase"
            case 2: label.text = "Encrypt"
            case 3: label.text = "Decrypt"
            default: break}
                        
        case 2:
            
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                
                label.text = "Disabled"
                label.textColor = UIColor.darkGray
                
            } else {
                
                label.text = "Enabled"
                label.textColor = UIColor.white
                
            }
            
        default:break
            
        }
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        switch section {
        case 0: return "Password"
        case 1: return "Wallet"
        case 2: return "Biometrics"
        default:return ""
        }
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
        }
        
        switch indexPath.section {
            
        case 0:
            
            //reset password
            DispatchQueue.main.async {
                
                self.showUnlockScreen()
                
            }
            
        case 1:
            
            //Wallet
            switch indexPath.row {
                
            case 0:
                
                print("create initial passphrase and encrypt")
                encryptWallet()
                
            case 1:
                
                print("change passphrase")
                changePassphrase()
                
            case 2:
                
                print("encrypt")
                executNodeCommand(method: .walletlock,
                                  param: "")
                
            case 3:
                
                print("decrypt")
                decryptWallet()
                
            default:
                
                break
                
            }
            
        case 2:
            
            //biometrics
            if ud.object(forKey: "bioMetricsDisabled") != nil {
                
                ud.removeObject(forKey: "bioMetricsDisabled")
                
            } else {
                
                ud.set(true, forKey: "bioMetricsDisabled")
                
            }
            
            DispatchQueue.main.async {
                
                tableView.reloadSections([2], with: .fade)
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    func configurePasswordManager() {
        
        textInput.delegate = self
        textInput.backgroundColor = UIColor.white
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.font = UIFont.systemFont(ofSize: 17)
        labelTitle.textColor = UIColor.white
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
        passwordInput.backgroundColor = UIColor.white
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
        nextButton.setTitleColor(UIColor.white, for: .normal)
        nextButton.alpha = 0
        
    }
    
    @objc func setLockPassword() {
        
        if self.textInput.text != "" {
            
            DispatchQueue.main.async {
                
                self.labelTitle.textAlignment = .center
                self.labelTitle.text = "Please confirm the Password to ensure there were no typos."
                self.firstPassword = self.textInput.text!
                self.textInput.text = ""
                self.nextButton.setTitle("Confirm", for: .normal)
                self.nextButton.removeTarget(self, action: #selector(self.setLockPassword), for: .touchUpInside)
                self.nextButton.addTarget(self, action: #selector(self.confirmLockPassword), for: .touchUpInside)
                
            }
            
        } else {
            
            shakeAlert(viewToShake: self.textInput)
            
        }
        
    }
    
    @objc func confirmLockPassword() {
        
        if self.textInput.text != "" {
            
            self.secondPassword = self.textInput.text!
            
            if self.firstPassword == self.secondPassword {
                
                let keychain = KeychainSwift()
                keychain.set(self.secondPassword, forKey: "UnlockPassword")
                
                self.nextButton.removeTarget(self, action: #selector(self.confirmLockPassword), for: .touchUpInside)
                self.textInput.text = ""
                self.textInput.resignFirstResponder()
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.2, animations: {
                        
                        self.labelTitle.alpha = 0
                        self.nextButton.alpha = 0
                        self.textInput.alpha = 0
                        self.lockView.alpha = 0
                        
                    }) { _ in
                        
                        self.textInput.text = ""
                        self.passwordInput.text = ""
                        self.labelTitle.text = "Unlock"
                        self.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 30)
                        self.labelTitle.alpha = 0
                        self.labelTitle.textAlignment = .center
                        self.nextButton.removeFromSuperview()
                        self.textInput.removeFromSuperview()
                        self.lockView.removeFromSuperview()
                        
                        DispatchQueue.main.async {
                            
                            self.securityTable.reloadSections([0], with: .fade)
                            
                        }
                        
                        displayAlert(viewController: self,
                                     isError: false,
                                     message: "Password updated")
                        
                    }
                    
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Passwords did not match")
                
            }
            
        } else {
            
            shakeAlert(viewToShake: self.textInput)
            
        }
        
    }
    
    func addNextButton(inputView: UITextField) {
        
        DispatchQueue.main.async {
            
            self.nextButton.removeFromSuperview()
            
            self.nextButton.frame = CGRect(x: self.view.center.x - 40,
                                           y: inputView.frame.maxY + 10,
                                           width: 80,
                                           height: 55)
            
            self.nextButton.showsTouchWhenHighlighted = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.setTitleColor(UIColor.white, for: .normal)
            self.nextButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
            self.nextButton.addTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.lockView.addSubview(self.nextButton)
            
        }
        
    }
    
    func addPassword() {
        
        DispatchQueue.main.async {
            
            self.textInput.placeholder = "Password"
            self.textInput.isSecureTextEntry = true
            self.nextButton.setTitle("Next", for: .normal)
            self.nextButton.removeTarget(self, action: #selector(self.nextButtonAction), for: .touchUpInside)
            self.nextButton.addTarget(self, action: #selector(self.setLockPassword), for: .touchUpInside)
            
            self.textInput.frame = CGRect(x: 50,
                                          y: self.labelTitle.frame.maxY + 10,
                                          width: self.view.frame.width - 100,
                                          height: 50)
            
            self.textInput.tintColor = UIColor.black
            
            self.nextButton.frame = CGRect(x: self.view.center.x - 40,
                                           y: self.textInput.frame.maxY + 10,
                                           width: 80,
                                           height: 50)
            
            self.labelTitle.text = "Please create a new password"
            self.labelTitle.font = UIFont.init(name: "HelveticaNeue-Light", size: 18)
            
            self.view.addSubview(self.alertView)
            self.lockView.addSubview(self.labelTitle)
            self.lockView.addSubview(self.textInput)
            self.lockView.addSubview(self.nextButton)
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.labelTitle.alpha = 1
                self.textInput.alpha = 1
                self.nextButton.alpha = 1
                
            }, completion: { _ in
                
                self.textInput.becomeFirstResponder()
                
            })
            
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        self.view.endEditing(true)
        return false
        
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        print("textFieldDidEndEditing")
        
        if textField == self.passwordInput {
            
            if self.passwordInput.text != "" {
                
                self.checkPassword(password: self.passwordInput.text!)
                
            } else {
                
                shakeAlert(viewToShake: self.passwordInput)
            }
            
        }
        
    }
    
    @objc func nextButtonAction() {
        
        self.view.endEditing(true)
        
    }
    
    func showUnlockScreen() {
        
        let keychain = KeychainSwift()
        
        if keychain.get("UnlockPassword") != nil {
            
            DispatchQueue.main.async {
                
                self.view.addSubview(self.lockView)
                self.lockView.addSubview(self.passwordInput)
                self.lockView.addSubview(self.labelTitle)
                self.addNextButton(inputView: self.passwordInput)
                UIImpactFeedbackGenerator().impactOccurred()
                
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.lockView.alpha = 1
                self.passwordInput.alpha = 1
                self.labelTitle.alpha = 1
                self.nextButton.alpha = 1
                
            })
            
            self.passwordInput.becomeFirstResponder()
            
        } else {
            
            print("set a password")
            DispatchQueue.main.async {
                
                self.view.addSubview(self.lockView)
                self.lockView.addSubview(self.passwordInput)
                self.lockView.addSubview(self.labelTitle)
                self.addNextButton(inputView: self.passwordInput)
                UIImpactFeedbackGenerator().impactOccurred()
                
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.lockView.alpha = 1
                self.passwordInput.alpha = 1
                self.labelTitle.alpha = 1
                self.nextButton.alpha = 1
                
            })
            
            self.passwordInput.becomeFirstResponder()
            addPassword()
            
        }
        
        
    }
    
    func checkPassword(password: String) {
        
        let keychain = KeychainSwift()
        let retrievedPassword = keychain.get("UnlockPassword")
        
        if self.passwordInput.text! == retrievedPassword {
            
            self.nextButton.removeFromSuperview()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.passwordInput.alpha = 0
                self.labelTitle.alpha = 0
                
            }, completion: { _ in
                
                self.passwordInput.removeFromSuperview()
                self.labelTitle.removeFromSuperview()
                self.addPassword()
                
            })
            
        } else {
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "Wrong password")
        }
        
    }
    
    func executNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        
        let connectIngView = ConnectingView()
        
        connectIngView.addConnectingView(vc: self,
                                         description: "")
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .encryptwallet:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Wallet encrypted with your passphrase")
                    
                    connectIngView.removeConnectingView()
                    
                case .walletlock:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Wallet encrypted")
                    
                    connectIngView.removeConnectingView()
                    
                case .walletpassphrase:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Wallet decrypted for 10 minutes only")
                    
                    connectIngView.removeConnectingView()
                    
                case .walletpassphrasechange:
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Passphrase updated")
                    
                    connectIngView.removeConnectingView()
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                connectIngView.removeConnectingView()
                
                displayAlert(viewController: self,
                             isError: true,
                             message: reducer.errorDescription)
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    func encryptWallet() {
        
        DispatchQueue.main.async {
            
            let title = "Encrypt Wallet"
            let message = "Please choose a passphrase\n\nYOU MUST REMEMBER THIS PASSPHRASE\n\nwithout it you will not be able to spend your bitcoin"
            let style = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: style)
            
            let encrypt = UIAlertAction(title: "Encrypt", style: .default) { (alertAction) in
                
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                
                if textField1 != "" && textField2 != "" && textField1 == textField2 {
                    
                    self.executNodeCommand(method: .encryptwallet,
                                           param: "\"\(textField1!)\"")
                    
                } else {
                    
                    alert.dismiss(animated: true, completion: {
                        
                        DispatchQueue.main.async {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Passphrases did not match, wallet encryption failed")
                            
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
            self.present(alert, animated:true, completion: nil)
            
        }
            
    }
    
    func decryptWallet() {
        
        DispatchQueue.main.async {
            
            let title = "Decrypt Wallet"
            let message = "Enter your passphrase\n\nThis will decrypt your wallet for 10 minutes\n\nAfter 10 minutes you will need to decrypt it again"
            let style = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: style)
            
            let decrypt = UIAlertAction(title: "Decrypt", style: .default) { (alertAction) in
                
                let textField = (alert.textFields![0] as UITextField).text
                
                if textField != "" {
                    
                    self.executNodeCommand(method: .walletpassphrase,
                                           param: "\"\(textField!)\", 600")
                    
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
            self.present(alert, animated:true, completion: nil)
            
        }
        
    }
    
    func changePassphrase() {
        
        DispatchQueue.main.async {
            
            let title = "Change Passphrase"
            let message = "Enter your existing passphrase and then your new one"
            let style = UIAlertController.Style.alert
            
            let alert = UIAlertController(title: title,
                                          message: message,
                                          preferredStyle: style)
            
            let update = UIAlertAction(title: "Update", style: .default) { (alertAction) in
                
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                let textField3 = (alert.textFields![2] as UITextField).text
                
                if textField1 != "" && textField2 != "" && textField3 != "" && textField2 == textField3 {
                    
                    self.executNodeCommand(method: .walletpassphrasechange,
                                           param: "\"\(textField1!)\", \"\(textField3!)\"")
                    
                } else {
                    
                    alert.dismiss(animated: true, completion: {
                        
                        DispatchQueue.main.async {
                            
                            displayAlert(viewController: self,
                                         isError: true,
                                         message: "Passphrases did not match, update failed")
                            
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
            self.present(alert, animated:true, completion: nil)
            
        }
        
    }

}
