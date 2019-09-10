//
//  ErrorView.swift
//  BitSense
//
//  Created by Peter on 16/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class ErrorView: UIView {
    
    let errorLabel = UILabel()
    
    let impact = UIImpactFeedbackGenerator()
    let backgroundView = UIView()
    
    let upSwipe = UISwipeGestureRecognizer()
    
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        
        print("handleSwipes")
     
        UIView.animate(withDuration: 0.2, animations: {
            
            self.backgroundView.frame = CGRect(x: 5,
                                          y: -100,
                                          width: self.backgroundView.frame.width - 10,
                                          height: 100)
            
            self.errorLabel.frame = CGRect(x: 5,
                                           y: -100,
                                           width: self.backgroundView.frame.width - 10,
                                           height: 100)
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                
            }, completion: { _ in
                
                self.backgroundView.removeFromSuperview()
                
            })
            
        }
        
    }
    
    func showErrorView(vc: UIViewController, text: String, isError: Bool) {
        
        self.isUserInteractionEnabled = true
        upSwipe.direction = .up
        upSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        backgroundView.addGestureRecognizer(self.upSwipe)
        backgroundView.clipsToBounds = true
        backgroundView.layer.cornerRadius = 15
        
        let width = vc.view.frame.width
        
        backgroundView.frame = CGRect(x: 5,
                                      y: -100,
                                      width: width - 10,
                                      height: 100)
        
        
        backgroundView.alpha = 0
        
        
        
        if isError {
            
            backgroundView.backgroundColor = UIColor.red
            
        } else {
            
            backgroundView.backgroundColor = UIColor(#colorLiteral(red: 0.007097487926, green: 0.6329314721, blue: 0, alpha: 1))
            
            
            
            
        }
        
        errorLabel.frame = CGRect(x: 5,
                                  y: -100,
                                  width: width - 10,
                                  height: 100)
        
        errorLabel.textColor = UIColor.white
        errorLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        errorLabel.text = text.lowercased()
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        
        backgroundView.addSubview(errorLabel)
        vc.view.addSubview(backgroundView)
        
        let imageView = UIImageView()
        imageView.backgroundColor = UIColor.clear
        
        imageView.image = UIImage(named: "Image-12")
        
        
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.backgroundView.alpha = 1
            
            self.backgroundView.frame = CGRect(x: 5,
                                               y: 65,
                                               width: width - 10,
                                               height: 100)
            
            self.errorLabel.frame = CGRect(x: 5,
                                           y: 0,
                                           width: width - 10,
                                           height: 100)
            
        }) { _ in
            
            DispatchQueue.main.async {
                
                imageView.alpha = 0.5
                imageView.frame = CGRect(x: self.errorLabel.frame.midX - 15,
                                         y: self.errorLabel.frame.maxY - 18,
                                         width: 20,
                                         height: 20)
                
                self.errorLabel.addSubview(imageView)
                
                self.impact.impactOccurred()
                
            }
            
            var deadlineTime = 8.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + deadlineTime, execute: {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.backgroundView.frame = CGRect(x: 5,
                                                       y: -100,
                                                       width: width - 10,
                                                       height: 100)
                    
                    self.errorLabel.frame = CGRect(x: 5,
                                                   y: -100,
                                                   width: width - 10,
                                                   height: 100)
                    
                }) { _ in
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        
                    }, completion: { _ in
                        
                        self.backgroundView.removeFromSuperview()
             
                    })
                    
                }
                
            })
            
        }
        
    }
    
}
