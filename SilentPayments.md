# Silent Payments (BIP352) in Fully Noded and FN-Server

> 🧪 **Experimental.** Silent payment support is in development on the
> `Silent-Payments` branch of both projects. Test with small amounts.

This document describes how silent payments (SP) work across the two apps today:
**Fully Noded** (the mobile wallet) holds the keys, sends to SP addresses and
signs spends of received SP outputs; **FN-Server** (the Mac node manager) scans
the chain for payments to you and imports them, watch-only, into your Fully
Noded wallet on your node. The same document lives in both repositories.

| | Fully Noded | FN-Server |
|---|---|---|
| Derive SP keys / show `sp1…` address + QR | ✅ Signer detail | – |
| Export the scan private key (QR) | ✅ Signer detail (auth required) | – |
| Import scan key + address | – | ✅ Utilities → Silent Payments |
| Scan the chain for payments to you | – | ✅ `SilentPaymentService` (background) |
| Make received outputs visible in a Core wallet | – | ✅ watch-only `rawtr()` import + rescan |
| Scanner status | – | ✅ Bitcoin Core view |
| Send to an `sp1…` / `tsp1…` address | ✅ Send view → `SilentPaymentSend` | – |
| Spend received SP outputs | ✅ Transaction verifier → `SilentPaymentSpend` | ❌ never holds `b_spend` |

---

## 1. End-to-end flow

```
Fully Noded signer (BIP39 seed)
  ├─ sp1… address (+ QR) ─────────────► share it with payers (any BIP352 wallet)
  │                         └─────────► FN-Server: B_spend is read from it
  ├─ scan private key b_scan (QR) ────► FN-Server: Utilities → Silent Payments
  │                                      scans every new block with b_scan
  │                                      → imports matches as watch-only rawtr()
  │                                      → rescans once caught up
  │                                      → Core wallet shows the SP balance
  └─ spend private key b_spend ───────► never leaves Fully Noded
                                         verifier detects SP inputs, recomputes
                                         each tweak and signs with b_spend + t_k
```

1. **Get your address.** In Fully Noded open a signer. The *Silent Payment
   Address* pane shows your `sp1…` (mainnet) or `tsp1…` (test networks) address
   with a QR export. Share it anywhere.
2. **Export the scan key.** In the same screen, *SP Scan Private Key* → QR
   button. It requires an app lock password, a confirmation and Face ID /
   Touch ID or the app password (never the device passcode). The key is derived
   on demand and shown only as a QR.
3. **Set up FN-Server.** Bitcoin Core view → Utilities → **Silent Payments**:
   pick your Fully Noded wallet, import the scan private key and your
   `sp1…` address (camera QR, QR image or paste), choose a start height and
   start scanning. Scanning runs in the background and resumes when FN-Server
   launches; its status is shown in the Bitcoin Core view.
4. **Receive.** Payers send to your address. FN-Server finds each payment and
   imports it into the wallet as a watch-only output.
5. **Spend.** In Fully Noded, spend from that wallet as usual. The transaction verifier
   recognises the silent payment inputs, recomputes their tweaks with your scan
   key and signs them with your spend key; any other inputs are signed by the
   normal signer. **Whenever silent payment outputs are spent**, Fully Noded asks
   where the change should go: your own silent payment address (its change
   label, found by FN-Server like any other payment) or the wallet's normal
   change address. Sweeping from the UTXO view needs no change.
6. **Send to someone else's SP address.** Paste an `sp1…` / `tsp1…` address in
   the send view. Fully Noded computes the one-time output and hands the PSBT to
   the verifier for the normal sign/broadcast flow. This works from a normal
   wallet holding silent payment outputs too (they can fund it; the same change
   question is asked).
7. **Bump the fee.** The verifier's bump-fee path signs silent payment inputs the
   same way as normal signing.

---

## 2. Keys (Fully Noded)

