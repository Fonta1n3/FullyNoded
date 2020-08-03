//
//  QRScanner.swift
//  BitSense
//
//  Created by Peter on 15/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

class QRScanner: UIView, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let avCaptureSession = AVCaptureSession()
    var imageView = UIImageView()
    var stringToReturn = ""
    var completion = {}
    var didChooseImage = {}
    var keepRunning = Bool()
    var downSwipeAction = {}
    var vc = UIViewController()
    let imagePicker = UIImagePickerController()
    var qrString = ""
    let textField = UITextField()
    var textFieldPlaceholder = ""
    let uploadButton = UIButton()
    let torchButton = UIButton()
    let closeButton = UIButton()
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let downSwipe = UISwipeGestureRecognizer()
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        stopScanner()
        downSwipeAction()
    }
    
    func configureCloseButton() {
    
        closeButton.frame = CGRect(x: vc.view.frame.midX - 15,
                                   y: vc.view.frame.maxY - 150,
                                   width: 30,
                                   height: 30)
        
        closeButton.setImage(UIImage(named: "Image-10"), for: .normal)
        
    }
    
    func configureTorchButton() {
        
        torchButton.frame = CGRect(x: 35 / 2,
                                   y: 35 / 2,
                                   width: 35,
                                   height: 35)
        
        torchButton.setImage(UIImage(named: "strobe.png"), for: .normal)
        addShadow(view: torchButton)
    }
    
    func configureUploadButton() {
        
        uploadButton.frame = CGRect(x: 35 / 2,
                                    y: 35 / 2,
                                    width: 35,
                                    height: 35)
        
        uploadButton.showsTouchWhenHighlighted = true
        uploadButton.setImage(UIImage(named: "images.png"), for: .normal)
        addShadow(view: uploadButton)
        
    }
    
    func addShadow(view: UIView) {
        
        view.layer.shadowColor = UIColor.black.cgColor
        
        view.layer.shadowOffset = CGSize(width: 1.5,
                                         height: 1.5)
        
        view.layer.shadowRadius = 1.5
        view.layer.shadowOpacity = 0.5
        
    }
    
    func configureTextField() {
        
        let width = vc.view.frame.width - 20
        
        textField.frame = CGRect(x: 0,
                                 y: 0,
                                 width: width,
                                 height: 50)
        
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
    
    func configureImagePicker() {
        
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        
    }
    
    func configureDownSwipe() {
        
        downSwipe.direction = .down
        downSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        imageView.addGestureRecognizer(downSwipe)
        
    }
    
    func toggleTorch(on: Bool) {
        
        guard let device = AVCaptureDevice.default(for: AVMediaType.video)
            else {return}
        
        if device.hasTorch {
            
            do {
                
                try device.lockForConfiguration()
                
                if on == true {
                    
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
    
    func scanQRCode() {
            
        func scanQRNow() throws {
                
            guard let avCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {
                    
                print("no camera")
                throw error.noCameraAvailable
                    
            }
                
            guard let avCaptureInput = try? AVCaptureDeviceInput(device: avCaptureDevice) else {
                    
                print("failed to int camera")
                throw error.videoInputInitFail
                    
            }
                
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
            avCaptureVideoPreviewLayer.frame = self.imageView.bounds
            self.imageView.layer.addSublayer(avCaptureVideoPreviewLayer)
            self.avCaptureSession.startRunning()
                
        }
            
        enum error: Error {
                
            case noCameraAvailable
            case videoInputInitFail
                
        }
            
        do {
                
            try scanQRNow()
            print("scanQRNow")
                
        } catch {
                
            print("Failed to scan QR Code")
            
        }
        
        configureImagePicker()
        configureTextField()
        configureUploadButton()
        configureTorchButton()
        configureCloseButton()
        configureDownSwipe()
        
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count > 0 {
            
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                
                let stringURL = machineReadableCode.stringValue!
                self.stringToReturn = stringURL
                self.avCaptureSession.stopRunning()
                AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
                completion()
                
                if keepRunning {
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        
                        self.avCaptureSession.startRunning()
                        
                    }
                    
                }
                
            }
            
        }
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        picker.dismiss(animated: true, completion: nil)
        
    }
    
    func chooseQRCodeFromLibrary() {
        
        vc.present(imagePicker, animated: true, completion: nil)
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
// Local variable inserted by Swift 4.2 migrator.
let info = convertFromUIImagePickerControllerInfoKeyDictionary(info)

        
        if let pickedImage = info[convertFromUIImagePickerControllerInfoKey(UIImagePickerController.InfoKey.originalImage)] as? UIImage {
            
            let detector:CIDetector=CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
            let ciImage:CIImage = CIImage(image:pickedImage)!
            var qrCodeLink = ""
            let features = detector.features(in: ciImage)
            
            for feature in features as! [CIQRCodeFeature] {
                qrCodeLink += feature.messageString!
            }
            
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            
            picker.dismiss(animated: true, completion: {
                
                self.qrString = qrCodeLink
                self.didChooseImage()
                
            })
            
        }
        
    }
    
    func removeScanner() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.avCaptureSession.stopRunning()
            vc.textField.removeFromSuperview()
            vc.torchButton.removeFromSuperview()
            vc.uploadButton.removeFromSuperview()
            vc.imageView.removeFromSuperview()
        }
    }
    
    func stopScanner() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.avCaptureSession.stopRunning()
        }
    }
    
    func startScanner() {
        DispatchQueue.main.async { [unowned vc = self] in
            vc.avCaptureSession.startRunning()
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
