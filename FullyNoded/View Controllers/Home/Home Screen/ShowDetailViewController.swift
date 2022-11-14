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
        spinner.addConnectingView(vc: self, description: "Auditing every single utxo with your node. This requires a low time preference...")
        Reducer.sharedInstance.makeCommand(command: .gettxoutsetinfo) { [weak self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let total = dict["total_amount"] as? Double, let utxos = dict["txouts"] as? Int {
                    self?.utxoCount = utxos
                    self?.totalAmount = total
                    self?.getFiatRate()
                } else {
                    self?.spinner.removeConnectingView()
                }
            } else {
                self?.spinner.removeConnectingView()
            }
        }
    }
    
    private func getFiatRate() {
        let fx = FiatConverter.sharedInstance
        fx.getFxRate { (fxRate) in
            guard let fxRate = fxRate else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    self.subHeaderLabel.text = self.totalAmount.withCommasNotRounded()  + " " + "btc"
                    
                    let fiatAmount = self.totalAmount * fxRate
                    let utxoCount = Double(self.utxoCount)
                    let valuePerUtxo = rounded(number: (self.totalAmount / utxoCount))
                    let fiatPerUtxo = fiatAmount / utxoCount
                    
                    self.textView.text += "\n\nTotal supply in USD:\n$\(fiatAmount.withCommas)\n\nTotal number of utxos:\n\(utxoCount.withCommas)\n\nAverage value per utxo:\n\(valuePerUtxo) btc - $\(fiatPerUtxo.withCommas)\n\nCurrent exchange rate:\n$\(fxRate.withCommas) USD / 1 btc"
                    
                    self.textView.addHyperLinksToText(originalText: self.textView.text, hyperLinks: ["bitcoin-cli gettxoutsetinfo": self.gettxoutsetinfo])
                    
                    self.spinner.removeConnectingView()
                }
        }
    }
    
    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if (URL.absoluteString == releases) || (URL.absoluteString == bitcoinp2pnetwork) {
            UIApplication.shared.open(URL) { (Bool) in }
        } else {
            //getInfoHelpText()
        }
        return false
    }
    
//    private func showHelp() {
//        DispatchQueue.main.async { [weak self] in
//            self?.performSegue(withIdentifier: "showHelpSegue", sender: self)
//        }
//    }
    
//    private func getInfoHelpText() {
//        let connectingView = ConnectingView()
//        connectingView.addConnectingView(vc: self, description: "help \(command)...")
//        Reducer.sharedInstance.makeCommand(command: .help, param: "\"\(command)\"") { [weak self] (response, errorMessage) in
//            if let helpCheck = response as? String {
//                connectingView.removeConnectingView()
//                self?.helpText = helpCheck
//                self?.showHelp()
//            }
//        }
//    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        // Get the new view controller using segue.destination.
//        // Pass the selected object to the new view controller.
//        switch segue.identifier {
//        case "showHelpSegue":
//            if let vc = segue.destination as? HelpViewController {
//                vc.textViewText = helpText
//                vc.labelText = command
//            }
//        default:
//            break
//        }
//    }
    

}
