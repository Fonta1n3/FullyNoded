//
//  QRGenerator.swift
//  BitSense
//
//  Created by Peter on 15/04/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation
import UIKit
import EFQRCode

class QRGenerator: UIView {
    
    var textInput = ""
    var backColor = UIColor()
    var foreColor = UIColor()
    
    func getQRCode() -> UIImage {
        
        if let cgImage = EFQRCode.generate(content: textInput,
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
            
            let qrImage = UIImage(cgImage: cgImage)
            
            return qrImage
            
        } else {
            
            return UIImage(named: "clear.png")!
            
        }
        
    }
    
}
