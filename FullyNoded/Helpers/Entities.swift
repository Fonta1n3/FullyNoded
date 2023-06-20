//
//  Entities.swift
//  BitSense
//
//  Created by Peter on 19/09/19.
//  Copyright © 2019 Fontaine. All rights reserved.
//

import Foundation

// Core data entities

public enum ENTITY: String {
    case newNodes = "NewNodes"
    case authKeys = "AuthKeys"
    case signers = "Signers"
    case wallets = "Wallets"
    case peers = "Peers"
    case utxos = "Utxos"
    case transactions = "Transactions"
    case jmWallets = "JMWallets"
}

//public enum ENTITY_BACKUP: String {
//    case nodes = "Nodes_"
//    case authKeys = "AuthKeys_"
//    case signers = "Signers_"
//    case wallets = "Wallets_"
//    case jmWallets = "JMWallets_"
//}
