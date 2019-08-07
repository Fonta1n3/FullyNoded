//
//  IncomingsTableViewController.swift
//  BitSense
//
//  Created by Peter on 22/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import NMSSH

class IncomingsTableViewController: UITableViewController, NMSSHChannelDelegate, UITabBarControllerDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    var isPruned = Bool()
    var isTestnet = Bool()
    
    var makeSSHCall:SSHelper!
    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    let userDefaults = UserDefaults.standard
    var rescan = Bool()
    var isInternal = Bool()
    var range = String()
    var fingerprint = String()
    var bip44 = Bool()
    var bip84 = Bool()
    var addToKeypool = Bool()
    
    var nativeSegwit = Bool()
    var p2shSegwit = Bool()
    var legacy = Bool()
    
    let button = UIButton()
    let picker = UIPickerView()
    let background = UIView()
    
    var activeNode = [String:Any]()
    @IBOutlet var incomingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configurePicker()
        
        tabBarController?.delegate = self

        incomingsTable.tableFooterView = UIView(frame: .zero)
        
        navigationController?.navigationBar.setBackgroundImage(UIImage(),
                                                               for: UIBarMetrics.default)
        
        navigationController?.navigationBar.shadowImage = UIImage()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        isUsingSSH = IsUsingSSH.sharedInstance
        
        if isUsingSSH {
            
            ssh = SSHService.sharedInstance
            makeSSHCall = SSHelper.sharedInstance
            
        } else {
            
            torRPC = MakeRPCCall.sharedInstance
            torClient = TorClient.sharedInstance
            
        }
        
        getSettings()
        
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 5
        
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 3 {
            
            return 7
            
        } else if section == 4 {
            
            return 3
            
        } else {
            
           return 1
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        switch indexPath.section {
            
        case 0:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            cell.textLabel?.text = "Invoice"
            return cell
            
        case 1:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            cell.textLabel?.text = "Import a Key"
            return cell
            
        case 2:
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "importCell",
                                                     for: indexPath)
            
            cell.selectionStyle = .none
            cell.textLabel?.text = "Create / Import Multisig"
            return cell
            
        case 3:
            
            let importSettingsCell = tableView.dequeueReusableCell(withIdentifier: "importSettingsCell", for: indexPath)
            let label = importSettingsCell.viewWithTag(1) as! UILabel
            let check = importSettingsCell.viewWithTag(2) as! UIImageView
            let switcher = importSettingsCell.viewWithTag(3) as! UISwitch
            let rangeLabel = importSettingsCell.viewWithTag(4) as! UILabel
            switcher.alpha = 0
            importSettingsCell.selectionStyle = .none
            
            switch indexPath.row {
                
            case 0:
                
                rangeLabel.alpha = 0
                label.text = "BIP44"
                check.alpha = 0
                
                if bip44 {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            case 1:
                
                rangeLabel.alpha = 0
                label.text = "BIP84"
                check.alpha = 0
                
                if bip84 {
                    
                    check.alpha = 1
                    label.textColor = UIColor.white
                    
                } else {
                    
                    check.alpha = 0
                    label.textColor = UIColor.darkGray
                    
                }
                
            case 2:
                
                switcher.alpha = 0
                check.alpha = 0
                rangeLabel.alpha = 1
                label.text = "Fingerprint: (optional)"
                rangeLabel.text = fingerprint
                rangeLabel.textColor = UIColor.white
                
                if fingerprint == "" {
                    
                    label.textColor = UIColor.darkGray
                    
                } else {
                    
                    label.textColor = UIColor.white
                    
                }
                
            case 3:
                
                label.text = "Range:"
                switcher.alpha = 0
                check.alpha = 0
                rangeLabel.alpha = 1
                rangeLabel.text = range
                rangeLabel.textColor = UIColor.white
                label.textColor = UIColor.white
                
            case 4:
                
                rangeLabel.alpha = 0
                label.text = "Add to Keypool"
                switcher.alpha = 1
                check.alpha = 0
                switcher.isOn = addToKeypool
                switcher.addTarget(self, action: #selector(switchAddToKeypool), for: .touchUpInside)
                
                if addToKeypool {
                    
                    label.textColor = UIColor.white
                    
                } else {
                    
                    label.textColor = UIColor.darkGray
                    
                }
                
            case 5:
                
                rangeLabel.alpha = 0
                switcher.alpha = 1
                label.text = "Rescan"
                check.alpha = 0
                switcher.isOn = rescan
                
                if rescan {
                    
                    label.textColor = UIColor.white
                    
                } else {
                    
                    label.textColor = UIColor.darkGray
                    
                }
                
                switcher.addTarget(self, action: #selector(switchRescan), for: .touchUpInside)
                
            case 6:
                
                rangeLabel.alpha = 0
                label.text = "Import as change addresses"
                switcher.alpha = 1
                check.alpha = 0
                switcher.isOn = isInternal
                
                if isInternal {
                    
                    label.textColor = UIColor.white
                    
                } else {
                    
                    label.textColor = UIColor.darkGray
                    
                }
                
                switcher.addTarget(self, action: #selector(switchInternal), for: .touchUpInside)
                
            default:
                
                break
            }
            
            return importSettingsCell
            
        case 4:
            
            let importSettingsCell = tableView.dequeueReusableCell(withIdentifier: "importSettingsCell", for: indexPath)
            let label = importSettingsCell.viewWithTag(1) as! UILabel
            let check = importSettingsCell.viewWithTag(2) as! UIImageView
            let switcher = importSettingsCell.viewWithTag(3) as! UISwitch
            let rangeLabel = importSettingsCell.viewWithTag(4) as! UILabel
            switcher.alpha = 0
            importSettingsCell.selectionStyle = .none
            
            //address type
            rangeLabel.alpha = 0
            
            print("nativeSegwit = \(nativeSegwit)")
            
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
            
            return importSettingsCell
            
        default:
            
            let cell = UITableViewCell()
            return cell
            
        }
        
    }
    

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row,
                                                           section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                switch indexPath.section {
                    
                case 0:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "createInvoice",
                                          sender: self)
                    }
                    
                case 1:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "importPrivKey",
                                          sender: self)
                    }
                    
                case 2:
                    
                    DispatchQueue.main.async {
                        
                        self.performSegue(withIdentifier: "importMultiSig",
                                          sender: self)
                    }
                    
                case 3:
                    
                    //Importing
                    switch indexPath.row {
                        
                    case 0:
                        
                        //BIP44
                        if self.bip44 {
                            
                            self.userDefaults.set(false, forKey: "bip44")
                            self.userDefaults.set(true, forKey: "bip84")
                            
                        } else {
                            
                            self.userDefaults.set(true, forKey: "bip44")
                            self.userDefaults.set(false, forKey: "bip84")
                            
                        }
                        
                        DispatchQueue.main.async {
                            
                            self.getSettings()
                            tableView.reloadRows(at: [IndexPath(row: 0, section: 3), IndexPath(row: 1, section: 3)], with: .none)
                            
                        }
                        
                    case 1:
                        
                        //BIP84
                        if self.bip84 {
                            
                            self.userDefaults.set(true, forKey: "bip44")
                            self.userDefaults.set(false, forKey: "bip84")
                            
                        } else {
                            
                            self.userDefaults.set(false, forKey: "bip44")
                            self.userDefaults.set(true, forKey: "bip84")
                            
                        }
                        
                        DispatchQueue.main.async {
                            
                            self.getSettings()
                            tableView.reloadRows(at: [IndexPath(row: 1, section: 3), IndexPath(row: 0, section: 3)], with: .none)
                            
                        }
                        
                    case 2:
                        
                        //Fingerprint
                        self.changeFingerprint()
                        
                    case 3:
                        
                        //Range
                        DispatchQueue.main.async {
                            
                            self.addPicker()
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                case 4:
                    
                    //Address format
                    for row in 0 ..< tableView.numberOfRows(inSection: 4) {
                        
                        if let cell = tableView.cellForRow(at: IndexPath(row: row, section: 4)) {
                            
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
                                
                                DispatchQueue.main.async {
                                    
                                    self.getSettings()
                                    tableView.reloadRows(at: [IndexPath(row: row, section: 4)], with: .none)
                                    
                                }
                                
                            } else {
                                
                                cell.isSelected = false
                                self.userDefaults.set(false, forKey: key)
                                
                                DispatchQueue.main.async {
                                    
                                    self.getSettings()
                                    tableView.reloadRows(at: [IndexPath(row: row, section: 4)], with: .none)
                                    
                                }
                                
                            }
                            
                        }
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
    
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            return "BIP21 Invoice"
            
        } else if section == 1{
            
            return "Import Key"
            
        } else if section == 2 {
            
            return "Multisig"
            
        } else if section == 4 {
            
            return "Invoice Address Format"
            
        } else {
            
            return "Import Settings"
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .right
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "importPrivKey":
            
            if let vc = segue.destination as? ImportPrivKeyViewController {
                
                vc.isPruned = self.isPruned
                vc.isTestnet = self.isTestnet
                
            }
            
        default:
            
            break
            
        }
        
    }
    
    func getSettings() {
        
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
        
        if userDefaults.object(forKey: "bip44") != nil {
            
            bip44 = userDefaults.bool(forKey: "bip44")
            
        } else {
            
            bip44 = false
            
        }
        
        if userDefaults.object(forKey: "bip84") != nil {
            
            bip84 = userDefaults.bool(forKey: "bip84")
            
        } else {
            
            bip84 = true
            
        }
        
        if userDefaults.object(forKey: "addToKeypool") != nil {
            
            addToKeypool = userDefaults.bool(forKey: "addToKeypool")
            
        } else {
            
            addToKeypool = false
            
        }
        
        if userDefaults.object(forKey: "reScan") != nil {
            
            rescan = userDefaults.bool(forKey: "reScan")
            
        } else {
            
            rescan = true
            
        }
        
        if userDefaults.object(forKey: "isInternal") != nil {
            
            isInternal = userDefaults.bool(forKey: "isInternal")
            
        } else {
            
            isInternal = false
            
        }
        
        if userDefaults.object(forKey: "range") != nil {
            
            range = userDefaults.object(forKey: "range") as! String
            
        } else {
            
            range = "0 to 99"
            
        }
        
        if userDefaults.object(forKey: "fingerprint") != nil {
            
            fingerprint = userDefaults.object(forKey: "fingerprint") as! String
            
        } else {
            
            fingerprint = ""
            
        }
        
        DispatchQueue.main.async {
            
            self.tableView.reloadData()
            
        }
        
    }
    
    @objc func switchInternal() {
        
        print("switchInternal")
        
        let cell = tableView.cellForRow(at: IndexPath(row: 6, section: 3))!
        let switcher = cell.viewWithTag(3) as! UISwitch
        
        func checkIfPrivKeysEnabled() {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    let result = makeSSHCall.dictToReturn
                    let privKeysEnabled = result["private_keys_enabled"] as! Bool
                    
                    if privKeysEnabled {
                        
                        //isInternal = false
                        userDefaults.set(false, forKey: "isInternal")
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: true,
                                     message: "In order to add imported keys to the change keypool your wallet needs to be created with private keys disabled.")
                        
                    } else {
                        
                        if isInternal {
                            
                            //isInternal = false
                            userDefaults.set(false, forKey: "isInternal")
                            
                        } else {
                            
                            //isInternal = true
                            userDefaults.set(true, forKey: "isInternal")
                            
                            if !addToKeypool {
                                
                                //self.addToKeypool = true
                                self.userDefaults.set(true, forKey: "addToKeypool")
                                
                            }
                            
                        }
                        
                    }
                    
                    DispatchQueue.main.async {
                        
                        self.getSettings()
                        self.tableView.reloadRows(at: [IndexPath(row: 6, section: 3), IndexPath(row: 4, section: 3)], with: .none)
                        
                    }
                    
                    
                }
                
            }
            
            if self.ssh != nil {
                
                if ssh.session.isConnected {
                    
                    makeSSHCall.executeSSHCommand(ssh: ssh,
                                                  method: BTC_CLI_COMMAND.getwalletinfo,
                                                  param: "",
                                                  completion: getResult)
                    
                } else {
                    
                    //switcher.isOn = false
                    
                    DispatchQueue.main.async {
                        
                        self.getSettings()
                        self.tableView.reloadRows(at: [IndexPath(row: 6, section: 3)], with: .none)
                        
                    }
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: "SSH not connected, we need to check your wallets settings before you can update this setting")
                    
                }
                
            } else {
                
                //switcher.isOn = false
                
                DispatchQueue.main.async {
                    
                    self.getSettings()
                    self.tableView.reloadRows(at: [IndexPath(row: 6, section: 3)], with: .none)
                    
                }
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "SSH not connected, we need to check your wallets settings before you can update this setting")
                
            }
            
        }
        
        if !switcher.isOn {
            
            //isInternal = false
            userDefaults.set(false, forKey: "isInternal")
            //reloadSettings()
            
            DispatchQueue.main.async {
                
                self.getSettings()
                self.tableView.reloadRows(at: [IndexPath(row: 6, section: 3)], with: .none)
                
            }
            
        } else {
            
            checkIfPrivKeysEnabled()
            
        }
        
    }
    
    @objc func switchAddToKeypool() {
        
        print("switchAddToKeypool")
        
        let ip = IndexPath(row: 4, section: 3)
        let cell = self.tableView.cellForRow(at: ip)!
        let switcher = cell.viewWithTag(3) as! UISwitch
        
        func checkIfPrivKeysEnabled() {
            
            func getResult() {
                
                if !makeSSHCall.errorBool {
                    
                    let result = makeSSHCall.dictToReturn
                    let privKeysEnabled = result["private_keys_enabled"] as! Bool
                    
                    if privKeysEnabled {
                        
                        //addToKeypool = false
                        userDefaults.set(false, forKey: "addToKeypool")
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: true,
                                     message: "In order to add imported keys to the keypool your wallet needs to be created with private keys disabled.")
                        
                    } else {
                        
                        if addToKeypool {
                            
                            //addToKeypool = false
                            userDefaults.set(false, forKey: "addToKeypool")
                            userDefaults.set(false, forKey: "isInternal")
                            
                        } else {
                            
                            //addToKeypool = true
                            userDefaults.set(true, forKey: "addToKeypool")
                            
                        }
                        
                    }
                    
                    //reloadSettings()
                    
                    DispatchQueue.main.async {
                        
                        self.getSettings()
                        self.tableView.reloadRows(at: [ip, IndexPath(row: 6, section: 3)], with: .none)
                        
                    }
                    
                }
                
            }
            
            if self.ssh != nil {
                
                if ssh.session.isConnected {
                    
                    makeSSHCall.executeSSHCommand(ssh: ssh,
                                                  method: BTC_CLI_COMMAND.getwalletinfo,
                                                  param: "",
                                                  completion: getResult)
                    
                } else {
                    
                    //switcher.isOn = false
                    
                    DispatchQueue.main.async {
                        
                        self.getSettings()
                        self.tableView.reloadRows(at: [ip], with: .none)
                        
                    }
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: "SSH not connected, we need to check your wallets settings before you can update this setting")
                    
                }
                
            } else {
                
                //switcher.isOn = false
                
                DispatchQueue.main.async {
                    
                    self.getSettings()
                    self.tableView.reloadRows(at: [ip], with: .none)
                    
                }
                
                displayAlert(viewController: self.navigationController!,
                             isError: true,
                             message: "SSH not connected, we need to check your wallets settings before you can update this setting")
                
            }
            
        }
        
        if !switcher.isOn {
            
            //addToKeypool = false
            userDefaults.set(false, forKey: "addToKeypool")
            //reloadSettings()
            
            DispatchQueue.main.async {
                
                self.getSettings()
                self.tableView.reloadRows(at: [ip], with: .none)
                
            }
            
        } else {
            
            checkIfPrivKeysEnabled()
            
        }
        
    }
    
   @objc func switchRescan() {
        
        print("switchRescan")
        
        let cell = tableView.cellForRow(at: IndexPath(row: 5, section: 3))!
        let switcher = cell.viewWithTag(3) as! UISwitch
        
        if !switcher.isOn {
            
            //self.rescan = false
            userDefaults.set(false, forKey: "reScan")
            
        } else {
            
            //self.rescan = true
            userDefaults.set(true, forKey: "reScan")
            
        }
        
        //reloadSettings()
        
        DispatchQueue.main.async {
            
            self.getSettings()
            self.tableView.reloadRows(at: [IndexPath(row: 5, section: 3)], with: .none)
            
        }
        
    }
    
    func changeFingerprint() {
        
        DispatchQueue.main.async {
            
            let alert = UIAlertController(title: "Master Key Fingerprint", message: "", preferredStyle: .alert)
            
            alert.addTextField { (textField1) in
                
                textField1.placeholder = ""
                textField1.keyboardType = UIKeyboardType.default
                textField1.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: { (action) in
                
                let fp = alert.textFields![0].text!
                
                if fp != "" {
                    
                    self.userDefaults.set(fp, forKey: "fingerprint")
                    
                } else {
                    
                    self.userDefaults.set("", forKey: "fingerprint")
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: "Fingerprint removed")
                    
                }
                
                //self.reloadSettings()
                DispatchQueue.main.async {
                    
                    self.getSettings()
                    self.tableView.reloadRows(at: [IndexPath(row: 2, section: 3)], with: .none)
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true)
            
        }
        
    }
    
    func addPicker() {
        
        self.tabBarController!.view.addSubview(background)
        background.addSubview(picker)
        self.background.addSubview(button)
        let frame = self.tabBarController!.view.frame
        
        UIView.animate(withDuration: 0.3) {
            
            self.background.frame = CGRect(x: 0,
                                           y: 0,
                                           width: frame.width,
                                           height: frame.height)
            
            self.picker.frame = CGRect(x: 0,
                                       y: 0,
                                       width: frame.width,
                                       height: frame.height)
            
        }
        
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 1000
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        let string = "\(row * 100) to \(row * 100 + 199)"
        return NSAttributedString(string: string, attributes: [NSAttributedString.Key.foregroundColor: UIColor.white])
        
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        let row = pickerView.selectedRow(inComponent: component)
        let string = "\(row * 100) to \(row * 100 + 199)"
        self.range = string
        
    }
    
    func configurePicker() {
        
        picker.dataSource = self
        picker.delegate = self
        picker.isUserInteractionEnabled = true
        button.isUserInteractionEnabled = true
        
        let frame = tabBarController!.view.frame
        
        background.frame = frame
        background.backgroundColor = view.backgroundColor
        
        picker.frame = CGRect(x: 0,
                              y: view.frame.maxY + 400,
                              width: frame.width,
                              height: 400)
        
        picker.backgroundColor = self.view.backgroundColor
        
        button.backgroundColor = view.backgroundColor
        
        button.frame = CGRect(x: 0,
                              y: 75,
                              width: frame.width,
                              height: 50)
        
        button.setImage(UIImage(named: "Image-10"), for: .normal)
        button.addTarget(self, action: #selector(closePicker), for: .touchUpInside)
        
    }
    
    @objc func closePicker() {
        print("closePicker")
        
        self.userDefaults.set(self.range, forKey: "range")
        
        DispatchQueue.main.async {
            
            self.getSettings()
            self.tableView.reloadRows(at: [IndexPath(row: 3, section: 3)], with: .none)
            
        }
        
        let frame = tabBarController!.view.frame
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.background.frame = CGRect(x: 0,
                                               y: frame.maxY + 400,
                                               width: frame.width,
                                               height: 400)
                
            }, completion: { _ in
                
                self.background.removeFromSuperview()
                
            })
            
        }
        
    }

}

extension IncomingsTableViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
