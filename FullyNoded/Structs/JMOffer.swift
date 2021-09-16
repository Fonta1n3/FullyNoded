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
    
    // This is failing: :J5DbkkCqGnfSNmHt!J5DbkkCqGn@tor.darkscience.net PRIVMSG J5EBCzgQ5yCUz1vZ :!sw0absoffer 0 100000 99999999 0 0!sw0reloffer 1 100000000 3110768682 0 0.00001999!tbond //8wRAIgYPXdaA+L8CVTJ9itwNR/5VRa58UnAL/3fmN2CNNGzYkCIBJK9QVVFAcPlcG6CGWSAUH9GZakEQl22X5VmqgxnJkq//8wRAIgbwPGbSAU+/NjXtTCwLbhmcWhl970j8GN/ud6RSGzNwACIDl2yqBuXutJC0/kQQ/4BQl7jMQkPTc7qJOvr789oOanAu0BqJgOvV6JTTxtpkVfCAQ+hcqA8ppftqmw1aE/V4m8WwEC/lU55H6vN7C0Up9irJZwTyEdWjbXVB6rP4otWR52452byAZsS/040/cQQAL6/M8gTSUMkcZ7rcCXPlqjnVXKmwAAAAAAz
    
    let maker:String
    //let host:String?
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
    //let tbond: String?
    let raw: String
    
    init(_ dict: [String:String]) {
        maker = dict["maker"]!
        raw = dict["offer"]!
        
        let array = raw.split(separator: " ")
                    
        let type = array[0]
        isNativeSegwit = type.hasPrefix("sw0")
        
        isAbs = type.contains("absoffer")
        isRel = type.contains("reloffer")
        
        oid = Int(array[1])
        minSize = Int(array[2])
        maxSize = Int(array[3])
        txFee = Int(array[4])
        cjFee = Int(array[5])
        
        if array.count > 6 {
            pubkey = "\(array[6])"
        } else {
            pubkey = nil
        }
        
        if array.count > 7 {
            encMessage = "\(array[7])"
        } else {
            encMessage = nil
        }
    }
    
    public var description: String {
        return ""
    }
}
