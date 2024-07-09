//
//  HDKey.swift
//  Gordian Seed Tool
//
//  Created by Wolf McNally on 1/21/21.
//

import SwiftUI
import URKit
import LibWally
import LifeHash

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
    
    convenience init(parent: HDKey_, derivedKeyType: KeyType, isDerivable: Bool) throws {
        guard parent.keyType == .private || derivedKeyType == .public else {
            // public -> private
            throw GeneralError("Cannot derive private key from public key.")
        }
        
        let chainCode = isDerivable ? parent.chainCode : nil
        if parent.keyType == derivedKeyType {
            // private -> private
            // public -> public
            self.init(name: parent.name, isMaster: parent.isMaster, keyType: derivedKeyType, keyData: parent.keyData, chainCode: chainCode, useInfo: parent.useInfo, origin: parent.origin, children: parent.children, parentFingerprint: parent.parentFingerprint)
        } else {
            // private -> public
            let pubKey = Data(of: parent.wallyExtKey.pub_key)
            
            self.init(name: parent.name, isMaster: parent.isMaster, keyType: derivedKeyType, keyData: pubKey, chainCode: chainCode, useInfo: parent.useInfo, origin: parent.origin, children: parent.children, parentFingerprint: parent.parentFingerprint)
        }
    }
    
