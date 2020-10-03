//
//  Base64FS.swift
//  FullyNoded
//
//  Created by Peter on 10/1/20.
//  Copyright © 2020 Fontaine. All rights reserved.
//

//
//  Base64FS.swift
//
//  Created by Jack Chorley on 27/06/2017.
//
import Foundation

public class Base64FS {
    
    private static let padding: UInt8 = 61 // Padding = "="
    
    private static let filenameSafeAlphabet: [UInt8] = [
        65, // 0 = "A"
        66, // 1 = "B"
        67, // 2 = "C"
        68, // 3 = "D"
        69, // 4 = "E"
        70, // 5 = "F"
        71, // 6 = "G"
        72, // 7 = "H"
        73, // 8 = "I"
        74, // 9 = "J"
        75, // 10 = "K"
        76, // 11 = "L"
        77, // 12 = "M"
        78, // 13 = "N"
        79, // 14 = "O"
        80, // 15 = "P"
        81, // 16 = "Q"
        82, // 17 = "R"
        83, // 18 = "S"
        84, // 19 = "T"
        85, // 20 = "U"
        86, // 21 = "V"
        87, // 22 = "W"
        88, // 23 = "X"
        89, // 24 = "Y"
        90, // 25 = "Z"
        97, // 26 = "a"
        98, // 27 = "b"
        99, // 28 = "c"
        100, // 29 = "d"
        101, // 30 = "e"
        102, // 31 = "f"
        103, // 32 = "g"
        104, // 33 = "h"
        105, // 34 = "i"
        106, // 35 = "j"
        107, // 36 = "k"
        108, // 37 = "l"
        109, // 38 = "m"
        110, // 39 = "n"
        111, // 40 = "o"
        112, // 41 = "p"
        113, // 42 = "q"
        114, // 43 = "r"
        115, // 44 = "s"
        116, // 45 = "t"
        117, // 46 = "u"
        118, // 47 = "v"
        119, // 48 = "w"
        120, // 49 = "x"
        121, // 50 = "y"
        122, // 51 = "z"
        48, // 52 = "0"
        49, // 53 = "1"
        50, // 54 = "2"
        51, // 55 = "3"
        52, // 56 = "4"
        53, // 57 = "5"
        54, // 58 = "6"
        55, // 59 = "7"
        56, // 60 = "8"
        57, // 61 = "9"
        45, // 62 = "-"
        95, // 63 = "_"
    ]
    
    private static let safeAlphabetToIndex: [UInt8 : UInt8] = [
        61 : 0, // Padding = 0
        65 : 0, // 0 = "A"
        66 : 1, // 1 = "B"
        67 : 2, // 2 = "C"
        68 : 3, // 3 = "D"
        69 : 4, // 4 = "E"
        70 : 5, // 5 = "F"
        71 : 6, // 6 = "G"
        72 : 7, // 7 = "H"
        73 : 8, // 8 = "I"
        74 : 9, // 9 = "J"
        75 : 10, // 10 = "K"
        76 : 11, // 11 = "L"
        77 : 12, // 12 = "M"
        78 : 13, // 13 = "N"
        79 : 14, // 14 = "O"
        80 : 15, // 15 = "P"
        81 : 16, // 16 = "Q"
        82 : 17, // 17 = "R"
        83 : 18, // 18 = "S"
        84 : 19, // 19 = "T"
        85 : 20, // 20 = "U"
        86 : 21, // 21 = "V"
        87 : 22, // 22 = "W"
        88 : 23, // 23 = "X"
        89 : 24, // 24 = "Y"
        90 : 25, // 25 = "Z"
        97 : 26, // 26 = "a"
        98 : 27, // 27 = "b"
        99 : 28, // 28 = "c"
        100 : 29, // 29 = "d"
        101 : 30, // 30 = "e"
        102 : 31, // 31 = "f"
        103 : 32, // 32 = "g"
        104 : 33, // 33 = "h"
        105 : 34, // 34 = "i"
        106 : 35, // 35 = "j"
        107 : 36, // 36 = "k"
        108 : 37, // 37 = "l"
        109 : 38, // 38 = "m"
        110 : 39, // 39 = "n"
        111 : 40, // 40 = "o"
        112 : 41, // 41 = "p"
        113 : 42, // 42 = "q"
        114 : 43, // 43 = "r"
        115 : 44, // 44 = "s"
        116 : 45, // 45 = "t"
        117 : 46, // 46 = "u"
        118 : 47, // 47 = "v"
        119 : 48, // 48 = "w"
        120 : 49, // 49 = "x"
        121 : 50, // 50 = "y"
        122 : 51, // 51 = "z"
        48 : 52, // 52 = "0"
        49 : 53, // 53 = "1"
        50 : 54, // 54 = "2"
        51 : 55, // 55 = "3"
        52 : 56, // 56 = "4"
        53 : 57, // 57 = "5"
        54 : 58, // 58 = "6"
        55 : 59, // 59 = "7"
        56 : 60, // 60 = "8"
        57 : 61, // 61 = "9"
        45 : 62, // 62 = "-"
        95 : 63, // 63 = "_"
    ]
    
    
    public static func encodeString(str: String) -> String {
        
        // Get the ascii representation and return
        let data = str.data(using: .ascii)!
        
        let encData = encode(data: [UInt8](data))
        
        let retStr = String(data: Data(encData), encoding: .ascii)!
        
        return retStr
    }
    
