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
    
    var vc = UIViewController()
    var rawString = ""
    var titleString = "Signed Raw Transaction"
    
    let decodeButton = UIButton()
    let closeButton = UIButton()
    let closeImageView = UIImageView()
    
    let titleLabel = UILabel()
    let bottomLabel = UILabel()
    
    let impact = UIImpactFeedbackGenerator()
    
    func addRawDisplay() {
        
        configureBackground()
        configureCloseButton()
        configureDecodeButton()
        configureQrView()
        configureTextView()
        
        
        qrView.image = generateQrCode(key: rawString)
        textView.text = rawString
        UIPasteboard.general.string = rawString
        
        backgroundView.addSubview(decodeButton)
        backgroundView.addSubview(qrView)
        backgroundView.addSubview(textView)
        vc.view.addSubview(backgroundView)
        
        UIView.animate(withDuration: 0.2, animations: {
            
            self.backgroundView.alpha = 1
            
        }) { _ in
            
            UIView.animate(withDuration: 0.4, animations: {
                
                self.qrView.frame = CGRect(x: 10,
                                      y: 80,
                                      width: self.vc.view.frame.width - 20,
                                      height:self.vc.view.frame.width - 20)
                
            }, completion: { _ in
                
                self.configureTitleLabel()
                self.configureBottomLabel()
                
                self.impact.impactOccurred()
                
                UIView.animate(withDuration: 0.4, animations: {
                    
                    self.titleLabel.alpha = 1
                    self.bottomLabel.alpha = 1
                    
                    self.textView.frame = CGRect(x: 10,
                                                 y: self.qrView.frame.maxY,
                                                 width: self.vc.view.frame.width - 20,
                                                 height: (self.vc.view.frame.height - 140) - (self.vc.view.frame.width - 20))
                    
                }, completion: { _ in
                    
                    self.impact.impactOccurred()
                    
                })
                
            })
            
        }
        
    }
    
    func configureBottomLabel() {
        
        bottomLabel.alpha = 0
        
        bottomLabel.frame = CGRect(x: 0,
                                  y: backgroundView.frame.maxY - 15,
                                  width: backgroundView.frame.width,
                                  height: 15)
        
        bottomLabel.textAlignment = .center
        bottomLabel.textColor = UIColor.white
        
        bottomLabel.font = UIFont.init(name: "HiraginoSans-W3",
                                      size: 10)
        
        bottomLabel.text = "Tap to save/copy"
        backgroundView.addSubview(bottomLabel)
        
    }
    
    func configureTitleLabel() {
        
        titleLabel.alpha = 0
        
        titleLabel.frame = CGRect(x: 0,
                                  y: 45,
                                  width: backgroundView.frame.width,
                                  height: 20)
        
        titleLabel.textAlignment = .center
        titleLabel.textColor = UIColor.white
        
        titleLabel.font = UIFont.init(name: "HiraginoSans-W3",
                                      size: 15)
        
        titleLabel.text = titleString
        backgroundView.addSubview(titleLabel)
        
    }
    
    func configureCloseButton() {
        
        closeButton.frame = CGRect(x: 0,
                                   y: 0,
                                   width: 100,
                                   height: 80)
        
        closeButton.backgroundColor = UIColor.clear
        
        closeImageView.image = UIImage(named: "back.png")
        
        closeImageView.frame = CGRect(x: 10,
                                      y: 40,
                                      width: 30,
                                      height: 30)
        
        backgroundView.addSubview(closeImageView)
        backgroundView.addSubview(closeButton)
        
    }
    
    func configureDecodeButton() {
        
        decodeButton.setTitle("Decode", for: .normal)
        decodeButton.setTitleColor(UIColor.white, for: .normal)
        decodeButton.showsTouchWhenHighlighted = true
        decodeButton.titleLabel?.font = UIFont.init(name: "HelveticaNeue-Bold", size: 20)
        decodeButton.titleLabel?.textAlignment = .right
        
        decodeButton.frame = CGRect(x: vc.view.frame.maxX - 120,
                                    y: vc.view.frame.maxY - 30,
                                    width: 110,
                                    height: 20)
        
    }
    
    func configureQrView() {
        
        qrView.isUserInteractionEnabled = true
        
        qrView.frame = CGRect(x: 10,
                              y: (vc.view.frame.width - 20) * -1,
                              width: vc.view.frame.width - 20,
                              height: vc.view.frame.width - 20)
        
    }
    
    func configureTextView() {
        
        textView.textColor = UIColor.white
        textView.backgroundColor = UIColor.clear
        textView.textAlignment = .natural
        textView.font = UIFont.init(name: "HelveticaNeue-Light", size: 14)
        textView.adjustsFontForContentSizeCategory = true
        textView.isUserInteractionEnabled = true
        textView.isEditable = false
        
        textView.frame = CGRect(x: 10,
                                y: vc.view.frame.maxY + 170,
                                width: vc.view.frame.width - 20,
                                height: (vc.view.frame.height - 140) - (vc.view.frame.width - 20))
        
    }
    
    func configureBackground() {
        
        backgroundView.alpha = 0
        backgroundView.backgroundColor = UIColor.clear
        backgroundView.frame = vc.view.frame
        
    }
    
    func generateQrCode(key: String) -> UIImage {
        
        self.qrGenerator.textInput = key
        self.qrGenerator.backColor = UIColor.clear
        self.qrGenerator.foreColor = UIColor.white
        let imageToReturn = self.qrGenerator.getQRCode()
        
        return imageToReturn
        
    }
    
}