//    convenience init(mnemonic: BIP39Mnemonic, path: BIP32Path, useInfo: UseInfo = .init()) {
//        let bip32Seed = mnemonic.seedHex()
//        let xx =
//        let key = try! LibWally.HDKey(seed: bip32Seed, network: useInfo.network.wallyNetwork)
//        
//        let isMaster = true
//        let keyType = KeyType.private
//        let keyData = Data(of: key.wally_ext_key.priv_key)
//        let chainCode = Data(of: key.wally_ext_key.chain_code)
//        let useInfo = UseInfo(asset: useInfo.asset, network: useInfo.network)
//        let origin: DerivationPath? = nil
//        let children: DerivationPath? = nil
//        let parentFingerprint: UInt32? = nil
//        
//        self.init(name: name, isMaster: isMaster, keyType: keyType, keyData: keyData, chainCode: chainCode, useInfo: useInfo, origin: origin, children: children, parentFingerprint: parentFingerprint)
//    }
    
    convenience init(parent: HDKey_, derivedKeyType: KeyType, childDerivation: DerivationStep) throws {
        guard parent.keyType == .private || derivedKeyType == .public else {
            throw GeneralError("Cannot derive private key from public key.")
        }
        guard parent.isDerivable else {
            throw GeneralError("Cannot derive from a non-derivable key.")
        }
        
        let isMaster = false
        let name = parent.name

        let parentFingerprint = parent.keyFingerprint
        var key = parent.wallyExtKey
        let childNum = try childDerivation.childNum()
        let flags: UInt32 = UInt32(derivedKeyType == .private ? BIP32_FLAG_KEY_PRIVATE : BIP32_FLAG_KEY_PUBLIC)
        var output = ext_key()
        let result = bip32_key_from_parent(&key, childNum, flags, &output)
        guard result == WALLY_OK else {
            throw GeneralError("Unknown problem deriving HDKey.")
        }

        let keyData = derivedKeyType == .private ? Data(of: output.priv_key) : Data(of: output.pub_key)
        let chainCode = Data(of: output.chain_code)
        let useInfo = parent.useInfo

        let origin: DerivationPath
        if let parentOrigin = parent.origin {
            var steps = parentOrigin.steps
            steps.append(childDerivation)
            let sourceFingerprint = parentOrigin.sourceFingerprint ?? parentFingerprint
            let depth: UInt8
            if let parentDepth = parentOrigin.depth {
                depth = parentDepth + 1
            } else {
                depth = 1
            }
            origin = DerivationPath(steps: steps, sourceFingerprint: sourceFingerprint, depth: depth)
        } else {
            origin = DerivationPath(steps: [childDerivation], sourceFingerprint: parentFingerprint, depth: 1)
        }
        
        let children: DerivationPath? = nil

        self.init(name: name, isMaster: isMaster, keyType: derivedKeyType, keyData: keyData, chainCode: chainCode, useInfo: useInfo, origin: origin, children: children, parentFingerprint: parentFingerprint)
    }
    
    convenience init(parent: HDKey_, derivedKeyType: KeyType, childDerivationPath: DerivationPath, isDerivable: Bool) throws {
        var key = parent
        for step in childDerivationPath.steps {
            key = try HDKey_(parent: key, derivedKeyType: parent.keyType, childDerivation: step)
        }
        try self.init(parent: key, derivedKeyType: derivedKeyType, isDerivable: isDerivable)
    }
    
    var keyFingerprintData: Data {
        var hdkey = wallyExtKey
        
        return withUnsafeByteBuffer(of: hdkey.pub_key) { pub_key in
            withUnsafeMutableByteBuffer(of: &hdkey.hash160) { hash160 in
                precondition(wally_hash160(pub_key.baseAddress, pub_key.count, hash160.baseAddress, hash160.count) == WALLY_OK)
                return Data(bytes: hash160.baseAddress!, count: Int(BIP32_KEY_FINGERPRINT_LEN))
            }
        }
    }

    var keyFingerprint: UInt32 {
        return UInt32(fromBigEndian: keyFingerprintData)
    }
    
    func base58(from key: ext_key) -> String? {
        guard !Data(of: key.chain_code).isAllZero else {
            return nil
        }
        var key = key
        guard key.version != 0 else { return nil }
        
        var output: UnsafeMutablePointer<Int8>?
        defer {
            wally_free_string(output)
        }
        
        let flags: UInt32
        switch keyType {
        case .private:
            flags = UInt32(BIP32_FLAG_KEY_PRIVATE)
        case .public:
            flags = UInt32(BIP32_FLAG_KEY_PUBLIC)
        }

        precondition(bip32_key_to_base58(&key, flags, &output) == WALLY_OK)
        precondition(output != nil)
        return String(cString: output!)
    }
    
    var base58: String? {
        base58(from: wallyExtKey)
    }

    private var wallyExtKey: ext_key {
        var k = ext_key()
        
        if let origin = origin {
            k.depth = origin.effectiveDepth

            if let lastStep = origin.steps.last,
               case let ChildIndexSpec.index(childIndex) = lastStep.childIndexSpec {
                let value = childIndex.value
                let isHardened = lastStep.isHardened
                let childNum = value | (isHardened ? 0x80000000 : 0)
                k.child_num = childNum
            }
        }
        
        switch keyType {
        case .private:
            keyData.store(into: &k.priv_key)
            withUnsafeByteBuffer(of: k.priv_key) { priv_key in
                withUnsafeMutableByteBuffer(of: &k.pub_key) { pub_key in
                    precondition(wally_ec_public_key_from_private_key(
                        priv_key.baseAddress! + 1, Int(EC_PRIVATE_KEY_LEN),
                        pub_key.baseAddress!, Int(EC_PUBLIC_KEY_LEN)
                    ) == WALLY_OK)
                }
            }
            
            if let useinfo = useInfo {
                switch useinfo.network {
                case .mainnet:
                    k.version = UInt32(BIP32_VER_MAIN_PRIVATE)
                case .testnet:
                    k.version = UInt32(BIP32_VER_TEST_PRIVATE)
                }
            } else {
                let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
                
                if chain == "main" {
                    k.version = UInt32(BIP32_VER_MAIN_PRIVATE)
                } else {
                    k.version = UInt32(BIP32_VER_TEST_PRIVATE)
                }
            }
        case .public:
            k.priv_key.0 = 0x01;
            keyData.store(into: &k.pub_key)
            
            if let useinfo = useInfo {
                switch useinfo.network {
                case .mainnet:
                    k.version = UInt32(BIP32_VER_MAIN_PUBLIC)
                case .testnet:
                    k.version = UInt32(BIP32_VER_TEST_PUBLIC)
                }
            } else {
                let chain = UserDefaults.standard.object(forKey: "chain") as? String ?? "main"
                
                if chain == "main" {
                    k.version = UInt32(BIP32_VER_MAIN_PUBLIC)
                } else {
                    k.version = UInt32(BIP32_VER_TEST_PUBLIC)
                }
            }
        }
        
        let hash160Size = MemoryLayout.size(ofValue: k.hash160)
        withUnsafeByteBuffer(of: k.pub_key) { pub_key in
            withUnsafeMutableByteBuffer(of: &k.hash160) { hash160 in
                precondition(wally_hash160(
                    pub_key.baseAddress!, Int(EC_PUBLIC_KEY_LEN),
                    hash160.baseAddress!, hash160Size
                ) == WALLY_OK)
            }
        }
        
        if let chainCode = chainCode {
            chainCode.store(into: &k.chain_code)
        }
        
        if let parentFingerprint = parentFingerprint {
            parentFingerprint.bigEndianData.store(into: &k.parent160)
        }
        
        k.checkValid()
        return k
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
            //a.append(.init(key: 1, value: true))
            a.insert(CBOR.unsigned(1), CBOR(booleanLiteral: true))
        }
        
        if keyType == .private {
            //a.append(.init(key: 2, value: true))
            a.insert(CBOR.unsigned(2), CBOR(booleanLiteral: true))
        }
        
        //a.append(.init(key: 3, value: CBOR.byteString(keyData.bytes)))
        a.insert(CBOR.unsigned(3), CBOR.bytes(keyData.cborData))
        
        if let chainCode = chainCode {
            //a.append(.init(key: 4, value: CBOR.byteString(chainCode.bytes)))
            a.insert(CBOR.unsigned(4), CBOR.bytes(chainCode.cborData))
        }
        
        if let useinfo = useInfo {
            if !useinfo.isDefault {
                //a.append(.init(key: 5, value: useinfo.taggedCBOR))
                a.insert(CBOR.unsigned(5), useinfo.taggedCBOR)
            }
        }
        
        if let origin = origin {
            //a.append(.init(key: 6, value: origin.taggedCBOR))
            a.insert(CBOR.unsigned(6), origin.taggedCBOR)
        }
        
        if let children = children {
            //a.append(.init(key: 7, value: children.taggedCBOR))
            a.insert(CBOR.unsigned(7), children.taggedCBOR)
        }
        
        if let parentFingerprint = parentFingerprint {
            //a.append(.init(key: 8, value: CBOR.unsignedInt(UInt64(parentFingerprint))))
            a.insert(CBOR.unsigned(8), CBOR.unsigned(UInt64(parentFingerprint)))
        }
        
        //return CBOR.orderedMap(a)
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
            print("HDKey: Doesn't contain a map.")
            throw GeneralError("HDKey: Doesn't contain a map.")
        }
        
        guard let isMaster = try? BooleanLiteralType(cbor: pairs[1] ?? CBOR(booleanLiteral: false)) else {
            print("HDKey: Invalid `isMaster` field.")
            throw GeneralError("HDKey: Invalid `isMaster` field.")
        }
        
