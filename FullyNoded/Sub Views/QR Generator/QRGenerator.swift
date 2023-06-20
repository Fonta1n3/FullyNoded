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
        
        let imageToReturn = UIImage(systemName: "exclamationmark.triangle")!
        
        let data = textInput.data(using: .ascii)
        
        // Generate the code image with CIFilter
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return imageToReturn }
        filter.setValue(data, forKey: "inputMessage")
        
        // Scale it up (because it is generated as a tiny image)
        //let scale = UIScreen.main.scale
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        guard let output = filter.outputImage?.transformed(by: transform) else { return imageToReturn }
        
        // Change the color using CIFilter
        let grey = #colorLiteral(red: 0.07804081589, green: 0.09001789242, blue: 0.1025182381, alpha: 1)
        
        let colorParameters = [
            "inputColor0": CIColor(color: grey), // Foreground
            "inputColor1": CIColor(color: UIColor.white) // Background
        ]
        
        let colored = (output.applyingFilter("CIFalseColor", parameters: colorParameters))
        
        func renderedImage(uiImage: UIImage) -> UIImage? {
            let image = uiImage
            if #available(iOS 10.0, *) {
                return UIGraphicsImageRenderer(size: image.size,
                                               format: image.imageRendererFormat).image { _ in
                                                image.draw(in: CGRect(origin: .zero, size: image.size))
                }
            } else {
                return nil
            }
        }
        
        let uiImage = UIImage(ciImage: colored)
        
        return renderedImage(uiImage: uiImage) ?? imageToReturn
        
    }
    
}
