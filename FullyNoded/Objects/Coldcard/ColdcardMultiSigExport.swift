//
//  ColdcardMultiSigExport.swift
//  FullyNoded
//
//  Created by Peter Denton on 7/18/24.
//  Copyright © 2024 Fontaine. All rights reserved.
//

import Foundation

struct ColdcardMultiSigExport : Codable {
    let p2sh_deriv : String?
    let p2sh : String?
    let p2sh_desc : String?
    let p2sh_p2wsh_deriv : String?
    let p2sh_p2wsh : String?
    let p2sh_p2wsh_desc : String?
    let p2wsh_deriv : String?
    let p2wsh : String?
    let p2wsh_desc : String?
    let account : String?
    let xfp : String?

    enum CodingKeys: String, CodingKey {

        case p2sh_deriv = "p2sh_deriv"
        case p2sh = "p2sh"
        case p2sh_desc = "p2sh_desc"
        case p2sh_p2wsh_deriv = "p2sh_p2wsh_deriv"
        case p2sh_p2wsh = "p2sh_p2wsh"
        case p2sh_p2wsh_desc = "p2sh_p2wsh_desc"
        case p2wsh_deriv = "p2wsh_deriv"
        case p2wsh = "p2wsh"
        case p2wsh_desc = "p2wsh_desc"
        case account = "account"
        case xfp = "xfp"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        p2sh_deriv = try values.decodeIfPresent(String.self, forKey: .p2sh_deriv)
        p2sh = try values.decodeIfPresent(String.self, forKey: .p2sh)
        p2sh_desc = try values.decodeIfPresent(String.self, forKey: .p2sh_desc)
        p2sh_p2wsh_deriv = try values.decodeIfPresent(String.self, forKey: .p2sh_p2wsh_deriv)
        p2sh_p2wsh = try values.decodeIfPresent(String.self, forKey: .p2sh_p2wsh)
        p2sh_p2wsh_desc = try values.decodeIfPresent(String.self, forKey: .p2sh_p2wsh_desc)
        p2wsh_deriv = try values.decodeIfPresent(String.self, forKey: .p2wsh_deriv)
        p2wsh = try values.decodeIfPresent(String.self, forKey: .p2wsh)
        p2wsh_desc = try values.decodeIfPresent(String.self, forKey: .p2wsh_desc)
        account = try values.decodeIfPresent(String.self, forKey: .account)
        xfp = try values.decodeIfPresent(String.self, forKey: .xfp)
    }

}