//        guard case let CBOR.boolean(isMaster) = pairs[1] ?? CBOR.boolean(false) else {
//            print("HDKey: Invalid `isMaster` field.")
//            throw GeneralError("HDKey: Invalid `isMaster` field.")
//        }
        
        guard let isPrivate = try? BooleanLiteralType(cbor: pairs[2] ?? CBOR(booleanLiteral: isMaster)) else {
            print("HDKey: Invalid `isPrivate` field.")
            throw GeneralError("HDKey: Invalid `isPrivate` field.")
        }
        
//        guard case let CBOR.boolean(isPrivate) = pairs[2] ?? CBOR.boolean(isMaster) else {
//            print("HDKey: Invalid `isPrivate` field.")
//            throw GeneralError("HDKey: Invalid `isPrivate` field.")
//        }
        
        if isMaster && !isPrivate {
            print("HDKey: Master key cannot be public.")
            throw GeneralError("HDKey: Master key cannot be public.")
        }
        
        guard case let CBOR.bytes(keyDataValue) = pairs[3] ?? CBOR.null,
            keyDataValue.count == 33 else {
            print("HDKey: Invalid key data.")
            throw GeneralError("HDKey: Invalid key data.")
        }
        
        let keyData = Data(keyDataValue)
        
        let chainCode: Data?
        if let chainCodeItem = pairs.get(4) {
            guard case let CBOR.bytes(chainCodeValue) = chainCodeItem,
                chainCodeValue.count == 32 else {
                print("HDKey: Invalid key chain code.")
                throw GeneralError("HDKey: Invalid key chain code.")
            }
            chainCode = Data(chainCodeValue)
        } else {
            chainCode = nil
        }
        
        let useInfo: UseInfo? = nil
