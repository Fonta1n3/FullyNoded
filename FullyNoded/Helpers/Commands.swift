//
//  Commands.swift
//  BitSense
//
//  Created by Peter on 24/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

public enum BTC_CLI_COMMAND: String {
    case abortrescan = "abortrescan"
    case listlockunspent = "listlockunspent"
    case lockunspent = "lockunspent"
    case getblock = "getblock"
    case getbestblockhash = "getbestblockhash"
    case getaddressesbylabel = "getaddressesbylabel"
    case listlabels = "listlabels"
    case decodescript = "decodescript"
    case combinepsbt = "combinepsbt"
    case utxoupdatepsbt = "utxoupdatepsbt"
    case listaddressgroupings = "listaddressgroupings"
    case converttopsbt = "converttopsbt"
    case getaddressinfo = "getaddressinfo"
    case createmultisig = "createmultisig"
    case analyzepsbt = "analyzepsbt"
    case createpsbt = "createpsbt"
    case joinpsbts = "joinpsbts"
    case getmempoolinfo = "getmempoolinfo"
    case signrawtransactionwithkey = "signrawtransactionwithkey"
    case listwallets = "listwallets"
    case unloadwallet = "unloadwallet"
    case rescanblockchain = "rescanblockchain"
    case listwalletdir = "listwalletdir"
    case loadwallet = "loadwallet"
    case createwallet = "createwallet"
    case finalizepsbt = "finalizepsbt"
    case walletprocesspsbt = "walletprocesspsbt"
    case decodepsbt = "decodepsbt"
    case walletcreatefundedpsbt = "walletcreatefundedpsbt"
    case fundrawtransaction = "fundrawtransaction"
    case uptime = "uptime"
    case importmulti = "importmulti"
    case getdescriptorinfo = "getdescriptorinfo"
    case deriveaddresses = "deriveaddresses"
    case getrawtransaction = "getrawtransaction"
    case decoderawtransaction = "decoderawtransaction"
    case getnewaddress = "getnewaddress"
    case gettransaction = "gettransaction"
    case signrawtransactionwithwallet = "signrawtransactionwithwallet"
    case createrawtransaction = "createrawtransaction"
    case getrawchangeaddress = "getrawchangeaddress"
    case getwalletinfo = "getwalletinfo"
    case getblockchaininfo = "getblockchaininfo"
    case getbalance = "getbalance"
    case sendtoaddress = "sendtoaddress"
    case getunconfirmedbalance = "getunconfirmedbalance"
    case listtransactions = "listtransactions"
    case listunspent = "listunspent"
    case bumpfee = "bumpfee"
    case importprivkey = "importprivkey"
    case abandontransaction = "abandontransaction"
    case getpeerinfo = "getpeerinfo"
    case getnetworkinfo = "getnetworkinfo"
    case getmininginfo = "getmininginfo"
    case estimatesmartfee = "estimatesmartfee"
    case sendrawtransaction = "sendrawtransaction"
    case importaddress = "importaddress"
    case signmessagewithprivkey = "signmessagewithprivkey"
    case verifymessage = "verifymessage"
    case signmessage = "signmessage"
    case encryptwallet = "encryptwallet"
    case walletpassphrase = "walletpassphrase"
    case walletlock = "walletlock"
    case walletpassphrasechange = "walletpassphrasechange"
    case gettxoutsetinfo = "gettxoutsetinfo"
    case help = "help"
    case testmempoolaccept = "testmempoolaccept"
    case psbtbumpfee = "psbtbumpfee"
    case importdescriptors = "importdescriptors"
}

public enum LIGHTNING_CLI: String {
    case getinfo = "getinfo"
    case invoice = "invoice"
    case newaddr = "newaddr"
    case listfunds = "listfunds"
    case listtransactions = "listtransactions"
    case txprepare = "txprepare"
    case txsend = "txsend"
    case pay = "pay"
    case decodepay = "decodepay"
    case connect = "connect"
    case fundchannel_start = "fundchannel_start"
    case fundchannel_complete = "fundchannel_complete"
    case listpeers = "listpeers"
    case listsendpays = "listsendpays"
    case listinvoices = "listinvoices"
    case withdraw = "withdraw"
    case getroute = "getroute"
    case listchannels = "listchannels"
    case sendpay = "sendpay"
    case rebalance = "rebalance"
    case keysend = "keysend"
    case listnodes = "listnodes"
    case sendmsg = "sendmsg"
    case recvmsg = "recvmsg"
    case close = "close"
    case disconnect = "disconnect"
}

public enum LND_REST: String {
    case walletbalance
    case getinfo
    case channelbalance
    case addinvoice
    case payreq, decodepayreq
    case getnewaddress
    case sendcoins, gettransactions
    case routepayment
    case payinvoice
    case listpeers, connect
    case listchannels
    case getnodeinfo
    case queryroutes
    case openchannel
    case fundingstep
    case closechannel
    case fwdinghistory
    case disconnect
    case keysend
    case listpayments
    case listinvoices
    
    var stringValue:String {
        switch self {
        case .connect, .listpeers, .disconnect:
            return "v1/peers"
        case .sendcoins, .gettransactions:
            return "v1/transactions"
        case .payreq, .decodepayreq:
            return "v1/payreq"
        case .walletbalance:
            return "v1/balance/blockchain"
        case .getinfo:
            return "v1/getinfo"
        case .channelbalance:
            return "v1/balance/channels"
        case .addinvoice, .listinvoices:
            return "v1/invoices"
        case .getnewaddress:
            return "v2/wallet/address/next"
        case .routepayment:
            return "v1/channels/transactions/route"
        case .payinvoice, .keysend:
            return "v1/channels/transactions"
        case .listchannels, .openchannel, .closechannel:
            return "v1/channels"
        case .getnodeinfo:
            return "v1/graph/node"
        case .queryroutes:
            return "v1/graph/routes"
        case .fundingstep:
            return "v1/funding/step"
        case .fwdinghistory:
            return "v1/switch"
        case .listpayments:
            return "v1/payments"
        }
    }
}

public enum JM_REST {
    case walletall
    case walletcreate
    case lockwallet(jmWallet: JMWallet)
    case unlockwallet(jmWallet: JMWallet)
    case walletdisplay(jmWallet: JMWallet)
    case getaddress(jmWallet: JMWallet, mixDepth: Int)
    
    var stringValue:String {
        switch self {
        case .walletall:
            return "api/v1/wallet/all"
        case .walletcreate:
            return "api/v1/wallet/create"
        case .lockwallet(let wallet):
            return "api/v1/wallet/\(wallet.name)/lock"
        case .unlockwallet(jmWallet: let wallet):
            return "api/v1/wallet/\(wallet.name)/unlock"
        case .walletdisplay(jmWallet: let wallet):
            return "api/v1/wallet/\(wallet.name)/display"
        case .getaddress(jmWallet: let wallet, mixDepth: let mixDepth):
            return "wallet/\(wallet.name)/address/new/\(mixDepth)"
        }
    }
}
