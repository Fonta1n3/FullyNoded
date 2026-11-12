# Testing Fully Noded

Fully Noded has two kinds of tests:

| | What | Needs | Time |
|---|---|---|---|
| **Unit tests** (`FullyNodedTests`) | Everything Fully Noded does with private keys, timelocks and wallet recovery | A simulator | ~1.5 min first build, then seconds |
| **UI tests** (`FullyNodedUITests`) | The app end to end against a regtest node: wallets, sending, payjoin, silent payments, recovery | A simulator and a local Bitcoin Core / Knots | Minutes per node build |

## Unit tests

### Run them

**Xcode:** pick the **FullyNodedTests** scheme and an iPhone simulator, then press **⌘U**.
Each test file is listed in the Test navigator (⌘6) and can be run on its own with the diamond next to it.

**Command line** (from the repository root):

```bash
xcodebuild test -workspace FullyNoded.xcworkspace -scheme FullyNodedTests -destination 'platform=iOS Simulator,id=<simulator UDID>' -collect-test-diagnostics never
```

Replace `<simulator UDID>` with one from `xcrun simctl list devices available` (any iPhone simulator). A name
works too (`name=iPhone 15 Pro`), but only for a simulator on the newest iOS unless you add `OS=17.2`.
`-collect-test-diagnostics never` stops xcodebuild spending 10 minutes gathering simulator logs after a failure.

Only one test file, or one test:

```bash
xcodebuild test -workspace FullyNoded.xcworkspace -scheme FullyNodedTests -destination 'platform=iOS Simulator,id=<simulator UDID>' -only-testing FullyNodedTests/PsbtSigningTests
```

```bash
xcodebuild test -workspace FullyNoded.xcworkspace -scheme FullyNodedTests -destination 'platform=iOS Simulator,id=<simulator UDID>' -only-testing FullyNodedTests/KeyDerivationTests/testFingerprint
```

No node, network or setup is needed. The tests run inside the app in the simulator, so they use the same
Keychain and settings code as the app. They put the app's network setting back when they finish.

### What they cover

| File | Covers |
|---|---|
| [SeedWordTests](../FullyNodedTests/SeedWordTests.swift) | New 12 / 24 word seeds are valid and random; checksums are checked; the "last word" helper offers only valid words |
| [KeyDerivationTests](../FullyNodedTests/KeyDerivationTests.swift) | Seed + passphrase → master key → fingerprint → BIP84 / BIP86 account keys → descriptors and addresses; descriptors never contain private keys; testnet keys |
| [EncryptionTests](../FullyNodedTests/EncryptionTests.swift) | Seeds are encrypted (ChaChaPoly) before storage, can't be read if changed, and the encryption key is never replaced; the Keychain never overwrites a key; secrets are wiped from memory |
| [PsbtSigningTests](../FullyNodedTests/PsbtSigningTests.swift) | Signing a PSBT the way the transaction verifier does, with and without a passphrase; a wrong passphrase or another seed signs nothing |
| [SilentPaymentKeyTests](../FullyNodedTests/SilentPaymentKeyTests.swift) | Silent payment address and scan key from a seed (the exported scan key is never the spend key); sending, finding and spending a silent payment; key arithmetic |
| [TimelockTests](../FullyNodedTests/TimelockTests.swift) | Timelocked addresses for segwit, taproot and multisig wallets (right key, right lock, address matches its descriptor); spending a timelocked coin; reading the lock back from scripts and wallet policies; when a coin shows as locked (block height, date, relative, lock on only one spending path) |
| [BlockExplorerTests](../FullyNodedTests/BlockExplorerTests.swift) | Reading the node's replies into blocks and transactions, the block map's layout, formats, miner tags, solo wins, transaction categories |
| [ExplorerDataDecoderTests](../FullyNodedTests/ExplorerDataDecoderTests.swift) | Decoding OP_RETURN protocols, inscriptions and data in bare multisig, from real and constructed samples |
| [WalletInsightsTests](../FullyNodedTests/WalletInsightsTests.swift) | The balance breakdown, mempool position and effective fee rate, what coins cost to spend, linked and reused addresses, the privacy rating, self transfers, changes since last opened, what a PSBT needs next |
| [WalletRecoveryTests](../FullyNodedTests/WalletRecoveryTests.swift) | Recovering from seed words, a descriptor, an account map or a wallet backup gives the same wallet and finds the node wallet it had before (whatever checksum, hardened notation or multisig key order); backups survive export and import; only missing descriptors are imported, rescanning from the right time; timelocked addresses come back with their labels; seeds starting "sh…"/"tr…" aren't mistaken for descriptors |

Expected values for keys and signing come from the published test vectors, so the tests check Fully Noded against the standards,
not against itself:
[BIP39](https://github.com/trezor/python-mnemonic/blob/master/vectors.json),
[BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki#test-vectors),
[BIP84](https://github.com/bitcoin/bips/blob/master/bip-0084.mediawiki#test-vectors),
[BIP86](https://github.com/bitcoin/bips/blob/master/bip-0086.mediawiki#test-vectors) and
[BIP352](https://github.com/bitcoin/bips/blob/master/bip-0352/send_and_receive_test_vectors.json).
Timelock and recovery tests build on the same seed, checking each result independently (an address
against its descriptor, a signed transaction against the lock its script demands).
Most use the BIP39 seed `abandon abandon … about`, the one those vectors share. It's public: never put
funds on it.

### Add a test

1. Add a method starting with `test` to the file that fits (or a new file in `FullyNodedTests/`, added to
   the **FullyNodedTests** target).
2. Subclass `KeyTestCase` rather than `XCTestCase`: each test then starts on mainnet settings, and
   `chain = "regtest"` (or `"test"`, `"signet"`) switches network for that test only.
3. Prefer a published test vector over a value Fully Noded produced: a value copied from the app's own
   output only proves the app still does what it did.
4. Keep each test about one thing, named for what it shows (`testWrongPassphraseCannotSign`).

## UI tests

The `FullyNodedUITests` target drives the app in the simulator against a regtest node started from your local
Bitcoin Core / Knots builds. One command runs everything on two simulators for every build:

```bash
FullyNodedUITests/regtest/matrix.sh <simulator A UDID> <simulator B UDID>
```

Setup, single runs and writing new UI tests: [FullyNodedUITests/regtest/README.md](../FullyNodedUITests/regtest/README.md).

## Troubleshooting

- **`Tor: can't link a dylib with itself`**: a build folder used for both "any simulator" and one specific
  simulator. Give each its own `-derivedDataPath`, or delete the build folder.
- **The scheme runs UI tests too**: the **FullyNoded** scheme's ⌘U runs both kinds. Choose
  **FullyNodedTests** for the unit tests alone.