//        if let useInfoItem = pairs[5] {
//            useInfo = try UseInfo(taggedCBOR: useInfoItem)
//        } else {
//            useInfo = nil
//        }
//
//        print("useInfo: \(useInfo)")
        
        
        
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
                print("HDKey: Invalid parent fingerprint.")
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
        print("convenience init(taggedCBOR: CBOR)")
        
//        guard case let CBOR.tagged(.hdKeyV1, cbor) = taggedCBOR else {
//            print("HDKeyV1 tag (303) not found.")
//            throw GeneralError("HDKeyV1 tag (303) not found.")
//        }
        
        guard case let CBOR.tagged(.hdKey, cbor) = taggedCBOR else {
            print("HDKey tag (303) not found.")
            throw GeneralError("HDKey tag (303) not found.")
        }
        
        try self.init(cbor: cbor)
    }
}

extension HDKey_: Fingerprintable {
    var fingerprintData: Data {
        var result: [CBOR] = []

        result.append(CBOR.bytes(keyData.cborData))

        if let chainCode = chainCode {
            result.append(CBOR.bytes(chainCode.cborData))
        } else {
            result.append(CBOR.null)
        }
        
        if let useinfo = useInfo {
            result.append(CBOR.unsigned(UInt64(useinfo.asset.rawValue)))
            result.append(CBOR.unsigned(UInt64(useinfo.network.rawValue)))
        }
        
        return result.cborData
    }
}

extension ext_key: CustomStringConvertible {
    public var description: String {
        let chain_code = Data(of: self.chain_code).hex
        let parent160 = Data(of: self.parent160).hex
        let depth = self.depth
        let priv_key = Data(of: self.priv_key).hex
        let child_num = self.child_num
        let hash160 = Data(of: self.hash160).hex
        let version = self.version
        let pub_key = Data(of: self.pub_key).hex
        
        return "ext_key(chain_code: \(chain_code), parent160: \(parent160), depth: \(depth), priv_key: \(priv_key), child_num: \(child_num), hash160: \(hash160), version: \(version), pub_key: \(pub_key))"
    }
    
    public var isPrivate: Bool {
        return priv_key.0 == BIP32_FLAG_KEY_PRIVATE
    }
    
    public var isMaster: Bool {
        return depth == 0
    }
    
    static func version_is_valid(ver: UInt32, flags: UInt32) -> Bool
    {
        if ver == BIP32_VER_MAIN_PRIVATE || ver == BIP32_VER_TEST_PRIVATE {
            return true
        }

        return flags == BIP32_FLAG_KEY_PUBLIC &&
               (ver == BIP32_VER_MAIN_PUBLIC || ver == BIP32_VER_TEST_PUBLIC)
    }

    public func checkValid() {
        let ver_flags = isPrivate ? UInt32(BIP32_FLAG_KEY_PRIVATE) : UInt32(BIP32_FLAG_KEY_PUBLIC)
        precondition(Self.version_is_valid(ver: version, flags: ver_flags))
        precondition(pub_key.0 == 0x2 || pub_key.0 == 0x3)
        precondition(!Data(of: pub_key).dropFirst().isAllZero)
        precondition(priv_key.0 == BIP32_FLAG_KEY_PUBLIC || priv_key.0 == BIP32_FLAG_KEY_PRIVATE)
        precondition(!isPrivate || !Data(of: priv_key).dropFirst().isAllZero)
        precondition(!isMaster || Data(of: parent160).isAllZero)
    }
}
