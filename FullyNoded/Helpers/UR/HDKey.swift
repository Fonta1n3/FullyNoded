//
//  HDKey.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/21/21.
//

import SwiftUI
//import LifeHash

final class HDKey_: ModelObject {
    let id: UUID
    @Published var name: String
    let isMaster: Bool
    let keyType: KeyType
    let keyData: Data
    let chainCode: Data?
    let useInfo: UseInfo?
    let origin: DerivationPath?
    let children: DerivationPath?
    let parentFingerprint: UInt32?

    var modelObjectType: ModelObjectType {
        switch keyType {
        case .private:
            return .privateKey
        case .public:
            return .publicKey
        }
    }

    private init(id: UUID = UUID(), name: String, isMaster: Bool, keyType: KeyType, keyData: Data, chainCode: Data? = nil, useInfo: UseInfo?, origin: DerivationPath? = nil, children: DerivationPath? = nil, parentFingerprint: UInt32? = nil)
    {
        self.id = id
        self.name = name
        self.isMaster = isMaster
        self.keyType = keyType
        self.keyData = keyData
        if let chainCode = chainCode {
            if chainCode.isAllZero {
                self.chainCode = nil
            } else {
                self.chainCode = chainCode
            }
        } else {
            self.chainCode = nil
        }
        self.useInfo = useInfo
        self.origin = origin
        self.children = children
        self.parentFingerprint = parentFingerprint
    }
    
    var isDerivable: Bool {
        chainCode != nil
    }

    /// Compressed public key: the key itself, or derived from the private key.
    private var publicKeyData: Data? {
        switch keyType {
        case .public:
            return keyData
        case .private:
            // keyData is 0x00 ‖ 32-byte private key.
            return Keys.compressedPublicKey(privateKey: keyData.dropFirst())
        }
    }

    /// First 4 bytes of HASH160(public key).
    var keyFingerprintData: Data {
        SPHashFN.hash160(publicKeyData ?? Data()).prefix(4)
    }

    /// BIP32 base58check serialization (xpub / tpub / xprv / tprv), nil without a chain
    /// code. The network comes from `useInfo`, else the app's current chain.
    var base58: String? {
        guard let chainCode = chainCode else { return nil }

        let isMainnet: Bool
        if let useInfo = useInfo {
            switch useInfo.network {
            case .mainnet:
                isMainnet = true
            case .testnet:
                isMainnet = false
            }
        } else {
            isMainnet = (UserDefaults.standard.object(forKey: "chain") as? String ?? "main") == "main"
        }

        let version: UInt32
        switch keyType {
        case .private:
            version = isMainnet ? 0x0488ADE4 : 0x04358394   // xprv / tprv
        case .public:
            version = isMainnet ? 0x0488B21E : 0x043587CF   // xpub / tpub
        }

        var depth: UInt8 = 0
        var childNumber: UInt32 = 0
        if let origin = origin {
            depth = origin.effectiveDepth
            if let lastStep = origin.steps.last,
               case let ChildIndexSpec.index(childIndex) = lastStep.childIndexSpec {
                childNumber = childIndex.value | (lastStep.isHardened ? 0x80000000 : 0)
            }
        }

        return Keys.serializeExtendedKey(version: version,
                                         depth: depth,
                                         parentFingerprint: parentFingerprint ?? 0,
                                         childNumber: childNumber,
                                         chainCode: chainCode,
                                         key: keyData)
    }
}

extension HDKey_ {
    var instanceDetail: String? {
        var result: [String] = []
        
        if let origin = origin {
            result.append("[\(origin.description)]")
            result.append("➜")
        }

        result.append(keyFingerprintData.hex)

        return result.joined(separator: " ")
    }
}

extension HDKey_: Equatable {
    static func == (lhs: HDKey_, rhs: HDKey_) -> Bool {
        lhs.id == rhs.id
    }
}

