//
//  QRGenerator.swift
//  BitSense
//
//  Created by Peter on 15/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit
//import EFQRCode

class QRGenerator: UIView {
    
    var textInput = ""
    var backColor = UIColor()
    var foreColor = UIColor()
    
    /*
     
     func generateQRCode(from string: String) -> UIImage? {
     let data = string.data(using: String.Encoding.ascii)
     
     if let filter = CIFilter(name: "CIQRCodeGenerator") {
     filter.setValue(data, forKey: "inputMessage")
     let transform = CGAffineTransform(scaleX: 3, y: 3)
     
     if let output = filter.outputImage?.transformed(by: transform) {
     return UIImage(ciImage: output)
     }
     }
     
     return nil
     }
     
     let image = generateQRCode(from: "Hacking with Swift is the best iOS coding tutorial I've ever read!")
     
     */
    
    func getQRCode() -> UIImage {
        
        var imageToReturn = UIImage()
        
        let data = textInput.data(using: String.Encoding.ascii)
        
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            
            if let output = filter.outputImage?.transformed(by: transform) {
                imageToReturn = UIImage(ciImage: output)
            } else {
                
                imageToReturn = UIImage(named: "clear.png")!
            }
        }
        
        return imageToReturn
        
        /*if let cgImage = EFQRCode.generate(content: textInput,
                                           size: EFIntSize.init(width: 256, height: 256),
                                           backgroundColor: (backColor).cgColor,
                                           foregroundColor: (foreColor).cgColor,
                                           watermark: nil,
                                           watermarkMode: EFWatermarkMode.scaleAspectFit,
                                           inputCorrectionLevel: EFInputCorrectionLevel.h,
                                           icon: nil,
                                           iconSize: nil,
                                           allowTransparent: true,
                                           pointShape: EFPointShape.circle,
                                           mode: EFQRCodeMode.none,
                                           binarizationThreshold: 0,
                                           magnification: EFIntSize.init(width: 50, height: 50),
                                           foregroundPointOffset: 0) {
            
            let qrImage = UIImage(cgImage: cgImage)*/
        /*if let qrImage = UIImage(named: "clear.png") as? UIImage {
            
            return qrImage
            
        } else {
            
            return UIImage(named: "clear.png")!
            
        }*/
        
    }
    
}
