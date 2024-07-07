//
//  Commands.swift
//  BitSense
//
//  Created by Peter on 24/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

public enum BTC_CLI_COMMAND {
    case scantxoutset(_ param: Scan_Tx_Out)
    case abortrescan
    case listlockunspent
    case lockunspent(_ param: Lock_Unspent)
    case getblock
    case getbestblockhash
    case getaddressesbylabel
    case listlabels
    case decodescript
    case combinepsbt
    case utxoupdatepsbt(_ param: Utxo_Update_Psbt)
    case listaddressgroupings
    case converttopsbt
    case getaddressinfo(param: Get_Address_Info)
    case analyzepsbt(param: Analyze_PSBT)
    case createpsbt(_ param: Create_Psbt)
    case joinpsbts(_ param: Join_Psbt)
    case getmempoolinfo
    case signrawtransactionwithkey
    case listwallets
    case unloadwallet
    case rescanblockchain(_ param: Rescan_Blockchain)
    case listwalletdir
    case loadwallet(_ param: Load_Wallet)
    case createwallet(param: Create_Wallet_Param)
    case finalizepsbt(_ param: Finalize_Psbt)
    case walletprocesspsbt(param: Wallet_Process_PSBT)
    case decodepsbt(param: Decode_Psbt)
    case walletcreatefundedpsbt(param: Wallet_Create_Funded_Psbt)
    case uptime
    case importmulti
    case getdescriptorinfo(param: Get_Descriptor_Info)
    case deriveaddresses(param: Derive_Addresses)
    case getrawtransaction(param: Get_Raw_Tx)
    case decoderawtransaction(param: Decode_Raw_Tx)
    case getnewaddress(param: Get_New_Address)
    case gettransaction(_ param: Get_Tx)
    case createrawtransaction
    case getrawchangeaddress
    case getwalletinfo
    case getblockchaininfo
    case getbalance(param: Get_Balance_Param)
    case sendtoaddress
    case listtransactions(_ param: List_Transactions)
    case listunspent(_ param: List_Unspent)
    case bumpfee(param: Bump_Fee)
    case importprivkey
    case getpeerinfo
    case getnetworkinfo
    case getmininginfo
    case estimatesmartfee(param: Estimate_Smart_Fee_Param)
    case sendrawtransaction(_ param: Send_Raw_Transaction)
    case encryptwallet(_ param: Encrypt_Wallet)
    case walletpassphrase(param: Wallet_Passphrase)
    case walletlock
    case walletpassphrasechange(_ param: Wallet_Change_Passphrase)
    case gettxoutsetinfo
    case testmempoolaccept(_ param: Test_Mempool_Accept)
    case psbtbumpfee(param: PSBT_Bump_Fee)
    case importdescriptors(param: Import_Descriptors)
    
