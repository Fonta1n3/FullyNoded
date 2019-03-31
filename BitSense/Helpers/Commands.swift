//
//  Commands.swift
//  BitSense
//
//  Created by Peter on 24/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation


public enum BTC_CLI_COMMAND: String {
    case getrawtransaction = "getrawtransaction"
    case decoderawtransaction = "decoderawtransaction"
    case getnewaddress = "getnewaddress"
    case gettransaction = "gettransaction"
    case sendrawtransaction = "sendrawtransaction"
    case signrawtransaction = "signrawtransactionwithwallet"
    case createrawtransaction = "createrawtransaction"
    case getrawchangeaddress = "getrawchangeaddress"
    case getaccountaddress = "getaddressesbyaccount"
    case getwalletinfo = "getwalletinfo"
    case getblockchaininfo = "getblockchaininfo"
    case getbalance = "getbalance"
    case getunconfirmedbalance = "getunconfirmedbalance"
    //case listaccounts = "listaccounts"
    //case listreceivedbyaccount = "listreceivedbyaccount"
    //case listreceivedbyaddress = "listreceivedbyaddress"
    case listtransactions = "listtransactions"
    case listunspent = "listunspent"
    case bumpfee = "bumpfee"
    case importprivkey = "importprivkey"
    case abandontransaction = "abandontransaction"
    case getpeerinfo = "getpeerinfo"
    case getnetworkinfo = "getnetworkinfo"
    case getmininginfo = "getmininginfo"
    case estimatesmartfee = "estimatesmartfee"
    case dumpwallet = "dumpwallet"
}
