# Silent Payments (BIP352) in FN-Server and Fully Noded

This document describes the silent payment (SP) code that exists today in
**FullyNoded-Server** (receiving/scanning) and **Fully Noded** (address
derivation, sending, and signing spends of received outputs). It covers the protocol logic only; UI wiring is
intentionally out of scope because neither app exposes SP in its UI yet.

| | FN-Server | Fully Noded |
|---|---|---|
| Derive SP keys / `sp1…` address | – | ✅ `WalletLogic.silentPaymentAddressFromMnemonic` |
| Send to an `sp1…` / `tsp1…` address | – | ✅ `SilentPaymentSend` |
| Scan the chain for received SP outputs | ✅ `SilentPaymentService` | – |
| Make received outputs visible in a Core wallet | ✅ watch-only `rawtr()` import + rescan | – |
| Sign spends of received SP outputs | ❌ (never holds `b_spend`) | ✅ `SilentPaymentSpend` (tweaks from FN-Server) |

---

## 1. FN-Server: the receiver / scanner

Source: `FullyNoded-Server/Helpers/SilentPaymentsScanner.swift`

### 1.1 What it does

`SilentPaymentService` is a long-running background service that follows the
local Bitcoin Core node **block by block**, finds every BIP352 output paying
one SP identity `(b_scan, B_spend)`, and imports each one into a Bitcoin Core
wallet as a **watch-only `rawtr(<xonly>)` descriptor**. The result is that the
Core wallet shows the SP balance, the UTXOs and their later spends, exactly
like any other watch-only wallet.

It is a *full-node scanner*: it does not use an SP index, tweak server or
BIP158 filters. It computes the shared secret for every eligible transaction
in every block itself.

### 1.2 Per-transaction logic

For each non-coinbase transaction in a block (`getblock` verbosity 3):

1. **Skip** the tx if any input spends a segwit v2+ output (BIP352 rule), or if
   the tx has no P2TR outputs.
2. **Collect eligible input public keys** (`SPPrevout.extractEligiblePubkey`):
   - **P2TR**: output key lifted to even Y (`02‖xonly`). A script-path spend
     whose control-block internal key is the BIP341 NUMS point `H` is
     excluded. The annex is stripped before inspecting the witness.
   - **P2WPKH**: witness `[sig, pubkey]`, compressed keys only.
   - **P2SH-P2WPKH**: scriptSig must be exactly one push of `0014<20>`,
     witness `[sig, pubkey]`, compressed keys only.
   - **P2PKH**: slides a 33-byte window from the end of the scriptSig and
     takes the first compressed key whose HASH160 matches the scriptPubKey,
     which handles malleated scriptSigs (spec behaviour). Uses a local
     RIPEMD160 port.
   - Everything else (P2WSH, bare multisig, other P2SH, anchors) contributes
     no key but its outpoint still counts.
3. **Compute the shared secret**:
   ```
   A          = Σ eligible input pubkeys          (tx skipped if A = ∞)
   input_hash = hash_BIP0352/Inputs(smallest_outpoint ‖ A)   (smallest over ALL inputs)
   ecdh       = (input_hash · b_scan) · A
   t_k        = hash_BIP0352/SharedSecret(serP(ecdh) ‖ ser32(k))
   ```
