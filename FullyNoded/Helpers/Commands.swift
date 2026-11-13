//
//  Commands.swift
//  BitSense
//
//  Created by Peter on 24/03/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

public enum BTC_CLI_COMMAND {
    case getblock(_ param: Get_Block)
    case getblockhash(_ param: Get_Block_Hash)
    case getblockheader(_ param: Get_Block_Header)
    case getblockstats(_ param: Get_Block_Stats)
    case getblocktemplate(_ param: Get_Block_Template)
    case gettxout(_ param: Get_Tx_Out)
    case getnettotals
    case getbalances
    case listaddressgroupings
    case listreceivedbyaddress(_ param: List_Received_By_Address)
    case listsinceblock(_ param: List_Since_Block)
    case abandontransaction(_ param: Abandon_Transaction)
    case getchaintips
    case getnetworkhashps(_ param: Get_Network_Hash_PS)
    case getmempoolentry(_ param: Get_Mempool_Entry)
    case gettxspendingprevout(_ param: Get_Tx_Spending_Prevout)
    case listdescriptors
    case setban(_ param: Set_Ban)
    case scantxoutset(_ param: Scan_Tx_Out)
    case abortrescan
    case listlockunspent
    case lockunspent(_ param: Lock_Unspent)
    case combinepsbt
    case utxoupdatepsbt(_ param: Utxo_Update_Psbt)
    case converttopsbt
    case getaddressinfo(param: Get_Address_Info)
    case analyzepsbt(param: Analyze_PSBT)
    case createpsbt(_ param: Create_Psbt)
    case joinpsbts(_ param: Join_Psbt)
    case getmempoolinfo
    case listwallets
    case unloadwallet(param: Unload_Wallet)
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
    case getwalletinfo
    case getblockchaininfo
    case getbalance(param: Get_Balance_Param)
    case listtransactions(_ param: List_Transactions)
    case listunspent(_ param: List_Unspent)
    case bumpfee(param: Bump_Fee)
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
    case setlabel(param: Set_Label_Param)
    
    var stringValue:String {
        switch self {
        case .getblock:
            return "getblock"
        case .getblockhash:
            return "getblockhash"
        case .getblockheader:
            return "getblockheader"
        case .getblockstats:
            return "getblockstats"
        case .getblocktemplate:
            return "getblocktemplate"
        case .gettxout:
            return "gettxout"
        case .getnettotals:
            return "getnettotals"
        case .getbalances:
            return "getbalances"
        case .listaddressgroupings:
            return "listaddressgroupings"
        case .listreceivedbyaddress:
            return "listreceivedbyaddress"
        case .listsinceblock:
            return "listsinceblock"
        case .abandontransaction:
            return "abandontransaction"
        case .getchaintips:
            return "getchaintips"
        case .getnetworkhashps:
            return "getnetworkhashps"
        case .getmempoolentry:
            return "getmempoolentry"
        case .gettxspendingprevout:
            return "gettxspendingprevout"
        case .listdescriptors:
            return "listdescriptors"
        case .setban:
            return "setban"
        case .setlabel:
            return "setlabel"
        case .scantxoutset:
            return "scantxoutset"
        case .abortrescan:
            return "abortrescan"
        case .listlockunspent:
            return "listlockunspent"
        case .lockunspent:
            return "lockunspent"
        case .combinepsbt:
            return "combinepsbt"
        case .utxoupdatepsbt:
            return "utxoupdatepsbt"
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
        case .getwalletinfo:
            return "getwalletinfo"
        case .getblockchaininfo:
            return "getblockchaininfo"
        case .listtransactions:
            return "listtransactions"
        case .listunspent:
            return "listunspent"
        case .bumpfee:
            return "bumpfee"
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
        case .getblock(param: let getBlock):
            return getBlock.param
        case .getblockhash(param: let getBlockhash):
            return getBlockhash.param
        case .getblockheader(let p):
            return p.param
        case .getblockstats(let p):
            return p.param
        case .getblocktemplate(let p):
            return p.param
        case .gettxout(let p):
            return p.param
        case .getnetworkhashps(let p):
            return p.param
        case .getmempoolentry(let p):
            return p.param
        case .listreceivedbyaddress(let p):
            return p.param
        case .listsinceblock(let p):
            return p.param
        case .abandontransaction(let p):
            return p.param
        case .gettxspendingprevout(let p):
            return p.param
        case .setban(param: let setBan):
            return setBan.param
        case .setlabel(param: let setLabel):
            return setLabel.param
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
        case.unloadwallet(param: let p):
            return p.param
        default:
            return [:]
        }
    }
    
    static let all: [BTC_CLI_COMMAND] = [
        listdescriptors,
        setban(.init(dict: [:])),
        setlabel(param: .init([:])),
        scantxoutset(.init([:])),
        abortrescan,
        listlockunspent,
        lockunspent(.init([:])),
        combinepsbt,
        utxoupdatepsbt(.init([:])),
        //listaddressgroupings,
        converttopsbt,
        getaddressinfo(param: .init([:])),
        analyzepsbt(param: .init([:])),
        createpsbt(.init([:])),
        joinpsbts(.init([:])),
        getmempoolinfo,
        //signrawtransactionwithkey,
        listwallets,
        unloadwallet(param: .init([:])),
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
        getwalletinfo,
        getblockchaininfo,
        getbalance(param: .init([:])),
        //sendtoaddress,
        listtransactions(.init([:])),
        listunspent(.init([:])),
        bumpfee(param: .init([:])),
        //importprivkey,
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
