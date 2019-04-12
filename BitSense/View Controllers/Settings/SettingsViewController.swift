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
    var sections = ["Mining fee", "Password"]
    
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
    }

    override func viewDidAppear(_ animated: Bool) {
        
        settingsTable.reloadData()
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        let label = cell.viewWithTag(1) as! UILabel
        let check = cell.viewWithTag(2) as! UIImageView
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
            
        default:
            
            break
            
        }
        
        cell.textLabel?.textColor = UIColor.white
        
        return cell
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return self.sections.count
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        return sections[section]
        
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.white
        
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        
        var footerView = UIView()
        var explanationLabel = UILabel()
        
        if section == 0 {
            
            footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 20))
            explanationLabel = UILabel(frame: CGRect(x: 20, y: 0, width: view.frame.size.width - 40, height: 40))
            explanationLabel.textColor = UIColor.white
            explanationLabel.numberOfLines = 0
            explanationLabel.backgroundColor = UIColor.clear
            footerView.backgroundColor = UIColor.clear
            explanationLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 10)
            explanationLabel.text = "Input a custom mining fee in Satoshis."
            footerView.addSubview(explanationLabel)
            
        } else if section == 1 {
            
            footerView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.size.width, height: 40))
            explanationLabel = UILabel(frame: CGRect(x: 20, y: 0, width: view.frame.size.width - 40, height: 40))
            explanationLabel.textColor = UIColor.white
            explanationLabel.numberOfLines = 0
            explanationLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 10)
            explanationLabel.backgroundColor = UIColor.clear
            footerView.backgroundColor = UIColor.clear
            explanationLabel.text = "Reset your password for unlocking the app. You will first need to enter your existing password."
            footerView.addSubview(explanationLabel)
            
        }
        
        return footerView
        
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 80
        
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 50
        
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
                            displayAlert(viewController: self, title: "Success", message: "Password updated!")
                            
                        }
                        
                    }
                
            } else {
                
                displayAlert(viewController: self, title: "Error", message: "Passwords did not match, try again.")
                
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
            
            displayAlert(viewController: self, title: "Error", message: "Wrong password!")
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