4. **Match outputs** for `k = 0, 1, 2, …` (stopping at the first `k` with no
   match, capped at `K_max = 2323`):
   - unlabeled: `P_k = B_spend + t_k·G`
   - labeled: `P_k,m = B_spend + label_m·G + t_k·G`, where
     `label_m = hash_BIP0352/Label(b_scan ‖ ser32(m))`.
     **Label `m = 0` (change) is always scanned**; extra labels `m ≥ 1` are
     scanned only if passed in `extraLabels`. Matching is done by computing
     `B_m + t_k·G` per label (O(#labels) point ops per `k`), which is fine for
     a handful of labels.
   - Comparison is on x-only keys. A matched output is removed from the
     candidate set so it cannot match twice.

Each match is recorded as an `SPFoundOutput`: txid, vout, scriptPubKey,
`t_k` (`tweakHex`), `k`, label `m` and `label_m` (if labeled), block height,
hash and time. That is everything needed to spend later:

```
spend key = b_spend + t_k (+ label_m) mod n
```

### 1.3 Service loop, import and rescan

- **One serial queue** owns all state; a `generation` counter makes stale
  callbacks from a previous `start()`/`stop()` exit instead of racing.
- **Step**: `getblockcount`. If behind the tip, scan `nextHeight`. If caught up
  and a rescan is pending, run it. Otherwise poll again after
  `pollInterval` (15 s).
- **A block only counts as scanned after it was fetched *and* any matches were
  imported.** Any error (node down, 401/403/503, wallet not loaded, missing
  prevouts) is retried with exponential backoff (5 s → 300 s) on the *same*
  height; blocks are never skipped.
- **Import**: for all matches in a block, `getdescriptorinfo` adds a checksum,
  then **one** `importdescriptors` call with
  `timestamp: "now"`, `active: false`, `internal: false` and a label of
  `sp scan=<B_scan> k=<k> [m=<m>]`. Re-importing is idempotent.
- **Deferred rescan**: because imports use `"now"`, the lowest height with a
  found output is kept in `pendingRescanFrom`. Once the scanner reaches the
  tip, **one** `rescanblockchain(start_height)` makes the wallet pick up the
  historical outputs and any later spends. This avoids a rescan per payment
  while catching up from an old birthday.
- **Wallet loading**: every wallet RPC that fails with `-18` (not loaded) runs
  `loadwallet` and retries once (`-35` "already loaded" is tolerated).
- **Reorgs**: each block's `previousblockhash` is checked against the hash
  saved for `height − 1` (last 200 heights kept). On mismatch it steps back one
  height, drops `found` entries from the orphaned block and rescans. Imported
  descriptors from orphaned blocks are left in the wallet (harmless,
  watch-only). Reorgs deeper than 200 blocks are not handled.
- **Persistence**: `SPScanState` (`nextHeight`, `recentHashes`,
  `pendingRescanFrom`, `found`) is saved to `UserDefaults` after **every**
  block under `sp_state_<first 16 hex of SHA256(wallet|B_scan|B_spend)>`, so
  restarts resume exactly where they stopped. The birthday height is only used
  when no saved state exists.
- **Callbacks** (main queue): `onFound([SPFoundOutput])`, `onError(SPError)`,
  `onProgress(height, tip)`. `foundOutputs()` returns a snapshot of everything
  found so far.

### 1.4 What it requires

**Keys (passed to `SilentPaymentService.start`)**

| Input | Why |
|---|---|
| `scanPrivateKeyHex` (`b_scan`, 32 bytes) | ECDH and label tweaks. Validated up front; a bad key throws instead of silently finding nothing. |
| `spendPublicKeyHex` (`B_spend`, 33 bytes compressed) | Building `P_k`. Only the **public** spend key is needed. |
| `scanPublicKeyHex` (`B_scan`) | Only used for the state key and descriptor labels. |
| `walletName` | Target Core wallet. |
| `birthdayHeight` | First block that could contain a payment (first run only). |
| `extraLabels` | Any labels `m ≥ 1` you hand out. |

The server never holds `b_spend`, so it **cannot spend** what it finds, by
design.

**Bitcoin Core**

- **Core ≥ 25**: `getblock` verbosity 3 provides `vin.prevout`.
- **Unpruned from the birthday height onward**: verbosity 3 needs undo data. A
  block without prevouts fails loudly rather than being skipped.
- **A watch-only descriptor wallet** (`disable_private_keys=true`); Core refuses
  to import a private-keyless `rawtr()` into a wallet with private keys. It
  should be `load_on_startup=true`, although the service will load it itself.
- **RPC access** to `127.0.0.1:<port>` with these methods allowed if
  `rpcwhitelist` is used: `getblockcount`, `getblockhash`, `getblock`,
  `getdescriptorinfo`, `importdescriptors`, `rescanblockchain`, `loadwallet`.
- `txindex` is **not** required.

**FN-Server configuration**

- `UserDefaults` `port` (default `8332`) and `rpcuser` (default
  `FullyNoded-Server`).
- Encrypted RPC password in Core Data (`rpcCreds`), decrypted with the
  app's keychain key.

### 1.5 Caveats

- **FN-Server can't spend.** The imported descriptors are watch-only. Spending
  is done by Fully Noded's `SilentPaymentSpend` (section 2.5), which needs the
  `t_k`/`label_m` values from FN-Server's saved state. If that state is lost,
  the tweaks can only be recovered by rescanning from the birthday with `b_scan`.
- **Privacy of saved state**: `tweakHex`, `labelTweakHex` and the outpoints are
  stored in a plain-text plist
  (`~/Library/Preferences/com.dentonllc.FullyNoded-Server.plist`). They can't
  spend anything without `b_spend`, but they identify outputs as yours.
- **`b_scan` in source**: the current development call in
  `Views/BitcoinCore.swift` hardcodes `scanPrivateKeyHex`, and commit
  `b4763db9` is on `origin/Silent-Payments`. Anyone with `b_scan` + `B_spend`
  can see every payment to that SP address (no theft risk, full privacy loss).
  Treat that SP identity as public and move to one whose `b_scan` is kept out of
  the repo.
- Throughput is bounded by `getblock` verbosity 3 serialization and one ECDH per
  eligible tx; catching up from an old birthday on mainnet is slow.
- One SP identity per running service (`SilentPaymentService` is a singleton).

---

## 2. Fully Noded: keys, sending and spending

Sources: `FullyNoded/Wallet Logic/SilentPaymentSend.swift`,
`FullyNoded/Wallet Logic/SilentPaymentSpend.swift`,
`FullyNoded/Wallet Logic/WalletLogic.swift`,
`FullyNoded/Helpers/AddressParser.swift`.

### 2.1 SP key derivation / address

`WalletLogic.silentPaymentAddressFromMnemonic(mnemonic:passphrase:network:)`
derives the BIP352 keys from a BIP39 mnemonic using the spec paths:

```
spend: m/352'/coin'/0'/0'/0
scan:  m/352'/coin'/0'/1'/0      coin = 0 mainnet, 1 test networks
address = bech32m(hrp "sp"/"tsp", version 0, B_scan ‖ B_spend)
```

It returns the address and all four keys (`b_scan`, `b_spend`, `B_scan`,
`B_spend`) as hex. This is exactly what FN-Server's scanner needs
(`b_scan`, `B_scan`, `B_spend`), so Fully Noded is the natural source of the
scanner's keys and the only place that can produce `b_spend` for spending.

Notes:
- `network` defaults to `.main`. A caller on testnet/signet must pass `.test`,
  or it gets mainnet paths and an `sp1` address.
- `SignerDetailViewController` currently calls it with the default network and
  no passphrase and does
  `print("spAddress: \(spAddress)")`. That prints the **whole tuple, including
  `b_scan` and `b_spend`**, to the console, and it is not wrapped in
  `#if DEBUG`.
- Bech32m encode/decode (`WalletLogic.Bech32m`) is local and handles SP
  addresses longer than 90 characters.

### 2.2 Sending to a silent payment address

`SilentPaymentSend.create(spAddress:amount:inputs:passphrase:completion:)` builds
an **unsigned PSBT** that pays an `sp1…`/`tsp1…` address from the active Fully
Noded (Core-backed) wallet. It creates an SP **output** from ordinary inputs; it
does not spend SP inputs.

Because an SP output key depends on the transaction's inputs *and their private
keys*, it cannot just call `walletcreatefundedpsbt` with the SP address. Flow:

1. **Parse the address** (`SPRecipient`): bech32m decode, HRP must match the
   node's chain (`sp` on main, `tsp` otherwise), v0 must be exactly 66 bytes,
   v1–v30 read forward-compatibly, v31 rejected, both keys must be valid points.
2. **Placeholder PSBT**: `walletcreatefundedpsbt` with a same-size P2TR output
   (x-only of `B_spend`) so Core selects inputs, change and fee as it would for
   the real output. Honors coin-control `inputs`. Never signed.
3. **`decodepsbt`** to get each input's outpoint, prevout script, redeem script
   and BIP32 / taproot derivations.
4. **Derive input private keys** (`SPInputKeys`) from the stored Fully Noded
   signers (decrypted mnemonics; tries the given passphrase, the signer's stored
   passphrase, then none). A key is only accepted if it reproduces the pubkey in
   the PSBT; for taproot, the BIP341 key-path tweak is applied and checked
   against the prevout script, and the key is negated for odd Y as BIP352
   requires. Supported inputs: `pkh`, `wpkh`, `sh(wpkh)`, `tr` key path.
   Other inputs (e.g. `wsh` multisig) are allowed but add no key; at least one
   eligible input is required. Taproot script-path inputs and segwit v2+ inputs
   are refused.
5. **Compute the output** (`SPSender.outputKey`, `k = 0`):
   ```
   a = Σ a_i mod n   (refused if 0)
   input_hash = hash_BIP0352/Inputs(smallest_outpoint ‖ a·G)
   ecdh = input_hash · a · B_scan
   t_0  = hash_BIP0352/SharedSecret(serP(ecdh) ‖ ser32(0))
   P    = B_spend + t_0·G   →   P2TR(xonly(P))
   ```
   Private keys are wiped (`secureZero`) right after.
6. **Rebuild** with exactly the same inputs and the real P2TR output.
7. **Safety checks**: input set unchanged and the `5120<xonly(P)>` output
   present, otherwise abort.
8. Return the unsigned PSBT for the normal verify/sign/broadcast flow.

`AddressParser` accepts `sp1`/`tsp1` (lowercasing them), and
`CreateRawTxViewController.getRawTx()` routes an SP recipient to
`SilentPaymentSend`.

### 2.3 What sending requires

- A **Core-backed wallet whose inputs are single-sig and whose seed is stored as
  a Fully Noded signer**. Every eligible input's private key must be derivable
  locally; inputs from hardware wallets or external signers can't be used.
- A node on the same network as the address HRP.
- PSBTs from Core that include BIP32/taproot derivations (normal for descriptor
  wallets).

### 2.4 Limitations

- **One SP recipient per transaction**, and only `k = 0` (no multiple outputs to
  the same SP address, no mixing SP with normal recipients). Change is still
  added by Core.
- **Inputs are frozen.** Signing is fine, but RBF/`bumpfee` that adds inputs,
  or any coin-control change, invalidates the SP output (the recipient would
  never find it). Rebuild instead.
- The PSBT has no BIP375 SP fields, so a separate signer can't verify the SP
  output independently; correctness rests on the checks above.
- No receiving/scanning in Fully Noded (that's FN-Server's job).

### 2.5 Spending received SP outputs (tweaked-key signing)

`SilentPaymentSpend.sign(psbt:outputs:passphrase:completion:)` signs every input
of a PSBT that is one of your silent payment outputs. A received SP output is a
P2TR output whose key is used as-is (`rawtr(<xonly>)`, no BIP341 taproot tweak),
so each input is signed with:

```
d = b_spend + t_k (+ label_m)  mod n
d = n − d   if d·G has odd Y                (BIP340 signs for the even-Y key)
sig = BIP340 Schnorr(d, BIP341 sighash)     → PSBT_IN_TAP_KEY_SIG (0x13)
```

- **`b_spend`** is derived from the stored Fully Noded signers at
  `m/352'/coin'/0'/0'/0`, trying the passed passphrase, the signer's stored
  passphrase, then none. The right one is whichever reproduces the input's
  output key.
- **`t_k` / `label_m`** come from the caller as `[OwnedOutput]`
  (`txid`, `vout`, `tweakHex`, `labelTweakHex`). The field names match
  FN-Server's `SPFoundOutput`, so its saved `found` array decodes directly.
- `sign(psbt:outputs:spendKey:)` is the pure core (no Core Data, no RPC) and can
  be used with an explicit 32-byte `b_spend`.

How it signs:
1. Parses the PSBT (v0 only) into raw key/value maps and the unsigned tx; every
   other field is re-serialized unchanged.
2. Reads every input's prevout (amount + scriptPubKey) from `witness_utxo`, or
   from `non_witness_utxo`. BIP341 needs all of them.
3. For each input whose outpoint is in `outputs`: computes `d`, negates for odd
   Y, and **only signs if `d·G` exactly matches that input's P2TR
   scriptPubKey**.
4. Computes the BIP341 key-path sighash locally (the bundled LibWally predates
   taproot sighash, and BDK can't sign `rawtr()`). Signs with P256K using random
   aux data, **verifies the signature** against the output key, then appends
   `PSBT_IN_TAP_KEY_SIG`. `d` is wiped afterwards.
5. Supports `SIGHASH_DEFAULT` (64-byte sig) and `SIGHASH_ALL` (65-byte sig,
   taken from `PSBT_IN_SIGHASH_TYPE`). Anything else is refused.

Safety properties:
- The BIP341 sighash commits to the amounts and scripts of **all** inputs, so a
  PSBT that lies about a prevout produces an invalid signature, not a
  fee-overpaying one.
- Clear errors for a wrong signer/passphrase (key doesn't match any input),
  inputs not in `outputs`, a bad tweak for one input, and unsupported sighash
  types. Already-signed inputs are skipped.

The result is **not finalized**. Run Core's `finalizepsbt` (it turns
`PSBT_IN_TAP_KEY_SIG` into the key-path witness), and sign any non-SP inputs
with the normal `Signer` first.

Verified against the BIP341 wallet test-vector sighashes (DEFAULT and ALL) and
end to end on regtest: spends of odd-Y, even-Y and labeled outputs, with both
sighash types, were accepted by `testmempoolaccept` and mined.

---

## 3. How the two fit together

```
Fully Noded signer mnemonic
  └─ silentPaymentAddressFromMnemonic → sp1… address, b_scan, B_scan, b_spend, B_spend
        │
        ├─ sp1… address ──────────► given to payers (any BIP352 sender, incl. Fully Noded)
        │
        ├─ b_scan, B_scan, B_spend ─► FN-Server SilentPaymentService
        │                              scans blocks → rawtr() watch-only import
        │                              → Core wallet shows SP balance
        │
        └─ b_spend ─────────────────► Fully Noded SilentPaymentSpend
                                       signs with b_spend + t_k (+ label_m),
                                       tweaks from FN-Server's found outputs
```

Missing for a complete loop: getting the scan keys from Fully Noded to FN-Server
without hardcoding them, and getting FN-Server's per-output tweaks to Fully
Noded's `SilentPaymentSpend`.
