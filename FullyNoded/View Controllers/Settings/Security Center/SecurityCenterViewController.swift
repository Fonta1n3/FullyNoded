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
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 5
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
        
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 8
        cell.layer.borderWidth = 0.5
        cell.layer.borderColor = UIColor.lightGray.cgColor
        cell.backgroundColor = #colorLiteral(red: 0.05172085258, green: 0.05855310153, blue: 0.06978280196, alpha: 1)
        
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
                label.textColor = .darkGray
                icon.image = UIImage(systemName: "eye.slash")
            } else {
                label.text = "Enabled"
                label.textColor = .lightGray
                icon.image = UIImage(systemName: "eye")
            }
            
            background.backgroundColor = .systemPurple
            
        case 4:
            if ud.object(forKey: "passphrasePrompt") != nil {
                label.text = "On"
                label.textColor = .lightGray
                icon.image = UIImage(systemName: "checkmark.circle")
                background.backgroundColor = .systemGreen
            } else {
                label.text = "Off"
                label.textColor = .darkGray
                icon.image = UIImage(systemName: "xmark.circle")
                background.backgroundColor = .systemRed
            }
                        
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
            
        case 4:
            textLabel.text = "Passphrase Prompt"
                        
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
                executNodeCommand(method: .walletlock)
                
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
            
        case 4:
            if ud.object(forKey: "passphrasePrompt") != nil {
                ud.removeObject(forKey: "passphrasePrompt")
            } else {
                ud.set(true, forKey: "passphrasePrompt")
            }
            DispatchQueue.main.async {
                tableView.reloadSections([4], with: .fade)
            }
            
        default:
            break
        }
    }
    
    private func exisitingPassword() -> Data? {
        return KeyChain.getData("UnlockPassword")
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
    }
        
    func executNodeCommand(method: BTC_CLI_COMMAND) {
        let connectingView = ConnectingView()
        connectingView.addConnectingView(vc: self, description: "")
        Reducer.sharedInstance.makeCommand(command: method) { [weak self] (response, errorMessage) in
            guard let self = self else { return }
            
            if errorMessage == nil {
                switch method {
                case .encryptwallet:
                    connectingView.removeConnectingView()
                    if let result = response as? String {
                        showAlert(vc: self, title: "", message: result)
                    }
                    
                case .walletlock:
                    showAlert(vc: self, title: "", message: "Wallet encrypted 🔐")
                    connectingView.removeConnectingView()
                    
                case .walletpassphrase:
                    showAlert(vc: self, title: "", message: "Wallet decrypted 🔓 for 10 minutes.")
                    connectingView.removeConnectingView()
                    
                case .walletpassphrasechange:
                    showAlert(vc: self, title: "", message: "Passphrase updated ✓")
                    connectingView.removeConnectingView()
                    
                default:
                    break
                }
            } else {
                connectingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: errorMessage ?? "")
            }
        }
    }
    
    func encryptWallet() {
        DispatchQueue.main.async { [unowned vc = self] in
            let title = "Encrypt Wallet"
            let message = "Please choose a passphrase\n\nYOU MUST REMEMBER THIS PASSPHRASE\n\nwithout it you will not be able to spend your bitcoin"
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let encrypt = UIAlertAction(title: "Encrypt", style: .default) { [unowned vc = self] (alertAction) in
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                if textField1 != "" && textField2 != "" && textField1 == textField2 {
                    let param: Encrypt_Wallet = .init(["passphrase":textField1!])
                    vc.executNodeCommand(method: .encryptwallet(param))
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
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let decrypt = UIAlertAction(title: "Decrypt", style: .default) { [unowned vc = self] (alertAction) in
                let text = (alert.textFields![0] as UITextField).text
                if text != "" {
                    let param: Wallet_Passphrase = .init(["passphrase":text, "timeout": 600])
                    vc.executNodeCommand(method: .walletpassphrase(param: param))
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
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let update = UIAlertAction(title: "Update", style: .default) { [unowned vc = self] (alertAction) in
                let textField1 = (alert.textFields![0] as UITextField).text
                let textField2 = (alert.textFields![1] as UITextField).text
                let textField3 = (alert.textFields![2] as UITextField).text
                if textField1 != "" && textField2 != "" && textField3 != "" && textField2 == textField3 {
                    let param: Wallet_Change_Passphrase = .init(["oldpassphrase": textField1!, "newpassphrase": textField3!])
                    vc.executNodeCommand(method: .walletpassphrasechange(param))
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
