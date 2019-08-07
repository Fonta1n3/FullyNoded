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
        
        blurView.frame = CGRect(x: 0, y: -20, width: vc.view.frame.width, height: vc.view.frame.height + 20)
        blurView.alpha = 0
        vc.view.addSubview(blurView)
        
        activityIndicator.frame = CGRect(x: blurView.center.x - 25,
                                         y: (blurView.center.y - 25) - 20,
                                         width: 50,
                                         height: 50)
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = UIActivityIndicatorView.Style.whiteLarge
        activityIndicator.alpha = 0
        blurView.contentView.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        label.frame = CGRect(x: (blurView.frame.maxX - 250) / 2,
                             y: activityIndicator.frame.maxY,
                             width: 250,
                             height: 60)
        
        label.text = description
        label.textColor = UIColor.white
        label.font = UIFont.init(name: "HiraginoSans-W3", size: 12)
        label.textAlignment = .center
        label.alpha = 0
        label.numberOfLines = 0
        blurView.contentView.addSubview(label)
        
        UIView.animate(withDuration: 0.5) {
            
            self.blurView.alpha = 1
            self.activityIndicator.alpha = 1
            self.label.alpha = 1
            
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
