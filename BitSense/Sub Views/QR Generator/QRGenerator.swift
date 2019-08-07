//
//  QRGenerator.swift
//  BitSense
//
//  Created by Peter on 15/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit

class QRGenerator: UIView {
    
    var textInput = ""
    
    func getQRCode() -> UIImage {
        
        var imageToReturn = UIImage()
        
        let data = textInput.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            
            filter.setValue(data, forKey: "inputMessage")
            
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                
                let context = CIContext(options: nil)
                let cgiImage = context.createCGImage(output, from: output.extent)
                imageToReturn = UIImage(cgImage: cgiImage!)
                
            } else {
                
                imageToReturn = UIImage(named: "clear.png")!
                
            }
            
        }
        
        return imageToReturn
        
    }
    
}