    var stringValue:String {
        switch self {
        case .scantxoutset:
            return "scantxoutset"
        case .abortrescan:
            return "abortrescan"
        case .listlockunspent:
            return "listlockunspent"
        case .lockunspent:
            return "lockunspent"
        case .getblock:
            return "getblock"
        case .getbestblockhash:
            return "getbestblockhash"
        case .getaddressesbylabel:
            return "getaddressesbylabel"
        case .listlabels:
            return "listlabels"
        case .decodescript:
            return "decodescript"
        case .combinepsbt:
            return "combinepsbt"
        case .utxoupdatepsbt:
            return "utxoupdatepsbt"
        case .listaddressgroupings:
            return "listaddressgroupings"
        case .converttopsbt:
            return "converttopsbt"
        case .getaddressinfo:
            return "getaddressinfo"
        case .analyzepsbt:
            return "analyzepsbt"
        case .createpsbt:
            return "createpsbt"
        case .joinpsbts:
            return "joinpsbts"
        case .getmempoolinfo:
            return "getmempoolinfo"
        case .signrawtransactionwithkey:
            return "signrawtransactionwithkey"
        case .listwallets:
            return "listwallets"
        case .unloadwallet:
            return "unloadwallet"
        case .rescanblockchain:
            return "rescanblockchain"
        case .listwalletdir:
            return "listwalletdir"
        case .loadwallet:
            return "loadwallet"
        case .finalizepsbt:
            return "finalizepsbt"
        case .walletprocesspsbt:
            return "walletprocesspsbt"
        case .decodepsbt:
            return "decodepsbt"
        case .walletcreatefundedpsbt:
            return "walletcreatefundedpsbt"
        case .uptime:
            return "uptime"
        case .importmulti:
            return "importmulti"
        case .getdescriptorinfo:
            return "getdescriptorinfo"
        case .deriveaddresses:
            return "deriveaddresses"
        case .getrawtransaction:
            return "getrawtransaction"
        case .decoderawtransaction:
            return "decoderawtransaction"
        case .getnewaddress:
            return "getnewaddress"
        case .gettransaction:
            return "gettransaction"
        case .createrawtransaction:
            return "createrawtransaction"
        case .getrawchangeaddress:
            return "getrawchangeaddress"
        case .getwalletinfo:
            return "getwalletinfo"
        case .getblockchaininfo:
            return "getblockchaininfo"
        case .sendtoaddress:
            return "sendtoaddress"
        case .listtransactions:
            return "listtransactions"
        case .listunspent:
            return "listunspent"
        case .bumpfee:
            return "bumpfee"
        case .importprivkey:
            return "importprivkey"
        case .getpeerinfo:
            return "getpeerinfo"
        case .getnetworkinfo:
            return "getnetworkinfo"
        case .getmininginfo:
            return "getmininginfo"
        case .estimatesmartfee:
            return "estimatesmartfee"
        case .sendrawtransaction:
            return "sendrawtransaction"
        case .encryptwallet:
            return "encryptwallet"
        case .walletpassphrase:
            return "walletpassphrase"
        case .getbalance:
            return "getbalance"
        case .createwallet:
            return "createwallet"
        case .importdescriptors:
            return "importdescriptors"
        case .psbtbumpfee:
            return "psbtbumpfee"
        case .testmempoolaccept:
            return "testmempoolaccept"
        case .gettxoutsetinfo:
            return "gettxoutsetinfo"
        case .walletpassphrasechange:
            return "walletpassphrasechange"
        case .walletlock:
            return "walletlock"
       }
    }
    
    var paramDict:[String:Any] {
        switch self {
        case .analyzepsbt(param: let analyzePsbt):
            return analyzePsbt.param
        case .getbalance(param: let getBalance):
            return getBalance.param
        case .createwallet(param: let createWallet):
            return createWallet.param
        case .estimatesmartfee(param: let estimateSmartFee):
            return estimateSmartFee.param
        case .getdescriptorinfo(param: let descInfo):
            return descInfo.param
        case .importdescriptors(param: let importDesc):
            return importDesc.param
        case .walletprocesspsbt(param: let walletProcessPsbt):
            return walletProcessPsbt.param
        case .walletpassphrase(param: let walletPassphrase):
            return walletPassphrase.param
        case .deriveaddresses(param: let deriveAddresses):
            return deriveAddresses.param
        case .getnewaddress(param: let getNewAddress):
            return getNewAddress.param
        case .decodepsbt(param: let decodePsbt):
            return decodePsbt.param
        case .decoderawtransaction(param: let decodeRaw):
            return decodeRaw.param
        case .getaddressinfo(param: let getAddressInfo):
            return getAddressInfo.param
        case .testmempoolaccept(param: let testAccept):
            return testAccept.param
        case .getrawtransaction(param: let getTx):
            return getTx.param
        case .gettransaction(param: let getTx):
            return getTx.param
        case .walletcreatefundedpsbt(param: let walletCreatePsbt):
            return walletCreatePsbt.param
        case .walletpassphrasechange(param: let changePassphrase):
            return changePassphrase.param
        case .listtransactions(para: let listTransactions):
            return listTransactions.param
        case .rescanblockchain(let rescanBlockchain):
            return rescanBlockchain.param
        case .listunspent(let listUnspent):
            return listUnspent.param
        case .joinpsbts(let joinPsbt):
            return joinPsbt.param
        case .finalizepsbt(let finalizePsbt):
            return finalizePsbt.param
        case .sendrawtransaction(let p):
            return p.param
        case .psbtbumpfee(param: let p):
            return p.param
        case .loadwallet(let p):
            return p.param
        case .createpsbt(let p):
            return p.param
        case .utxoupdatepsbt(let p):
            return p.param
        case .scantxoutset(let p):
            return p.param
        case .lockunspent(let p):
            return p.param
        default:
            return [:]
        }
    }
    
