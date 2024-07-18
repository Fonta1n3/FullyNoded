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
import Bbqr

@available(macCatalyst 14.0, *)
class QRScannerViewController: UIViewController {
    
    var isImporting = false
    private var hasScanned = false
    private let avCaptureSession = AVCaptureSession()
    private var stringToReturn = ""
    private let imagePicker = UIImagePickerController()
    private var qrString = ""
    private let uploadButton = UIButton()
    private let torchButton = UIButton()
    private let closeButton = UIButton()
    private let downSwipe = UISwipeGestureRecognizer()
    var isQuickConnect = Bool()
    var isScanningAddress = Bool()
    var onDoneBlock : ((String?) -> Void)?
    var fromSignAndVerify = Bool()
    var decoder:URDecoder!
    var bbqrParts: [String] = []
    private let spinner = ConnectingView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    private var blurArray = [UIVisualEffectView]()
    private var isTorchOn = Bool()
    private var psbtParts = [[String:String]]()
    
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
    
    @IBAction func closeAction(_ sender: Any) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.removeScanner()
            self.dismiss(animated: true, completion: nil)
        }
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
        torchButton.addTarget(self, action: #selector(toggleTorchNow), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        isTorchOn = false
        configureImagePicker()
        configureUploadButton()
        configureTorchButton()
        configureCloseButton()
        configureDownSwipe()
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
                self.onDoneBlock!(psbt)
            }
        }
    }
    
    private func processUrQr(text: String) {
        guard decoder.result == nil else {
            guard let result = try? decoder.result?.get() else { return }
            
            hasScanned = true
            stopScanning(result.string)
            return
        }

        decoder.receivePart(text.lowercased())
        
        let expectedParts = decoder.expectedFragmentCount ?? 0
        
        guard expectedParts != 0 else {
            guard let result = try? decoder.result?.get() else { return }
            hasScanned = true
            stopScanning(result.string)
            return
        }
        
        let percentageCompletion = "\(Int(decoder.estimatedPercentComplete * 100))% complete"
        updateProgress(percentageCompletion, self.decoder.estimatedPercentComplete)
        hasScanned = false
    }
    
    private func updateProgress(_ progressText: String, _ progressDoub: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if self.blurArray.count > 0 {
                for i in self.blurArray {
                    i.removeFromSuperview()
                }
                self.blurArray.removeAll()
            }
            
            self.progressView.setProgress(Float(progressDoub), animated: false)
            self.progressDescriptionLabel.text = progressText
            self.backgroundView.alpha = 1
            self.progressView.alpha = 1
            self.progressDescriptionLabel.alpha = 1
        }
    }
    
    private func uniq<S : Sequence, T : Hashable>(source: S) -> [T] where S.Iterator.Element == T {
        var buffer = [T]()
        var added = Set<T>()
        for elem in source {
            if !added.contains(elem) {
                buffer.append(elem)
                added.insert(elem)
            }
        }
        return buffer
    }
    
    private func parseSpecterAnimatedQr(_ part: String) {
        var partArray = [String]()
        let arr = part.split(separator: " ")
        
        if arr.count > 0 {
            var prefix =  "\(arr[0])"
            let part = "\(arr[1])"
            
            prefix = prefix.replacingOccurrences(of: "p", with: "")
            prefix = prefix.replacingOccurrences(of: "of", with: "*")
            
            let arr1 = prefix.split(separator: "*")
            
            if arr1.count > 0 {
                if let index = Int(arr1[0]), let count = Int(arr1[1]) {
                    
                    var alreadyAdded = false
                    for (i, item) in psbtParts.enumerated() {
                        if let existingIndex = item["index"] {
                            if existingIndex == "\(index)" {
                                alreadyAdded = true
                            }
                        }
                        
                        if i + 1 == psbtParts.count {
                            if !alreadyAdded {
                                let number = Double(psbtParts.count) / Double(count)
                                let percentageComplete = "\(Int(number * 100))% complete"
                                if number < 1.1 {
                                    self.updateProgress(percentageComplete, number)
                                }
                            }
                        }
                    }
                    
                    if !alreadyAdded {
                        psbtParts.append(["part":part, "index":"\(index)"])
                        
                        if psbtParts.count >= count {
                            psbtParts.sort(by: {($0["index"]!) < $1["index"]!})
                            
                            for (i, item) in psbtParts.enumerated() {
                                guard let part = item["part"] else { return }
                                
                                partArray.append(part)
                                
                                if i + 1 == psbtParts.count {
                                    let unique = uniq(source: partArray)
                                    let psbtString = unique.joined()
                                                                    
                                    if Keys.validPsbt(psbtString) {
                                        hasScanned = true
                                        stopScanning(psbtString)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func continousJoiner(parts: [String]) throws -> ((psbt: String?, descriptor: String?)) {
        let continousJoiner = ContinuousJoiner()
        
        for part in parts {
            switch try continousJoiner.addPart(part: part) {
            case .notStarted:
                #if DEBUG
                print("not started")
                #endif
                
            case .inProgress(let partsLeft):
                #if DEBUG
                print("added item, \(partsLeft) parts left")
                #endif
                hasScanned = false
                
            case .complete(let joined):
                hasScanned = true
                let s = String(decoding: joined.data(), as: UTF8.self)
                if s.hasPrefix("psbt") {
                    stopScanning(joined.data().base64EncodedString())
                } else {
                    stopScanning(s)
                }
            }
        }

        return ((nil, nil))
    }
    
    private func processBBQr(text: String) {
        let numberOfQrsBase36 = "\(text[4..<6])"
        //let qrNumberBase36 = "\(text[6..<8])"
        let numberOfQrs = strtoul(numberOfQrsBase36, nil, 36)
        //let qrNumber = strtoul(qrNumberBase36, nil, 36)
        
        if !bbqrParts.contains(text) {
            bbqrParts.append(text)
            
            DispatchQueue.main.async {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            }
            
            let number = Double(bbqrParts.count) / Double(numberOfQrs)
            let percentageComplete = "\(Int(number * 100))% complete"
            updateProgress(percentageComplete, number)
        }
        
        guard let result = try? continousJoiner(parts: bbqrParts) else { return }
        
        #if DEBUG
        print("BBQr result: \(result)")
        #endif
    }
    
    private func process(text: String) {
        let lowercased = text.lowercased()
        
        #if DEBUG
        print("text: \(text)")
        #endif
        
        if text.hasPrefix("B$") {
            processBBQr(text: text)
            
        } else if fromSignAndVerify {
            if lowercased.hasPrefix("ur:crypto-psbt") || lowercased.hasPrefix("ur:bytes") {
                processUrQr(text: text)
                
            } else if Keys.validTx(text) {
                // its a raw transaction
                hasScanned = true
                stopScanning(text)
            } else if Keys.validPsbt(text) {
                // its a plain text base64 psbt
                hasScanned = true
                stopScanning(text)
            } else if text.hasPrefix("p") {
                // could be a specter animated psbt
                parseSpecterAnimatedQr(text)
            } else {
                spinner.removeConnectingView()
                showAlert(vc: self, 
                          title: "Unrecognized format",
                          message: "That is an unrecognized transaction format, please reach out to us so we can add compatibility.")
            }
            
        } else if isImporting {
            if lowercased.hasPrefix("ur:") {
                processUrQr(text: lowercased)
            } else {
                DispatchQueue.main.async { [unowned vc = self] in
                    vc.dismiss(animated: true) {
                        vc.stopScanner()
                        vc.onDoneBlock!(text)
                    }
                }
            }
                        
        } else {
            DispatchQueue.main.async { [unowned vc = self] in
                vc.dismiss(animated: true) {
                    vc.stopScanner()
                    vc.onDoneBlock!(text)
                }
            }
        }
    }
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
    }
    
    private func configureCloseButton() {
        closeButton.frame = CGRect(x: view.frame.midX - 15, y: view.frame.maxY - 150, width: 30, height: 30)
        closeButton.setImage(UIImage(named: "Image-10"), for: .normal)
    }
    
    private func configureTorchButton() {
        torchButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        torchButton.setImage(UIImage(named: "strobe.png"), for: .normal)
        addShadow(view: torchButton)
    }
    
    private func configureUploadButton() {
        uploadButton.frame = CGRect(x: 17.5, y: 17.5, width: 35, height: 35)
        uploadButton.setImage(UIImage(named: "images.png"), for: .normal)
        addShadow(view: uploadButton)
    }
    
    private func addShadow(view: UIView) {
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 1.5, height: 1.5)
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
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
        let queue = DispatchQueue(label: "codes", qos: .userInteractive)
        
        guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else { return }
        
        guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else { return }
        
        let avCaptureMetadataOutput = AVCaptureMetadataOutput()
        avCaptureMetadataOutput.setMetadataObjectsDelegate(self, queue: queue)
        
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
        self.startScanner()
    }
    
    private func removeScanner() {
        stopScanner()
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.torchButton.removeFromSuperview()
            self.uploadButton.removeFromSuperview()
        }
    }
    
    private func stopScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.stopRunning()
        })
    }
    
    private func startScanner() {
        DispatchQueue.background(delay: 0.0, completion:  { [weak self] in
            guard let self = self else { return }
            self.avCaptureSession.startRunning()
        })
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

@available(macCatalyst 14.0, *)
extension QRScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !hasScanned {
            guard metadataObjects.count > 0, let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject, machineReadableCode.type == AVMetadataObject.ObjectType.qr, let stringURL = machineReadableCode.stringValue else {
                
                return
            }
            
            hasScanned = true
                        
            process(text: stringURL)
        }
    }
}

@available(macCatalyst 14.0, *)
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

extension DispatchQueue {

    static func background(delay: Double = 0.0, background: (()->Void)? = nil, completion: (() -> Void)? = nil) {
        DispatchQueue.global(qos: .background).async {
            background?()
            if let completion = completion {
                    completion()
            }
        }
    }
}

extension String {

    var length: Int {
        return count
    }

    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }

    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

@available(macCatalyst 14.0, *)
extension QRScannerViewController: UINavigationControllerDelegate {}
