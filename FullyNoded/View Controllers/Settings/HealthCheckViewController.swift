//
//  HealthCheckViewController.swift
//  FullyNoded
//
//  Created by Peter Denton on 10/19/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import UIKit

class HealthCheckViewController: UIViewController, UITextFieldDelegate {
    
    private var signers:[[String:Any]] = [["Data":"None"]]
    private var nodes:[[String:Any]] = [["Data":"None"]]
    private var wallets:[[String:Any]] = [["Data":"None"]]
    private var authKeys:[[String:Any]] = [["Data":"None"]]
    private var spinner = ConnectingView()
    private var tapGesture:UITapGestureRecognizer!
    
    let entities:[ENTITY_BACKUP] = [
        .signers,
        .nodes,
        .wallets,
        .authKeys
    ]
    
    @IBOutlet weak private var passwordField: UITextField!
    @IBOutlet weak private var tableView: UITableView!
    
    private enum Section: Int {
        case signers
        case nodes
        case wallets
        case authKeys
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        tableView.delegate = self
        passwordField.delegate = self
        load()
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.passwordField.resignFirstResponder()
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        passwordField.resignFirstResponder()
        return true
    }
    
    @IBAction func decryptAction(_ sender: Any) {
        passwordField.resignFirstResponder()
        
        guard let password = passwordField.text,
              password != "",
              let passwordHash = hash(password) else {
            showAlert(vc: self, title: "There was an issue...", message: "Enter a decryption password first.")
            return
        }
        
        var didFail = false
        
        for (x, entity) in entities.enumerated() {
            switch entity {
            case .signers:
                decryptedArray(signers, passwordHash, entity) { [weak self] (newArray, failed) in
                    guard let self = self else { return }
                    
                    if failed {
                        didFail = true
                    }
                    
                    self.signers = newArray
                    self.loadTableData()
                }
            case .nodes:
                decryptedArray(nodes, passwordHash, entity) { [weak self] (newArray, failed) in
                    guard let self = self else { return }
                    
                    if failed {
                        didFail = true
                    }
                    
                    self.nodes = newArray
                    self.loadTableData()
                }
            case .wallets:
                decryptedArray(wallets, passwordHash, entity) { [weak self] (newArray, failed) in
                    guard let self = self else { return }
                    
                    if failed {
                        didFail = true
                    }
                    
                    self.wallets = newArray
                    self.loadTableData()
                }
            case .authKeys:
                decryptedArray(authKeys, passwordHash, entity) { [weak self] (newArray, failed) in
                    guard let self = self else { return }
                    
                    if failed {
                        didFail = true
                    }
                    
                    self.authKeys = newArray
                    self.loadTableData()
                }
            }
            
            if x + 1 == entities.count {
                if didFail {
                    showAlert(vc: self, title: "Decryption failed...", message: "The decryption password you entered can not decrypt your backup. You can either keep trying with other passwords or delete the iCloud backup and make sure you save the new encryption password safely.")
                } else {
                    showAlert(vc: self, title: "Data decrypted ✓", message: "Do not disclose this data to anyone else!")
                }
            }
        }
    }
    
    private func hash(_ text: String) -> Data? {
        return Data(hexString: Crypto.sha256hash(text))
    }
    
