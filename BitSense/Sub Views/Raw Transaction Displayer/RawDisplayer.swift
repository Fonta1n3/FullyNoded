//
//  RawDisplayer.swift
//  BitSense
//
//  Created by Peter on 25/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class RawDisplayer {
    
    let textView = UITextView()
    let qrView = UIImageView()
    let qrGenerator = QRGenerator()
    let backgroundView = UIView()
    let copiedLabel = UILabel()
    var navigationBar = UINavigationBar()
    var tabbar = UITabBar()
    var vc = UIViewController()
    var rawString = ""
    
    func addRawDisplay() {
        
        tabbar = vc.tabBarController!.tabBar
        navigationBar = vc.navigationController!.navigationBar
        configureBackground()
        configureQrView()
        configureTextView()
        configureCopiedLabel()
        
        qrView.image = generateQrCode(key: rawString)
        textView.text = rawString
        UIPasteboard.general.string = rawString
        
        backgroundView.addSubview(qrView)
        backgroundView.addSubview(textView)
        vc.view.addSubview(backgroundView)
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.backgroundView.alpha = 1
            
        }) { _ in
            
            UIView.animate(withDuration: 0.4, animations: {
                
                self.qrView.frame = CGRect(x: 10,
                                           y: self.navigationBar.frame.maxY + 20,
                                           width: self.vc.view.frame.width - 20,
                                           height:self.vc.view.frame.width - 20)
                
            }, completion: { _ in
                
                impact()
                
                UIView.animate(withDuration: 0.4, animations: {
                    
                    let qrHeight = self.vc.view.frame.width - 20
                    let totalViewHeight = self.vc.view.frame.height

                    
                    self.textView.frame = CGRect(x: 10,
                                                 y: self.qrView.frame.maxY,
                                                 width: self.vc.view.frame.width - 20,
                                                 height: totalViewHeight - qrHeight)
                    
                }, completion: { _ in
                    
                    impact()
                    
                    DispatchQueue.main.async {
                        
                        self.addCopiedLabel()
                        
                    }
                    
                })
                
            })
            
        }
        
    }
    
    func addCopiedLabel() {
        
        vc.view.addSubview(copiedLabel)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            
            UIView.animate(withDuration: 0.3, animations: {
                
                self.copiedLabel.frame = CGRect(x: 0,
                                                y: self.tabbar.frame.minY - 50,
                                                width: self.vc.view.frame.width,
                                                height: 50)
                
            })
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.copiedLabel.frame = CGRect(x: 0,
                                                    y: self.vc.view.frame.maxY + 100,
                                                    width: self.vc.view.frame.width,
                                                    height: 50)
                    
                }, completion: { _ in
                    
                    self.copiedLabel.removeFromSuperview()
                    
                })
                
            })
            
        }
        
    }
    
    func configureCopiedLabel() {
        
        copiedLabel.text = "copied to clipboard ✓"
        
        copiedLabel.frame = CGRect(x: 0,
                                   y: vc.view.frame.maxY + 100,
                                   width: vc.view.frame.width,
                                   height: 50)
        
        copiedLabel.textColor = UIColor.darkGray
        copiedLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 17)
        copiedLabel.backgroundColor = UIColor.black
        copiedLabel.textAlignment = .center
        
    }
    
    func configureQrView() {
        
        qrView.isUserInteractionEnabled = true
        
        qrView.frame = CGRect(x: 10,
                              y: (vc.view.frame.width - 20) * -1,
                              width: vc.view.frame.width - 20,
                              height: vc.view.frame.width - 20)
        
    }
    
    func configureTextView() {
        
        textView.textColor = UIColor.green
        textView.backgroundColor = UIColor.clear
        textView.textAlignment = .natural
        textView.font = UIFont.init(name: "HelveticaNeue-Light", size: 14)
        if #available(iOS 10.0, *) {
            textView.adjustsFontForContentSizeCategory = true
        } else {
            // Fallback on earlier versions
        }
        textView.isUserInteractionEnabled = true
        textView.isEditable = false
        
        let qrHeight = vc.view.frame.width - 20
        let totalViewHeight = vc.view.frame.height
        
        textView.frame = CGRect(x: 10,
                                y: vc.view.frame.maxY + 170,
                                width: vc.view.frame.width - 20,
                                height: totalViewHeight - qrHeight/*200*/)
        
    }
    
    func configureBackground() {
        
        backgroundView.alpha = 0
        backgroundView.backgroundColor = UIColor.clear
        backgroundView.frame = vc.view.frame
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        self.qrGenerator.textInput = key
        let imageToReturn = self.qrGenerator.getQRCode()
        return imageToReturn
        
    }
    
}
