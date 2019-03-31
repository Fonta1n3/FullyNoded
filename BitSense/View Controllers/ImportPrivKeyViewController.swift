//
//  ImportPrivKeyViewController.swift
//  BitSense
//
//  Created by Peter on 23/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit
import AVFoundation
import SwiftKeychainWrapper
import AES256CBC

class ImportPrivKeyViewController: UIViewController, UITextFieldDelegate, AVCaptureMetadataOutputObjectsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    var makeRPCCall:MakeRPCCall!
    var ssh:SSHService!
    var isUsingSSH = Bool()
    let textInput = UITextField()
    let avCaptureSession = AVCaptureSession()
    let imagePicker = UIImagePickerController()
    let uploadButton = UIButton()
    var isPruned = Bool()
    var rescan = String()
    @IBOutlet var qrView: UIImageView!
    
    @IBAction func backAction(_ sender: Any) {
        
        DispatchQueue.main.async {
            
            self.dismiss(animated: true, completion: nil)
            
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .photoLibrary
        textInput.delegate = self
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard (_:)))
        tapGesture.numberOfTapsRequired = 1
        self.view.addGestureRecognizer(tapGesture)
        
        textInput.frame = CGRect(x: view.frame.minX + 25, y: self.qrView.frame.minY - 55, width: view.frame.width - 50, height: 50)
        textInput.textAlignment = .center
        textInput.borderStyle = .roundedRect
        textInput.autocorrectionType = .no
        textInput.autocapitalizationType = .none
        textInput.keyboardAppearance = UIKeyboardAppearance.dark
        textInput.backgroundColor = UIColor.groupTableViewBackground
        textInput.returnKeyType = UIReturnKeyType.go
        textInput.placeholder = "Private Key"
        
        uploadButton.showsTouchWhenHighlighted = true
        uploadButton.setTitle("From Photos", for: .normal)
        uploadButton.setTitleColor(UIColor.white, for: .normal)
        uploadButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        uploadButton.addTarget(self, action: #selector(self.chooseQRCodeFromLibrary), for: .touchUpInside)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        scanQRCode()
        textInput.removeFromSuperview()
        view.addSubview(textInput)
        uploadButton.removeFromSuperview()
        view.addSubview(uploadButton)
    }
    
    func scanQRCode() {
        
        do {
            
            try scanQRNow()
            print("scanQRNow")
            
        } catch {
            
            print("Failed to scan QR Code")
        }
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn")
        
        if textInput.text != "" {
            
            DispatchQueue.main.async {
                
                let pk = self.textInput.text!
                self.importPrivateKey(ssh: self.ssh, pk: pk)
                
            }
            
        }
        
        return true
    }
    
    @objc func dismissKeyboard (_ sender: UITapGestureRecognizer) {
        
        textInput.resignFirstResponder()
        
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        
        dismiss(animated: true, completion: nil)
        
    }
    
    @objc func chooseQRCodeFromLibrary() {
        
        present(imagePicker, animated: true, completion: nil)
        
    }
    
    enum error: Error {
        
        case noCameraAvailable
        case videoInputInitFail
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            
            let detector:CIDetector=CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy:CIDetectorAccuracyHigh])!
            let ciImage:CIImage = CIImage(image:pickedImage)!
            var qrCodeLink = ""
            let features = detector.features(in: ciImage)
            
            for feature in features as! [CIQRCodeFeature] {
                qrCodeLink += feature.messageString!
            }
            
            print(qrCodeLink)
            
            if qrCodeLink != "" {
                
                DispatchQueue.main.async {
                    
                    self.importPrivateKey(ssh: self.ssh, pk: qrCodeLink)
                    
                }
                
            }
            
        }
        
        dismiss(animated: true, completion: nil)
        
    }
    
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
        avCaptureVideoPreviewLayer.frame = self.qrView.bounds
        self.qrView.layer.addSublayer(avCaptureVideoPreviewLayer)
        self.avCaptureSession.startRunning()
        
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        if metadataObjects.count > 0 {
            print("metadataOutput")
            
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                
                let stringURL = machineReadableCode.stringValue!
                self.importPrivateKey(ssh: self.ssh, pk: stringURL)
                self.avCaptureSession.stopRunning()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    
                    self.avCaptureSession.startRunning()
                    
                }
                
            }
            
        }
        
    }
    
    func executeNodeCommand(method: BTC_CLI_COMMAND, param: Any) {
        print("executeNodeCommand")
        
        func getResult() {
            
            if !makeRPCCall.errorBool {
                
                switch method {
                    
                case BTC_CLI_COMMAND.importprivkey:
                    
                    DispatchQueue.main.async {
                        
                        displayAlert(viewController: self, title: "Success", message: "Private key imported, your node will need to rescan the blockchain which can take some time before the balance will show up.")
                        
                    }
                    
                default:
                    
                    break
                    
                }
                
            } else {
                
                displayAlert(viewController: self, title: "Error", message: makeRPCCall.errorDescription)
                
            }
            
        }
        
        makeRPCCall.executeRPCCommand(method: method, param: param, completion: getResult)
        
    }
    
    func importPrivateKey(ssh: SSHService, pk: String) {
        print("importPrivateKey")
        
        if isUsingSSH {
            
            let queue = DispatchQueue(label: "com.FullyNoded.getInitialNodeConnection")
            queue.async {
                
                ssh.executeStringResponse(command: BTC_CLI_COMMAND.importprivkey, params: "\"\(pk)\"", response: { (result, error) in
                    
                    if error != nil {
                        
                        print("error importPrivateKey = \(String(describing: error))")
                        
                    } else {
                        
                        DispatchQueue.main.async {
                                
                            displayAlert(viewController: self, title: "Success", message: "Private key imported, your node will need to rescan the blockchain which can take some time before the balance will show up.")
                                
                        }
                        
                    }
                    
                })
                
            }
            
        } else {
            
            self.executeNodeCommand(method: BTC_CLI_COMMAND.importprivkey, param: "\"\(pk)\"")
            
        }
        
    }

}
