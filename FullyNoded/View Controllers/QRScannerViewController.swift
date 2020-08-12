//
//  QRScannerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import UIKit

class QRScannerViewController: UIViewController {
    
    var onImportDoneBlock : (([String:Any]?) -> Void)?
    var isAccountMap = Bool()
    var isQuickConnect = Bool()
    var isScanningAddress = Bool()
    var onQuickConnectDoneBlock : ((String?) -> Void)?
    var onAddressDoneBlock : ((String?) -> Void)?
    let spinner = ConnectingView()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let qrImageView = UIImageView()
    var stringURL = String()
    var blurArray = [UIVisualEffectView]()
    let qrScanner = QRScanner()
    var isTorchOn = Bool()
    @IBOutlet weak var scannerView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureScanner()
        spinner.addConnectingView(vc: self, description: "")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanNow()
    }
    
    private func scanNow() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.qrScanner.scanQRCode()
            vc.addScannerButtons()
            vc.scannerView.addSubview(vc.qrScanner.closeButton)
            vc.spinner.removeConnectingView()
        }
    }
    
    private func configureScanner() {
        scannerView.isUserInteractionEnabled = true
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        qrScanner.keepRunning = false
        qrScanner.vc = self
        qrScanner.imageView = scannerView
        qrScanner.textField.alpha = 0
        qrScanner.completion = { self.getQRCode() }
        qrScanner.didChooseImage = { self.didPickImage() }
        qrScanner.uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        qrScanner.torchButton.addTarget(self, action: #selector(toggleTorch), for: .touchUpInside)
        qrScanner.closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
    }
    
    func addScannerButtons() {
        addBlurView(frame: CGRect(x: scannerView.frame.maxX - 80, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: qrScanner.uploadButton)
        addBlurView(frame: CGRect(x: 10, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: qrScanner.torchButton)
    }
    
    func didPickImage() {
        let qrString = qrScanner.qrString
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        qrScanner.chooseQRCodeFromLibrary()
    }
    
    func getQRCode() {
        let stringURL = qrScanner.stringToReturn
        process(text: stringURL)
    }
    
    @objc func toggleTorch() {
        if isTorchOn {
            qrScanner.toggleTorch(on: false)
            isTorchOn = false
        } else {
            qrScanner.toggleTorch(on: true)
            isTorchOn = true
        }
    }
    
    private func addBlurView(frame: CGRect, button: UIButton) {
        button.removeFromSuperview()
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
        blur.frame = frame
        blur.clipsToBounds = true
        blur.layer.cornerRadius = frame.width / 2
        blur.contentView.addSubview(button)
        scannerView.addSubview(blur)
    }
    
    @objc func back() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.qrScanner.avCaptureSession.stopRunning()
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    private func process(text: String) {
        spinner.addConnectingView(vc: self, description: "processing...")
        if isAccountMap {
            if let data = text.data(using: .utf8) {
                do {
                    let accountMap = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                    spinner.removeConnectingView()
                    DispatchQueue.main.async { [unowned vc = self] in
                        vc.dismiss(animated: true) {
                            vc.qrScanner.stopScanner()
                            vc.qrScanner.avCaptureSession.stopRunning()
                            vc.onImportDoneBlock!(accountMap)
                        }
                    }
                } catch {
                    spinner.removeConnectingView()
                    showAlert(vc: self, title: "Errore", message: "That is not a valid account map")
                }
            }
        } else if isQuickConnect {
            spinner.removeConnectingView()
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.qrScanner.stopScanner()
                    vc.qrScanner.avCaptureSession.stopRunning()
                    vc.onQuickConnectDoneBlock!(text)
                }
            }
        } else if isScanningAddress {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.qrScanner.stopScanner()
                    vc.qrScanner.avCaptureSession.stopRunning()
                    vc.onAddressDoneBlock!(text)
                }
            }
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.qrScanner.stopScanner()
                    vc.qrScanner.avCaptureSession.stopRunning()
                    vc.onAddressDoneBlock!(text)
                }
            }
        }
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
