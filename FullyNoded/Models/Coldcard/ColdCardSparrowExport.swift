//
//  ColdCardSparrowExport.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/17/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import Foundation

struct ColdcardSparrowExport : Codable {
    let chain : String?
    let xfp : String?
    let account : Int?
    let xpub : String?
    let bip44 : Bip44?
    let bip49 : Bip49?
    let bip84 : Bip84?
    //let bip48_1 : Bip48_1?
    let bip48_2 : Bip48_2?
    let bip45 : Bip45?

    enum CodingKeys: String, CodingKey {

        case chain = "chain"
        case xfp = "xfp"
        case account = "account"
        case xpub = "xpub"
        case bip44 = "bip44"
        case bip49 = "bip49"
        case bip84 = "bip84"
        //case bip48_1 = "bip48_1"
        case bip48_2 = "bip48_2"
        case bip45 = "bip45"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        chain = try values.decodeIfPresent(String.self, forKey: .chain)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        account = try values.decodeIfPresent(Int.self, forKey: .account)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        bip44 = try values.decodeIfPresent(Bip44.self, forKey: .bip44)
        bip49 = try values.decodeIfPresent(Bip49.self, forKey: .bip49)
        bip84 = try values.decodeIfPresent(Bip84.self, forKey: .bip84)
        //bip48_1 = try values.decodeIfPresent(Bip48_1.self, forKey: .bip48_1)
        bip48_2 = try values.decodeIfPresent(Bip48_2.self, forKey: .bip48_2)
        bip45 = try values.decodeIfPresent(Bip45.self, forKey: .bip45)
    }

}


struct Bip44 : Codable {
    let name : String?
    let xfp : String?
    let deriv : String?
    let xpub : String?
    let desc : String?
    let first : String?
    let standardDesc : String?

    enum CodingKeys: String, CodingKey {

        case name = "name"
        case xfp = "xfp"
        case deriv = "deriv"
        case xpub = "xpub"
        case desc = "desc"
        case first = "first"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        desc = try values.decodeIfPresent(String.self, forKey: .desc)
        first = try values.decodeIfPresent(String.self, forKey: .first)
        standardDesc = desc?.standardDesc()
    }

}


struct Bip45 : Codable {
    let name : String?
    let xfp : String?
    let deriv : String?
    let xpub : String?
    let desc : String?
    let standardDesc : String?

    enum CodingKeys: String, CodingKey {

        case name = "name"
        case xfp = "xfp"
        case deriv = "deriv"
        case xpub = "xpub"
        case desc = "desc"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        desc = try values.decodeIfPresent(String.self, forKey: .desc)
        standardDesc = desc?.standardDesc()
    }

}


//struct Bip48_1 : Codable {
//    let name : String?
//    let xfp : String?
//    let deriv : String?
//    let xpub : String?
//    let desc : String?
//    let _pub : String?
//
//    enum CodingKeys: String, CodingKey {
//
//        case name = "name"
//        case xfp = "xfp"
//        case deriv = "deriv"
//        case xpub = "xpub"
//        case desc = "desc"
//        case _pub = "_pub"
//    }
//
//    init(from decoder: Decoder) throws {
//        let values = try decoder.container(keyedBy: CodingKeys.self)
//        name = try values.decodeIfPresent(String.self, forKey: .name)
//        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
//        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
//        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
//        desc = try values.decodeIfPresent(String.self, forKey: .desc)
//        _pub = try values.decodeIfPresent(String.self, forKey: ._pub)
//    }
//
//}


struct Bip48_2 : Codable {
    let name : String?
    let xfp : String?
    let deriv : String?
    let xpub : String?
    let desc : String?
    let _pub : String?
    let standardDesc : String?

    enum CodingKeys: String, CodingKey {

        case name = "name"
        case xfp = "xfp"
        case deriv = "deriv"
        case xpub = "xpub"
        case desc = "desc"
        case _pub = "_pub"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        desc = try values.decodeIfPresent(String.self, forKey: .desc)
        _pub = try values.decodeIfPresent(String.self, forKey: ._pub)
        if var descToEdit = desc {
            descToEdit = descToEdit.replacingOccurrences(of: "sortedmulti(M,", with: "")
            descToEdit = descToEdit.replacingOccurrences(of: ",...))", with: ")")
            standardDesc = descToEdit.standardDesc()
        } else {
            standardDesc = nil
        }
    }

}


struct Bip49 : Codable {
    let name : String?
    let xfp : String?
    let deriv : String?
    let xpub : String?
    let desc : String?
    let _pub : String?
    let first : String?
    let standardDesc : String?

    enum CodingKeys: String, CodingKey {

        case name = "name"
        case xfp = "xfp"
        case deriv = "deriv"
        case xpub = "xpub"
        case desc = "desc"
        case _pub = "_pub"
        case first = "first"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        desc = try values.decodeIfPresent(String.self, forKey: .desc)
        _pub = try values.decodeIfPresent(String.self, forKey: ._pub)
        first = try values.decodeIfPresent(String.self, forKey: .first)
        standardDesc = desc?.standardDesc()
    }

}


struct Bip84 : Codable {
    let name : String?
    let xfp : String?
    let deriv : String?
    let xpub : String?
    let desc : String?
    let _pub : String?
    let first : String?
    let standardDesc : String?

    enum CodingKeys: String, CodingKey {

        case name = "name"
        case xfp = "xfp"
        case deriv = "deriv"
        case xpub = "xpub"
        case desc = "desc"
        case _pub = "_pub"
        case first = "first"
        //case standardDesc =
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
        deriv = try values.decodeIfPresent(String.self, forKey: .deriv)
        xpub = try values.decodeIfPresent(String.self, forKey: .xpub)
        desc = try values.decodeIfPresent(String.self, forKey: .desc)
        _pub = try values.decodeIfPresent(String.self, forKey: ._pub)
        first = try values.decodeIfPresent(String.self, forKey: .first)
        standardDesc = desc?.standardDesc()
    }

}

extension String {
    func standardDesc() -> String {
        if self.contains("multi(M,[") {
            var desc = self
            desc = desc.replacingOccurrences(of: "sortedmulti(M,", with: "")
            desc = desc.replacingOccurrences(of: ",...))", with: ")")
            
            return desc.replacingOccurrences(of: "<0;1>", with: "0").removeChecksum()
            
        } else {
            return self.replacingOccurrences(of: "<0;1>", with: "0").removeChecksum()
        }
        
    }
    
    func removeChecksum() -> String {
        let descArray = self.split(separator: "#")
        if descArray.count > 0 {
            //print("descArray[0] = \("\(descArray[0])".replacingOccurrences(of: "<0;1>", with: "0"))")
            return "\(descArray[0])".replacingOccurrences(of: "<0;1>", with: "0")
        } else {
            return self.replacingOccurrences(of: "<0;1>", with: "0")
        }
    }
}


