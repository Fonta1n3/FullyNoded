//
//  SignerViewController.swift
//  BitSense
//
//  Created by Peter on 03/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit
import LibWally

class SignerViewController: UIViewController {
    
    @IBOutlet weak var fxRateLabel: UILabel!
    @IBOutlet weak var analyzeOutlet: UIButton!
    @IBOutlet weak var decodeOutlet: UIButton!
    var fxRate = Double()
    var outputsString = ""
    var inputsString = ""
    var inputArray = [[String:Any]]()
    var index = Int()
    var inputTotal = Double()
    var outputTotal = Double()
    var spinner = ConnectingView()
    var psbt = ""
    var txn = ""
    var txnUnsigned = ""
    var broadcast = false
    var export = false
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var signOutlet: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        textView.layer.cornerRadius = 8
        textView.layer.borderColor = UIColor.lightGray.cgColor
        textView.layer.borderWidth = 0.5
        if psbt != "" {
            psbt = (psbt.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            textView.text = psbt
            if export {
                titleLabel.text = "Export PSBT"
                signOutlet.setTitle("export", for: .normal)
                analyzeOutlet.alpha = 1
                decodeOutlet.alpha = 1
            } else {
                spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
            }
        } else if txn != "" {
            txn = (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            titleLabel.text = "Broadcaster"
            broadcast = true
            textView.text = (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            signOutlet.setTitle("broadcast", for: .normal)
            analyzeOutlet.setTitle("verify", for: .normal)
            analyzeOutlet.alpha = 1
            decodeOutlet.alpha = 1
            spinner.addConnectingView(vc: self, description: "checking which network the node is on...")
        } else if txnUnsigned != "" {
            txnUnsigned = (txnUnsigned.replacingOccurrences(of: "\n", with: "")).condenseWhitespace()
            analyzeOutlet.setTitle("verify", for: .normal)
            analyzeOutlet.alpha = 1
            textView.text = txnUnsigned
            titleLabel.text = "Export Unsigned Tx"
            signOutlet.setTitle("export", for: .normal)
            decodeOutlet.alpha = 1
        }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if !export && txnUnsigned == "" {
            Reducer.makeCommand(command: .getblockchaininfo, param: "") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    if let network = dict["chain"] as? String {
                        var chain:Network!
                        if network == "main" {
                            chain = .mainnet
                        } else {
                            chain = .testnet
                        }
                        vc.getPsbt(chain: chain)
                    } else {
                        vc.showError(error: "error getting network type: \(errorMessage ?? "unknown")")
                    }
                }
            }
        }
    }
    