    public static func encode(data: [UInt8]) -> [UInt8] {
        
        var result: [UInt8] = []
        
        let size = data.count
        
        // Step through 3 bytes at a time
        for i in stride(from: 0, to: size, by: 3) {
            
            
            // Get the first 6 bits, and add the Base64 letter
            let first = data[i] >> 2
            result.append(filenameSafeAlphabet[Int(first)])
            
            // Get the remaining 2 bits from the previous byte
            var second = (data[i] & 0b11) << 4
            
            
            // If there is more of the array, add the next 4 bits from byte 2, or return with padding for the 3rd and 4th characters
            if i + 1 < size {
                second |= (data[i + 1] & 0b11110000) >> 4
                result.append(filenameSafeAlphabet[Int(second)])
            } else {
                result.append(filenameSafeAlphabet[Int(second)])
                result.append(padding)
                result.append(padding)
                return result
            }
            
            
            // Get the remaining 4 bits from the previous byte
            var third = (data[i + 1] & 0b1111) << 2
            
            // If there is more of the array, add the next 2 bits from byte 3, or return with padding for the 4th character
            if i + 2 < size {
                third |= (data[i + 2] & 0b11000000) >> 6
                result.append(filenameSafeAlphabet[Int(third)])
            } else {
                result.append(filenameSafeAlphabet[Int(third)])
                result.append(padding)
                return result
            }
            
            
            // Get the remaining 6 bits from the previous byte, add to the result
            let forth = data[i + 2] & 0b00111111
            result.append(filenameSafeAlphabet[Int(forth)])
        }
        
        return result
    }
    
    public static func decode(data: [UInt8]) -> [UInt8] {
        
        var result: [UInt8] = []
        
        let size = data.count
        // We loop over the 4 letters at a time
        // We know it is padded, so we dont need to check for size
        for i in stride(from: 0, to: size, by: 4) {
            
            // Get the 4 letters, then get back to their non-index values
            let first = safeAlphabetToIndex[data[i]]!
            let second = safeAlphabetToIndex[data[i + 1]]!
            let third = safeAlphabetToIndex[data[i + 2]]!
            let forth = safeAlphabetToIndex[data[i + 3]]!
            
            // Get the 3 binary letters from the four 6-bit ones
            let l1 = first << 2 | ((second & 0b110000) >> 4)
            let l2 = ((second & 0b1111) << 4) | ((third & 0b111100) >> 2)
            let l3 = ((third & 0b11) << 6) | forth
            
            // Return the letters if they arent empty
            result.append(l1)
            
            if l3 != 0 {
                result.append(l2)
                result.append(l3)
            } else if l2 != 0 {
                result.append(l2)
            }
        }
        
        return result
    }
    
    public static func decodeString(str: String) -> String {
        
        // Get the ascii representation and return
        let data = str.data(using: .ascii)!
        
        let decData = decode(data: [UInt8](data))
        
        let retStr = String(data: Data(decData), encoding: .ascii)!
        
        return retStr
    }
}

