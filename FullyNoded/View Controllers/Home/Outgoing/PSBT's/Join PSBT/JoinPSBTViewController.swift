//
//  JoinPSBTViewController.swift
//  BitSense
//
//  Created by Peter on 15/07/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class JoinPSBTViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextViewDelegate {

    var psbtArray = [""]
    var index = Int()
    var psbt = ""
    let spinner = ConnectingView()
    @IBOutlet var joinTable: UITableView!
    var combinePSBT = Bool()
    
    @IBAction func add(_ sender: Any) {
        psbtArray.append("")
        let ind = psbtArray.count - 1
        joinTable.insertRows(at: [IndexPath.init(row: ind, section: 0)], with: .automatic)
    }
    
    @IBAction func joinNow(_ sender: Any) {
        if !combinePSBT {
            spinner.addConnectingView(vc: self, description: "→← Joining")
        } else {
            spinner.addConnectingView(vc: self, description: "→← Combining")
        }
        
        hideKeyboards()
        if psbtArray.count > 1 {
            if !combinePSBT {
                executeNodeCommand(method: .joinpsbts, param: processedPsbt())
            } else {
                executeNodeCommand(method: .combinepsbt, param: processedPsbt())
            }
        } else {
            spinner.removeConnectingView()
            displayAlert(viewController: self, isError: true, message: "You need to add more then one PSBT")
        }
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .combinepsbt:
                    if let psbtCombined = response as? String {
                        vc.psbt = psbtCombined
                        vc.spinner.removeConnectingView()
                        vc.showRaw(raw: vc.psbt)
                    }
                case .joinpsbts:
                    if let psbtJoined = response as? String {
                        vc.psbt = psbtJoined
                        vc.spinner.removeConnectingView()
                        vc.showRaw(raw: vc.psbt)
                    }
                default:
                    break
                }
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.spinner.removeConnectingView()
                    displayAlert(viewController: vc, isError: true, message: errorMessage!)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        joinTable.delegate = self
        joinTable.dataSource = self
        
        joinTable.tableFooterView = UIView(frame: .zero)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillShow),
                                               name: UIResponder.keyboardWillShowNotification,
                                               object: nil)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillHide),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if combinePSBT {
            
            self.navigationController?.navigationBar.topItem?.title = "Combine PSBT"
            
        }
        
    }
    
    private func processedPsbt() -> String {
        //var processed = psbtArray.description.replacingOccurrences(of: "[", with: "")
        return psbtArray.description//processed.replacingOccurrences(of: "]", with: "")
    }
    
    func showRaw(raw: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToSignerFromCombiner", sender: vc)
        }
    }
    
    @objc func keyboardWillShow(_ notification:Notification) {
        
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            joinTable.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: keyboardSize.height, right: 0)
        }
    }
    
    @objc func keyboardWillHide(_ notification:Notification) {
        
        if ((notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue) != nil {
            joinTable.contentInset = UIEdgeInsets.init(top: 0, left: 0, bottom: 0, right: 0)
        }
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        
        for (i, _) in psbtArray.enumerated() {
            
            if let cell = joinTable.cellForRow(at: IndexPath.init(row: i, section: 0)) {
                
                if let field = cell.viewWithTag(2) as? UITextView {
                    
                    field.resignFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return psbtArray.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "psbt", for: indexPath)
        cell.selectionStyle = .none
        
        let button = cell.viewWithTag(1) as! UIButton
        let psbtField = cell.viewWithTag(2) as! UITextView
        let label = cell.viewWithTag(3) as! UILabel
        psbtField.delegate = self
        psbtField.accessibilityLabel = "\(indexPath.row)"
        button.accessibilityLabel = "\(indexPath.row)"
        
        psbtField.text = self.psbtArray[indexPath.row]
        
        label.text = "PSBT #" + "\(indexPath.row + 1)"
        
        button.addTarget(self,
                         action: #selector(scanNow),
                         for: .touchUpInside)
        
        return cell
        
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
        if editingStyle == .delete {
            
            psbtArray.remove(at: indexPath.row)
            
            UIView.animate(withDuration: 0.4, animations: {
                
                tableView.deleteRows(at: [indexPath], with: .fade)
                
            }) { _ in
                
                tableView.reloadData()
                
            }
            
        }
        
    }
    
    func hideKeyboards() {
        
        for (i, _) in psbtArray.enumerated() {
            
            if let cell = joinTable.cellForRow(at: IndexPath.init(row: i, section: 0)) {
                
                if let field = cell.viewWithTag(2) as? UITextView {
                    
                    field.resignFirstResponder()
                    
                }
                
            }
            
        }
        
    }
    
    @objc func scanNow(sender: UIButton) {
        
        hideKeyboards()
        
        index = Int(sender.accessibilityLabel!)!
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "segueToScannerFromPsbtJoiner", sender: vc)
        }
    }
    
    func addPSBT(url: String) {
        let cell = self.joinTable.cellForRow(at: IndexPath.init(row: self.index, section: 0))!
        let textView = cell.viewWithTag(2) as! UITextView
        DispatchQueue.main.async { [unowned vc = self] in
            textView.text = url
            vc.psbtArray[vc.index] = url
        }
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        
        self.index = Int(textView.accessibilityLabel!)!
        
        if textView.text != "" {
            
            textView.becomeFirstResponder()
            
        } else {
            
            if let string = UIPasteboard.general.string {
                
                textView.resignFirstResponder()
                textView.text = string
                addPSBT(url: string)
                
            } else {
                
                textView.becomeFirstResponder()
                
            }
            
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToScannerFromPsbtJoiner" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isScanningAddress = true
                vc.onAddressDoneBlock = {text in
                    if text != nil {
                        self.addPSBT(url: text!)
                    }
                }
            }
        } else if segue.identifier == "segueToSignerFromCombiner" {
            if let vc = segue.destination as? VerifyTransactionViewController {
                vc.unsignedPsbt = self.psbt
            }
        }
    }

}
