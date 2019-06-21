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
    //let blurEffectView = UIVisualEffectView()
    
    let impact = UIImpactFeedbackGenerator()
    let backgroundView = UIView()
    
    let upSwipe = UISwipeGestureRecognizer()
    
    
    @objc func handleSwipes(_ sender: UIGestureRecognizer) {
        
        print("handleSwipes")
     
        UIView.animate(withDuration: 0.2, animations: {
            
            self.backgroundView.frame = CGRect(x: 0,
                                          y: -100,
                                          width: self.backgroundView.frame.width,
                                          height: 100)
            
            self.errorLabel.frame = CGRect(x: 0,
                                           y: -100,
                                           width: self.backgroundView.frame.width,
                                           height: 100)
            
        }) { _ in
            
            UIView.animate(withDuration: 0.2, animations: {
                
                //self.blurEffectView.alpha = 0
                
            }, completion: { _ in
                
                self.backgroundView.removeFromSuperview()
                //self.blurEffectView.removeFromSuperview()
                
            })
            
        }
        
    }
    
    func showErrorView(vc: UIViewController, text: String, isError: Bool) {
        
        self.isUserInteractionEnabled = true
        
        /*let blurEffect = UIBlurEffect(style: .dark)
        blurEffectView.effect = blurEffect
        blurEffectView.frame = vc.view.frame
        blurEffectView.alpha = 0
        blurEffectView.isUserInteractionEnabled = true*/
        upSwipe.direction = .up
        upSwipe.addTarget(self, action: #selector(handleSwipes(_:)))
        backgroundView.addGestureRecognizer(self.upSwipe)
        
        let width = vc.view.frame.width
        
        backgroundView.frame = CGRect(x: 0,
                                      y: -100,
                                      width: width,
                                      height: 100)
        
        
        backgroundView.alpha = 0
        
        
        
        if isError {
            
            backgroundView.backgroundColor = UIColor.red
            
        } else {
            
            backgroundView.backgroundColor = UIColor(#colorLiteral(red: 0.007097487926, green: 0.6329314721, blue: 0, alpha: 1))
            
            
            
            
        }
        
        errorLabel.frame = CGRect(x: 0,
                                  y: -100,
                                  width: width,
                                  height: 100)
        
        errorLabel.textColor = UIColor.white
        errorLabel.font = UIFont.init(name: "HiraginoSans-W3", size: 15)
        errorLabel.text = text
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        
        //blurEffectView.contentView.addSubview(errorLabel)
        backgroundView.addSubview(errorLabel)
        vc.view.addSubview(backgroundView)
        //vc.view.addSubview(blurEffectView)
        
        UIView.animate(withDuration: 0.3, animations: {
            
            self.backgroundView.alpha = 1
            
            self.backgroundView.frame = CGRect(x: 0,
                                               y: 0,
                                               width: width,
                                               height: 100)
            
            self.errorLabel.frame = CGRect(x: 0,
                                           y: 5,
                                           width: width,
                                           height: 100)
            
            //self.blurEffectView.alpha = 1
            
        }) { _ in
            
            DispatchQueue.main.async {
                
                self.impact.impactOccurred()
                
            }
            
            var deadlineTime = 5.0
            
            if !isError {
                
               deadlineTime = 2.0
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + deadlineTime, execute: {
                
                UIView.animate(withDuration: 0.3, animations: {
                    
                    self.backgroundView.frame = CGRect(x: 0,
                                                       y: -100,
                                                       width: width,
                                                       height: 100)
                    
                    self.errorLabel.frame = CGRect(x: 0,
                                                   y: -100,
                                                   width: width,
                                                   height: 100)
                    
                }) { _ in
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        
                        //self.blurEffectView.alpha = 0
                        
                    }, completion: { _ in
                        
                        self.backgroundView.removeFromSuperview()
                        //self.blurEffectView.removeFromSuperview()
             
                    })
                    
                }
                
            })
            
        }
        
    }
    
}
