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
    var isTorchOn = Bool()
    var scannerShowing = Bool()
    var blurArray = [UIVisualEffectView]()
    var isFirstTime = Bool()
    var psbt = ""
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    
    let qrGenerator = QRGenerator()
    let scanner = QRScanner()
    let connectingView = ConnectingView()
    let rawDisplayer = RawDisplayer()
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var joinTable: UITableView!
    
    var combinePSBT = Bool()
    
    @IBAction func add(_ sender: Any) {
        
        psbtArray.append("")
        let ind = psbtArray.count - 1
        joinTable.insertRows(at: [IndexPath.init(row: ind, section: 0)], with: .automatic)
        
    }
    
    @IBAction func joinNow(_ sender: Any) {
        
        if !combinePSBT {
            
            connectingView.addConnectingView(vc: self,
                                             description: "→← Joining")
            
        } else {
            
            connectingView.addConnectingView(vc: self,
                                             description: "→← Combining")
            
        }
        
        hideKeyboards()
        
        if psbtArray.count > 1 {
            
            if !combinePSBT {
                
                executeNodeCommand(method: BTC_CLI_COMMAND.joinpsbts,
                                      param: psbtArray)
                
            } else {
                
                executeNodeCommand(method: BTC_CLI_COMMAND.combinepsbt,
                                      param: psbtArray)
                
            }
            
        } else {
            
            connectingView.removeConnectingView()
            
            displayAlert(viewController: self,
                         isError: true,
                         message: "You need to add more then one PSBT")
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        
        let reducer = Reducer()
        
        func getResult() {
            
            if !reducer.errorBool {
                
                switch method {
                    
                case .combinepsbt:
                    
                    psbt = reducer.stringToReturn
                    showRaw(raw: psbt)
                    
                case .joinpsbts:
                    
                    psbt = reducer.stringToReturn
                    showRaw(raw: psbt)
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                DispatchQueue.main.async {
                    
                    self.connectingView.removeConnectingView()
                    
                    displayAlert(viewController: self,
                                 isError: true,
                                 message: reducer.errorDescription)
                    
                }
                
            }
            
        }
        
        reducer.makeCommand(command: method,
                            param: param,
                            completion: getResult)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        joinTable.delegate = self
        joinTable.dataSource = self
        
        joinTable.tableFooterView = UIView(frame: .zero)
        
        let tapGesture = UITapGestureRecognizer(target: self,
                                                action: #selector(self.dismissKeyboard (_:)))
        
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        scanner.uploadButton.addTarget(self,
                                       action: #selector(chooseQRCodeFromLibrary),
                                       for: .touchUpInside)
        
        scanner.torchButton.addTarget(self,
                                      action: #selector(toggleTorch),
                                      for: .touchUpInside)
        
        imageView.alpha = 0
        imageView.backgroundColor = UIColor.black
        imageView.isUserInteractionEnabled = true
        scanner.imageView = imageView
        scanner.vc = self
        scanner.textField.alpha = 0
        scanner.completion = { self.getQRCode() }
        scanner.didChooseImage = { self.didPickImage() }
        scanner.downSwipeAction = { self.closeScanner() }
        
        isFirstTime = true
        
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
    
    func showRaw(raw: String) {
        
        DispatchQueue.main.async {
            
            self.joinTable.removeFromSuperview()
            self.rawDisplayer.rawString = raw
            self.rawDisplayer.vc = self
            var titleString = "Joined PSBT"
            
            if self.combinePSBT {
                
                titleString = "Combined PSBT"
                
            }
            
            self.navigationController?.navigationBar.topItem?.title = titleString
            self.rawDisplayer.qrView.addGestureRecognizer(self.tapQRGesture)
            
            self.tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                             action: #selector(self.shareRawText(_:)))
            
            self.rawDisplayer.textView.addGestureRecognizer(self.tapTextViewGesture)
            
            let newView = UIView()
            newView.backgroundColor = self.view.backgroundColor
            newView.frame = self.view.frame
            self.view.addSubview(newView)
            self.scanner.removeFromSuperview()
            self.connectingView.removeConnectingView()
            self.rawDisplayer.addRawDisplay()
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.qrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.qrView.alpha = 1
                    
                })
                
            }
            
            self.qrGenerator.textInput = self.rawDisplayer.rawString
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.completionWithItemsHandler = { (type,completed,items,error) in }
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.rawDisplayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.rawDisplayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.rawDisplayer.rawString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func close() {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
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
    
    func addBlurView(frame: CGRect, button: UIButton) {
        
        button.removeFromSuperview()
        let blur = UIVisualEffectView()
        blur.effect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        view.addSubview(blur)
        blurArray.append(blur)
        
    }
    
    func getQRCode() {
        
        let stringURL = scanner.stringToReturn
        addPSBT(url: stringURL)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        scanner.chooseQRCodeFromLibrary()
        
    }
    
    @objc func scanNow(sender: UIButton) {
        
        hideKeyboards()
        
        index = Int(sender.accessibilityLabel!)!
        
        if isFirstTime {
            
            DispatchQueue.main.async {
                
                self.addScannerButtons()
                self.scanner.scanQRCode()
                self.isFirstTime = false
                self.imageView.addSubview(self.scanner.closeButton)
                
                DispatchQueue.main.async {
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        self.imageView.alpha = 1
                        
                    })
                    
                }
                
            }
            
        } else {
            
            scanner.startScanner()
            
            self.addScannerButtons()
            
            DispatchQueue.main.async {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.imageView.alpha = 1
                    
                })
                
            }
            
            
        }
        
        scannerShowing = true
        
    }
    
    func addScannerButtons() {
        
        self.addBlurView(frame: CGRect(x: self.imageView.frame.maxX - 80,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.uploadButton)
        
        self.addBlurView(frame: CGRect(x: 10,
                                       y: self.imageView.frame.maxY - 80,
                                       width: 70,
                                       height: 70), button: self.scanner.torchButton)
        
    }
    
    func hideScanner() {
        print("hideScanner")
        
        DispatchQueue.main.async {
            
            self.scanner.stopScanner()
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.imageView.alpha = 0
                
            })
            
        }
        
        for blur in blurArray {
            
            blur.removeFromSuperview()
            
        }
        
        self.scannerShowing = false
        
    }
    
    @objc func closeScanner() {
        
        hideScanner()
        
    }
    
    func didPickImage() {
        
        let qrString = scanner.qrString
        addPSBT(url: qrString)
        
    }
    
    @objc func toggleTorch() {
        
        if isTorchOn {
            
            scanner.toggleTorch(on: false)
            isTorchOn = false
            
        } else {
            
            scanner.toggleTorch(on: true)
            isTorchOn = true
            
        }
        
    }
    
    func addPSBT(url: String) {
        
        let cell = self.joinTable.cellForRow(at: IndexPath.init(row: self.index, section: 0))!
        let textView = cell.viewWithTag(2) as! UITextView
        
        DispatchQueue.main.async {
            
            textView.text = url
            self.psbtArray[self.index] = url
            self.hideScanner()
            
            
        }
        
        if isTorchOn {
            
            toggleTorch()
            
        }
        
        DispatchQueue.main.async {
            
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            
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

}
