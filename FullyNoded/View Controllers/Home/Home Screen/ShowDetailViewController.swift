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
    let gettxoutsetinfo = "https://gettxoutsetinfo.com"
    var totalAmount:Double!
    var utxoCount:Int!
    let spinner = ConnectingView()

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
        textView.addHyperLinksToText(originalText: textView.text, hyperLinks: ["releases": releases, "bitcoin-cli getnetworkinfo": getnetworkinfo, "bitcoin-cli getblockchaininfo": getblockchaininfo, "bitcoin-cli getpeerinfo": getpeerinfo, "Bitcoin p2p network": bitcoinp2pnetwork, "bitcoin-cli gettxoutsetinfo": gettxoutsetinfo])
        if command == "gettxoutsetinfo" {
            getTotalSupply()
        }
    }
    
    private func getTotalSupply() {
        spinner.addConnectingView(vc: self, description: "checking total supply, this can take 30 seconds or so, be patient...")
        Reducer.makeCommand(command: .gettxoutsetinfo, param: "") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let total = dict["total_amount"] as? Double, let utxos = dict["txouts"] as? Int {
                    vc.utxoCount = utxos
                    vc.totalAmount = total
                    vc.getFiatRate()
                } else {
                    vc.spinner.removeConnectingView()
                }
            } else {
                vc.spinner.removeConnectingView()
            }
        }
    }
    
    private func getFiatRate() {
        let fx = FiatConverter.sharedInstance
        fx.getFxRate { (fxRate) in
            if fxRate != nil {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.subHeaderLabel.text = vc.totalAmount.withCommasNotRounded()  + " " + "btc"
                    vc.textView.text += "\n\nTotal supply in USD:\n$\((vc.totalAmount * fxRate!).withCommas())\n\nTotal number of utxos:\n\(Double(vc.utxoCount).withCommas())\n\nAverage value per utxo:\n \(rounded(number: (vc.totalAmount / Double(vc.utxoCount)))) btc - $\(((vc.totalAmount * fxRate!) / Double(vc.utxoCount)).withCommas())\n\nCurrent exchange rate:\n$\(fxRate!.withCommas()) USD / 1 btc"
                    vc.textView.addHyperLinksToText(originalText: vc.textView.text, hyperLinks: ["bitcoin-cli gettxoutsetinfo": vc.gettxoutsetinfo])
                    vc.spinner.removeConnectingView()
                }
            }
        }
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
