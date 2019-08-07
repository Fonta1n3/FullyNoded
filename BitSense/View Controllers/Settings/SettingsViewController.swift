//
//  SettingsViewController.swift
//  BitSense
//
//  Created by Peter on 08/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit
import KeychainSwift

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, UITabBarControllerDelegate {
    
    let keychain = KeychainSwift()
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
    var miningFeeText = ""
    
    @IBOutlet var settingsTable: UITableView!
    
    let connectingView = ConnectingView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController!.delegate = self
        settingsTable.delegate = self
        configurePasswordManager()
        
    }

    override func viewDidAppear(_ animated: Bool) {
        
        settingsTable.reloadData()
        
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
        
    }
    
    func updateFeeLabel(label: UILabel, numberOfBlocks: Int) {
        
        let seconds = ((numberOfBlocks * 10) * 60)
        
        func updateFeeSetting() {
            
            userDefaults.set(numberOfBlocks, forKey: "feeTarget")
            
        }
        
        DispatchQueue.main.async {
            
            if seconds < 86400 {
                
                //less then a day
                
                if seconds < 3600 {
                    
                    DispatchQueue.main.async {
                        
                        //less then an hour
                        label.text = "Mining fee target \(numberOfBlocks) blocks (\(seconds / 60) minutes)"
                        //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                        
                    }
                    
                } else {
                    
                    DispatchQueue.main.async {
                        
                        //more then an hour
                        label.text = "Mining fee target \(numberOfBlocks) blocks (\(seconds / 3600) hours)"
                        //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                        
                    }
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    //more then a day
                    label.text = "Mining fee target \(numberOfBlocks) blocks (\(seconds / 86400) days)"
                    //self.settingsTable.reloadSections(IndexSet(arrayLiteral: 1), with: .none)
                    
                }
                
            }
            
            updateFeeSetting()
            
        }
            
    }
    
    @objc func setFee(_ sender: UISlider) {
        
        let cell = settingsTable.cellForRow(at: IndexPath.init(row: 0, section: 3))
        let label = cell?.viewWithTag(1) as! UILabel
        let numberOfBlocks = Int(sender.value) * -1
        updateFeeLabel(label: label, numberOfBlocks: numberOfBlocks)
            
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let settingsCell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        let label = settingsCell.viewWithTag(1) as! UILabel
        let check = settingsCell.viewWithTag(2) as! UIImageView
        let switcher = settingsCell.viewWithTag(3) as! UISwitch
        let rangeLabel = settingsCell.viewWithTag(4) as! UILabel
        switcher.alpha = 0
        settingsCell.selectionStyle = .none
        
        switch indexPath.section {
            
        case 0:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "nodeCell", for: indexPath)
            cell.selectionStyle = .none
            return cell
            
        case 1:
            
            check.alpha = 0
            rangeLabel.alpha = 0
            label.textColor = UIColor.white
            
            //wallet manager
            switch indexPath.row {
                
            case 0: label.text = "Wallet Manager"
                
            default:
                
                let cell = UITableViewCell()
                cell.backgroundColor = UIColor.clear
                return cell
                
            }
            
            return settingsCell
            
        case 2:
            
            rangeLabel.alpha = 0
            label.textColor = UIColor.white
            
            if keychain.get("UnlockPassword") != nil {
                
                label.text = "Reset Password"
                
            } else {
                
                label.text = "Set a password"
                
            }
            
            check.alpha = 0
            
            return settingsCell
            
        case 3:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "miningFeeCell", for: indexPath)
            let label = cell.viewWithTag(1) as! UILabel
            let slider = cell.viewWithTag(2) as! UISlider
            
            slider.addTarget(self, action: #selector(setFee), for: .allEvents)
            
            slider.maximumValue = 2 * -1
            slider.minimumValue = 1008 * -1
            
            if userDefaults.object(forKey: "feeTarget") != nil {
                
                let numberOfBlocks = userDefaults.object(forKey: "feeTarget") as! Int
                slider.value = Float(numberOfBlocks) * -1
                updateFeeLabel(label: label, numberOfBlocks: numberOfBlocks)
                
            } else {
                
                label.text = "Minimum fee set (you can always bump it)"
                slider.value = 1008 * -1
                
            }
            
            label.text = ""
            
            return cell
            
        default:
            
            let cell = UITableViewCell()
            cell.backgroundColor = UIColor.clear
            return cell
            
        }
       
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 4
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            return "Node Manager"
            
        } else if section == 1 {
            
            return "Multi Wallet Manager"
            
        } else if section == 2 {
            
            return "Password Manager"
            
        } else if section == 3 {
            
            return "Mining Fee"
            
        } else {
            
            return ""
            
        }
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .right
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 20
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
        }
        
        switch indexPath.section {
            
        case 0:
            
            //node manager
            DispatchQueue.main.async {
                
                self.performSegue(withIdentifier: "goToNodes", sender: self)
                
            }
            
        case 1:
            
            //Wallet manager
            switch indexPath.row {
                
            case 0:
                
                self.goToWalletManager()
                
            default:
                
                break
                
            }
            
        case 2:
            
            //reset password
            DispatchQueue.main.async {
                
                self.showUnlockScreen()
                
            }
            
        case 3:
            
            //mining fee
            print("do nothing")
            
        default:
            
            break
            
        }
        
    }
    
    func goToWalletManager() {
        
        DispatchQueue.main.async {
            
            self.performSegue(withIdentifier: "goManageWallets", sender: self)
            
        }
        
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
            
        } else {
            
            print("set a password")
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



