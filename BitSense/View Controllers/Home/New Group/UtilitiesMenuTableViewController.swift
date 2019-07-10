//
//  UtilitiesMenuTableViewController.swift
//  BitSense
//
//  Created by Peter on 19/06/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class UtilitiesMenuTableViewController: UITableViewController, UINavigationControllerDelegate {
    
    var ssh:SSHService!
    var makeSSHCall:SSHelper!
    var activeNode = [String:Any]()
    let connectingView = ConnectingView()
    
    @IBAction func goBack(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 5
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if indexPath.section == 0 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "createWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 1 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "loadWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 2 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "unloadWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 3 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "rescanWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else if indexPath.section == 4 {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "defaultWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        } else {
            
            let cell = tableView.dequeueReusableCell(withIdentifier: "defaultWallet", for: indexPath)
            
            cell.selectionStyle = .none
            let label = cell.viewWithTag(1) as! UILabel
            label.adjustsFontSizeToFitWidth = true
            
            return cell
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                if indexPath.section == 0 {
                    
                    self.createWallet()
                    
                } else if indexPath.section == 1 {
                    
                    self.connectingView.addConnectingView(vc: self.navigationController!,
                                                          description: "Getting Wallets")
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.listwalletdir,
                                          param: "")
                    
                } else if indexPath.section == 2 {
                    
                    self.connectingView.addConnectingView(vc: self.navigationController!,
                                                          description: "Getting Loaded Wallets")
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.listwallets,
                                               param: "")
                    
                } else if indexPath.section == 3 {
                    
                    self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.rescanblockchain,
                                               param: "")
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: false,
                                 message: "Rescanning the blockchain, this can take an hour or so.")
                    
                } else if indexPath.section == 4 {
                    
                    UserDefaults.standard.removeObject(forKey: "walletName")
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: false,
                                 message: "Now using the nodes default wallet")
                    
                }
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    cell.alpha = 1
                    
                })
                
            })
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        
        let view = UIView()
        view.backgroundColor = UIColor.clear
        return view
        
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0 {
            
            return 20
            
        } else {
            
            return 30
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        
        let footerView = UIView()
        let explanationLabel = UILabel()
        
        footerView.frame = CGRect(x: 0,
                                  y: 0,
                                  width: view.frame.size.width,
                                  height: 20)
        
        explanationLabel.frame = CGRect(x: 20,
                                        y: 5,
                                        width: view.frame.size.width - 40,
                                        height: 40)
        
        explanationLabel.textColor = UIColor.darkGray
        explanationLabel.numberOfLines = 0
        explanationLabel.backgroundColor = UIColor.clear
        footerView.backgroundColor = UIColor.clear
        explanationLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 10)
        
        if section == 0 {
            
            explanationLabel.text = "Creates a watch-only wallet with private keys disabled. You will have to import keys into this wallet in order to use it. You can import an xpub in \"Incomings\" and set custom settings for importing keys in \"Settings\".\n\n"
            
        } else if section == 1 {
            
            explanationLabel.text = "Allows you to manually load an existing wallet, if the wallet is already loaded it will return an error.\n\n"
            
        } else if section == 2 {
            
            explanationLabel.text = "Unloads a wallet. It will display a list of your loaded wallets so you can choose one to unload.\n\n"
            
        } else if section == 3 {
            
            explanationLabel.text = "Rescans the blockchain. If you have loaded a wallet or created one it will only rescan for that specific wallet. You would do this if you have imported keys which have transaction history to see the balances.\n"
            
        } else if section == 4 {
            
            explanationLabel.text = "If you loaded or created a wallet in Fully Noded then the app will only check your node for that specific wallet, this button reverts Fully Noded back to checking your nodes default wallet.\n"
            
        }
        
        footerView.addSubview(explanationLabel)
        
        return footerView
        
    }
    
    func createWallet() {
        
        print("createWallet")
        
        DispatchQueue.main.async {
            
            let alert = UIAlertController(title: "Create a wallet", message: "Give the new wallet a name.\n\nThis is a watch-only wallet.\n\nThe keypool will be empty until you import keys into it.\n\nYou can import your xpub by going to \"Incomings\" -> \"Import a key\" where you can import xpubs or individual keys.\n\nPay close attention to your \"Import\" settings when importing xpubs.", preferredStyle: .alert)
            
            alert.addTextField { (textField1) in
                
                textField1.placeholder = "ColdCard"
                textField1.keyboardType = UIKeyboardType.default
                textField1.keyboardAppearance = UIKeyboardAppearance.dark
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: ""), style: .default, handler: { (action) in
                
                let walletName = alert.textFields![0].text!
                
                if walletName != "" {
                    
                    let aes = AESService()
                    
                    let nospaces = walletName.replacingOccurrences(of: " ", with: "_")
                    
                    self.connectingView.addConnectingView(vc: self.navigationController!,
                                                          description: "Creating \(nospaces) Wallet")
                    
                    let param = "[\"\(nospaces)\", true]"
                    
                    var rpcuser = "user"
                    var rpcpassword = "password"
                    var port = "18332"
                    
                    //delete!!!!
                    //port = "18443"
                    
                    if self.activeNode["rpcuser"] != nil {
                        
                        let enc = self.activeNode["rpcuser"] as! String
                        rpcuser = aes.decryptKey(keyToDecrypt: enc)
                        
                    }
                    
                    if self.activeNode["rpcpassword"] != nil {
                        
                        let enc = self.activeNode["rpcpassword"] as! String
                        rpcpassword = aes.decryptKey(keyToDecrypt: enc)
                        
                    }
                    
                    if self.activeNode["rpcport"] != nil {
                        
                        let enc = self.activeNode["rpcport"] as! String
                        port = aes.decryptKey(keyToDecrypt: enc)
                        
                    }
                    
                    let command = "curl --data-binary '{\"jsonrpc\": \"1.0\", \"id\":\"curltest\", \"method\": \"createwallet\", \"params\":\(param) }' -H 'content-type: text/plain;' http://\(rpcuser):\(rpcpassword)@127.0.0.1:\(port)/"
                    
                    var error: NSError?
                    
                    let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
                    queue.async {
                        
                        if let responseString = self.ssh.session?.channel.execute(command, error: &error) {
                            
                            guard let responseData = responseString.data(using: .utf8) else { return }
                            
                            do {
                                
                                let json = try JSONSerialization.jsonObject(with: responseData, options: [.allowFragments]) as! NSDictionary
                                
                                print("json = \(json)")
                                
                                if let result = json["result"] as? NSDictionary {
                                    
                                    print("result = \(result)")
                                    let name = result["name"] as! String
                                    let warning = result["warning"] as! String
                                    
                                    UserDefaults.standard.set(name, forKey: "walletName")
                                    
                                    if warning == "" {
                                        
                                        self.connectingView.removeConnectingView()
                                        
                                        displayAlert(viewController: self.navigationController!,
                                                     isError: false,
                                                     message: "Succesfully created wallet \"\(name)\"")
                                        
                                    } else {
                                        
                                        self.connectingView.removeConnectingView()
                                        
                                        displayAlert(viewController: self.navigationController!,
                                                     isError: true,
                                                     message: "Wallet \"\(name)\" created with warning: \(warning)")
                                        
                                    }
                                    
                                } else {
                                    
                                    let error = json["error"] as! NSDictionary
                                    let errorMessage = error["message"] as! String
                                    
                                    self.connectingView.removeConnectingView()
                                    
                                    displayAlert(viewController: self.navigationController!,
                                                 isError: true,
                                                 message: errorMessage)
                                    
                                }
                                
                            } catch {
                                
                                self.connectingView.removeConnectingView()
                                
                                displayAlert(viewController: self.navigationController!,
                                             isError: true,
                                             message: "Unknown error")
                                
                            }
                            
                        }
                        
                    }
                    
                } else {
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: "You need to name your wallet first")
                    
                }
                
            }))
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true)
            
        }
        
    }
    
    func chooseWalletToLoad(wallets: NSArray) {
        
        DispatchQueue.main.async {
            
            self.connectingView.removeConnectingView()
            
            let alert = UIAlertController(title: "Which wallet do you want to load?", message: "", preferredStyle: .actionSheet)
            
            for wallet in wallets {
                
                let dict = wallet as! NSDictionary
                
                let walletName = dict["name"] as! String
                
                if walletName != "" {
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString(walletName, comment: ""), style: .default, handler: { (action) in
                        
                        self.connectingView.addConnectingView(vc: self.navigationController!,
                                                              description: "Loading \(walletName)")
                        
                        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.loadwallet,
                                                   param: "\"\(dict["name"] as! String)\"")
                        
                    }))
                    
                }
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true)
            
        }
        
    }
    
    func unloadWallet(wallets: NSArray) {
        
        DispatchQueue.main.async {
            
            self.connectingView.removeConnectingView()
            
            let alert = UIAlertController(title: "Which wallet do you want to unload?", message: "", preferredStyle: .actionSheet)
            
            for wallet in wallets {
                
                let walletName = wallet as! String
                
                if walletName != "" {
                    
                    alert.addAction(UIAlertAction(title: NSLocalizedString(walletName, comment: ""), style: .default, handler: { (action) in
                        
                        self.connectingView.addConnectingView(vc: self.navigationController!,
                                                              description: "Unloading \(walletName)")
                        
                        let ud = UserDefaults.standard
                        
                        if ud.object(forKey: "walletName") != nil {
                            
                            if ud.object(forKey: "walletName") as! String == wallet as! String {
                                
                                ud.removeObject(forKey: "walletName")
                                
                            }
                            
                        }
                        
                        self.executeNodeCommandSsh(method: BTC_CLI_COMMAND.unloadwallet,
                                                   param: "\"\(walletName)\"")
                        
                    }))
                    
                }
                
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: { (action) in }))
            
            alert.popoverPresentationController?.sourceView = self.view
            
            self.present(alert, animated: true)
            
        }
        
    }
    

    func executeNodeCommandSsh(method: BTC_CLI_COMMAND, param: String) {
        
        func getResult() {
            
            if !makeSSHCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.loadwallet:
                    
                    let result = makeSSHCall.dictToReturn
                    
                    let name = result["name"] as! String
                    let warning = result["warning"] as! String
                    
                    UserDefaults.standard.set(name, forKey: "walletName")
                    
                    self.connectingView.removeConnectingView()
                    
                    if warning == "" {
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: false,
                                     message: "Succesfully loaded wallet \"\(name)\"")
                        
                    } else {
                        
                        displayAlert(viewController: self.navigationController!,
                                     isError: true,
                                     message: "Wallet \"\(name)\" loaded with warning: \(warning)")
                        
                    }
                    
                case BTC_CLI_COMMAND.listwalletdir:
                    
                    let dict =  makeSSHCall.dictToReturn
                    let walletArray = dict["wallets"] as! NSArray
                    chooseWalletToLoad(wallets: walletArray)
                    
                case BTC_CLI_COMMAND.rescanblockchain:
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: false,
                                 message: "Rescanning the blockchain, this can take an hour or so.")
                    
                case BTC_CLI_COMMAND.listwallets:
                    
                    let array =  makeSSHCall.arrayToReturn
                    unloadWallet(wallets: array)
                    
                case BTC_CLI_COMMAND.unloadwallet:
                    
                    let response = makeSSHCall.stringToReturn
                    connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: false,
                                 message: response)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self.navigationController!,
                                 isError: true,
                                 message: self.makeSSHCall.errorDescription)
                    
                }
                
            }
            
        }
        
        if self.ssh.session.isConnected {
            
            makeSSHCall.executeSSHCommand(ssh: self.ssh,
                                          method: method,
                                          param: param,
                                          completion: getResult)
            
        } else {
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self.navigationController!,
                         isError: true,
                         message: "Not connected")
            
        }
        
    }

}