`WalletLogic.silentPaymentAddressFromMnemonic(mnemonic:passphrase:network:)`
derives the BIP352 keys from a signer's BIP39 seed (and its stored passphrase,
if any) using the spec paths:

```
spend: m/352'/coin'/0'/0'/0
scan:  m/352'/coin'/0'/1'/0      coin = 0 mainnet, 1 test networks
address = bech32m(hrp "sp"/"tsp", version 0, B_scan ‖ B_spend)
```

Thin wrappers keep private keys away from the UI:

- `silentPaymentAddress(mnemonic:passphrase:mainnet:)` returns only the address
  (signer detail, Silent Payment Address pane).
- `silentPaymentScanPrivateKey(mnemonic:passphrase:mainnet:)` returns only
  `b_scan`; the spend private key derived alongside it is wiped
  (signer detail, SP Scan Private Key pane).

The signer detail screen follows its network switch (mainnet / test), so the
address and scan key always match the network shown. Decrypted seed words and
passphrases are wiped right after use. `WalletLogic.Bech32m` is local and handles
SP addresses longer than 90 characters.

**What each key can do**

| Key | Who has it | Can |
|---|---|---|
| `b_spend` | Fully Noded only | spend (with each output's tweak) |
| `b_scan` | Fully Noded, and FN-Server once imported | **see** every payment to you, never spend |
| `B_scan`, `B_spend` | public (they *are* the address) | – |

Leaking `b_scan` costs privacy, not funds. Because every step of both paths is
hardened, `b_scan` can't be used to derive any other key in the wallet, even
together with the master xpub.

---

## 3. FN-Server: the scanner

Sources: `FullyNoded-Server/Helpers/SilentPaymentsScanner.swift`,
`FullyNoded-Server/Views/SilentPaymentsView.swift`.

### 3.1 Setup window (Utilities → Silent Payments)

A single SwiftUI window:

- **Wallet**: picker of the node's loaded wallets; pick the Fully Noded wallet
  you'll spend from (Fully Noded wallets are watch-only descriptor wallets on
  the node, with their own change addresses). Before starting, `getwalletinfo`
  confirms the wallet is a descriptor wallet with private keys disabled (Core
  refuses watch-only imports otherwise).
- **Scan private key**: hidden field with show/hide; *Scan QR* (only if the Mac
  has a camera), *QR image…* and *Paste*. Validated as a secp256k1 key; `B_scan`
  is computed from it.
- **Silent payment address**: `sp1…` / `tsp1…` only. `B_spend` is read from it.
  The address must match the node's network, and its `B_scan` must match the
  scan key (so a wrong or mistyped key is caught before scanning).
- **Start height**: the first block that could contain a payment to you, with
  *Use current height*. Only used the first time a key pair is scanned.
- **Scanner**: status, progress, payments found this session, last error, and
  *Start scanning* / *Save & restart*, *Stop*, *Resume saved*, *Forget keys*.

The camera is read with AVFoundation, each frame is displayed as a SwiftUI
`Image`, and QR codes are decoded with Core Image. `bitcoin:` prefixes and query
strings are stripped from scanned or pasted text. The app has the camera
entitlement and an `NSCameraUsageDescription`, so macOS asks once.

### 3.2 Status in the Bitcoin Core view

Once keys are imported, a read-only *Silent Payments* row shows the scanner state
(refreshed every 5 s from `SilentPaymentService.status()`): stopped, starting,
retrying (with the error), scanning block X of Y, wallet rescan pending /
running, or up to date. On/off stays in Utilities.

### 3.3 Per-transaction logic

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
     **Label `m = 0` (change) is always scanned**; extra labels `m ≥ 1` only if
     passed to `start(extraLabels:)` (the setup window passes none).
   - Comparison is on x-only keys. A matched output is removed from the
     candidate set so it cannot match twice.

Validated against the official BIP352 receiving test vectors.

