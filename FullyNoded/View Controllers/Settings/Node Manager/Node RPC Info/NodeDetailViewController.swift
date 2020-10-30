//
//  NodeDetailViewController.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation

class NodeDetailViewController: UIViewController, UITextFieldDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    var selectedNode:[String:Any]?
    let cd = CoreDataService()
    var createNew = Bool()
    var newNode = [String:Any]()
    var isInitialLoad = Bool()
    var isLightning = Bool()
    var isHost = Bool()
    var hostname: String?
    let imagePicker = UIImagePickerController()
    
    @IBOutlet weak var scanQROutlet: UIBarButtonItem!
    @IBOutlet weak var header: UILabel!
    @IBOutlet var nodeLabel: UITextField!
    @IBOutlet var rpcUserField: UITextField!
    @IBOutlet var rpcPassword: UITextField!
    @IBOutlet var rpcLabel: UILabel!
    @IBOutlet var saveButton: UIButton!
    @IBOutlet weak var onionAddressField: UITextField!
    @IBOutlet weak var deleteLightningOutlet: UIButton!
    @IBOutlet weak var addressHeaderOutlet: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        configureTapGesture()
        nodeLabel.delegate = self
        rpcPassword.delegate = self
        rpcUserField.delegate = self
        onionAddressField.delegate = self
        rpcPassword.isSecureTextEntry = true
        onionAddressField.isSecureTextEntry = false
        saveButton.clipsToBounds = true
        saveButton.layer.cornerRadius = 8
        if isLightning {
            addressHeaderOutlet.text = "Address: (xxx.onion:8080 or 127.0.0.1:8080)"
            if selectedNode != nil {
                deleteLightningOutlet.alpha = 1
            }
            header.text = "Lightning Node"
        } else {
            addressHeaderOutlet.text = "Address: (xxx.onion:8332 or xxx.127.0.0.1:8332)"
            deleteLightningOutlet.alpha = 0
            header.text = "Bitcoin Core Node"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        loadValues()
    }
    
    private func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    @IBAction func showHostAction(_ sender: Any) {
        #if targetEnvironment(macCatalyst)
            // Code specific to Mac.
            let hostAddress = onionAddressField.text ?? ""
            let macName = UIDevice.current.name
            if hostAddress.contains("127.0.0.1") || hostAddress.contains("localhost") || hostAddress.contains(macName) {
                hostname = TorClient.sharedInstance.hostname()
                if hostname != nil {
                    hostname = hostname?.replacingOccurrences(of: "\n", with: "")
                    isHost = true
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
                    }
                } else {
                    showAlert(vc: self, title: "Ooops", message: "There was an error getting your hostname for remote connection... Please make sure you are connected to the internet and that Tor successfully bootstrapped.")
                }
            } else {
                showAlert(vc: self, title: "Ooops", message: "This feature can only be used with nodes which are running on the same computer as Fully Noded - Desktop.\n\nTo take advantage of this feature just download Bitcoin Core and run it.\n\nThen add your local node to Fully Noded - Desktop using 127.0.0.1:8332 as the address.\n\nYou can then tap this button to get a QR code which will allow you to connect your node via your iPhone or iPad on the mobile app.")
            }
        #else
            // Code to exclude from Mac.
            showAlert(vc: self, title: "Ooops", message: "This is a macOS feature only, when you use Fully Noded - Desktop, it has the ability to display a QR code you can scan with your iPhone or iPad to connect to your node remotely.")
        #endif
    }
    
    
    @IBAction func scanQuickConnect(_ sender: Any) {
        #if targetEnvironment(macCatalyst)
            configureImagePicker()
            chooseQRCodeFromLibrary()
        #else
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "segueToScanNodeCreds", sender: self)
            }
        #endif
    }
    
    private func deleteLightningNodeNow() {
        if selectedNode != nil {
            let nodestr = NodeStruct(dictionary: selectedNode!)
            let id = nodestr.id
            CoreDataService.deleteEntity(id: id!, entityName: .newNodes) { [unowned vc = self] (success) in
                if success {
                    showAlert(vc: vc, title: "Deleted", message: "Your lightning node has been deleted, you can always add another by tapping the bolt on node manager.")
                    vc.selectedNode = nil
                    vc.createNew = true
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.nodeLabel.text = ""
                        vc.onionAddressField.text = ""
                        vc.rpcPassword.text = ""
                        vc.rpcUserField.text = ""
                        vc.loadValues()
                    }
                }
            }
        }
    }
    
    private func promptToDeleteLightningNode() {
        DispatchQueue.main.async { [weak self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Delete lightning node?", message: "You will no longer be able to access your lightning node!", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { [weak self] action in
                self?.deleteLightningNodeNow()
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self?.view
            self?.present(alert, animated: true) {}
        }
    }
    
    @IBAction func deleteLightningNode(_ sender: Any) {
        promptToDeleteLightningNode()
    }
    
    @IBAction func goManageLightning(_ sender: Any) {
        if isLightning {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToLightningSettings", sender: vc)
            }
        }
    }
    
    @IBAction func exportNode(_ sender: Any) {
        if onionAddressField.text != "" && rpcPassword.text != "" && rpcUserField.text != "" {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.performSegue(withIdentifier: "segueToExportNode", sender: vc)
            }
        } else {
            showAlert(vc: self, title: "Ooops", message: "You can not export something that does not exist")
        }
    }
    
    @IBAction func save(_ sender: Any) {
        
        func encryptedValue(_ decryptedValue: Data) -> Data? {
            return Crypto.encrypt(decryptedValue)
        }
        
        if createNew || selectedNode == nil {
            
            newNode["id"] = UUID()
            newNode["isLightning"] = isLightning
            
            if nodeLabel.text != "" {
                newNode["label"] = nodeLabel.text!
            }
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcuser"] = enc
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                newNode["rpcpassword"] = enc
            }
            
            guard let encryptedOnionAddress = encryptedValue((onionAddressField.text)!.dataUsingUTF8StringEncoding)  else { return }
            newNode["onionAddress"] = encryptedOnionAddress
            
            if nodeLabel.text != "" && rpcPassword.text != "" && rpcUserField.text != "" && onionAddressField.text != "" {
                CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
                    if nodes != nil {
                        if !vc.isLightning {
                            if nodes!.count == 0 {
                                vc.newNode["isActive"] = true
                            } else {
                                vc.newNode["isActive"] = false
                            }
                        } else {
                            vc.newNode["isActive"] = false
                        }
                        
                        CoreDataService.saveEntity(dict: vc.newNode, entityName: .newNodes) { [unowned vc = self] success in
                            if success {
                                vc.nodeAddedSuccess()
                            } else {
                                displayAlert(viewController: vc, isError: true, message: "Error saving tor node")
                            }
                        }
                    }
                }
                
            } else {
                
                displayAlert(viewController: self,
                             isError: true,
                             message: "Fill out all fields first")
                
            }
            
        } else {
            
            //updating
            
            let id = selectedNode!["id"] as! UUID
            
            if nodeLabel.text != "" {
                CoreDataService.update(id: id, keyToUpdate: "label", newValue: nodeLabel.text!, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating label")
                    }
                }
            }
            
            if rpcUserField.text != "" {
                guard let enc = encryptedValue((rpcUserField.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcuser", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc username")
                    }
                }
            }
            
            if rpcPassword.text != "" {
                guard let enc = encryptedValue((rpcPassword.text)!.dataUsingUTF8StringEncoding) else { return }
                CoreDataService.update(id: id, keyToUpdate: "rpcpassword", newValue: enc, entity: .newNodes) { success in
                    if !success {
                        displayAlert(viewController: self, isError: true, message: "error updating rpc password")
                    }
                }
            }
            
            let decryptedAddress = (onionAddressField.text)!.dataUsingUTF8StringEncoding
            guard let encryptedOnionAddress = encryptedValue(decryptedAddress) else { return }
            CoreDataService.update(id: id, keyToUpdate: "onionAddress", newValue: encryptedOnionAddress, entity: .newNodes) { [unowned vc = self] success in
                if success {
                    vc.nodeAddedSuccess()
                } else {
                    displayAlert(viewController: vc, isError: true, message: "Error updating node!")
                }
            }
        }
    }
    
    func configureTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        view.addGestureRecognizer(tapGesture)
    }
    
    func loadValues() {
        
        func decryptedValue(_ encryptedValue: Data) -> String {
            guard let decrypted = Crypto.decrypt(encryptedValue) else { return "" }
            
            return decrypted.utf8
        }
        
        if selectedNode != nil {
            let node = NodeStruct(dictionary: selectedNode!)
            
            if node.id != nil {
                
                if node.label != "" {
                    
                    nodeLabel.text = node.label
                    
                } else {
                    
                    nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
                if node.rpcuser != nil {
                    
                    rpcUserField.text = decryptedValue(node.rpcuser!)
                    
                } else {
                    
                    rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
                if node.rpcpassword != nil {
                    
                    rpcPassword.text = decryptedValue(node.rpcpassword!)
                    
                } else {
                    
                    rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                           attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                    
                }
                
                if let enc = node.onionAddress {
                    onionAddressField.text = decryptedValue(enc)
                } else {
                    var placeHolder = "127.0.0.1:8332"
                    
                    if isLightning {
                        placeHolder = "127.0.0.1:8080"
                    }
                    
                    onionAddressField.attributedPlaceholder = NSAttributedString(string: placeHolder,
                                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                }
                
            } else {
                rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                       attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                     attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
                
                var placeHolder = "127.0.0.1:8332"
                
                if isLightning {
                    placeHolder = "127.0.0.1:8080"
                }
                
                onionAddressField.attributedPlaceholder = NSAttributedString(string: placeHolder,
                                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            }
        } else {
            rpcPassword.attributedPlaceholder = NSAttributedString(string: "rpcpassword",
                                                                   attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            rpcUserField.attributedPlaceholder = NSAttributedString(string: "rpcuser",
                                                                    attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            nodeLabel.attributedPlaceholder = NSAttributedString(string: "Give your node a label",
                                                                 attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            var placeHolder = "127.0.0.1:8332"
            
            if isLightning {
                placeHolder = "127.0.0.1:8080"
                nodeLabel.text = "Lightning Node"
            } else {
                nodeLabel.text = "Bitcoin Core"
            }
            
            onionAddressField.attributedPlaceholder = NSAttributedString(string: "127.0.0.1:8332",
                                                                         attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
            
            #if targetEnvironment(macCatalyst)
                onionAddressField.text = placeHolder
            #endif
        }
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        onionAddressField.resignFirstResponder()
        nodeLabel.resignFirstResponder()
        rpcUserField.resignFirstResponder()
        rpcPassword.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return true
    }
    
    private func nodeAddedSuccess() {
        CoreDataService.retrieveEntity(entityName: .newNodes) { [unowned vc = self] nodes in
            if nodes != nil {
                if !vc.isLightning {
                    if nodes!.count > 1 {
                        vc.deActivateNodes(nodes: nodes!) {
                            DispatchQueue.main.async { [unowned vc = self] in
                                var alertStyle = UIAlertController.Style.actionSheet
                                if (UIDevice.current.userInterfaceIdiom == .pad) {
                                  alertStyle = UIAlertController.Style.alert
                                }
                                let alert = UIAlertController(title: "Node added successfully ✅", message: "Your node has been saved and activated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection to your new node.", preferredStyle: alertStyle)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        if !vc.isLightning {
                                            NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        }
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        }
                    } else {
                        if !vc.createNew {
                            DispatchQueue.main.async { [unowned vc = self] in
                                var alertStyle = UIAlertController.Style.actionSheet
                                if (UIDevice.current.userInterfaceIdiom == .pad) {
                                  alertStyle = UIAlertController.Style.alert
                                }
                                let alert = UIAlertController(title: "Node updated successfully", message: "Your node has been updated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection using your updated node credentials.", preferredStyle: alertStyle)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        if !vc.isLightning {
                                            NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        }
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        } else {
                           DispatchQueue.main.async { [unowned vc = self] in
                            var alertStyle = UIAlertController.Style.actionSheet
                            if (UIDevice.current.userInterfaceIdiom == .pad) {
                              alertStyle = UIAlertController.Style.alert
                            }
                                let alert = UIAlertController(title: "Node added successfully ✅", message: "Your node has been added and activated. The home screen is automatically refreshing. Tap Done to go back.", preferredStyle: alertStyle)
                                alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                    DispatchQueue.main.async { [unowned vc = self] in
                                        if !vc.isLightning {
                                            NotificationCenter.default.post(name: .refreshNode, object: nil)
                                        }
                                        vc.navigationController?.popToRootViewController(animated: true)
                                    }
                                }))
                                alert.popoverPresentationController?.sourceView = vc.view
                                vc.present(alert, animated: true) {}
                            }
                        }
                    }
                } else {
                    if !vc.createNew {
                        DispatchQueue.main.async { [unowned vc = self] in
                            var alertStyle = UIAlertController.Style.actionSheet
                            if (UIDevice.current.userInterfaceIdiom == .pad) {
                              alertStyle = UIAlertController.Style.alert
                            }
                            let alert = UIAlertController(title: "Node updated successfully", message: "Your node has been updated, tap Done to go back. Sometimes its necessary to force quit and reopen FullyNoded to refresh the Tor connection using your updated node credentials.", preferredStyle: alertStyle)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    if !vc.isLightning {
                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    }
                                    vc.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    } else {
                       DispatchQueue.main.async { [unowned vc = self] in
                        var alertStyle = UIAlertController.Style.actionSheet
                        if (UIDevice.current.userInterfaceIdiom == .pad) {
                          alertStyle = UIAlertController.Style.alert
                        }
                            let alert = UIAlertController(title: "Node added successfully ✅", message: "Your node has been added and activated. The home screen is automatically refreshing. Tap Done to go back.", preferredStyle: alertStyle)
                            alert.addAction(UIAlertAction(title: "Done", style: .cancel, handler: { action in
                                DispatchQueue.main.async { [unowned vc = self] in
                                    if !vc.isLightning {
                                        NotificationCenter.default.post(name: .refreshNode, object: nil)
                                    }
                                    vc.navigationController?.popToRootViewController(animated: true)
                                }
                            }))
                            alert.popoverPresentationController?.sourceView = vc.view
                            vc.present(alert, animated: true) {}
                        }
                    }
                }
            }
        }
    }
    
    private func deActivateNodes(nodes: [[String:Any]], completion: @escaping () -> Void) {
        for (i, node) in nodes.enumerated() {
            let str = NodeStruct(dictionary: node)
            let isActive = str.isActive
            if isActive {
                CoreDataService.update(id: str.id!, keyToUpdate: "isActive", newValue: false, entity: .newNodes) { _ in }
            }
            if i + 1 == nodes.count {
                if createNew {
                    let id = newNode["id"] as! UUID
                    CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                        completion()
                    }
                } else {
                    if selectedNode != nil {
                        if let id = selectedNode!["id"] as? UUID {
                            CoreDataService.update(id: id, keyToUpdate: "isActive", newValue: true, entity: .newNodes) { success in
                                completion()
                            }
                        }
                    }
                }
            }
        }
    }
    
    func addBtcRpcQr(url: String) {
        QuickConnect.addNode(url: url) { [weak self] (success, errorMessage) in
            if success {
                if url.hasPrefix("clightning-rpc") {
                    self?.navigationController?.popViewController(animated: true)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.navigationController?.popViewController(animated: true)
                        NotificationCenter.default.post(name: .refreshNode, object: nil, userInfo: nil)
                    }
                }
            } else {
                displayAlert(viewController: self, isError: true, message: "Error adding that node: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    
    func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        if let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            let detector:CIDetector=CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
            let ciImage:CIImage = CIImage(image:pickedImage)!
            var qrCodeLink = ""
            let features = detector.features(in: ciImage)
            for feature in features as! [CIQRCodeFeature] {
                qrCodeLink += feature.messageString!
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            picker.dismiss(animated: true, completion: { [weak self] in
                self?.addBtcRpcQr(url: qrCodeLink)
            })
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "segueToExportNode" {
            if let vc = segue.destination as? QRDisplayerViewController {
                var prefix = "btcrpc"
                if isLightning {
                    prefix = "clightning-rpc"
                }
                if isHost {
                    vc.text = "\(prefix)://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(hostname!):11221/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "Quick Connect - Remote Control"
                    vc.descriptionText = "Fully Noded macOS hosts a secure hidden service for your node which can be used to remotely connect to it.\n\nSimply scan this QR with your iPhone or iPad using the Fully Noded iOS app and connect to your node remotely from anywhere in the world!"
                    isHost = false
                    vc.headerIcon = UIImage(systemName: "antenna.radiowaves.left.and.right")
                    
                } else {
                    vc.text = "\(prefix)://\(rpcUserField.text ?? ""):\(rpcPassword.text ?? "")@\(onionAddressField.text ?? "")/?label=\(nodeLabel.text?.replacingOccurrences(of: " ", with: "%20") ?? "")"
                    vc.headerText = "QuickConnect QR"
                    vc.descriptionText = "You can share this QR with trusted others who you want to share your node with, they will have access to all wallets on your node! If you want to maintain privacy and share your node you can look at running Bitcoin Knots which allows you to configure specific wallets to be accessed by specific rpcuser's."
                    vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
                }
                
            }
        }
        
        if segue.identifier == "segueToScanNodeCreds" {
            if let vc = segue.destination as? QRScannerViewController {
                vc.isQuickConnect = true
                vc.onQuickConnectDoneBlock = { [unowned thisVc = self] url in
                    if url != nil {
                        thisVc.addBtcRpcQr(url: url!)
                    }
                }
            }
        }
    }
    
}

fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}