extension HDKey_ {
    var cbor: CBOR {
        var a: Map = [:]
        
        if isMaster {
            a.insert(CBOR.unsigned(1), CBOR(booleanLiteral: true))
        }
        
        if keyType == .private {
            a.insert(CBOR.unsigned(2), CBOR(booleanLiteral: true))
        }
        
        a.insert(CBOR.unsigned(3), CBOR.bytes(keyData.cborData))
        
        if let chainCode = chainCode {
            a.insert(CBOR.unsigned(4), CBOR.bytes(chainCode.cborData))
        }
        
        if let useinfo = useInfo {
            if !useinfo.isDefault {
                a.insert(CBOR.unsigned(5), useinfo.taggedCBOR)
            }
        }
        
        if let origin = origin {
            a.insert(CBOR.unsigned(6), origin.taggedCBOR)
        }
        
        if let children = children {
            a.insert(CBOR.unsigned(7), children.taggedCBOR)
        }
        
        if let parentFingerprint = parentFingerprint {
            a.insert(CBOR.unsigned(8), CBOR.unsigned(UInt64(parentFingerprint)))
        }
        
        return CBOR.map(a)
    }
    
    var taggedCBOR: CBOR {
        CBOR.tagged(.hdKey, cbor)
    }

    var ur: UR {
        return try! UR(type: "crypto-hdkey", cbor: cbor)
    }
    
    var sizeLimitedUR: UR {
        return ur
    }

    convenience init(cbor: CBOR) throws {
        guard case let CBOR.map(pairs) = cbor else {
            throw GeneralError("HDKey: Doesn't contain a map.")
        }
        
        guard let isMaster = try? BooleanLiteralType(cbor: pairs[1] ?? CBOR(booleanLiteral: false)) else {
            throw GeneralError("HDKey: Invalid `isMaster` field.")
        }

        guard let isPrivate = try? BooleanLiteralType(cbor: pairs[2] ?? CBOR(booleanLiteral: isMaster)) else {
            throw GeneralError("HDKey: Invalid `isPrivate` field.")
        }

        if isMaster && !isPrivate {
            throw GeneralError("HDKey: Master key cannot be public.")
        }
        
        guard case let CBOR.bytes(keyDataValue) = pairs[3] ?? CBOR.null,
            keyDataValue.count == 33 else {
            throw GeneralError("HDKey: Invalid key data.")
        }
        
        let keyData = Data(keyDataValue)
        
        let chainCode: Data?
        if let chainCodeItem = pairs.get(4) {
            guard case let CBOR.bytes(chainCodeValue) = chainCodeItem,
                chainCodeValue.count == 32 else {
                throw GeneralError("HDKey: Invalid key chain code.")
            }
            chainCode = Data(chainCodeValue)
        } else {
            chainCode = nil
        }
        
        let useInfo: UseInfo? = nil

        let origin: DerivationPath?
        if let originItem = pairs.get(6) {
            origin = try DerivationPath(taggedCBOR: originItem)
        } else {
            origin = nil
        }
                        
        let children: DerivationPath?
        if let childrenItem = pairs.get(7) {
            children = try DerivationPath(taggedCBOR: childrenItem)
        } else {
            children = nil
        }
                
        let parentFingerprint: UInt32?
        if let parentFingerprintItem = pairs.get(8) {
            guard
                case let CBOR.unsigned(parentFingerprintValue) = parentFingerprintItem,
                parentFingerprintValue > 0,
                parentFingerprintValue <= UInt32.max
            else {
                throw GeneralError("HDKey: Invalid parent fingerprint.")
            }
            parentFingerprint = UInt32(parentFingerprintValue)
        } else {
            parentFingerprint = nil
        }
        
        let keyType: KeyType = isPrivate ? .private : .public
                
        self.init(name: "", isMaster: isMaster, keyType: keyType, keyData: keyData, chainCode: chainCode, useInfo: useInfo, origin: origin, children: children, parentFingerprint: parentFingerprint)
    }
    
    convenience init(taggedCBOR: CBOR) throws {
        guard case let CBOR.tagged(.hdKey, cbor) = taggedCBOR else {
            throw GeneralError("HDKey tag (303) not found.")
        }
        
        try self.init(cbor: cbor)
    }
}

