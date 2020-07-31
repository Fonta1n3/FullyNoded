//
//  CreateRawTxViewController.swift
//  BitSense
//
//  Created by Peter on 09/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import UIKit

class CreateRawTxViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource {
    
    var stringToExport = ""
    var spendable = Double()
    var rawTxUnsigned = String()
    var rawTxSigned = String()
    var amountAvailable = Double()
    var stringURL = String()
    var address = String()
    var amount = String()
    var outputs = [Any]()
    var outputsString = ""
    
    @IBOutlet weak var addOutputOutlet: UIBarButtonItem!
    @IBOutlet weak var playButtonOutlet: UIBarButtonItem!
    @IBOutlet var amountInput: UITextField!
    @IBOutlet var addressInput: UITextField!
    @IBOutlet var amountLabel: UILabel!
    @IBOutlet var actionOutlet: UIButton!
    @IBOutlet var scanOutlet: UIButton!
    @IBOutlet var receivingLabel: UILabel!
    @IBOutlet var outputsTable: UITableView!
    
    var creatingView = ConnectingView()
    var spendableBalance = Double()
    var outputArray = [[String:String]]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        amountInput.delegate = self
        addressInput.delegate = self
        outputsTable.delegate = self
        outputsTable.dataSource = self
        outputsTable.tableFooterView = UIView(frame: .zero)
        outputsTable.alpha = 0
        addTapGesture()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        amountInput.text = ""
        addressInput.text = ""
        outputs.removeAll()
        outputsString = ""
        outputArray.removeAll()
    }
    
    @IBAction func createPsbt(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToCreatePsbt", sender: vc)
        }
    }
    
    @IBAction func makeADonationAction(_ sender: Any) {
        if let address = Keys.donationAddress() {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.addressInput.text = address
                showAlert(vc: vc, title: "Thank you!", message: "A donation address has automatically been added so you may build a transaction which will fund further development of Fully Noded.\n\nFully Noded is free but has cost an enormous amount of time, blood, sweat and tears to bring it to where it is today as well as a significant amount of money.\n\nPlease donate generously so that the app may remain free for all to use and so that new awesome features can continue to be added!")
            }
        }
    }
    
    @IBAction func scanNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerToGetAddress", sender: vc)
        }
        
    }
    
    @IBAction func addOutput(_ sender: Any) {
        if amountInput.text != "" && addressInput.text != "" && amountInput.text != "0.0" {
            let dict = ["address":addressInput.text!, "amount":amountInput.text!] as [String : String]
            outputArray.append(dict)
            DispatchQueue.main.async { [unowned vc = self] in
                vc.outputsTable.alpha = 1
                vc.amountInput.text = ""
                vc.addressInput.text = ""
                vc.outputsTable.reloadData()
            }
        } else {
            displayAlert(viewController: self, isError: true, message: "You need to fill out a recipient and amount first then tap this button, this button is used for adding multiple recipients aka \"batching\".")
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Outputs:"
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 30
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        (view as! UITableViewHeaderFooterView).backgroundView?.backgroundColor = UIColor.clear
        (view as! UITableViewHeaderFooterView).textLabel?.textAlignment = .left
        (view as! UITableViewHeaderFooterView).textLabel?.font = UIFont.init(name: "System", size: 17)
        (view as! UITableViewHeaderFooterView).textLabel?.textColor = UIColor.darkGray
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return outputArray.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 85
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.backgroundColor = view.backgroundColor
        if outputArray.count > 0 {
            if outputArray.count > 1 {
                tableView.separatorColor = UIColor.white
                tableView.separatorStyle = .singleLine
            }
            let address = outputArray[indexPath.row]["address"]!
            let amount = outputArray[indexPath.row]["amount"]!
            cell.textLabel?.text = "\n#\(indexPath.row + 1)\n\nSending: \(String(describing: amount))\n\nTo: \(String(describing: address))"
        } else {
           cell.textLabel?.text = ""
        }
        return cell
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: User Actions
    
    @IBAction func sweep(_ sender: Any) {
        if addressInput.text != "" {
            creatingView.addConnectingView(vc: self, description: "sweeping...")
            let receivingAddress = addressInput.text!
            Reducer.makeCommand(command: .listunspent, param: "0") { [unowned vc = self] (response, errorMessage) in
                if let resultArray = response as? NSArray {
                    var inputArray = [Any]()
                    var inputs = ""
                    var amount = Double()
                    var spendFromCold = Bool()
                    
                    for utxo in resultArray {
                        let utxoDict = utxo as! NSDictionary
                        let txid = utxoDict["txid"] as! String
                        let vout = "\(utxoDict["vout"] as! Int)"
                        let spendable = utxoDict["spendable"] as! Bool
                        if !spendable {
                            spendFromCold = true
                        }
                        amount += utxoDict["amount"] as! Double
                        let input = "{\"txid\":\"\(txid)\",\"vout\": \(vout),\"sequence\": 1}"
                        inputArray.append(input)
                    }
                    
                    inputs = inputArray.description
                    inputs = inputs.replacingOccurrences(of: "[\"", with: "[")
                    inputs = inputs.replacingOccurrences(of: "\"]", with: "]")
                    inputs = inputs.replacingOccurrences(of: "\"{", with: "{")
                    inputs = inputs.replacingOccurrences(of: "}\"", with: "}")
                    inputs = inputs.replacingOccurrences(of: "\\", with: "")
                    
                    let ud = UserDefaults.standard
                    let param = "''\(inputs)'', ''{\"\(receivingAddress)\":\(rounded(number: amount))}'', 0, ''{\"includeWatching\": \(spendFromCold), \"replaceable\": true, \"conf_target\": \(ud.object(forKey: "feeTarget") as! Int), \"subtractFeeFromOutputs\": [0], \"changeAddress\": \"\(receivingAddress)\"}'', true"
                    Reducer.makeCommand(command: .walletcreatefundedpsbt, param: param) { (response, errorMessage) in
                        if let result = response as? NSDictionary {
                            let psbt1 = result["psbt"] as! String
                            Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt1)\"") { [unowned vc = self] (response, errorMessage) in
                                if let dict = response as? NSDictionary {
                                    if let processedPSBT = dict["psbt"] as? String {
                                        Signer.sign(psbt: processedPSBT) { (psbt, rawTx, errorMessage) in
                                            if psbt != nil {
                                                vc.rawTxUnsigned = psbt!
                                                vc.creatingView.removeConnectingView()
                                                vc.showRaw(raw: psbt!)
                                            } else if rawTx != nil {
                                                vc.rawTxSigned = rawTx!
                                                vc.creatingView.removeConnectingView()
                                                vc.showRaw(raw: rawTx!)
                                            } else if errorMessage != nil {
                                                vc.creatingView.removeConnectingView()
                                                showAlert(vc: vc, title: "Error", message: errorMessage!)
                                            }
                                        }
                                    }
                                } else {
                                    vc.creatingView.removeConnectingView()
                                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                                }
                            }
                        } else {
                            vc.creatingView.removeConnectingView()
                            displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                        }
                    }
                } else {
                    vc.creatingView.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage ?? "")
                }
            }
        }
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToBroadcaster", sender: vc)
        }
    }
    
    @IBAction func tryRawNow(_ sender: Any) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.rawTxSigned = ""
            vc.rawTxUnsigned = ""
            vc.amountInput.resignFirstResponder()
            vc.addressInput.resignFirstResponder()
            vc.tryRaw()
        }
    }
    
    @objc func tryRaw() {
        creatingView.addConnectingView(vc: self, description: "creating psbt...")
        
        func convertOutputs() {
            for output in outputArray {
                if let amount = output["amount"] {
                    if let address = output["address"] {
                        if address != "" {
                            let dbl = Double(amount)!
                            let out = [address:dbl]
                            outputs.append(out)
                        }
                    }
                }
            }
            
            outputsString = outputs.description
            outputsString = outputsString.replacingOccurrences(of: "[", with: "")
            outputsString = outputsString.replacingOccurrences(of: "]", with: "")
            getRawTx()
        }
        
        if outputArray.count == 0 {
            if self.amountInput.text != "" && self.amountInput.text != "0.0" && self.addressInput.text != "" {
                let dict = ["address":addressInput.text!, "amount":amountInput.text!] as [String : String]
                outputArray.append(dict)
                convertOutputs()
            } else {
                creatingView.removeConnectingView()
                displayAlert(viewController: self, isError: true, message: "You need to fill out an amount and a recipient")
            }
            
        } else if outputArray.count > 0 && self.amountInput.text != "" || self.amountInput.text != "0.0" && self.addressInput.text != "" {
            creatingView.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "If you want to add multiple recipients please tap the \"+\" and add them all first.")
            
        } else if outputArray.count > 0 {
            convertOutputs()
            
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        amountInput.resignFirstResponder()
        addressInput.resignFirstResponder()
    }
        
    //MARK: Textfield methods
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if (textField.text?.contains("."))! {
           let decimalCount = (textField.text?.components(separatedBy: ".")[1])?.count
            if decimalCount! <= 7 {
            } else {
                DispatchQueue.main.async {
                    displayAlert(viewController: self, isError: true, message: "Only 8 decimal places allowed")
                    self.amountInput.text = ""
                }
            }
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        textField.resignFirstResponder()
        if textField == addressInput && addressInput.text != "" {
            processBIP21(url: addressInput.text!)
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    //MARK: Helpers
    
    func processBIP21(url: String) {
        let addressParser = AddressParser()
        let errorBool = addressParser.parseAddress(url: url).errorBool
        let errorDescription = addressParser.parseAddress(url: url).errorDescription
        if !errorBool {
            address = addressParser.parseAddress(url: url).address
            amount = "\(addressParser.parseAddress(url: url).amount)"
            DispatchQueue.main.async { [unowned vc = self] in
                vc.addressInput.resignFirstResponder()
                vc.amountInput.resignFirstResponder()
                DispatchQueue.main.async { [unowned vc = self] in
                    if vc.amount != "" && vc.amount != "0.0" {
                        vc.amountInput.text = vc.amount
                    }
                    vc.addressInput.text = vc.address
                }
            }
        } else {
            displayAlert(viewController: self, isError: true, message: errorDescription)
        }
    }
    
    func getRawTx() {
        CreatePSBT.create(outputs: outputsString) { [unowned vc = self] (psbt, rawTx, errorMessage) in
            if psbt != nil {
                vc.rawTxUnsigned = psbt!
                vc.creatingView.removeConnectingView()
                vc.showRaw(raw: psbt!)
            } else if rawTx != nil {
                vc.rawTxSigned = rawTx!
                vc.creatingView.removeConnectingView()
                vc.showRaw(raw: rawTx!)
            } else if errorMessage != nil {
                vc.creatingView.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: errorMessage!)
            }
        }
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == addressInput {
            if textField.text != "" {
                textField.becomeFirstResponder()
            } else {
                if let string = UIPasteboard.general.string {
                    textField.becomeFirstResponder()
                    textField.text = string
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [unowned vc = self] in
                        textField.resignFirstResponder()
                        vc.processBIP21(url: string)
                    }
                } else {
                    textField.becomeFirstResponder()
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "segueToScannerToGetAddress":
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = { addrss in
                    if addrss != nil {
                        DispatchQueue.main.async { [unowned thisVc = self] in
                            thisVc.processBIP21(url: addrss!)
                        }
                    }
                }
            }
        case "segueToBroadcaster":
            if let vc = segue.destination as? SignerViewController {
                if rawTxSigned != "" {
                    vc.txn = rawTxSigned
                    vc.broadcast = true
                } else if rawTxUnsigned != "" {
                    vc.psbt = rawTxUnsigned
                    vc.export = true
                }
            }
        default:
            break
        }
    }
}

extension String {
    func toDouble() -> Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }
}



