//
//  NoConnectionView.swift
//  BitSense
//
//  Created by Peter on 19/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class NoConnectionView: UIView {
    
    let imageView = UIImageView()
    
    func addNoConnectionView(cell: UITableViewCell) {
        
        let image1 = UIImage(named: "dino1.png")!
        let image2 = UIImage(named: "dino2.png")!
        let image3 = UIImage(named: "dino3.png")!
        let image4 = UIImage(named: "dino4.png")!
        
        DispatchQueue.main.async {
            
            let imageList = [image1, image2, image3, image4]
            
            self.imageView.animationImages = imageList
            self.imageView.animationDuration = 2.0
            
            self.imageView.frame = CGRect(x: cell.center.x - cell.frame.height,
                                     y: 0,
                                     width: cell.frame.height * 2,
                                     height: cell.frame.height)
            
            self.imageView.alpha = 0
            
            cell.addSubview(self.imageView)
            self.imageView.startAnimating()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5 , execute: {
                
                UIView.animate(withDuration: 0.2, animations: {
                    
                    self.imageView.alpha = 0.1
                    
                })
                
            })
            
        }
        
    }
    
}