### 3.4 Service loop, import and rescan

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
  then **one** `importdescriptors` call with `timestamp: "now"`,
  `active: false`, `internal: false` and a label of
  `sp scan=<B_scan> k=<k> [m=<m>] t=<t_k>`. Fully Noded reads this label to
  recognise and sign the input without fetching any blocks (5.1). `t_k` can't
  spend anything without `b_spend`. Re-importing is idempotent.
- **Deferred rescan**: because imports use `"now"`, the lowest height with a
  found output is kept in `pendingRescanFrom`. Once the scanner reaches the
  tip, **one** `rescanblockchain(start_height)` makes the wallet pick up the
  historical outputs and any later spends. This avoids a rescan per payment
  while catching up from an old start height.
- **Wallet loading**: every wallet RPC that fails with `-18` (not loaded) runs
  `loadwallet` and retries once (`-35` "already loaded" is tolerated).
- **Reorgs**: each block's `previousblockhash` is checked against the hash
  saved for `height − 1` (last 200 heights kept). On mismatch it steps back one
  height and rescans. Imported descriptors from orphaned blocks stay in the
  wallet (harmless, watch-only). Reorgs deeper than 200 blocks are not handled.
- **API**: `start(...)` (validates the keys, throws on bad ones), `stop()`,
  `isRunning`, `status()` (thread-safe snapshot for the UI), and main-queue
  callbacks `onProgress(height, tip)`, `onFound([SPFoundOutput])` and
  `onError(SPError)`.

### 3.5 What is stored

| What | Where | Why |
|---|---|---|
| Wallet name, `b_scan`, `B_scan`, `B_spend`, address, start height | Keychain, encrypted with the app's key (`SPConfigStore`) | resume scanning at launch; *Forget keys* deletes it |
| Scan progress: next height, recent block hashes, pending rescan height | UserDefaults, `sp_state_<first 16 hex of SHA256(wallet\|B_scan\|B_spend)>` | resume exactly where it stopped |
| Found outputs (txids, tweaks, labels) | only in the imported output's **wallet label** in Core (nothing in FN-Server) | lets Fully Noded recognise and sign the input without fetching blocks |

The server never holds `b_spend`, so it **cannot spend** what it finds.

### 3.6 Requirements

**Bitcoin Core**

- **Core ≥ 25**: `getblock` verbosity 3 provides `vin.prevout`.
- **Unpruned from the start height onward**: verbosity 3 needs undo data. A
  block without prevouts fails loudly rather than being skipped.
- **A watch-only descriptor wallet** (private keys disabled): your Fully Noded
  wallet. The service loads it itself if it isn't loaded.
- **RPC methods** (if `rpcwhitelist` is used): `getblockcount`, `getblockhash`,
  `getblock`, `getdescriptorinfo`, `importdescriptors`, `rescanblockchain`,
  `loadwallet`, plus `listwallets` and `getwalletinfo` for the setup window.
- `txindex` is **not** required.

**FN-Server**: the RPC port / user from settings and the encrypted RPC password
(Core Data), as for everything else in FN-Server.

### 3.7 Caveats

- It's a full-node scanner (no SP index, tweak server or BIP158 filters): one
  ECDH per eligible transaction. Catching up from an old start height on mainnet
  is slow.
- One SP identity at a time (`SilentPaymentService` is a singleton).
- Scanning only runs while FN-Server is open (it resumes, and catches up, at
  the next launch).

---

## 4. Fully Noded: sending to an SP address

Source: `FullyNoded/Wallet Logic/SilentPaymentSend.swift`.

`SilentPaymentSend.create(spAddress:amount:inputs:passphrase:change:completion:)`
builds an **unsigned PSBT** that pays an `sp1…` / `tsp1…` address from the active
(Core-backed) Fully Noded wallet, including your received silent payment outputs
in it. `AddressParser` accepts `sp1` / `tsp1`, and
`CreateRawTxViewController` routes an SP recipient here; the resulting PSBT goes
to the transaction verifier for the normal sign/broadcast flow.