    private func updateLabel(text: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.label.text = text
        }
    }
    
    private func getPsbt(chain: Network) {
        if psbt != "" {
            do {
                let psbtTocheck = try PSBT(psbt, chain)
                if psbtTocheck.complete {
                    finalizePsbt()
                } else {
                    process()
                }
            } catch {
                showError(error: "error processing psbt")
            }
        } else {
            spinner.removeConnectingView()
        }
    }
    
    private func showError(error: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.spinner.removeConnectingView()
            showAlert(vc: vc, title: "Error", message: error)
        }
    }
    
    private func finalizePsbt() {
        updateLabel(text: "finalizing psbt...")
        Reducer.makeCommand(command: .finalizepsbt, param: "\"\(psbt)\"") { [unowned vc = self] (object, errorDescription) in
            if let result = object as? NSDictionary {
                if let complete = result["complete"] as? Bool {
                    if complete {
                        let hex = result["hex"] as! String
                        vc.txn = hex
                    }
                } else {
                    vc.showError(error: errorDescription ?? "")
                }
            } else {
                vc.showError(error: errorDescription ?? "")
            }
        }
    }
    
    private func process() {
        updateLabel(text: "processing psbt with active wallet...")
        Reducer.makeCommand(command: .walletprocesspsbt, param: "\"\(psbt)\", true, \"ALL\", true") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                if let processedPsbt = dict["psbt"] as? String {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.psbt = processedPsbt
                        vc.textView.text = "\(processedPsbt)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
                }
            } else {
                vc.showError(error: "error processing psbt: \(errorMessage ?? "unknown")")
            }
        }
    }
    
    private func decodeRaw(raw: String) {
        Reducer.makeCommand(command: .decoderawtransaction, param: "\"\(raw)\"") { [unowned vc = self] (response, errorMessage) in
            if let dict = response as? NSDictionary {
                vc.parseDecodedTx(response: dict)
            } else {
                vc.spinner.removeConnectingView()
                showAlert(vc: vc, title: "Error", message: errorMessage ?? "error decoding raw transaction")
            }
        }
    }
    
    private func parseDecodedTx(response: Any?) {
        if let dict = response as? NSDictionary {
            parseTransaction(tx: dict)
        }
    }
    
    func parseTransaction(tx: NSDictionary) {
        let inputs = tx["vin"] as! NSArray
        let outputs = tx["vout"] as! NSArray
        parseOutputs(outputs: outputs)
        parseInputs(inputs: inputs, completion: getFirstInputInfo)
    }
    
    func getFirstInputInfo() {
        index = 0
        getInputInfo(index: index)
    }
    
    func getInputInfo(index: Int) {
        let dict = inputArray[index]
        if let txid = dict["txid"] as? String {
            if let vout = dict["vout"] as? Int {
                parsePrevTx(method: .gettransaction, param: "\"\(txid)\", true", vout: vout)
            }
        }
    }
    
    func parsePrevTxOutput(outputs: NSArray, vout: Int) {
        for o in outputs {
            let output = o as! NSDictionary
            let n = output["n"] as! Int
            if n == vout {
                //this is our inputs output, get amount and address
                let scriptpubkey = output["scriptPubKey"] as! NSDictionary
                let addresses = scriptpubkey["addresses"] as! NSArray
                let amount = output["value"] as! Double
                var addressString = ""
                for a in addresses {
                    addressString += a as! String + " "
                }
                inputTotal += amount
                inputsString += "Input #\(index + 1):\nAmount: \(amount.avoidNotation) btc - \(String(format: "$%.02f", amount * fxRate))\nAddress: \(addressString)\n\n"
            }
        }
        
        if index + 1 < inputArray.count {
            index += 1
            getInputInfo(index: index)
        } else if index + 1 == inputArray.count {
            DispatchQueue.main.async {
                let txfee = (self.inputTotal - self.outputTotal)
                let miningFee = "Mining Fee: \(txfee.avoidNotation) btc - \(String(format: "$%.02f", txfee * self.fxRate))"
                self.textView.text = self.inputsString + "\n\n\n" + self.outputsString + "\n\n\n" + miningFee
                self.spinner.removeConnectingView()
            }
        }
    }
    
    func parsePrevTx(method: BTC_CLI_COMMAND, param: String, vout: Int) {
        Reducer.makeCommand(command: method, param: param) { [unowned vc = self] (response, errorMessage) in
            if errorMessage == nil {
                switch method {
                case .decoderawtransaction:
                    if let txDict = response as? NSDictionary {
                        let outputs = txDict["vout"] as! NSArray
                        vc.parsePrevTxOutput(outputs: outputs, vout: vout)
                    }
                    
                case .gettransaction:
                    if let dict = response as? NSDictionary {
                        let rawTransaction = dict["hex"] as! String
                        vc.parsePrevTx(method: .decoderawtransaction, param: "\"\(rawTransaction)\"", vout: vout)
                    }
                    
                default:
                    break
                }
            } else {
                vc.spinner.removeConnectingView()
                showAlert(vc: self, title: "Error", message: errorMessage!)
            }
        }
    }
    
    func parseInputs(inputs: NSArray, completion: @escaping () -> Void) {
        for (index, i) in inputs.enumerated() {
            let input = i as! NSDictionary
            if let txid = input["txid"] as? String {
                if let vout = input["vout"] as? Int {
                    let dict = ["inputNumber":index + 1, "txid":txid, "vout":vout as Any] as [String : Any]
                    inputArray.append(dict)
                    if index + 1 == inputs.count {
                        completion()
                    }
                }
                
            } else if let coinbase = input["coinbase"] as? String {
                let dict = ["coinbase":coinbase] as [String : Any]
                inputArray.append(dict)
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.textView.text = "Coinbase: \(coinbase)" + "\n\n\n" + vc.outputsString
                    vc.spinner.removeConnectingView()
                }
            }
        }
    }
    
    func parseOutputs(outputs: NSArray) {
        for (i, o) in outputs.enumerated() {
            let output = o as! NSDictionary
            let scriptpubkey = output["scriptPubKey"] as! NSDictionary
            let addresses = scriptpubkey["addresses"] as? NSArray ?? []
            let amount = output["value"] as! Double
            let number = i + 1
            var addressString = ""
            let type = scriptpubkey["type"] as? String ?? ""
            let hex = scriptpubkey["hex"] as? String ?? ""
            for a in addresses {
                addressString += a as! String + " "
            }
            outputTotal += amount
            outputsString += "Output #\(number):\nAmount: \(amount.avoidNotation) btc - \(String(format: "$%.02f", amount * fxRate))\nAddress: \(addressString)\n"
            if type == "nulldata" {
                if hex != "" {
                    outputsString += "NullData: \(hex)"
                }
            }
            outputsString += "\n\n"
        }
    }
    
    @IBAction func decodePsbt(_ sender: Any) {
        if txn != "" {
            spinner.addConnectingView(vc: self, description: "decoding raw...")
            Reducer.makeCommand(command: .decoderawtransaction, param: "\"\(txn)\"") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.textView.text = "\(dict)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error decoding raw: \(errorMessage ?? "unknown")")
                }
            }
        } else if psbt != "" {
            spinner.addConnectingView(vc: self, description: "decoding psbt...")
            Reducer.makeCommand(command: .decodepsbt, param: "\"\(psbt)\"") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.textView.text = "\(dict)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error decoding psbt: \(errorMessage ?? "unknown")")
                }
            }
        }
    }
    
    @IBAction func analyzePsbt(_ sender: Any) {
        if psbt != "" {
            spinner.addConnectingView(vc: self, description: "analyzing psbt...")
            Reducer.makeCommand(command: .analyzepsbt, param: "\"\(psbt)\"") { [unowned vc = self] (response, errorMessage) in
                if let dict = response as? NSDictionary {
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.textView.text = "\(dict)"
                        vc.spinner.removeConnectingView()
                    }
                } else {
                    vc.showError(error: "error analyzing psbt: \(errorMessage ?? "unknown")")
                }
            }
        } else {
            spinner.addConnectingView(vc: self, description: "verifying...")
            let fx = FiatConverter.sharedInstance
            fx.getFxRate { [unowned vc = self] (fx) in
                if fx != nil {
                    vc.fxRate = fx!
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.fxRateLabel.text = "$\(fx!.withCommas()) / btc"
                    }
                }
                if vc.txn != "" {
                    vc.decodeRaw(raw: vc.txn)
                } else if vc.txnUnsigned != "" {
                    vc.decodeRaw(raw: vc.txnUnsigned)
                }
            }
        }
    }
    
    @IBAction func signNow(_ sender: Any) {
        if txnUnsigned != "" {
            exportUnisgned(txnUnsigned: txnUnsigned)
        } else if export {
            exportPsbt(psbt: psbt)
        } else if !broadcast {
            spinner.addConnectingView(vc: self, description: "signing psbt...")
            Signer.sign(psbt: psbt) { [unowned vc = self] (psbt, rawTx, errorMessage) in
                if psbt != nil {
                    vc.spinner.removeConnectingView()
                    vc.exportPsbt(psbt: psbt!)
                    DispatchQueue.main.async {
                        vc.textView.text = psbt!
                    }
                } else if rawTx != nil {
                    vc.spinner.removeConnectingView()
                    vc.broadcastNow(tx: rawTx!)
                    DispatchQueue.main.async {
                        vc.decodeOutlet.alpha = 0
                        vc.analyzeOutlet.alpha = 0
                        vc.textView.text = rawTx!
                        vc.signOutlet.setTitle("broadcast", for: .normal)
                        vc.broadcast = true
                    }
                } else {
                    vc.spinner.removeConnectingView()
                    vc.showError(error: "Error signing psbt: \(errorMessage ?? "unknown error")")
                }
            }
        } else {
            broadcastNow(tx: (txn.replacingOccurrences(of: "\n", with: "")).condenseWhitespace())
        }
        
    }
    
    private func exportUnisgned(txnUnsigned: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Export as text or QR?", message: "", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    let textToShare = [txnUnsigned]
                    let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                    }
                    vc.present(activityViewController, animated: true) {}
                }
            }))
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.performSegue(withIdentifier: "segueToExportPsbtAsQr", sender: vc)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    private func exportPsbt(psbt: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Share as a .psbt file, text or QR?", message: "Sharing as a .psbt file allows you to send the unsigned psbt directly to your Coldcard or to Electrum 4.0 for signing", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: ".psbt file", style: .default, handler: { [unowned vc = self] action in
                vc.convertPSBTtoData(string: psbt)
            }))
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    let textToShare = [psbt]
                    let activityViewController = UIActivityViewController(activityItems: textToShare, applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                    }
                    vc.present(activityViewController, animated: true) {}
                }
            }))
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.performSegue(withIdentifier: "segueToExportPsbtAsQr", sender: vc)
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    private func convertPSBTtoData(string: String) {
        if let data = Data(base64Encoded: string) {
            if let url = exportPsbtToURL(data: data) {
                DispatchQueue.main.async { [unowned vc = self] in
                    let activityViewController = UIActivityViewController(activityItems: ["Fully Noded PSBT", url], applicationActivities: nil)
                    if UIDevice.current.userInterfaceIdiom == .pad {
                        activityViewController.popoverPresentationController?.sourceView = self.view
                        activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                    }
                    vc.present(activityViewController, animated: true) {}
                }
            }
        }
    }
    
    private func broadcastNow(tx: String) {
        DispatchQueue.main.async { [unowned vc = self] in
            var alertStyle = UIAlertController.Style.actionSheet
            if (UIDevice.current.userInterfaceIdiom == .pad) {
              alertStyle = UIAlertController.Style.alert
            }
            let alert = UIAlertController(title: "Broadcast with your node?", message: "You can optionally broadcast this transaction using Blockstream's esplora API over Tor V3 for improved privacy.", preferredStyle: alertStyle)
            alert.addAction(UIAlertAction(title: "Privately", style: .default, handler: { action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Broadcaster.sharedInstance.send(rawTx: tx) { [unowned vc = self] (txid) in
                    if txid != nil {
                        DispatchQueue.main.async { [unowned vc = self] in
                            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            vc.textView.text = "txid: " + txid!
                            vc.decodeOutlet.alpha = 0
                            vc.analyzeOutlet.alpha = 0
                            vc.spinner.removeConnectingView()
                            showAlert(vc: vc, title: "Success! ✅", message: "Transaction sent.")
                        }
                    } else {
                        vc.showError(error: "Error broadcasting privately, try again and use your node instead.")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Use my node", style: .default, handler: { [unowned vc = self] action in
                vc.spinner.addConnectingView(vc: vc, description: "broadcasting...")
                Reducer.makeCommand(command: .sendrawtransaction, param: "\"\(tx)\"") { [unowned vc = self] (response, errorMesage) in
                    if let txid = response as? String {
                        DispatchQueue.main.async { [unowned vc = self] in
                            NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                            vc.textView.text = "txid: " + txid
                            vc.spinner.removeConnectingView()
                            vc.decodeOutlet.alpha = 0
                            vc.analyzeOutlet.alpha = 0
                            showAlert(vc: vc, title: "Success! ✅", message: "Transaction sent.")
                        }
                    } else {
                        vc.showError(error: "Error broadcasting: \(errorMesage ?? "")")
                    }
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = vc.view
            vc.present(alert, animated: true) {}
        }
    }
    
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        if segue.identifier == "segueToExportPsbtAsQr" {
            if let vc = segue.destination as? QRDisplayerViewController {
                if psbt != "" {
                    vc.text = psbt
                } else if txn != "" {
                    vc.text = txn
                } else if txnUnsigned != "" {
                    vc.text = txnUnsigned
                }
            }
        }
    }
}
