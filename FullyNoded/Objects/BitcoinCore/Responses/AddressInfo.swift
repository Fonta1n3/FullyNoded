//
//  AddressInfo.swift
//  FullyNoded
//
//  Created by Peter Denton on 2/7/22.
//  Copyright © 2022 Fontaine. All rights reserved.
//

import Foundation


// address = bc1q3qum3ncd0yxtqgz2yu2rysln9ktvz2nrullraa;
// desc = "wpkh([77b6eb24/84'/0'/4'/0/4]0392c85012a12ccdce0d43562a0f7c2c02ab6c2e64fcf0cf91d59c26d9495bb6c0)#3yjwgt5r";
// hdkeypath = "m/84'/0'/4'/0/4";
// hdmasterfingerprint = 77b6eb24;
// hdseedid = 0000000000000000000000000000000000000000;
// ischange = 1;
// ismine = 1;
// isscript = 0;
// iswatchonly = 0;
// iswitness = 1;
// labels =     (
// );
// "parent_desc" = "wpkh([77b6eb24/84'/0'/4']xpub6BhkVXvaeiNT8QAoVwH12rcDkhZzre7nXVAPoFjcNRfWe7pLnmWP6CuBTGzcrFfTsSvEyxz8LmBgHiNy8F3y88a6gidB8JAs1VqGFukveuu/0/*)#2g3vjagj";
// pubkey = 0392c85012a12ccdce0d43562a0f7c2c02ab6c2e64fcf0cf91d59c26d9495bb6c0;
// scriptPubKey = 00148839b8cf0d790cb0204a27143243f32d96c12a63;
// solvable = 1;
// timestamp = 1644248378;
// "witness_program" = 8839b8cf0d790cb0204a27143243f32d96c12a63;
// "witness_version" = 0;
 

public struct AddressInfo: CustomStringConvertible {
    
    let ismine: Bool
    let hdkeypath: String
    let solvable: Bool
    let desc: String
    
    init(_ dictionary: [String: Any]) {
        ismine = dictionary["ismine"] as! Bool
        hdkeypath = dictionary["hdkeypath"] as? String ?? "derivation path unknown"
        solvable = dictionary["solvable"] as? Bool ?? false
        desc = dictionary["desc"] as? String ?? "descriptor unknown"
    }
    
    public var description: String {
        return ""
    }
}