Because an SP output key depends on the transaction's inputs *and their private
keys*, it can't simply call `walletcreatefundedpsbt` with the SP address:

1. **Parse the address** (`SPRecipient`): bech32m decode, HRP must match the
   node's chain (`sp` on main, `tsp` otherwise), v0 must be exactly 66 bytes,
   v1–v30 read forward-compatibly, v31 rejected, both keys must be valid points.
2. **Placeholder PSBT**: `walletcreatefundedpsbt` with a same-size P2TR output
   (x-only of `B_spend`) so Core selects inputs, change and fee as it would for
   the real output. Honors coin-control `inputs`. Never signed. Change follows
   5.3: the wallet's own change by default; if silent payment outputs are spent
   the send view asks, and silent payment change (`change: .silentPayment`) is
   rebuilt with the same inputs and a placeholder change output.
3. **`decodepsbt`** for each input's outpoint, prevout script, redeem script and
   BIP32 / taproot derivations.
4. **Derive input private keys** (`SPInputKeys`) from the stored signers (tries
   the typed passphrase, the signer's stored passphrase, then none). A key is
   only accepted if it reproduces the pubkey in the PSBT; for taproot the BIP341
   key-path tweak is applied and checked, and the key is negated for odd Y as
   BIP352 requires. **Your own received silent payment outputs** are found with
   the verifier's detection (5.1) and use `a_i = b_spend + t_k (+ label_m)`, only
   if `a_i·G` is the input's output key, negated for odd Y. Taproot inputs
   with a script tree use the **output key's** private key (internal key tweaked
   with `taproot_merkle_root`) whichever path they're later spent by, as BIP352
   requires; taproot inputs whose internal key is the NUMS point `H` are skipped
   (no key, outpoint still counts). Eligible: `pkh`, `wpkh`, `sh(wpkh)`, `tr` key path. Other
   inputs (e.g. `wsh` multisig) are allowed but add no key; at least one
   eligible input is required. Segwit v2+ inputs are refused, and so is any
   eligible input whose (output) private key isn't held by a signer.
5. **Compute the output** (`SPSender.outputKey`, `k = 0`):
   ```
   a = Σ a_i mod n   (refused if 0)
   input_hash = hash_BIP0352/Inputs(smallest_outpoint ‖ a·G)
   ecdh = input_hash · a · B_scan
   t_0  = hash_BIP0352/SharedSecret(serP(ecdh) ‖ ser32(0))
   P    = B_spend + t_0·G   →   P2TR(xonly(P))
   ```
   Private keys are wiped right after.
6. **Rebuild** with `createpsbt`: exactly the same inputs, sequences, locktime,
   outputs and amounts (so the same fee), placeholder(s) replaced by the real
   P2TR output (and silent payment change, if chosen). If you're paying your own
   SP address, the payment is `k = 0` and the change, which shares the same scan
   key, is `k = 1` (BIP352 numbers outputs per scan key); scanners find both.
   Prevouts are added with `walletprocesspsbt` (no signing).
7. **Safety checks**: same inputs, same amounts and the `5120<xonly(P)>` output
   (and change) present, otherwise abort.

Validated against the BIP352 sending test vectors.

**Requirements / limitations**

- Every eligible input's private key must be derivable from a Fully Noded
  signer (BIP32 path, or `b_spend + t_k` for your SP outputs); inputs from
  hardware wallets or external signers can't be used.
- One SP recipient per transaction, `k = 0` only (no multiple outputs to the same
  SP address, no mixing with normal recipients). Core still adds change.
- **Inputs are frozen**: anything that adds inputs or changes coin control
  invalidates the SP output; rebuild instead. Core's `psbtbumpfee` can add inputs
  when the change can't cover the higher fee, so the verifier checks every bump
  (see 5.2).
- No BIP375 PSBT fields, so a separate signer can't verify the SP output
  independently; correctness rests on the checks above.

---

## 5. Fully Noded: spending received SP outputs

