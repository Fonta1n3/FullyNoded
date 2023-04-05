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
    var isLnd = false
    
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
        if !isLnd {
            DispatchQueue.main.async { [weak self] in
                self?.performSegue(withIdentifier: "segueToNoise", sender: self)
            }
        } else {
            showAlert(vc: self, title: "Coming to LND soon", message: "")
        }
        
    }
    
    private func listNodes() {
        spinner.addConnectingView(vc: self, description: "getting peer details...")
        
        CoreDataService.retrieveEntity(entityName: .peers) { [weak self] (peers) in
            guard let self = self else { return }
            
            guard let peers = peers, peers.count > 0 else {
                return
            }
            
            for peer in peers {
                let peerStruct = PeersStruct(dictionary: peer)
                if peerStruct.pubkey == self.id {
                    self.peer = peerStruct
                    self.uuid = peerStruct.id
                    
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.iconBackground.backgroundColor = hexStringToUIColor(hex: peerStruct.color)
                        self.aliasLabel.text = peerStruct.alias
                        self.uriField.text = peerStruct.uri
                        self.nameField.text = peerStruct.label
                        self.spinner.removeConnectingView()
                    }
                }
            }
        }
        
        isLndNode { [weak self] isLnd in
            guard let self = self else { return }
            
            self.isLnd = isLnd
            
            guard isLnd else {
                self.getPeerCL()
                return
            }
            
            self.getPeerLND()
        }
    }
    
    private func getPeerLND() {
        LndRpc.sharedInstance.command(.getnodeinfo, nil, self.id, nil) { [weak self] (response, error) in
            guard let self = self else { return }
            
            guard let node = response?["node"] as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: error ?? "Unknown error fetching that node.")
                return
            }
            
            self.processNodeLND(nodeDict: node)
        }
    }
    
    private func getPeerCL() {
        let commandId = UUID()
        LightningRPC.sharedInstance.command(id: commandId, method: .listnodes, param: ["id":id]) { [weak self] (uuid, response, errorDesc) in
            guard let self = self else { return }
            
            guard let dict = response as? NSDictionary, let nodes = dict["nodes"] as? NSArray, nodes.count > 0, let nodeDict = nodes[0] as? [String:Any] else {
                self.spinner.removeConnectingView()
                showAlert(vc: self, title: "Ooops", message: errorDesc ?? "unknown error fetching node info")
                return
            }
            
            self.processNodeCL(nodeDict: nodeDict)
        }
    }
    
    private func processNodeLND(nodeDict: [String:Any]) {
        let nodeId = nodeDict["pub_key"] as? String ?? ""
        let alias = nodeDict["alias"] as? String ?? ""
        let color = nodeDict["color"] as? String ?? "03c304"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.iconBackground.backgroundColor = hexStringToUIColor(hex:color)
            self.aliasLabel.text = alias
        }
        
        guard let addresses = nodeDict["addresses"] as? NSArray, addresses.count > 0, let addressDict = addresses[0] as? NSDictionary else {
            if self.uuid != nil {
                self.uuid = UUID()
                var d = [String:Any]()
                d["color"] = color
                d["uri"] = ""
                d["alias"] = alias
                d["pubkey"] = nodeId
                d["id"] = self.uuid
                CoreDataService.saveEntity(dict: d, entityName: .peers) { _ in }
            }
            
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Private node", message: "We could not get any info about that node other then its pubkey")
            return
        }
        
        let address = addressDict["addr"] as? String ?? ""
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let uri = nodeId + "@" + address
            self.uriField.text = uri
            
            if let uuid = self.uuid {
                print("updating")
                CoreDataService.update(id: uuid, keyToUpdate: "color", newValue: color, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "uri", newValue: uri, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "alias", newValue: alias, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "pubkey", newValue: nodeId, entity: .peers) { _ in }
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
            
            self.spinner.removeConnectingView()
        }
    }
    
    private func processNodeCL(nodeDict: [String:Any]) {
        let nodeId = nodeDict["nodeid"] as? String ?? ""
        let alias = nodeDict["alias"] as? String ?? ""
        let color = nodeDict["color"] as? String ?? "03c304"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.iconBackground.backgroundColor = hexStringToUIColor(hex:color)
            self.aliasLabel.text = alias
        }
        
        guard let addresses = nodeDict["addresses"] as? NSArray, addresses.count > 0, let addressDict = addresses[0] as? NSDictionary else {
            if self.uuid != nil {
                self.uuid = UUID()
                var d = [String:Any]()
                d["color"] = color
                d["uri"] = ""
                d["alias"] = ""
                d["pubkey"] = nodeId
                d["id"] = self.uuid
                CoreDataService.saveEntity(dict: d, entityName: .peers) { _ in }
            }
            
            self.spinner.removeConnectingView()
            showAlert(vc: self, title: "Private node", message: "We could not get any info about that node other then its pubkey")
            return
        }
        
        let address = addressDict["address"] as? String ?? ""
        let port = addressDict["port"] as? Int ?? 9735
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let uri = nodeId + "@" + address + ":" + "\(port)"
            self.uriField.text = uri
            
            if let uuid = self.uuid {
                print("updating")
                CoreDataService.update(id: uuid, keyToUpdate: "color", newValue: color, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "uri", newValue: uri, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "alias", newValue: alias, entity: .peers) { _ in }
                CoreDataService.update(id: uuid, keyToUpdate: "pubkey", newValue: nodeId, entity: .peers) { _ in }
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
            
            self.spinner.removeConnectingView()
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
                CoreDataService.update(id: self.uuid!, keyToUpdate: "label", newValue: textField.text!, entity: .peers) { _ in
                    return
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
    }

}
