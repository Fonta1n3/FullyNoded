//
//  DescriptorDisplayerViewController.swift
//  BitSense
//
//  Created by Peter on 22/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import UIKit

class DescriptorDisplayerViewController: UIViewController {
    
    var tapQRGesture = UITapGestureRecognizer()
    var tapTextViewGesture = UITapGestureRecognizer()
    let displayer = RawDisplayer()
    let qrGenerator = QRGenerator()
    var descriptor = ""
    var label = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        configureDisplayer()
        showDescriptor()
        
    }
    
    func configureDisplayer() {
        
        displayer.vc = self
        //displayer.tabbar = self.tabBarController!.tabBar
        //displayer.navigationBar = self.navigationController!.navigationBar
        tapQRGesture = UITapGestureRecognizer(target: self,
                                              action: #selector(shareQRCode(_:)))
        
        displayer.qrView.addGestureRecognizer(tapQRGesture)
        
        tapTextViewGesture = UITapGestureRecognizer(target: self,
                                                    action: #selector(shareRawText(_:)))
        
        displayer.textView.addGestureRecognizer(tapTextViewGesture)
        displayer.textView.isSelectable = true
        
    }
    
    func showDescriptor() {
        
        var processedDesc = descriptor.replacingOccurrences(of: "'\"'\"", with: "")
        processedDesc = processedDesc.replacingOccurrences(of: "\"", with: "")
        displayer.rawString = processedDesc
        displayer.addRawDisplay()
        navigationItem.title = label
        
    }
    
    @objc func shareRawText(_ sender: UITapGestureRecognizer) {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.displayer.textView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.displayer.textView.alpha = 1
                    
                })
                
            }
            
            let textToShare = [self.displayer.rawString]
            
            let activityViewController = UIActivityViewController(activityItems: textToShare,
                                                                  applicationActivities: nil)
            
            activityViewController.popoverPresentationController?.sourceView = self.view
            self.present(activityViewController, animated: true) {}
            
        }
        
    }
    
    @objc func shareQRCode(_ sender: UITapGestureRecognizer) {
        print("shareQRCode")
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.2, animations: {
                
                self.displayer.qrView.alpha = 0
                
            }) { _ in
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.displayer.qrView.alpha = 1
                    
                })
                
            }
            
            self.qrGenerator.textInput = self.displayer.rawString
            let qrImage = self.qrGenerator.getQRCode()
            let objectsToShare = [qrImage]
            
            let activityController = UIActivityViewController(activityItems: objectsToShare,
                                                              applicationActivities: nil)
            
            activityController.popoverPresentationController?.sourceView = self.view
            self.present(activityController, animated: true) {}
            
        }
        
    }

}
