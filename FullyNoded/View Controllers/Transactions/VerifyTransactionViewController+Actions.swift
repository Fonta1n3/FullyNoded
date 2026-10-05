//
//  VerifyTransactionViewController+Actions.swift
//  FullyNoded
//
//  User actions: adding a transaction (scan / paste / file), export, broadcast, copy,
//  and the screens pushed from the verifier.
//

import UIKit

extension VerifyTransactionViewController {

    @objc func showRawDataAction(_ sender: Any) {
        let method: BTC_CLI_COMMAND
        let name: String
        if signedRawTx != "" {
            method = .decoderawtransaction(param: .init(["hexstring": signedRawTx]))
            name = "decoderawtransaction"
        } else if unsignedPsbt != "" {
            method = .decodepsbt(param: Decode_Psbt(["psbt": unsignedPsbt]))
            name = "decodepsbt"
        } else {
            showAlert(vc: self, title: "", message: "No transaction to decode.")
            return
        }

        showActivity(name == "decodepsbt" ? "Decoding psbt..." : "Decoding raw transaction...")
        MakeRPCCall.sharedInstance.executeRPCCommand(method: method) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            self.finishActivity()
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "No response from \(name).")
                return
            }
            self.showModal(data: response, title: name)
        }
    }

    func showModal(data: [String: Any], title: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let modalVC = TextModalViewController(data: data, viewTitle: title)
            let nav = UINavigationController(rootViewController: modalVC)
            nav.modalPresentationStyle = .fullScreen
            nav.modalTransitionStyle = .coverVertical
            present(nav, animated: true)
        }
    }

    func promptToAddTx() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Add Transaction",
                                          message: "You can add a transaction in a number of ways.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Upload File", style: .default, handler: { action in
                self.presentUploader()
            }))
            
            alert.addAction(UIAlertAction(title: "Paste Text", style: .default, handler: { action in
                self.pasteAction()
            }))
            
            alert.addAction(UIAlertAction(title: "QR Code", style: .default, handler: { action in
                self.scanQr()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

    func scanQr() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.presentScanner()
        }
    }

    func pasteAction() {
        if let data = UIPasteboard.general.data(forPasteboardType: "com.apple.traditional-mac-plain-text") {
            guard let string = String(bytes: data, encoding: .utf8) else {
                showAlert(vc: self, title: "Not a psbt?", message: "Looks like you do not have valid text on your clipboard")
                return
            }
            
            processPastedString(string)
        } else if let string = UIPasteboard.general.string {
            
           processPastedString(string)
        } else {
            
            showAlert(vc: self, title: "", message: "Not valid text. You can copy and paste the base64 text of a psbt or a signed raw transaction with this button.")
        }
    }

    func processPastedString(_ string: String) {
        let processed = string.condenseWhitespace()
        reset()
        if Keys.validPsbt(processed) {
            enableExportButton()
            processPsbt(processed)
        } else if Keys.validTx(processed) {
            enableExportButton()
            signedRawTx = processed
            load()
        } else {
            showAlert(vc: self, title: "Invalid", message: "Whatever you pasted was not a valid psbt, raw transaction or txid.")
        }
    }

    func presentUploader() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            var documentPicker:UIDocumentPickerViewController!
            
            if #available(iOS 14.0, *) {
                documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
            } else {
                documentPicker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
            }
            documentPicker.delegate = self
            documentPicker.modalPresentationStyle = .formSheet
            self.present(documentPicker, animated: true, completion: nil)
        }
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {        
        guard let text = try? String(contentsOf: urls[0].absoluteURL), Keys.validTx(text) else {
            
            guard let data = try? Data(contentsOf: urls[0].absoluteURL) else {
                self.finishActivity()
                showAlert(vc: self, title: "Invalid File", message: "That is not a recognized format, generally it will be a .psbt or .txn file.")
                return
            }
                        
            if Keys.validPsbt(data.base64EncodedString()) {
                unsignedPsbt = data.base64EncodedString()
                processPsbt(data.base64EncodedString())
                self.reset()
            } else if let psbtUtf8 = data.utf8String, Keys.validPsbt(psbtUtf8) {
                unsignedPsbt = psbtUtf8
                self.reset()
                processPsbt(psbtUtf8)
            } else {
                self.finishActivity()
                showAlert(vc: self, title: "Invalid format", message: "That is not a valid BIP174 format.")
            }
            
            return
        }
        
        reset()
        signedRawTx = text.condenseWhitespace()
        load()
    }

    @objc func exportAction(_ sender: Any) {
        if unsignedPsbt != "" {
            exportPsbt(plainText: unsignedPsbt)
        } else if signedRawTx != "" {
            exportTxn(txn: signedRawTx)
        }
    }

    func send() {
        
        if self.signedRawTx != "" {
            broadcast()
        } else {
            showAlert(vc: self, title: "", message: "Transaction not fully signed, you can export it to another signer or sign it if the sign button is enabled.")
        }
    }

    @objc func copyAddress(_ sender: UIButton) {
        UIPasteboard.general.string = sender.restorationIdentifier
        
        SuccessView.toast("Address copied", in: self)
    }

    @objc func showAddressQr(_ sender: UIButton) {
        guard let address = sender.restorationIdentifier else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.qrCodeStringToExport = address
            self.showAddressQR()
        }
    }

    @objc func showAddressInfo(_ sender: UIButton) {
        guard let address = sender.restorationIdentifier else { return }
        self.showActivity("getting address info...", button: sender)
        
        let p = Get_Address_Info(["address": address])
        
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .getaddressinfo(param: p)) { [weak self] (response, errorDesc) in
            guard let self = self else { return }
            
            self.finishActivity()
            
            guard let response = response as? [String: Any] else {
                showAlert(vc: self, title: "", message: errorDesc ?? "Unable to get address info.")
                return
            }
            
            self.showModal(data: response, title: "getaddressinfo")
        }
    }

    @objc func copyDesc(_ sender: UIButton) {
        UIPasteboard.general.string = sender.restorationIdentifier
        
        SuccessView.toast("Descriptor copied", in: self)
    }

    @objc func updateLabelMemoAction() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.presentLabelMemo()
        }
    }

    func broadcastPrivately() {
        self.showActivity("broadcasting...", button: sendOutlet)
        
        Task {
            let result: Broadcaster.BroadcastResult
            do {
                result = try await Broadcaster.sharedInstance.broadcastRawTransaction(rawTx: signedRawTx, network: WalletLogic.shared.bdkNetwork() ?? .bitcoin)
            } catch {
                showError(error: "Error broadcasting privately. Error: \(error.localizedDescription)")
                return
            }
            self.finishActivity()
            switch result {
            case .success(_):
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    disableSendButton()
                    SuccessView.show(in: self, title: "Transaction sent",
                                     subtitle: "Broadcast privately over Tor.", detail: self.txid) { [weak self] in
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                }
            case .failure(let message):
                showError(error: "Error broadcasting privately. Error: \(message)")
            }
        }
    }

    func broadcastWithMyNode() {
        self.showActivity("broadcasting...", button: sendOutlet)
        let paramDict:[String:Any] = ["hexstring":self.signedRawTx]
        let param:Send_Raw_Transaction = .init(paramDict)
        MakeRPCCall.sharedInstance.executeRPCCommand(method: .sendrawtransaction(param)) { [weak self] (response, errorMesage) in
            guard let self = self else { return }
            
            guard let id = response as? String else {
                self.showError(error: "Error broadcasting: \(errorMesage ?? "unknown error")")
                return
            }
            
            DispatchQueue.main.async {
                if self.txid == id {
                    NotificationCenter.default.post(name: .refreshWallet, object: nil, userInfo: nil)
                    self.disableSendButton()
                    self.finishActivity()
                    
                    SuccessView.show(in: self, title: "Transaction sent",
                                     subtitle: "Broadcast with your node.", detail: id) { [weak self] in
                        self?.navigationController?.popToRootViewController(animated: true)
                    }
                } else {
                    self.finishActivity()
                    showAlert(vc: self, title: "Hmmm we got a strange response...", message: id)
                }
            }
        }
    }

    func broadcast() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Broadcast transaction?",
                                          message: "You can broadcast with your node or via Blockstreams Esplora onion. Broadcasting with Esplora is more private.",
                                          preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Via my node", style: .default, handler: { action in
                self.broadcastWithMyNode()
            }))
            
            alert.addAction(UIAlertAction(title: "Via Esplora (Tor)", style: .default, handler: { action in
                self.broadcastPrivately()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

    func showError(error: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.finishActivity()
            showAlert(vc: self, title: "Uh oh", message: error)
        }
    }

    @objc func copyTxid() {
        DispatchQueue.main.async { [unowned vc = self] in
            let pasteBoard = UIPasteboard.general
            pasteBoard.string = vc.txid
            displayAlert(viewController: vc, isError: false, message: "Transaction ID copied to clipboard")
        }
    }

    func exportPsbt(plainText: String?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
                        
            var itemToExport = ""
            
            if let plain = plainText {
                itemToExport = plain
            }
            
            let alert = UIAlertController(title: "", message: "Share?", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "File", style: .default, handler: { action in
                self.convertPSBTtoData(string: itemToExport)
            }))
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                self.shareText(itemToExport)
            }))
            
            alert.addAction(UIAlertAction(title: "UR QR", style: .default, handler: { action in
                self.qrCodeStringToExport = itemToExport
                self.isUR = true
                self.isPlainText = false
                self.showExportQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Plain Text QR", style: .default, handler: { action in
                self.isUR = false
                self.isPlainText = true
                self.qrCodeStringToExport = itemToExport
                self.showExportQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

    func shareText(_ text: String) {
            #if !os(macOS)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
                
                if UIDevice.current.userInterfaceIdiom == .pad {
                    activityViewController.popoverPresentationController?.sourceView = self.view
                    activityViewController.popoverPresentationController?.sourceRect = CGRect(x: 0, y: 0, width: 100, height: 100)
                }
                
                self.present(activityViewController, animated: true) {}
            }
            
            #else
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                UIPasteboard.general.string = text
                SuccessView.toast("Transaction copied to clipboard", in: self)
            }
            
            #endif
    }

    func exportTxn(txn: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(title: "Export as text or QR?", message: "", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "Text", style: .default, handler: { action in
                self.shareText(txn)
            }))
            
            alert.addAction(UIAlertAction(title: "QR", style: .default, handler: { action in
                self.showExportQR()
            }))
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { action in }))
            alert.popoverPresentationController?.sourceView = self.view
            self.present(alert, animated: true) {}
        }
    }

    /// Saves the psbt (or blinded UR:BYTES psbt) as a file and opens the share sheet.
    func convertPSBTtoData(string: String) {
        let isBlinded = string.hasPrefix("UR:BYTES")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let data = isBlinded ? URHelper.ur(string)?.qrData : Data(base64Encoded: string)
            guard let data = data else { return }

            let label = self.labelText.isEmpty ? "FullyNoded" : self.labelText
            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(label).\(isBlinded ? "blindedPsbt" : "psbt")")
            try? data.write(to: fileURL)
            self.present(UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true), animated: true)
        }
    }

    static func storyboardViewController<T: UIViewController>(_ identifier: String, as type: T.Type) -> T? {
        UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: identifier) as? T
    }

    func showAddressQR() {
        guard let vc = VerifyTransactionViewController.storyboardViewController("QRDisplayer", as: QRDisplayerViewController.self) else { return }
        vc.text = qrCodeStringToExport
        vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
        vc.headerText = "Address"
        vc.descriptionText = qrCodeStringToExport
        navigationController?.pushViewController(vc, animated: true)
    }

    func showExportQR() {
        guard let vc = VerifyTransactionViewController.storyboardViewController("QRDisplayer", as: QRDisplayerViewController.self) else { return }
        vc.isUR = isUR

        if qrCodeStringToExport != "" {
            vc.psbt = qrCodeStringToExport
            vc.headerIcon = UIImage(systemName: "square.and.arrow.up")

            if qrCodeStringToExport.hasPrefix("UR:BYTES") {
                vc.headerText = "Encrypted PSBT"
                vc.descriptionText = "Pass this psbt to your signer or to others to create a collaborative batch transaction."
            } else {
                if isUR {
                    vc.headerText = "PSBT UR QR"
                } else if isPlainText {
                    vc.headerText = "PSBT Plain Text"
                }
                vc.descriptionText = "This psbt still needs more signatures to be complete, you can share it with another signer."
            }
        } else if signedRawTx != "" {
            vc.txn = signedRawTx
            vc.headerIcon = UIImage(systemName: "square.and.arrow.up")
            vc.headerText = "Signed Transaction"
            vc.descriptionText = "You can save this signed transaction and broadcast it later or share it with someone else."
        }

        navigationController?.pushViewController(vc, animated: true)
    }

    func presentLabelMemo() {
        guard let vc = VerifyTransactionViewController.storyboardViewController("TransactionLabelMemo", as: TransactionLabelMemoViewController.self) else { return }
        vc.txid = txid
        vc.labelText = labelText

        vc.doneBlock = { [weak self] result in
            guard let self = self else { return }
            self.labelText = result

            DispatchQueue.main.async {
                self.verifyTable.reloadData()
                SuccessView.toast("Transaction updated", in: self)
            }
        }

        present(vc, animated: true)
    }

    func presentScanner() {
        if #available(macCatalyst 14.0, *) {
            guard let vc = VerifyTransactionViewController.storyboardViewController("QRScanner", as: QRScannerViewController.self) else { return }

            vc.fromSignAndVerify = true

            vc.onDoneBlock = { [weak self] tx in
                guard let self = self, let tx = tx else { return }

                self.reset()

                if Keys.validPsbt(tx) {
                    self.processPsbt(tx)
                } else if Keys.validTx(tx) {
                    self.signedRawTx = tx
                    self.load()
                } else if tx.uppercased().hasPrefix("UR:BYTES") {
                    guard let ur = URHelper.ur(tx) else {
                        showAlert(vc: self, title: "", message: "Unable to convert ur string to ur.")
                        return
                    }

                    guard let psbt = URHelper.bytesToData(ur) else { return }

                    self.processPsbt(psbt.base64EncodedString())

                } else if tx.uppercased().hasPrefix("UR:CRYPTO-PSBT") {
                    guard let ur = URHelper.ur(tx) else {
                        showAlert(vc: self, title: "", message: "Unable to convert ur string to ur.")
                        return
                    }

                    guard let psbt = URHelper.psbtUrToBase64Text(ur) else {
                        showAlert(vc: self, title: "", message: "Unable to convert ur to psbt.")
                        return
                    }

                    self.processPsbt(psbt)
                }
            }

            present(vc, animated: true)
        }
    }
}
