//
//  JMOffer.swift
//  FullyNoded
//
//  Created by Peter Denton on 8/30/21.
//  Copyright © 2021 Fontaine. All rights reserved.
//

import Foundation

public struct JMOffer: CustomStringConvertible {
    
    // :J55TWfyX3UhHYLfa!J55TWfyX3U@tor.darkscience.net PRIVMSG J5AQwDrG1gYb2sry :!sw0reloffer 0 4298649 575541456 122 0.000029 0260b19d7816fc08cae4535a1c88b002c95a8c7525d0a012ca01231ddd884c9da3 MEUCIQDVqkx7dCdGVVDH00V7VpdniU/Km1Dl1wOdI9ibsp27EAIgCyJJiB6dqsoy6Sin3z3daOMGFsHP8b6GhwtVCDTB5U0= ~
    
    // nick, ordertype, oid, minsize, maxsize, txfee, cjfee
    
    // J5Etzdoiyh2NRMLR :!sw0absoffer 0 3574 18462061 0 3955 02f688091f596d4e1b7f00f7e3721865f073dd1ffbc7a0be8212138f1c88cd5a74 MEQCIFH3XPQgpBsFZoHVvHe4dTTpKpUmlhWfMw2Hv381fi0qAiBIzTESxvoY/q7jG2zqCVam/BrR0DLc9pKlJx+mHCYlFA== ~
    
    // :J55vjw11pKVRCCWf!J55vjw11pK@tor.darkscience.net PRIVMSG J5Cga4zDqdTdpeh6 :!sw0reloffer 0 449999 64402488 3 0.00001!tbond //8wRAIgEWoOltbN3xoq8nAewaIKjeQhyfAfMIVClr1OJIAaDoECIG1rNafW+WIgOfeIx2r9Ho0r0PqRhsQMzbMPXxCjYBnX/zBFAiEA6hnCm+KyubLR8UhPYMCpe1JPip3ME8Uj6Ws1uKLOo70CIFeus7CMcwqjHMGqtXik8lxV7LGjpFLAPEoVfNkn7u4jAzD0qlTcO2aoov0IMFoE8ESZgauy3Ez+/3JLbeWdWY+BAQQDIYS4vtLGzuMiH+VcdIt7YfjQxUE2yDDM2i5NKbuVtVYN6IOu0Ii7lTxMdplHyxw+blFd5CkL9RY0EUFKftzBBAEAAACAwi5h 02522b154bcd1087ab31e35d54ca7cc625060f
    
    let maker:String?
    let host:String?
    let oid: Int?
    let isAbs: Bool?
    let isRel: Bool?
    let isNativeSegwit: Bool?
    let minSize: Int?
    let maxSize: Int?
    let txFee: Int?
    let cjFee: Int?
    let pubkey: String?
    let encMessage: String?
    let tbond: String?
    let raw: String
    
    init(_ message: String) {
        let array = message.split(separator: " ")
        
        // single offers - with or without tbond
        if array.count == 12 || array.count == 10 {
            let item = "\(array[0])".replacingOccurrences(of: ":", with: "")
            let subarray = item.split(separator: "!")
            
            if subarray.count == 2 {
                maker = "\(subarray[0])"
                host = "\(subarray[1])"
            } else {
                maker = nil
                host = nil
            }
            
            let typeRaw = "\(array[3])".replacingOccurrences(of: ":!", with: "")
            isNativeSegwit = typeRaw.hasPrefix("sw0")
            
            let processed = typeRaw.replacingOccurrences(of: "sw0", with: "")
            isAbs = processed == "absoffer"
            isRel = processed == "reloffer"
            
            oid = Int(array[4])
            minSize = Int(array[5])
            maxSize = Int(array[6])
            txFee = Int(array[7])
            
            if array[8].contains("!tbond") {
                let subarray = "\(array[8])".split(separator: "!")
                cjFee = Int("\(subarray[0])".replacingOccurrences(of: "!", with: ""))
                tbond = "\(subarray[1] + " " + array[9])"
            } else {
                cjFee = Int(array[8])
                tbond = nil
            }
            
            pubkey = "\(array[9])"
            encMessage = "\(array[10])"
        } else {
            maker = nil
            host = nil
            oid = nil
            minSize = nil
            maxSize = nil
            txFee = nil
            cjFee = nil
            isNativeSegwit = nil
            isRel = nil
            isAbs = nil
            pubkey = nil
            encMessage = nil
            tbond = nil
        }
        
        raw = message
    }
    
    public var description: String {
        return ""
    }
}
