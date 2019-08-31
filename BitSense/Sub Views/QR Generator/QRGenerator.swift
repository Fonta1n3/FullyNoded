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
        
        let imageToReturn = UIImage(named: "clear.png")!
        
        /*let data = textInput.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            
            filter.setValue(data, forKey: "inputMessage")
            
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                
                let context = CIContext(options: nil)
                let cgiImage = context.createCGImage(output, from: output.extent)
                
                // Change the color using CIFilter
                let colorParameters = [
                    "inputColor0": CIColor(color: UIColor.black), // Foreground
                    "inputColor1": CIColor(color: UIColor.clear) // Background
                ]
                
                let colored = output.applyingFilter("CIFalseColor", parameters: colorParameters)
                
                imageToReturn = UIImage(cgImage: cgiImage!)
                
            } else {
                
                imageToReturn = UIImage(named: "clear.png")!
                
            }
            
        }*/
        
        let data = textInput.data(using: .ascii)
        
        // Generate the code image with CIFilter
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return imageToReturn }
        filter.setValue(data, forKey: "inputMessage")
        
        // Scale it up (because it is generated as a tiny image)
        //let scale = UIScreen.main.scale
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        guard let output = filter.outputImage?.transformed(by: transform) else { return imageToReturn }
        
        // Change the color using CIFilter
        let colorParameters = [
            "inputColor0": CIColor(color: UIColor.green), // Foreground
            "inputColor1": CIColor(color: UIColor.clear) // Background
        ]
        
        let colored = output.applyingFilter("CIFalseColor", parameters: colorParameters)
        
        return UIImage(ciImage: colored)
        
    }
    
}
