//
//  ConnectingView.swift
//  BitSense
//
//  Created by Peter on 06/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class ConnectingView: UIView {
    
    let blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffect.Style.dark))
    let label = UILabel()
    let activityIndicator = UIActivityIndicatorView()
    
    func addConnectingView(vc: UIViewController, description: String) {
        
        DispatchQueue.main.async {
            
            self.blurView.frame = CGRect(x: 0, y: -20, width: vc.view.frame.width, height: vc.view.frame.height + 20)
            vc.view.addSubview(self.blurView)
            
            self.activityIndicator.frame = CGRect(x: self.blurView.center.x - 25,
                                             y: (self.blurView.center.y - 25) - 20,
                                             width: 50,
                                             height: 50)
            
            self.activityIndicator.hidesWhenStopped = true
            self.activityIndicator.style = .large
            self.activityIndicator.alpha = 0
            self.blurView.contentView.addSubview(self.activityIndicator)
            self.activityIndicator.startAnimating()
            
            self.label.frame = CGRect(x: (self.blurView.frame.maxX - 250) / 2,
                                 y: self.activityIndicator.frame.maxY,
                                 width: 250,
                                 height: 60)
            
            self.label.text = description.lowercased()
            self.label.textColor = UIColor.white
            self.label.font = UIFont.systemFont(ofSize: 12)
            self.label.textAlignment = .center
            self.label.alpha = 0
            self.label.numberOfLines = 0
            self.blurView.contentView.addSubview(self.label)
            
            UIView.animate(withDuration: 0.5) {
                
                self.blurView.alpha = 1
                self.activityIndicator.alpha = 1
                self.label.alpha = 1
                
            }
            
        }
        
    }
    
    func removeConnectingView() {
        
        DispatchQueue.main.async {
            
            UIView.animate(withDuration: 0.5, animations: {
                
                self.blurView.alpha = 0
                
            }) { _ in
                
                self.blurView.removeFromSuperview()
                self.label.removeFromSuperview()
                self.activityIndicator.stopAnimating()
                self.activityIndicator.removeFromSuperview()
                
            }
            
        }
        
    }
}
