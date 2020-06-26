//
//  ShowDetailViewController.swift
//  BitSense
//
//  Created by Peter on 20/06/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class ShowDetailViewController: UIViewController, UITextViewDelegate, UINavigationControllerDelegate {
    
    @IBOutlet weak var background: UIView!
    @IBOutlet weak var icon: UIImageView!
    @IBOutlet weak var headerLabel: UILabel!
    @IBOutlet weak var subHeaderLabel: UILabel!
    @IBOutlet weak var textView: UITextView!
    
    var iconImage = UIImage()
    var backgroundTint = UIColor()
    var detailHeaderText = ""
    var detailSubheaderText = ""
    var detailTextDescription = ""
    var helpText = ""
    var command = ""
    let releases = "https://bitcoincore.org/en/releases/"
    let bitcoinp2pnetwork = "https://en.bitcoinwiki.org/wiki/Network"
    let getblockchaininfo = "https://getblockchaininfo.com"
    let getnetworkinfo = "https://getnetworkinfo.com"
    let getpeerinfo = "https://getpeerinfo.com"

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.delegate = self
        textView.delegate = self
        textView.isUserInteractionEnabled = true
        background.layer.cornerRadius = 8
        background.backgroundColor = backgroundTint
        icon.image = iconImage
        headerLabel.text = detailHeaderText
        subHeaderLabel.text = detailSubheaderText
        textView.text = detailTextDescription
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        textView.addHyperLinksToText(originalText: textView.text, hyperLinks: ["releases": releases, "bitcoin-cli getnetworkinfo": getnetworkinfo, "bitcoin-cli getblockchaininfo": getblockchaininfo, "bitcoin-cli getpeerinfo": getpeerinfo, "Bitcoin p2p network": bitcoinp2pnetwork])
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if (URL.absoluteString == releases) || (URL.absoluteString == bitcoinp2pnetwork) {
            UIApplication.shared.open(URL) { (Bool) in }
        } else {
            getInfoHelpText()
        }
        return false
    }
    
    private func showHelp() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.performSegue(withIdentifier: "showHelpSegue", sender: vc)
        }
    }
    
    private func getInfoHelpText() {
        let connectingView = ConnectingView()
        connectingView.addConnectingView(vc: self, description: "help \(command)...")
        Reducer.makeCommand(command: .help, param: "\"\(command)\"") { [unowned vc = self] (response, errorMessage) in
            if let helpCheck = response as? String {
                connectingView.removeConnectingView()
                vc.helpText = helpCheck
                vc.showHelp()
            }
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        switch segue.identifier {
        case "showHelpSegue":
            if let vc = segue.destination as? HelpViewController {
                vc.textViewText = helpText
                vc.labelText = command
            }
        default:
            break
        }
    }
    

}
