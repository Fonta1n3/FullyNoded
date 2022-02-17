//
//  MixIndexes.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/17/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation


public struct MixIndexes: CustomStringConvertible {
    
    let zeroExt:Int
    let zeroInt:Int
    let oneExt:Int
    let oneInt:Int
    let twoExt:Int
    let twoInt:Int
    let threeExt:Int
    let threeInt:Int
    let fourExt:Int
    let fourInt:Int
    
    init(_ array: [[Int]]) {
        zeroExt = array[0][0]
        zeroInt = array[0][1]
        oneExt = array[1][0]
        oneInt = array[1][1]
        twoExt = array[2][0]
        twoInt = array[2][1]
        threeExt = array[3][0]
        threeInt = array[3][1]
        fourExt = array[4][0]
        fourInt = array[4][1]
    }
    
    public var description: String {
        return ""
    }
}