    private func decryptedArray(_ encryptedArray: [[String:Any]], _ passwordHash: Data, _ entity: ENTITY_BACKUP, completion: @escaping (((decryptedArray: [[String:Any]], failed: Bool)) -> Void)) {
        var newArray = [[String:Any]]()
        var failed = false
        
        for (i, dict) in encryptedArray.enumerated() {
            var item = dict
            item.removeValue(forKey: "watching")
            item.removeValue(forKey: "mixIndexes")
            
            for (key, value) in item {
                if let data = value as? Data {
                    
                    switch key {
                    case "publicKey",
                        "label",
                        "name",
                        "changeDescriptor",
                        "receiveDescriptor",
                        "type",
                        "privateKey",
                        "cert",
                        "macaroon",
                        "onionAddress",
                        "rpcpassword",
                        "rpcuser",
                        "passphrase",
                        "words",
                        "bip84xpub",
                        "bip84tpub",
                        "bip48xpub",
                        "bip48tpub",
                        "xfp",
                        "rootTpub",
                        "rootXpub":
                        
                        if key == "cert" {
                            if let decrypted = Crypto.decryptForBackup(passwordHash, data) {
                                let string = decrypted.base64EncodedString()
                                item["\(key)"] = string
                            } else {
                                failed = true
                            }
                            
                        } else if !(entity == .nodes && key == "label") {
                            if let decrypted = Crypto.decryptForBackup(passwordHash, data),
                                let string = decrypted.utf8 {
                                item["\(key)"] = string
                            } else {
                                failed = true
                            }
                        }
                        
                    default:
                        break
                    }
                }
            }
            
            newArray.append(item)
            
            if i + 1 == encryptedArray.count {
                completion((newArray, failed))
            }
        }
    }
    

    private func load() {
        spinner.addConnectingView(vc: self, description: "Fetching iCloud backup...")
        var dataExists = false
        
        for (x, entity) in entities.enumerated() {
            CoreDataiCloud.retrieveEntity(entity: entity) { [weak self] iCloudEntities in
                guard let self = self else { return }
                
                if let iCloudEntities = iCloudEntities {
                    if iCloudEntities.count > 0 {
                        dataExists = iCloudEntities.count > 0
                    }
                    
                    switch entity {
                    case .signers:
                        self.signers = iCloudEntities
                    case .nodes:
                        self.nodes = iCloudEntities
                    case .authKeys:
                        self.authKeys = iCloudEntities
                    case .wallets:
                        self.wallets = iCloudEntities
                    }
                    
                    if x + 1 == self.entities.count {
                        self.loadTableData()
                    }
                } else {
                    self.spinner.removeConnectingView()
                    
                    if x + 1 == self.entities.count && !dataExists {
                        showAlert(vc: self, title: "No existing data in iCloud.", message: "If this is the first time you are checking the status of your iCloud backup you may need to wait around 30 seconds and try again, there can be a delay when fetching your backup the first time.")
                    }
                }
            }
        }
    }
    
    private func loadTableData() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.tableView.reloadData()
            self.spinner.removeConnectingView()
        }
    }
    
    private func headerName(for section: Section) -> String {
        switch section {
        case .signers:
            return "Signers"
        case .nodes:
            return "Nodes"
        case .wallets:
            return "Wallets"
        case .authKeys:
            return "Tor Auth Keys"
        }
    }
    
    private func labelText(_ array: [[String:Any]], _ row: Int) -> String {
        var labelText = ""
        for (key, value) in array[row] {
            labelText += "\(key): \(value)\n\n"
        }
        return labelText
    }
}

extension HealthCheckViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .signers:
            return signers.count
        case .nodes:
            return nodes.count
        case .wallets:
            return wallets.count
        case .authKeys:
            return authKeys.count
        default:
            return 0
        }
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "healthCheckCell", for: indexPath)
        cell.selectionStyle = .none
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.sizeToFit()
        cell.sizeToFit()
        
        switch Section(rawValue: indexPath.section) {
        case .signers:
            cell.textLabel?.text = labelText(signers, indexPath.row)
        case .nodes:
            cell.textLabel?.text = labelText(nodes, indexPath.row)
        case .wallets:
            cell.textLabel?.text = labelText(wallets, indexPath.row)
        case .authKeys:
            cell.textLabel?.text = labelText(authKeys, indexPath.row)
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
        textLabel.frame = CGRect(x: 0, y: 0, width: 300, height: 50)
        
        if let section = Section(rawValue: section) {
            textLabel.text = headerName(for: section)
        }
        
        header.addSubview(textLabel)
        return header
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }
}

extension HealthCheckViewController: UITableViewDataSource {}
