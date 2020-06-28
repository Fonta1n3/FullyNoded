import LibWally

BIP39Words.first!

let mnemonic = BIP39Mnemonic("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")

mnemonic!.words.count
mnemonic!.description

// Initialize mnemonic from entropy:
let bytes = [Int8](repeating: 0, count: 16)
BIP39Entropy(Data(bytes: bytes, count: 16))

// Or from hex string:
BIP39Mnemonic(BIP39Entropy("00000000000000000000000000000000")!)

// The seed hex is the starting point for BIP32 deriviation. It can take an optional BIP39 passphrase.
// https://github.com/trezor/python-mnemonic/blob/master/vectors.json#L6
let seedHex: BIP39Seed = mnemonic!.seedHex("TREZOR")
let masterKey = HDKey(seedHex, .mainnet)!
masterKey.description
// Wallets are often identified by their master fingerprint
masterKey.fingerprint.hexString
let path = BIP32Path("m/44'/0'/0'")!
var account = try! masterKey.derive(path)
account.xpub
account.address(.payToWitnessPubKeyHash)

var address = Address("bc1q6zwjfmhdl4pvhvfpv8pchvtanlar8hrhqdyv0t")
address?.scriptPubKey
address?.scriptPubKey.type

// Constructing a transaction on testnet
//
// Destination address. We only need public keys for this, so start by parsing a tpub (xpub for testnet):
account = HDKey("tpubDDgEAMpHn8tX5Bs19WWJLZBeFzbpE7BYuP3Qo71abZnQ7FmN3idRPg4oPWt2Q6Uf9huGv7AGMTu8M2BaCxAdThQArjLWLDLpxVX2gYfh2YJ")!
let destinationAddress = try! account.derive(BIP32Path("0/5")!).address(.payToWitnessPubKeyHash)

// Legacy input:
let key1 = try! account.derive(BIP32Path("0/0")!)
let address1 = key1.address(.payToPubKeyHash)
let amount: Satoshi = 10000000 // 0.1 BTC
// This has been funded with 0.1 tBTC in transaction 48bf2039d28b369080400e3d6a16be49d09ffd9edbd794686b30234e2c4dd0b5, output 0
let txId1 = "48bf2039d28b369080400e3d6a16be49d09ffd9edbd794686b30234e2c4dd0b5"
let vout1: UInt32 = 0
// To create a TxInput we need the scriptPubKey of the output we're spending:
let scriptPubKey1 = address1.scriptPubKey
// We also need the public key
let pubKey1 = key1.pubKey
// There's no witness:
let witness1: Witness? = nil
// Now construct the TxInput
let scriptSig1 = ScriptSig(.payToPubKeyHash(pubKey1))
let input1 = TxInput(Transaction(txId1)!, vout1, amount, scriptSig1, witness1, scriptPubKey1)!

// Construct a transaction:
var transaction = Transaction([input1], [TxOutput(destinationAddress.scriptPubKey, amount - 500)])

// Get the worst case size in vbytes:
transaction.vbytes // 189

// Get the fee (rate):
transaction.fee // Satoshi
transaction.feeRate // Satoshi per byte

// In order to sign it we need the private keys (in the same order as [TxInput]):
let accountPriv = HDKey("tprv8gzC1wn3dmCrBiqDFrqhw9XXgy5t4mzeL5SdWayHBHz1GmWbRKoqDBSwDLfunPAWxMqZ9bdGsdpTiYUfYiWypv4Wfj9g7AYX5K3H9gRYNCA")!
account.xpub == accountPriv.xpub
let privKey1 = try! accountPriv.derive(BIP32Path("0/0")!)
transaction.sign([privKey1])
transaction.description

// Get the actual size in vbytes (usually 1 less):
transaction.vbytes // 188

// To test using Bitcoin, assuming nobody broadcast it before, use:
// testmempoolaccept '["..."]'

// When spending native SegWit, construct the input as follows:

// Native SegWit input:
let key2 = try! account.derive(BIP32Path("0/1")!)
let address2 = key2.address(.payToWitnessPubKeyHash) // tb1q5h88ajzdl5czjuc57lfjlnwepprlgd9sj2fqkx
// This has been funded with 0.1 tBTC in transaction 400b52dab0a2bb5ce5fdf5405a965394b43a171828cd65d35ffe1eaa0a79a5c4, output 1
let txId2 = "400b52dab0a2bb5ce5fdf5405a965394b43a171828cd65d35ffe1eaa0a79a5c4"
let vout2: UInt32 = 1
// scriptPubKey of the output we're spending:
let scriptPubKey2 = address2.scriptPubKey
// We also need the public key
let pubKey2 = key2.pubKey
pubKey2.hexString
// Now construct the TxInput
// No scriptSig needed
let witness2 = Witness(.payToWitnessPubKeyHash(pubKey2))
let input2 = TxInput(Transaction(txId2)!, vout2, amount, nil, witness2, scriptPubKey2)!

// Construct a transaction:
transaction = Transaction([input2], [TxOutput(destinationAddress.scriptPubKey, amount - 110)])

// Get the worst case size in vbytes:
transaction.vbytes // 110

// Get the fee (rate):
transaction.fee // Satoshi
transaction.feeRate // Satoshi per byte

let privKey2 = try! accountPriv.derive(BIP32Path("0/1")!)
transaction.sign([privKey2])
transaction.description

// Get the actual size in vbytes:
transaction.vbytes // 110

// When spending wrapped SegWit, construct the input as follows:
let key3 = try! account.derive(BIP32Path("0/2")!)
let address3 = key3.address(.payToScriptHashPayToWitnessPubKeyHash) // 2N8JzYHt1L2FJkBt37geLatfW6DBXCZW9pr
// This has been funded with 0.1 tBTC in transaction 5f50a17eb6eab5437b79f357f37a5198a21d9d8dd226b66d8189f3a2fc66dce4, output 0
let txId3 = "5f50a17eb6eab5437b79f357f37a5198a21d9d8dd226b66d8189f3a2fc66dce4"
let vout3: UInt32 = 0
// scriptPubKey of the output we're spending:
let scriptPubKey3 = address3.scriptPubKey
// We also need the public key
let pubKey3 = key3.pubKey
// Now construct the TxInput
// scriptSig is set automatically
let witness3 = Witness(.payToScriptHashPayToWitnessPubKeyHash(pubKey3))
let input3 = TxInput(Transaction(txId3)!, vout3, amount, nil, witness3, scriptPubKey3)!

// Construct a transaction:
transaction = Transaction([input3], [TxOutput(destinationAddress.scriptPubKey, amount - 133)])

// Get the worst case size in vbytes:
transaction.vbytes // 133

// Get the fee (rate):
transaction.fee // Satoshi
transaction.feeRate // Satoshi per byte

let privKey3 = try! accountPriv.derive(BIP32Path("0/2")!)
transaction.sign([privKey3])
transaction.description

// Get the actual size in vbytes:
transaction.vbytes
