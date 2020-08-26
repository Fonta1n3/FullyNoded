//
//  PeerDetailsViewController.swift
//  FullyNoded
//
//  Created by Peter on 22/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class PeerDetailsViewController: UIViewController, UITextFieldDelegate {
    
    var uuid:UUID?
    let spinner = ConnectingView()
    var id = ""
    var peer:PeersStruct?
    
    @IBOutlet weak var uriField: UITextView!
    @IBOutlet weak var iconBackground: UIView!
    @IBOutlet weak var aliasLabel: UILabel!
    @IBOutlet weak var nameField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        iconBackground.clipsToBounds = true
        iconBackground.layer.cornerRadius = 5
        nameField.delegate = self
        nameField.keyboardAppearance = .dark
        uriField.layer.borderColor = UIColor.darkGray.cgColor
        uriField.layer.borderWidth = 0.5
        uriField.layer.cornerRadius = 5
        addTapGesture()
        listNodes()
    }
    
    @IBAction func keySendAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToKeySend", sender: self)
        }
    }
    
    @IBAction func noiseAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            self?.performSegue(withIdentifier: "segueToNoise", sender: self)
        }
    }
    
    private func listNodes() {
        spinner.addConnectingView(vc: self, description: "getting peer details...")
        
        CoreDataService.retrieveEntity(entityName: .peers) { [weak self] (peers) in
            if peers != nil {
                if peers!.count > 0 {
                    for peer in peers! {
                        let peerStruct = PeersStruct(dictionary: peer)
                        if peerStruct.pubkey == self?.id {
                            self?.peer = peerStruct
                            self?.uuid = peerStruct.id
                            DispatchQueue.main.async { [weak self] in
                                self?.iconBackground.backgroundColor = hexStringToUIColor(hex: peerStruct.color)
                                self?.aliasLabel.text = peerStruct.alias
                                self?.uriField.text = peerStruct.uri
                                self?.nameField.text = peerStruct.label
                                self?.spinner.removeConnectingView()
                            }
                        }
                    }
                }
            }
        }
        
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .listnodes, param: "\"\(id)\"") { [weak self] (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    if let nodes = dict["nodes"] as? NSArray {
                        if nodes.count > 0 {
                            if let nodeDict = nodes[0] as? NSDictionary {
                                let nodeId = nodeDict["nodeid"] as? String ?? ""
                                let alias = nodeDict["alias"] as? String ?? ""
                                let color = nodeDict["color"] as? String ?? "03c304"
                                DispatchQueue.main.async { [weak self] in
                                    self?.iconBackground.backgroundColor = hexStringToUIColor(hex:color)
                                    self?.aliasLabel.text = alias
                                }
                                if let addresses = nodeDict["addresses"] as? NSArray {
                                    if addresses.count > 0 {
                                        if let addressDict = addresses[0] as? NSDictionary {
                                            let address = addressDict["address"] as? String ?? ""
                                            let port = addressDict["port"] as? Int ?? 9735
                                            DispatchQueue.main.async { [weak self] in
                                                let uri = nodeId + "@" + address + ":" + "\(port)"
                                                self?.uriField.text = uri
                                                if self?.uuid != nil {
                                                    if self != nil {
                                                        print("updating")
                                                        CoreDataService.update(id: self!.uuid!, keyToUpdate: "color", newValue: color, entity: .peers) { _ in }
                                                        CoreDataService.update(id: self!.uuid!, keyToUpdate: "uri", newValue: uri, entity: .peers) { _ in }
                                                        CoreDataService.update(id: self!.uuid!, keyToUpdate: "alias", newValue: alias, entity: .peers) { _ in }
                                                        CoreDataService.update(id: self!.uuid!, keyToUpdate: "pubkey", newValue: nodeId, entity: .peers) { _ in }
                                                    }
                                                } else {
                                                    print("saving new")
                                                    var d = [String:Any]()
                                                    d["color"] = color
                                                    d["uri"] = uri
                                                    d["alias"] = alias
                                                    d["pubkey"] = nodeId
                                                    d["id"] = UUID()
                                                    CoreDataService.saveEntity(dict: d, entityName: .peers) { _ in }
                                                }
                                                self?.spinner.removeConnectingView()
                                            }
                                        }
                                    }
                                } else {
                                    if self?.uuid != nil {
                                        if self != nil {
                                            self!.uuid = UUID()
                                            var d = [String:Any]()
                                            d["color"] = color
                                            d["uri"] = ""
                                            d["alias"] = ""
                                            d["pubkey"] = nodeId
                                            d["id"] = self!.uuid
                                            CoreDataService.saveEntity(dict: d, entityName: .peers) { _ in }
                                        }
                                    }
                                    self?.spinner.removeConnectingView()
                                    showAlert(vc: self, title: "Private node", message: "We could not get any info about that node other then its pubkey")
                                }
                            }
                        } else {
                            self?.spinner.removeConnectingView()
                            showAlert(vc: self, title: "Ooops", message: "We could not get any info about that node...")
                        }
                    } else {
                        self?.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Ooops", message: "We could not get any info about that node...")
                    }
                } else {
                    self?.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Ooops", message: errorDesc ?? "unknown error fetching node info")
                }
            }
        }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        nameField.resignFirstResponder()
        uriField.resignFirstResponder()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.endEditing(true)
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == nameField && textField.text != "" {
            if self.uuid != nil {
                CoreDataService.update(id: self.uuid!, keyToUpdate: "label", newValue: textField.text!, entity: .peers) { (success) in
                    if success {
                        showAlert(vc: self, title: "Success", message: "Peer's name updated")
                    }
                }
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToKeySend" {
            if let vc = segue.destination as? KeySendViewController {
                vc.id = id
                vc.peer = peer
            }
        }
        
        if segue.identifier == "segueToNoise" {
            if let vc = segue.destination as? NoiseViewController {
                vc.id = id
            }
        }
    }

}
