//
//  QRScannerViewController.swift
//  BitSense
//
//  Created by Peter on 16/07/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

import URKit
import AVFoundation
import UIKit

class QRScannerViewController: UIViewController {
    
    private let avCaptureSession = AVCaptureSession()
    private var stringToReturn = ""
    private let imagePicker = UIImagePickerController()
    private var qrString = ""
    private let textField = UITextField()
    private var textFieldPlaceholder = ""
    private let uploadButton = UIButton()
    private let torchButton = UIButton()
    private let closeButton = UIButton()
    private let downSwipe = UISwipeGestureRecognizer()
    var onImportDoneBlock : (([String:Any]?) -> Void)?
    var isAccountMap = Bool()
    var isQuickConnect = Bool()
    var isScanningAddress = Bool()
    var onQuickConnectDoneBlock : ((String?) -> Void)?
    var onAddressDoneBlock : ((String?) -> Void)?
    var isUrPsbt = Bool()
    var decoder:URDecoder!
    private let spinner = ConnectingView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private var blurArray = [UIVisualEffectView]()
    private var isTorchOn = Bool()
    
    @IBOutlet weak private var scannerView: UIImageView!
    @IBOutlet weak private var progressDescriptionLabel: UILabel!
    @IBOutlet weak private var progressView: UIProgressView!
    @IBOutlet weak var backgroundView: UIVisualEffectView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 8
        backgroundView.alpha = 0
        progressDescriptionLabel.alpha = 0
        progressView.alpha = 0
        configureScanner()
        spinner.addConnectingView(vc: self, description: "")
        decoder = URDecoder()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        scanNow()
    }
    
    private func scanNow() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.scanQRCode()
            self.addScannerButtons()
            self.scannerView.addSubview(self.closeButton)
            self.spinner.removeConnectingView()
        }
    }
    
    private func configureScanner() {
        scannerView.isUserInteractionEnabled = true
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        textField.alpha = 0
        uploadButton.addTarget(self, action: #selector(chooseQRCodeFromLibrary), for: .touchUpInside)
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
        configureImagePicker()
        
        #if targetEnvironment(macCatalyst)
            chooseQRCodeFromLibrary()
        #else
            configureTextField()
            configureUploadButton()
            configureTorchButton()
            configureCloseButton()
            configureDownSwipe()
        #endif
    }
    
    private func addScannerButtons() {
        addBlurView(frame: CGRect(x: scannerView.frame.maxX - 80, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: uploadButton)
        addBlurView(frame: CGRect(x: 10, y: scannerView.frame.maxY - 80, width: 70, height: 70), button: torchButton)
    }
    
    private func didPickImage() {
        process(text: qrString)
    }
    
    @objc func chooseQRCodeFromLibrary() {
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func toggleTorchNow() {
        if isTorchOn {
            toggleTorch(on: false)
            isTorchOn = false
        } else {
            toggleTorch(on: true)
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
        blurArray.append(blur)
        scannerView.addSubview(blur)
    }
    
    @objc func back() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.avCaptureSession.stopRunning()
            vc.dismiss(animated: true, completion: nil)
        }
    }
    
    private func stopScanning(_ psbt: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            
            self.dismiss(animated: true) {
                self.onAddressDoneBlock!(psbt)
            }
        }
    }
    
    private func processUrPsbt(text: String) {
        // Stop if we're already done with the decode.
        guard decoder.result == nil else {
            guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
            stopScanning(psbt)
            return
        }

        decoder.receivePart(text.lowercased())
        
        let expectedParts = decoder.expectedPartCount ?? 0
        
        guard expectedParts != 0 else {
            guard let result = try? decoder.result?.get(), let psbt = URHelper.psbtUrToBase64Text(result) else { return }
            stopScanning(psbt)
            return
        }
        
        let percentageCompletion = "\(Int(decoder.estimatedPercentComplete * 100))% complete"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.blurArray.count > 0 {
                for i in self.blurArray {
                    i.removeFromSuperview()
                }
                self.blurArray.removeAll()
            }
            
            self.progressView.setProgress(Float(self.decoder.estimatedPercentComplete), animated: false)
            self.progressDescriptionLabel.text = percentageCompletion
            self.backgroundView.alpha = 1
            self.progressView.alpha = 1
            self.progressDescriptionLabel.alpha = 1
        }
    }
    
    private func process(text: String) {
        //spinner.addConnectingView(vc: self, description: "processing...")
        
        if isUrPsbt {
            processUrPsbt(text: text)
            
        } else if isAccountMap {
            if let data = text.data(using: .utf8) {
                do {
                    let accountMap = try JSONSerialization.jsonObject(with: data, options: []) as! [String:Any]
                    spinner.removeConnectingView()
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        
                        self.dismiss(animated: true) {
                            self.stopScanner()
                            self.avCaptureSession.stopRunning()
                            self.onImportDoneBlock!(accountMap)
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
                    vc.stopScanner()
                    vc.avCaptureSession.stopRunning()
                    vc.onQuickConnectDoneBlock!(text)
                }
            }
        } else if isScanningAddress {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.stopScanner()
                    vc.avCaptureSession.stopRunning()
                    vc.onAddressDoneBlock!(text)
                }
            }
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.stopScanner()
                    vc.avCaptureSession.stopRunning()
                    vc.onAddressDoneBlock!(text)
                }
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
    }
    
    private func configureCloseButton() {
        closeButton.frame = CGRect(x: view.frame.midX - 15, y: view.frame.maxY - 150, width: 30, height: 30)
        closeButton.showsTouchWhenHighlighted = true
        closeButton.setImage(UIImage(named: "Image-10"), for: .normal)
    }
    
    private func configureTorchButton() {
        torchButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        torchButton.setImage(UIImage(named: "strobe.png"), for: .normal)
        torchButton.showsTouchWhenHighlighted = true
        addShadow(view: torchButton)
    }
    
    private func configureUploadButton() {
        uploadButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        uploadButton.showsTouchWhenHighlighted = true
        uploadButton.setImage(UIImage(named: "images.png"), for: .normal)
        addShadow(view: uploadButton)
    }
    
    private func addShadow(view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
    }
    
    private func configureTextField() {
        let width = view.frame.width - 20
        textField.frame = CGRect(x: 0, y: 0, width: width, height: 50)
        textField.layer.cornerRadius = 12
        textField.textAlignment = .center
        textField.clipsToBounds = true
        addShadow(view: textField)
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.textColor = UIColor.white
        textField.keyboardAppearance = UIKeyboardAppearance.dark
        textField.backgroundColor = UIColor.clear
        textField.returnKeyType = UIReturnKeyType.go
        textField.attributedPlaceholder = NSAttributedString(string: textFieldPlaceholder,
                                                             attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightText])
    }
    
    private func configureImagePicker() {
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
    }
    
    private func configureDownSwipe() {
        downSwipe.direction = .down
        downSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        scannerView.addGestureRecognizer(downSwipe)
    }
    
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        if device.hasTorch {
            do {
                try device.lockForConfiguration()
                
                if on {
                    device.torchMode = .on
                } else {
                    device.torchMode = .off
                }
                
                device.unlockForConfiguration()
            } catch {
                print("Torch could not be used")
            }
            
        } else {
            print("Torch is not available")
        }
    }
    
    private func scanQRCode() {
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        
        if let inputs = self.avCaptureSession.inputs as? [AVCaptureDeviceInput] {
            for input in inputs {
                self.avCaptureSession.removeInput(input)
            }
        }
        
        if let outputs = self.avCaptureSession.outputs as? [AVCaptureMetadataOutput] {
            for output in outputs {
                self.avCaptureSession.removeOutput(output)
            }
        }
        
        self.avCaptureSession.addInput(avCaptureInput)
        self.avCaptureSession.addOutput(avCaptureMetadataOutput)
        avCaptureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        let avCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: avCaptureSession)
        avCaptureVideoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        avCaptureVideoPreviewLayer.frame = self.scannerView.bounds
        self.scannerView.layer.addSublayer(avCaptureVideoPreviewLayer)
        self.avCaptureSession.startRunning()
    }
    
    private func removeScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
            self.textField.removeFromSuperview()
            self.torchButton.removeFromSuperview()
            self.uploadButton.removeFromSuperview()
            //self.scannerView.removeFromSuperview()
        }
    }
    
    private func stopScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
        }
    }
    
    private func startScanner() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.startRunning()
        }
    }
    
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKeyDictionary(_ input: [UIImagePickerController.InfoKey: Any]) -> [String: Any] {
    return Dictionary(uniqueKeysWithValues: input.map {key, value in (key.rawValue, value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromUIImagePickerControllerInfoKey(_ input: UIImagePickerController.InfoKey) -> String {
    return input.rawValue
}

extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        guard metadataObjects.count > 0, let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject, machineReadableCode.type == AVMetadataObject.ObjectType.qr, let stringURL = machineReadableCode.stringValue else {
            
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.stopRunning()
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            AudioServicesPlaySystemSound(1103)
        }
        
        process(text: stringURL)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            self.avCaptureSession.startRunning()
        }
    }
    
}

extension QRScannerViewController: UIImagePickerControllerDelegate {
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // Local variable inserted by Swift 4.2 migrator.
        let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)
        
        guard let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage,
            let detector:CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh]),
            let ciImage:CIImage = CIImage(image:pickedImage),
            let features = detector.features(in: ciImage) as? [CIQRCodeFeature] else {
            
            return
        }
        
        var qrCodeLink = ""
        
        for feature in features {
            qrCodeLink += feature.messageString!
        }
        
        DispatchQueue.main.async {
            let impact = UIImpactFeedbackGenerator()
            impact.impactOccurred()
            AudioServicesPlaySystemSound(1103)
        }
        
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let self = self else { return }
            
            self.process(text: qrCodeLink)
        })
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            DispatchQueue.main.async { [weak self] in
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

extension QRScannerViewController: UINavigationControllerDelegate {}