    static let all: [BTC_CLI_COMMAND] = [
        scantxoutset(.init([:])),
        abortrescan,
        listlockunspent,
        lockunspent(.init([:])),
        getblock,
        getbestblockhash,
        getaddressesbylabel,
        listlabels,
        decodescript,
        combinepsbt,
        utxoupdatepsbt(.init([:])),
        listaddressgroupings,
        converttopsbt,
        getaddressinfo(param: .init([:])),
        analyzepsbt(param: .init([:])),
        createpsbt(.init([:])),
        joinpsbts(.init([:])),
        getmempoolinfo,
        signrawtransactionwithkey,
        listwallets,
        unloadwallet,
        rescanblockchain(.init([:])),
        listwalletdir,
        loadwallet(.init([:])),
        createwallet(param: .init([:])),
        finalizepsbt(.init([:])),
        walletprocesspsbt(param: .init([:])),
        decodepsbt(param: .init([:])),
        walletcreatefundedpsbt(param: .init([:])),
        uptime,
        importmulti,
        getdescriptorinfo(param: .init([:])),
        deriveaddresses(param: .init([:])),
        getrawtransaction(param: .init([:])),
        decoderawtransaction(param: .init([:])),
        getnewaddress(param: .init([:])),
        gettransaction(.init([:])),
        createrawtransaction,
        getrawchangeaddress,
        getwalletinfo,
        getblockchaininfo,
        getbalance(param: .init([:])),
        sendtoaddress,
        listtransactions(.init([:])),
        listunspent(.init([:])),
        bumpfee(param: .init([:])),
        importprivkey,
        getpeerinfo,
        getnetworkinfo,
        getmininginfo,
        estimatesmartfee(param: .init([:])),
        sendrawtransaction(.init([:])),
        encryptwallet(.init([:])),
        walletpassphrase(param: .init([:])),
        walletlock,
        walletpassphrasechange(.init([:])),
        gettxoutsetinfo,
        testmempoolaccept(.init([:])),
        psbtbumpfee(param: .init([:])),
        importdescriptors(param: .init([:]))
    ]
    
    init?(_ rawDesc: String) {
        var c:BTC_CLI_COMMAND?
        for com in BTC_CLI_COMMAND.all {
            switch com {
            case _ where rawDesc == com.stringValue:
                c = com
            default:
                break
            }
        }
        guard let c = c else { return nil }
        self = c
    }
}



public enum LIGHTNING_CLI: String {
    case listconfigs = "listconfigs"
    case getinfo = "getinfo"
    case invoice = "invoice"
    case offer = "offer"
    case fetchinvoice = "fetchinvoice"
    case newaddr = "newaddr"
    case listfunds = "listfunds"
    case listtransactions = "listtransactions"
    case txprepare = "txprepare"
    case txsend = "txsend"
    case pay = "pay"
    case decode = "decode"
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

let rootUrl = "api/v1"

public enum JM_REST {
    case walletall
    case walletcreate
    case session
    case lockwallet(jmWallet: Wallet)
    case unlockwallet(jmWallet: Wallet)
    case walletdisplay(jmWallet: Wallet)
    case getaddress(jmWallet: Wallet, mixdepth: Int)
    case coinjoin(jmWallet: Wallet)
    case makerStart(jmWallet: Wallet)
    case makerStop(jmWallet: Wallet)
    case takerStop(jmWallet: Wallet)
    case configGet(jmWallet: Wallet)
    case configSet(jmWallet: Wallet)
    case gettimelockaddress(jmWallet: Wallet, date: String)
    case getSeed(jmWallet: Wallet)
    case unfreeze(jmWallet: Wallet)
    case listutxos(jmWallet: Wallet)
    case directSend(jmWallet: Wallet)
    
    var stringValue:String {
        switch self {
        case .walletall:
            return "\(rootUrl)/wallet/all"
        case .session:
            return "\(rootUrl)/session"
        case .walletcreate:
            return "\(rootUrl)/wallet/create"
        case .lockwallet(let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/lock"
        case .unlockwallet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/unlock"
        case .walletdisplay(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/display"
        case .getaddress(jmWallet: let wallet, mixdepth: let mixdepth):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/address/new/\(mixdepth)"
        case .coinjoin(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/coinjoin"
        case .makerStart(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/maker/start"
        case .makerStop(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/maker/stop"
        case .takerStop(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/stop"
        case .configGet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/configget"
        case .configSet(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/configset"
        case .gettimelockaddress(jmWallet: let wallet, date: let date):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/address/timelock/new/\(date)"
        case .getSeed(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/getseed"
        case .unfreeze(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/freeze"
        case .listutxos(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/utxos"
        case .directSend(jmWallet: let wallet):
            return "\(rootUrl)/wallet/\(wallet.jmWalletName)/taker/direct-send"
        }
    }
}