Source: `FullyNoded/Wallet Logic/SilentPaymentSpend.swift`, wired into
`VerifyTransactionViewController`.

Every input in the verifier has a "signable" row naming the signer that can sign
it. Normal inputs are matched by master fingerprint (the PSBT's BIP32 derivations,
or the descriptor's key origins for a raw transaction). Silent payment inputs carry
no derivation, so taproot inputs no fingerprint matches go through the same
detection as signing (5.1, via `detectInputSigners`), using the wallet info the
verifier already fetched with `getaddressinfo`, and show as
"Signable by <signer> (silent payment)".

### 5.1 Detection (from the active wallet, no block fetching)

The verifier only cares about inputs the active wallet owns, and Core already
knows those. `SilentPaymentSpend.detect(candidates:)` works from that:

1. Takes every P2TR input and its `getaddressinfo` in the active wallet (the
   verifier already has it from verifying the inputs; other callers make one
   cheap wallet call per taproot input).
2. Keeps only inputs the wallet **owns as a bare taproot key**: FN-Server's
   `rawtr(<xonly>)` imports, recognised by their label
   `sp scan=<B_scan> k=<k> [m=<m>] t=<t_k>` (or a `rawtr()` / `addr()`
   descriptor). Normal wallet inputs (`tr(…)`, `wpkh(…)`, …) are skipped with no
   extra work, and nothing is derived if no input qualifies.
3. For a labeled input, the signer whose `B_scan` is in the label is used and
   the tweak is **checked locally**: `B_spend (+ label_m·G) + t_k·G` must equal
   the input's output key. No RPC. A match becomes an `OwnedOutput`
   (`t_k`, `label_m`) for signing.
4. Only outputs imported before FN-Server wrote `t=` (or imported unlabeled)
   fall back to scanning their own funding transaction: block hash from
   `gettransaction`, then `getrawtransaction <txid> 2 <blockhash>`, then the
   BIP352 receiving computation (section 3.3) with every signer's keys
   (passphrase candidates: typed, stored, none).

The label is only a hint: signing still refuses unless `b_spend + t_k
(+ label_m)` reproduces the output key (5.2). No SP inputs → exactly the normal
signing flow.

### 5.2 Signing

`SilentPaymentSpend.sign(psbt:outputs:passphrase:)` signs each owned input. A
received SP output is a P2TR key used as-is (no BIP341 tweak), so:

```
d = b_spend + t_k (+ label_m)  mod n
d = n − d   if d·G has odd Y                (BIP340 signs for the even-Y key)
sig = BIP340 Schnorr(d, BIP341 sighash)     → PSBT_IN_TAP_KEY_SIG (0x13)
```

1. Parses the PSBT (v0) into raw key/value maps; every other field is
   re-serialized unchanged.
2. Reads every input's prevout (`witness_utxo` or `non_witness_utxo`); BIP341
   needs all of them.
3. For each owned input: derives `b_spend` from the signers (typed, stored, no
   passphrase), computes `d`, and **only signs if `d·G` exactly matches that
   input's scriptPubKey**.
4. Computes the BIP341 key-path sighash locally (BDK can't sign
   `rawtr()` inputs), signs with P256K using random
   aux data, **verifies the signature**, then adds `PSBT_IN_TAP_KEY_SIG`. `d` is
   wiped afterwards.
5. Supports `SIGHASH_DEFAULT` and `SIGHASH_ALL`; anything else is refused.

Then the verifier signs the **remaining (non-SP) inputs** with the normal
`Signer` for each input's parent descriptor, and finalizes with the node's
`finalizepsbt`. A fully signed transaction is shown ready to broadcast;
otherwise the partially signed PSBT is returned for export.

**Fee bumps** use the same path: the PSBT from `psbtbumpfee` goes through the
same detection, `SilentPaymentSpend.sign`, remaining-input signing and
finalization (`signBumpedPsbt`). Without SP inputs it's the normal Signer, as
before.

Before signing a bump, `checkBumpKeepsSilentPaymentOutputs` compares its inputs
with the original transaction's. BIP352 outputs depend on the exact inputs, so:

- same inputs → sign;
- inputs added / changed and the original pays one of **your** SP addresses
  (found by running the receiver scan on the original, with prevouts from the
  bumped PSBT) → refused, the original stays as is (use CPFP);
- inputs added / changed and the original has other taproot outputs (possibly a
  silent payment to someone else, which can't be told from outside) → explicit
  confirmation required.

Safety properties: the BIP341 sighash commits to all input amounts and scripts,
so a PSBT that lies about a prevout produces an invalid signature rather than an
overpaid fee. Wrong signer/passphrase, a bad tweak and unsupported sighash types
give clear errors. Already-signed inputs are skipped.

Verified against the BIP341 wallet sighash test vectors and end to end on
regtest (odd-Y, even-Y and labeled outputs, both sighash types, accepted by
`testmempoolaccept` and mined).

### 5.3 Change when silent payment outputs are spent

The send view first builds the transaction with the wallet's own change. If it
spends silent payment outputs (same detection as the verifier) and has a change
output, it asks where the change should go:

- **Wallet change address**: the transaction as built.
- **My silent payment address** → rebuilt with the **same inputs** (pinned) by
  `SilentPaymentChange.create(inputs:outputs:)`, or by `SilentPaymentSend` with
  `change: .silentPayment` when the recipient is a silent payment address.

Silent payment change goes to the **change address (label `m = 0`)** of the
signer that owns the silent payment inputs, `B_m = B_spend + label_0·G`.
FN-Server always scans label 0 and the verifier always checks it, so the change
reappears in the same wallet and is spendable like any other silent payment
output.
  1. Fund with a placeholder P2TR change output (same size) so Core picks the
     fee (inputs pinned to the ones already chosen).
  2. Find the owning signer from the inputs' wallet labels (`B_scan` in
     `sp scan=…`), falling back to the funding-transaction scan only for
     unlabeled imports.
  3. Compute the change key **as the receiver**, which needs no input private
     keys. A sums the eligible inputs' public keys: taproot output keys (even Y;
     script-path spends with the NUMS internal key excluded) and, for `wpkh`,
     `sh(wpkh)` and `pkh` inputs, the compressed key from the PSBT's BIP32
     derivations (checked against the script). Other inputs (e.g. multisig) add
     only their outpoint. Refused if an eligible input's key is missing or any
     input is segwit v2+:
     ```
     A          = Σ eligible input keys (taproot: even Y)
     input_hash = hash_BIP0352/Inputs(smallest_outpoint ‖ A)
     t_0        = hash_BIP0352/SharedSecret(serP(input_hash · b_scan · A) ‖ ser32(0))
     P          = B_spend + label_0·G + t_0·G
     ```
     (`t_1` instead of `t_0` when the same transaction also pays your own SP
     address, which takes `k = 0`.)
     This equals what a BIP352 sender computes from the input private keys
     (checked in a Python model over random keys).
  4. Self-check: the verifier's receiver scan runs on the transaction as it will
     be broadcast (each input with a witness / scriptSig shaped like its real
     spend) and must find the change as a label-0 output.
  5. Rebuild with `createpsbt` (same inputs, sequences, outputs and amounts, so
     the same fee) and add prevouts with `walletprocesspsbt` (no signing); abort
     unless inputs, amounts and the change output all match.

---

## 6. Current limitations

- Labels: only the change label `m = 0` is scanned and spendable; handing out
  labeled addresses (`m ≥ 1`) isn't supported in the UI.
- Sending: one SP recipient per transaction (see section 4).
- Silent payment change needs the public key of every eligible input in the
  PSBT (always true for Fully Noded wallets) and no segwit v2+ inputs.
- No BIP375 / BIP376 PSBT fields yet.
- Scanning needs FN-Server (a full node on a Mac); Fully Noded doesn't scan by
  itself.
