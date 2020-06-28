# LibWally Swift [![Build Status](https://travis-ci.org/blockchain/libwally-swift.svg?branch=master)](https://travis-ci.org/blockchain/libwally-swift)

Opinionated Swift wrapper around [LibWally](https://github.com/ElementsProject/libwally-core),
a collection of useful primitives for cryptocurrency wallets.

Supports a minimal set of features based on v0.7.7. See also [original docs](https://wally.readthedocs.io/en/release_0.7.7).

- [ ] Core Functions
  - [x] base58 encode / decode
- [ ] Crypto Functions
  - [x] sign ECDSA, convert to DER
- [ ] Address Functions
  - [x] Parse to scriptPubKey
  - [ ] Generate from scriptPubKey #7 (wishlist, done for SegWit)
  - [x] Derive
  - [x] WIF
  - [ ] Detect bech32 typos #4 (wishlist)
- [x] BIP32 Functions
  - [ ] Derive scriptPubKey #6 (wishlist)
- [ ] BIP38 Functions
- [x] BIP39 Functions
- [ ] Script Functions
  - [x] Serialize scriptPubKey
  - [x] Determine scriptPubkey type
- [ ] PSBT functions
  - [x] Parse and serialize (base64 / binary)
  - [x] Check completeness and extract transaction
- [ ] Transaction Functions
  - [x] Compose and sign transaction
  - [x] Calculate fee

Items marked with wishlist are not (yet) available upstream.

Multisig as well as [Elements](https://blockstream.com/elements/) specific functions such as confidential addresses are not implemented.

Works with iOs 11+ on 64-bit devices and the simulator.

## Usage

Derive address from a seed:

```swift
let mnemonic = BIP39Mnemonic("abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about")
let masterKey = HDKey(mnemonic.seedHex("bip39 passphrase"))!
masterKey.fingerprint.hexString
let path = BIP32Path("m/44'/0'/0'")!
let account = try! masterKey.derive(path)
account.xpub
account.address(.payToWitnessPubKeyHash)
```

Derive address from an xpub:

```swift
let account = HDKey("xpub6ASuArnXKPbfEwhqN6e3mwBcDTgzisQN1wXN9BJcM47sSikHjJf3UFHKkNAWbWMiGj7Wf5uMash7SyYq527Hqck2AxYysAA7xmALppuCkwQ")
let receivePath = BIP32Path("0/0")!
key = account.derive(receivePath)
key.address(.payToPubKeyHash) # => 1JQheacLPdM5ySCkrZkV66G2ApAXe1mqLj
```

Parse an address:

```swift
var address = Address("bc1q6zwjfmhdl4pvhvfpv8pchvtanlar8hrhqdyv0t")
address?.scriptPubKey # => 0014d09d24eeedfd42cbb12161c38bb17d9ffa33dc77
address?.scriptPubKey.type # => .payToWitnessPubKeyHash
```

Create and sign a transaction:

```swift
let txId = "400b52dab0a2bb5ce5fdf5405a965394b43a171828cd65d35ffe1eaa0a79a5c4"
let vout: UInt32 = 1
let amount: Satoshi = 10000
let witness = Witness(.payToWitnessPubKeyHash(key.pubKey))
let input = TxInput(Transaction(txId)!, vout, amount, nil, witness, scriptPubKey)!
transaction = Transaction([input], [TxOutput(destinationAddress.scriptPubKey, amount - 110)])
transaction.feeRate // Satoshi per byte
let accountPriv = HDKey("xpriv...")
let privKey = try! accountPriv.derive(BIP32Path("0/0")!)
transaction.sign([privKey])
transaction.description # transaction hex
```

See also the included [Playground](/DemoPlayground.playground/Contents.swift) and [tests](/LibWallyTests).

## Install

Via CocoaPods:

```
pod 'LibWally', :git => 'https://github.com/blockchain/LibWally-Swift.git', :branch => 'master', :submodules => true
```

```
pod install --verbose
```

## Build

Install dependencies:

```sh
brew install gnu-sed
```

Clone the repository, including submodules:

```sh
git clone https://github.com/blockchain/libwally-swift.git --recurse-submodules
```

Build libwally-core:

```
./build-libwally.sh -dsc
```
