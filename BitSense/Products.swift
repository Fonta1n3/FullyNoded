//
//  Products.swift
//  BitSense
//
//  Created by Peter on 14/10/18.
//  Copyright © 2018 Fontaine. All rights reserved.
//

import Foundation

public struct FullyNodedProducts {
    
    public static let SwiftShopping = "com.fontaine.FullyNoded.NodeSubscription"
    
    private static let productIdentifiers: Set<ProductIdentifier> = [FullyNodedProducts.SwiftShopping]
    
    public static let store = IAPHelper(productIds: FullyNodedProducts.productIdentifiers)
    
}

func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
    return productIdentifier.components(separatedBy: ".").last
}


