//
//  OutgoingsTableViewController.swift
//  BitSense
//
//  Created by Peter on 22/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class OutgoingsTableViewController: UITableViewController, UITabBarControllerDelegate {

    var ssh:SSHService!
    var torClient:TorClient!
    var torRPC:MakeRPCCall!
    var makeSSHCall:SSHelper!
    var isTestnet = Bool()
    var activeNode = [String:Any]()
    var isUsingSSH = IsUsingSSH.sharedInstance
    
    var decodeRaw = Bool()
    var decodePSBT = Bool()
    var process = Bool()
    var finalize = Bool()
    var analyze = Bool()
    var convert = Bool()
    var txChain = Bool()
    var combinePSBT = Bool()
    
    var amountToSend = String()
    let amountInput = UITextField()
    let amountView = UIView()
    var utxos = NSArray()
    
    var firstLink = ""
    
    let creatingView = ConnectingView()
    let blurView2 = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    
    @IBOutlet var outgoingsTable: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tabBarController?.delegate = self
        outgoingsTable.tableFooterView = UIView(frame: .zero)
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.shadowImage = UIImage()
        configureAmountView()
        
   }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        self.amountInput.resignFirstResponder()
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.amountView.frame = CGRect(x: 0,
                                           y: -200,
                                           width: self.view.frame.width,
                                           height: -200)
            self.blurView2.alpha = 0
            
        }) { _ in
            
            self.blurView2.removeFromSuperview()
            self.amountView.removeFromSuperview()
            self.amountInput.removeFromSuperview()
            
        }
        
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
        
        decodeRaw = false
        decodePSBT = false
        process = false
        finalize = false
        analyze = false
        convert = false
        txChain = false
        combinePSBT = false
        firstLink = ""
        
    }
    
    @IBAction func goBack(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        
        return 2//3
        
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if section == 0 {
            
            return 5
            
        } else if section == 1 {
            
            return 8
            
        } else {
            
            return 2
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        
        if section == 0 {
            
            return "Raw Transactions"
            
        } else if section == 1 {
            
            return "PSBT's"
            
        } else {
            
            return "TXChain"
            
        }
        
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        return 30
        
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        
        return 20
        
    }
    
    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .right
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.green
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "transactionsCell", for: indexPath)
        cell.selectionStyle = .none
        let label = cell.viewWithTag(1) as! UILabel
        label.adjustsFontSizeToFitWidth = true
        
        switch indexPath.section {
            
        case 0:
            
            // Raw Transactions
            switch indexPath.row {
            case 0: label.text = "My wallet"
            case 1: label.text = "External wallet"
            case 2: label.text = "UTXO's"
            case 3: label.text = "Sign"
            case 4: label.text = "Decode"
            default:break}
            
        case 1:
            
            // PSBT's
            switch indexPath.row {
            case 0: label.text = "Create"
            case 1: label.text = "Process"
            case 2: label.text = "Finalize"
            case 3: label.text = "Join"
            case 4: label.text = "Analyze"
            case 5: label.text = "Convert"
            case 6: label.text = "Decode"
            case 7: label.text = "Combine"
            default:break}
            
        case 2:
            
            switch indexPath.row {
            case 0: label.text = "Add a link"
            case 1: label.text = "Start a chain"
            default: break}
            
        default:
            
            break
            
        }
        
        return cell
        
    }
    
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: IndexPath.init(row: indexPath.row, section: indexPath.section))!
        
        let impact = UIImpactFeedbackGenerator()
        
        DispatchQueue.main.async {
            
            impact.impactOccurred()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                cell.alpha = 0
                
            }, completion: { _ in
                
                switch indexPath.section {
                    
                case 0:
                    
                    // Raw Transactions
                    switch indexPath.row {
                        
                    case 0:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "createRawNow", sender: self)
                        }
                        
                    case 1:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToUnsigned", sender: self)
                            
                        }
                    case 2:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToUtxos", sender: self)
                        }
                        
                    case 3:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "goToSignIt", sender: self)
                            
                        }
                        
                    case 4:
                        
                        DispatchQueue.main.async {
                            
                            self.decodeRaw = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    default:break}
                    
                case 1:
                    
                    // PSBT's
                    switch indexPath.row {
                        
                    case 0:
                        
                        DispatchQueue.main.async {
                            
                            self.performSegue(withIdentifier: "createPSBT", sender: self)
                            
                        }
                    case 1:
                        
                        DispatchQueue.main.async {
                            
                            self.process = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 2:
                        
                        DispatchQueue.main.async {
                            
                            self.finalize = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 3:
                        
                        DispatchQueue.main.async {
                            
                            self.combinePSBT = false
                            self.performSegue(withIdentifier: "joinPSBT", sender: self)
                            
                        }
                        
                    case 4:
                        
                        DispatchQueue.main.async {
                            
                            self.analyze = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 5:
                        
                        DispatchQueue.main.async {
                            
                            self.convert = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 6:
                        
                        DispatchQueue.main.async {
                            
                            self.decodePSBT = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 7:
                        
                        DispatchQueue.main.async {
                            
                            self.combinePSBT = true
                            self.performSegue(withIdentifier: "joinPSBT", sender: self)
                            
                        }
                        
                    default:
                        
                        break
                        
                    }
                    
                case 2:
                    
                    //TXChain
                    switch indexPath.row {
                        
                    case 0:
                        
                        DispatchQueue.main.async {
                            
                            self.txChain = true
                            self.performSegue(withIdentifier: "goDecode", sender: self)
                            
                        }
                        
                    case 1:
                        
                        //start a chain - sh
                        self.getAmount()
                        
                    default:
                        
                        break
                        
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
    
    func configureAmountView() {
        
        amountView.backgroundColor = view.backgroundColor
        
        amountView.frame = CGRect(x: 0,
                                  y: -200,
                                  width: view.frame.width,
                                  height: -200)
        
        amountInput.backgroundColor = view.backgroundColor
        amountInput.textColor = UIColor.white
        amountInput.keyboardAppearance = .dark
        amountInput.textAlignment = .center
        
        amountInput.frame = CGRect(x: 0,
                                   y: amountView.frame.midY,
                                   width: amountView.frame.width,
                                   height: 90)
        
        amountInput.keyboardType = UIKeyboardType.decimalPad
        amountInput.font = UIFont.init(name: "HiraginoSans-W3", size: 40)
        amountInput.tintColor = UIColor.white
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.blurView2.addGestureRecognizer(tapGesture)
        
    }
    
    func amountAvailable(amount: Double) -> (Bool, String) {
        
        var amountAvailable = Double()
        
        for utxoDict in utxos {
            
            let utxo = utxoDict as! NSDictionary
            let amnt = utxo["amount"] as! Double
            let spendable = utxo["spenadable"] as! Bool
            
            if spendable {
                
                amountAvailable += amnt
                
            }
            
        }
        
        let string = "\(amountAvailable)"
        
        if amountAvailable >= amount {
            
            return (true, string)
            
        } else {
            
            return (false, string)
            
        }
        
    }
    
    @objc func closeAmount() {
        
        if self.amountInput.text != "" {
            
            self.creatingView.addConnectingView(vc: self, description: "")
            
            self.amountToSend = self.amountInput.text!
            
            let amount = Double(self.amountToSend)!
            
            self.amountInput.resignFirstResponder()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.amountView.frame = CGRect(x: 0,
                                               y: -200,
                                               width: self.view.frame.width,
                                               height: -200)
                
            }) { _ in
                
                self.amountView.removeFromSuperview()
                self.amountInput.removeFromSuperview()
                self.startATxChain(amount: amount)
                
            }
            
        } else {
            
            self.amountInput.resignFirstResponder()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.amountView.frame = CGRect(x: 0,
                                               y: -200,
                                               width: self.view.frame.width,
                                               height: -200)
                self.blurView2.alpha = 0
                
            }) { _ in
                
                self.blurView2.removeFromSuperview()
                self.amountView.removeFromSuperview()
                self.amountInput.removeFromSuperview()
                
            }
            
        }
        
    }
    
    func getAmount() {
        
        blurView2.removeFromSuperview()
        
        let label = UILabel()
        
        label.frame = CGRect(x: 0,
                             y: 15,
                             width: amountView.frame.width,
                             height: 20)
        
        label.font = UIFont.init(name: "HiraginoSans-W3", size: 20)
        label.textColor = UIColor.white
        label.textAlignment = .center
        label.text = "Amount to send"
        
        let button = UIButton()
        button.setImage(UIImage(named: "Minus"), for: .normal)
        button.frame = CGRect(x: 0, y: 140, width: self.view.frame.width, height: 60)
        button.addTarget(self, action: #selector(closeAmount), for: .touchUpInside)
        
        blurView2.alpha = 0
        
        blurView2.frame = CGRect(x: 0,
                                 y: -20,
                                 width: self.view.frame.width,
                                 height: self.view.frame.height + 20)
        
        self.view.addSubview(self.blurView2)
        self.view.addSubview(self.amountView)
        self.amountView.addSubview(self.amountInput)
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.amountView.frame = CGRect(x: 0,
                                           y: 0,
                                           width: self.view.frame.width,
                                           height: 200)
            
            self.amountInput.frame = CGRect(x: 0,
                                            y: 40,
                                            width: self.amountView.frame.width,
                                            height: 90)
            
        }) { _ in
            
            self.amountView.addSubview(label)
            self.amountView.addSubview(button)
            self.amountInput.becomeFirstResponder()
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.blurView2.alpha = 1
                
            })
            
        }
        
    }
    
    func startATxChain(amount: Double) {
        
        let txChain = TXChain()
        txChain.torClient = self.torClient
        txChain.torRPC = self.torRPC
        txChain.ssh = self.ssh
        txChain.makeSSHCall = self.makeSSHCall
        txChain.isUsingSSH = self.isUsingSSH
        txChain.amount = amount
        
        func getResult() {
            
            if !txChain.errorBool {
                
                DispatchQueue.main.async {
                    
                    self.blurView2.removeFromSuperview()
                    
                    self.creatingView.removeConnectingView()
                    
                    self.firstLink = txChain.processedChain
                    
                    self.performSegue(withIdentifier: "goDecode",
                                      sender: self)
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.blurView2.removeFromSuperview()
                    
                    self.creatingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: txChain.errorDescription)
                    
                }
                
            }
            
        }
        
        txChain.startAChain(completion: getResult)
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        switch segue.identifier {
            
        case "goDecode":
            
            if let vc = segue.destination as? ProcessPSBTViewController {
                
                vc.decodePSBT = self.decodePSBT
                vc.decodeRaw = self.decodeRaw
                vc.process = self.process
                vc.analyze = self.analyze
                vc.convert = self.convert
                vc.finalize = self.finalize
                vc.txChain = self.txChain
                vc.firstLink = self.firstLink
                
            }
            
        case "joinPSBT":
            
            if let vc = segue.destination as? JoinPSBTViewController {
                
                vc.combinePSBT = self.combinePSBT
                
            }
            
        default:
            
            break
            
        }
        
    }

}

extension OutgoingsTableViewController  {
    func tabBarController(_ tabBarController: UITabBarController, animationControllerForTransitionFrom fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return MyTransition(viewControllers: tabBarController.viewControllers)
    }
}
