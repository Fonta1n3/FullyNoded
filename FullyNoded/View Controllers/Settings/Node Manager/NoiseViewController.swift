//
//  NoiseViewController.swift
//  FullyNoded
//
//  Created by Peter on 23/08/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class NoiseViewController: UIViewController {
    
    @IBOutlet weak var textView: UITextView!
    var id = ""
    let spinner = ConnectingView()

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 0.5
        textView.layer.borderColor = UIColor.lightGray.cgColor
        addTapGesture()
    }
    
    @IBAction func listenAction(_ sender: Any) {
        listen()
    }
    
    @IBAction func sendAction(_ sender: Any) {
        send()
    }
    
    private func listen() {
        DispatchQueue.main.async { [weak self] in
            self?.textView.text = "listening.... as soon as you receive a message it will show here, the timeout is set for 3 minutes"
        }
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .recvmsg, param: "") { [weak self] (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    let body = dict["body"] as? String ?? "(error: body missing)"
                    let sender = dict["sender"] as? String ?? "(error: sender id missing)"
                    self?.fetchLocalPeers(id: sender) { (name) in
                        DispatchQueue.main.async { [weak self] in
                            let impact = UIImpactFeedbackGenerator()
                            impact.impactOccurred()
                            displayAlert(viewController: self, isError: false, message: "noise received ⚡️")
                            self?.textView.text = name + ":" + "\n\n" + body
                        }
                    }
                }
            }
        }
    }
    
    private func send() {
        spinner.addConnectingView(vc: self, description: "sending noise...")
        let commandId = UUID()
        LightningRPC.command(id: commandId, method: .sendmsg, param: "\"\(id)\", \"\(textView.text ?? "I have nothing to say apparently...")\"") { (uuid, response, errorDesc) in
            if commandId == uuid {
                if let dict = response as? NSDictionary {
                    if let _ = dict["payment_hash"] as? String {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Noise sent!", message: "If you are expecting a reply back tap \"listen\"")
                    } else {
                        self.spinner.removeConnectingView()
                        showAlert(vc: self, title: "Hmmm something not quite right", message: "\(dict)")
                    }
                } else {
                    self.spinner.removeConnectingView()
                    showAlert(vc: self, title: "Error", message: errorDesc ?? "unknown error sending message")
                }
            }
        }
    }
    
    private func fetchLocalPeers(id: String, completion: @escaping ((String)) -> Void) {
        CoreDataService.retrieveEntity(entityName: .peers) { (peers) in
            if peers != nil {
                if peers!.count > 0 {
                    for peer in peers! {
                        let peerStruct = PeersStruct(dictionary: peer)
                        if id == peerStruct.pubkey {
                            if peerStruct.label != "" {
                                completion(peerStruct.label)
                            } else if peerStruct.alias != "" {
                               completion(peerStruct.alias)
                            } else {
                                completion(id)
                            }
                        }
                    }
                } else {
                    completion(id)
                }
            } else {
                completion(id)
            }
        }
    }
    
    func addTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
    }
    
    @objc func dismissKeyboard(_ sender: UITapGestureRecognizer) {
        textView.resignFirstResponder()
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
