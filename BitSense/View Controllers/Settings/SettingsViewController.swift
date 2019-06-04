//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITabBarControllerDelegate {
    
    let userDefaults = UserDefaults.standard
    let imageView = UIImageView()
    let lockView = UIView()
    let passwordInput = UITextField()
    let textInput = UITextField()
    let nextButton = UIButton()
    let alertView = UIView()
    let labelTitle = UILabel()
    var firstPassword = String()
    var secondPassword = String()
    @IBOutlet var settingsTable: UITableView!
    
    var sections = ["Mining fee",
                    "Password",
                    "Address Format",
                    "Rescan",
                    "RPC Credentials",
                    "Path"]
    
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    var rescan = Bool()
    var path = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController!.delegate = self
        settingsTable.delegate = self
        
        textInput.delegate = self
        textInput.backgroundColor = UIColor.white
        textInput.keyboardType = UIKeyboardType.default
        textInput.layer.cornerRadius = 10
        textInput.textColor = UIColor.black
        textInput.textAlignment = .center
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.autocorrectionType = .no
        
        labelTitle.font = UIFont.init(name: "HiraginoSans-W6", size: 30)
        labelTitle.textColor = UIColor.white
        labelTitle.alpha = 0
        labelTitle.numberOfLines = 0
        labelTitle.text = "Unlock"
        labelTitle.textAlignment = .center
        
        alertView.frame = view.frame
        alertView.backgroundColor = UIColor.black
        alertView.alpha = 0
        
        lockView.frame = view.frame
        lockView.backgroundColor = UIColor.black
        lockView.alpha = 0
        
        imageView.image = UIImage(named: "whiteLock.png")
        imageView.alpha = 1
        imageView.frame = CGRect(x: self.view.center.x - 40, y: 40, width: 80, height: 80)
        
        passwordInput.frame = CGRect(x: 50, y: imageView.frame.maxY + 80, width: view.frame.width - 100, height: 50)
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
        
        labelTitle.frame = CGRect(x: self.view.center.x - ((view.frame.width - 10) / 2), y: passwordInput.frame.minY - 50, width: view.frame.width - 10, height: 50)
        
        nextButton.titleLabel?.font = UIFont.init(name: "HiraginoSans-W6", size: 20)
        nextButton.titleLabel?.textAlignment = .right
        nextButton.backgroundColor = UIColor.clear
        nextButton.showsTouchWhenHighlighted = true
        nextButton.setTitleColor(UIColor.white, for: .normal)
        nextButton.alpha = 0
        
        if userDefaults.object(forKey: "reScan") != nil {
            
            rescan = userDefaults.bool(forKey: "reScan")
            
        } else {
            
            rescan = true
            
        }
        
    }

    override func viewDidAppear(_ animated: Bool) {
        
        getAddressSettings()
        settingsTable.reloadData()
        
    }
    
    func getAddressSettings() {
        
        if userDefaults.object(forKey: "path") != nil {
            
            path = userDefaults.object(forKey: "path") as! String
            
        } else {
            
            path = "bitcoin-cli"
            
        }
        
        if userDefaults.object(forKey: "nativeSegwit") != nil {
            
            nativeSegwit = userDefaults.bool(forKey: "nativeSegwit")
            
        } else {
            
            nativeSegwit = true
            
        }
        
        if userDefaults.object(forKey: "p2shSegwit") != nil {
            
            p2shSegwit = userDefaults.bool(forKey: "p2shSegwit")
            
        } else {
            
            p2shSegwit = false
            
        }
        
        if userDefaults.object(forKey: "legacy") != nil {
            
            legacy = userDefaults.bool(forKey: "legacy")
            
        } else {
            
            legacy = false
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let check = cell.viewWithTag(2) as! UIImageView
        let switcher = cell.viewWithTag(3) as! UISwitch
        switcher.alpha = 0
        cell.selectionStyle = .none
        
        switch indexPath.section {
            
        case 0:
            
            if let fee = userDefaults.object(forKey: "miningFee") as? String {
                
                label.text = "\(fee) Satoshis"
                
            } else {
                
                label.text = "500 Satoshis"
                
            }
            
            check.alpha = 0
            
        case 1:
            
            label.text = "Reset Password"
            check.alpha = 0
            
        case 2:
            
            switch indexPath.row {
                
            case 0:
                
                label.text = "Native Segwit"
                
                if nativeSegwit {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
                
            case 1:
                
                label.text = "P2SH Segwit"
                
                if p2shSegwit {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            case 2:
                
                label.text = "Legacy"
                
                if legacy {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            default:
                
                break
                
            }
            
        case 3:
            
            switcher.alpha = 1
            label.text = "Rescan"
            check.alpha = 0
            
            if rescan {
                
                switcher.isOn = true
                label.textColor = UIColor.white
                
            } else {
                
                switcher.isOn = false
                label.textColor = UIColor.darkGray
                
            }
            
            switcher.addTarget(self, action: #selector(switchRescan), for: .touchUpInside)
            
        case 4:
            
            switcher.alpha = 0
            check.alpha = 0
            label.text = "Set RPC Login"
            label.textColor = UIColor.white
            
        case 5:
            
            switcher.alpha = 0
            check.alpha = 0
            label.textColor = UIColor.white
            
            if userDefaults.object(forKey: "path") != nil {
                
                label.text = (userDefaults.object(forKey: "path") as! String)
                
            } else {
                
                label.text = path
                
            }
            
        default:
            
            break
            
        }
                
        return cell
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return self.sections.count
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 2 {
            
            return 3
            
        } else {
            
            return 1
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return sections[section]
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.darkGray
        
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        
        var footerView = UIView()
        var explanationLabel = UILabel()
        footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 20))
        explanationLabel = UILabel(frame: CGRect(x: 20, y: 0, width: view.frame.size.width - 40, height: 40))
        explanationLabel.textColor = UIColor.darkGray
        explanationLabel.numberOfLines = 0
        explanationLabel.backgroundColor = UIColor.clear
        footerView.backgroundColor = UIColor.clear
        explanationLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 10)
        
        if section == 0 {
            
            explanationLabel.text = "Input a custom mining fee in Satoshis."
            
        } else if section == 1 {
            
            explanationLabel.text = "Reset your password for unlocking the app. You will first need to enter your existing password."
            
        } else if section == 2 {
            
            explanationLabel.text = "Choose an address format, Native Segwit (bech32) is default."
            
        } else if section == 3 {
            
            explanationLabel.text = "Rescans the blockchain when importing keys."
            
        } else if section == 4 {
            
            explanationLabel.text = "In order to sign an unsigned raw tx with a private key you need to set your RPC credentials you DO NOT need to open any port we are only using SSH to connect to the node."
            
        } else if section == 5 {
            
            explanationLabel.text = "You can set a custom path to bitcoin-cli, by default the path is \"bitcoin-cli\". For example on a mac the path is \"/usr/local/bin/bitcoin-cli\""
            
        }
        
        footerView.addSubview(explanationLabel)
        
        return footerView
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 50
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 40
        
    }
    
   func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 0 {
            
            DispatchQueue.main.async {
                
                let alert = UIAlertController(title: "Set a mining fee in Satoshis", message: "Please enter your custom mining fee in Satoshis.", preferredStyle: .alert)
                
                alert.addTextField { (textField1) in
                    
                    textField1.placeholder = "Fee in Satoshis"
                    textField1.keyboardType = UIKeyboardType.numberPad
                    textField1.keyboardAppearance = UIKeyboardAppearance.dark
                    
                }
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("Set Fee", comment: ""), style: .default, handler: { (action) in
                    
                    if alert.textFields![0].text! != "" {
                        
                        let fee = Int(alert.textFields![0].text!)
                        let feeString = fee?.withCommas()
                        self.userDefaults.set(feeString, forKey: "miningFee")
                        let cell = tableView.cellForRow(at: indexPath)!
                        cell.textLabel?.textColor = UIColor.white
                        
                        DispatchQueue.main.async {
                            
                            cell.textLabel?.text = "\(self.userDefaults.object(forKey: "miningFee") as! String) Satoshis"
                            
                        }
                        
                    }
                    
                }))
                
                alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
                
                self.present(alert, animated: true, completion: nil)
            }
            
        } else if indexPath.section == 1 {
            
            DispatchQueue.main.async {
                
                self.showUnlockScreen()
                
            }
            
        } else if indexPath.section == 2 {
            
            DispatchQueue.main.async {
                
                let impact = UIImpactFeedbackGenerator()
                impact.impactOccurred()
                
            }
            
            for row in 0 ..< tableView.numberOfRows(inSection: 2) {
                
                if let cell = self.settingsTable.cellForRow(at: IndexPath(row: row, section: 2)) {
                    
                    let label = cell.viewWithTag(1) as! UILabel
                    let check = cell.viewWithTag(2) as! UIImageView
                    var key = ""
                    
                    switch row {
                    case 0:
                        key = "nativeSegwit"
                    case 1:
                        key = "p2shSegwit"
                    case 2:
                        key = "legacy"
                    default:
                        break
                    }
                    
                    if indexPath.row == row && cell.isSelected {
                        
                        cell.isSelected = true
                        self.userDefaults.set(true, forKey: key)
                        label.textColor = UIColor.white
                        check.alpha = 1
                        
                    } else {
                        
                        cell.isSelected = false
                        self.userDefaults.set(false, forKey: key)
                        label.textColor = UIColor.darkGray
                        check.alpha = 0
                        
                    }
                    
                }
                
            }
            
        } else if indexPath.section == 4 {
            
            setRPC()
            
        } else if indexPath.section == 5 {
            
            setPath()
            
        }
        
    }
    
    func setPath() {
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            let alert = UIAlertController(title: "Set your path", message: "In your terminal type something like \"where bitcoin-cli\" and it will give you your path, copy that and save it here. In a mac you would type \"which bitcoin-cli\"\n\nThis should only be used if you are troubleshooting your connection, generally just a path of \"bitcoin-cli\" works.", preferredStyle: .alert)
            
            alert.addTextField { (textField1) in
                
                textField1.placeholder = "/usr/local/bin/bitcoin-cli"
                textField1.keyboardType = UIKeyboardType.default
                textField1.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                
                if alert.textFields![0].text! != "" {
                    
                    let userDefaults = UserDefaults.standard
                    let path = alert.textFields![0].text!
                    userDefaults.set(path, forKey: "path")
                    
                    DispatchQueue.main.async {
                        
                        self.settingsTable.reloadData()
                        
                    }
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "Path set to: \(path)")
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Fill out both fields")
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            self.present(alert, animated: true, completion: nil)
            
        }
        
    }
    
    func setRPC() {
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
            let alert = UIAlertController(title: "RPC Credentials", message: "Please enter your RPC credentials as they appear in your bitcoin.conf file.", preferredStyle: .alert)
            
            alert.addTextField { (textField1) in
                
                textField1.isSecureTextEntry = true
                textField1.placeholder = "rpcuser"
                textField1.keyboardType = UIKeyboardType.default
                textField1.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addTextField { (textField2) in
                
                textField2.isSecureTextEntry = true
                textField2.placeholder = "rpcpassword"
                textField2.keyboardType = UIKeyboardType.default
                textField2.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addTextField { (textField3) in
                
                textField3.isSecureTextEntry = false
                textField3.placeholder = "rpcport"
                textField3.keyboardType = UIKeyboardType.numberPad
                textField3.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                
                if alert.textFields![0].text! != "" && alert.textFields![1].text! != "" && alert.textFields![2].text! != "" {
                    
                    let userDefaults = UserDefaults.standard
                    let rpcuser = alert.textFields![0].text!
                    let rpcpassword = alert.textFields![1].text!
                    let port = alert.textFields![2].text!
                    userDefaults.set(rpcuser, forKey: "rpcuser")
                    userDefaults.set(rpcpassword, forKey: "rpcpassword")
                    userDefaults.set(port, forKey: "rpcport")
                    
                    displayAlert(viewController: self,
                                 isError: false,
                                 message: "RPC Credentials set")
                    
                } else {
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: "Fill out both fields")
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            self.present(alert, animated: true, completion: nil)
            
        }
        
    }
    
    @objc func switchRescan() {
        
        let cell = self.settingsTable.cellForRow(at: IndexPath(row: 0, section: 3))!
        let switcher = cell.viewWithTag(3) as! UISwitch
        let label = cell.viewWithTag(1) as! UILabel
        
        if rescan {
            
            self.rescan = false
            
            userDefaults.set(false, forKey: "reScan")
            
            DispatchQueue.main.async {
                
                switcher.isOn = false
                label.textColor = UIColor.darkGray
                
            }
            
        } else {
            
            self.rescan = true
            
            userDefaults.set(true, forKey: "reScan")
            
            DispatchQueue.main.async {
                
                switcher.isOn = true
                label.textColor = UIColor.white
                
            }
            
        }
        
    }
    
    @objc func setLockPassword() {
        
        if self.textInput.text != "" {
            
            DispatchQueue.main.async {
                
                self.labelTitle.textAlignment = .natural
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
                
                userDefaults.set(self.secondPassword, forKey: "UnlockPassword")
                
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
                            displayAlert(viewController: self, isError: false, message: "Password updated")
                            
                        }
                        
                    }
                
            } else {
                
                displayAlert(viewController: self, isError: true, message: "Passwords did not match")
                
            }
            
        } else {
            
            shakeAlert(viewToShake: self.textInput)
            
        }
        
    }
        
    func addNextButton(inputView: UITextField) {
        
        DispatchQueue.main.async {
            
            self.nextButton.removeFromSuperview()
            self.nextButton.frame = CGRect(x: self.view.center.x - 40, y: inputView.frame.maxY + 10, width: 80, height: 55)
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
            self.textInput.frame = CGRect(x: 50, y: self.labelTitle.frame.maxY + 10, width: self.view.frame.width - 100, height: 50)
            self.nextButton.frame = CGRect(x: self.view.center.x - 40, y: self.textInput.frame.maxY + 10, width: 80, height: 50)
            
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
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextFieldDidEndEditingReason) {
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
        
        DispatchQueue.main.async {
            
        self.view.addSubview(self.lockView)
        self.lockView.addSubview(self.imageView)
        self.lockView.addSubview(self.passwordInput)
        self.lockView.addSubview(self.labelTitle)
        self.addNextButton(inputView: self.passwordInput)
        UIImpactFeedbackGenerator().impactOccurred()
            
        }
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.lockView.alpha = 1
            self.imageView.alpha = 1
            self.passwordInput.alpha = 1
            self.labelTitle.alpha = 1
            self.nextButton.alpha = 1
            
        })
        
        self.passwordInput.becomeFirstResponder()
    }
    
    func checkPassword(password: String) {
        
        let retrievedPassword = userDefaults.string(forKey: "UnlockPassword")
        
        if self.passwordInput.text! == retrievedPassword {
            
            self.nextButton.removeFromSuperview()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.passwordInput.alpha = 0
                self.labelTitle.alpha = 0
                self.imageView.alpha = 0
                
            }, completion: { _ in
                
                self.imageView.removeFromSuperview()
                self.passwordInput.removeFromSuperview()
                self.labelTitle.removeFromSuperview()
                self.addPassword()
                
                
            })
            
        } else {
            
            displayAlert(viewController: self, isError: true, message: "Wrong password")
        }
        
    }
}

public extension Int {
    
    func withCommas() -> String {
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter.string(from: NSNumber(value:self))!
    }
    
}

extension SettingsViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}



