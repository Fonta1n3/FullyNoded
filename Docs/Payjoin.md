# Payjoin (BIP78)

**A payjoin is a payment both sides put coins into.** The payer adds their coins as usual, and
the receiver adds one of theirs. On-chain it looks like an ordinary transaction, but the usual
assumption that "all inputs belong to the payer" is wrong, which breaks the chain-analysis
heuristic that most wallet clustering relies on. Payjoins also hide the payment amount and let
the receiver consolidate a coin for free.

Fully Noded does both sides of [BIP78](https://github.com/bitcoin/bips/blob/master/bip-0078.mediawiki):

- **Paying** an invoice that offers payjoin (`pj=` in the payment link), for example a BTCPay
  Server store or another Fully Noded.
- **Receiving** a payjoin from this phone: the invoice screen hosts a one-time onion address over
  Tor while it's open.

Either way, if anything goes wrong the normal payment goes through instead. A payjoin never
blocks a payment.

## Paying a payjoin invoice

1. Scan or paste the payment request. If it offers payjoin, the summary says so.
2. Create and sign the transaction as usual. Your signed payment is kept as the fallback.
3. Fully Noded sends it to the receiver's payjoin address (over Tor when it's connected, always
   for `.onion` addresses) and waits up to a minute for their proposal.
4. **Payjoin ready:** every check passed and the payjoin is signed. Review it, then broadcast.
   **Signed (no payjoin):** the reason, and your normal payment is ready to broadcast.

Nothing is broadcast without you tapping Send.

### What's checked before you sign

The receiver's proposal is checked against BIP78's sender rules, and refused if any fail:

- version, locktime and your inputs' sequence numbers unchanged, and all inputs share one sequence
- every input and output of yours still there, in the original order
- the payment output still pays the same address at least the same amount (Fully Noded always
  sends `disableoutputsubstitution=true`, so the receiver can't redirect it)
- no key paths or partial signatures anywhere; your inputs not finalized by the receiver; the
  receiver's inputs finalized, with UTXO data, of your script type
- the fee never goes down, and any extra fee taken from your change stays within the limit you
  set (`maxadditionalfeecontribution`: your fee rate × one input's size), the actual fee
  increase, and the size of the inputs the receiver added
- then only your own inputs are signed, the node finalizes the transaction, and it must pass
  `testmempoolaccept`

Error messages from the receiver are never shown as they are (they could be used for phishing):
only BIP78's well-known errors, in Fully Noded's own words.

## Receiving a payjoin

On the **Receive** screen of a single-sig **segwit (P2WPKH)** or **taproot** wallet whose signer is
on this device:

1. Turn on **Payjoin**. Fully Noded:
   - starts a small payjoin listener inside the app (on this phone only),
   - asks Tor for a **one-time onion address** for it (`ADD_ONION … Flags=DiscardPK`: the key is
     thrown away, so the address can never be reused or linked to another invoice),
   - publishes it, and fetches its own onion through Tor until it answers, so "ready" means payers
     really can reach it (usually under a minute).
2. The invoice gains `pj=http://<onion>/pj&pjos=0`. Plain `http` is right for an onion: Tor
   encrypts and authenticates the connection. `pjos=0` tells the payer you won't change the
   payment output.
3. **Keep the screen open** until you're paid. iOS pauses the listener in the background; a payer
   who can't reach it simply pays normally.
4. When a payer connects, Fully Noded checks their payment, adds one of your coins and replies.
   They sign and broadcast the payjoin.
5. If they never broadcast anything, a **Broadcast the payer's payment** button appears after a
   couple of minutes: it broadcasts their original payment instead (only one of the two can
   confirm).

Leaving the screen removes the onion and stops the listener. A new address gets a new onion.

### What the receiver checks

- payjoin version 1
- every input finalized and with its UTXO, all P2WPKH or all taproot
- it pays this invoice's address at least the invoice amount
- none of its inputs have been seen before (stops a proposal being replayed as a new payment)
- it's fully signed and accepted by your node's `testmempoolaccept`, so nobody can probe your
  coins with fake payments
- none of its inputs are yours (Fully Noded only ever signs the coin it adds)
- one payjoin per invoice (a payer retrying the same payment gets the same reply)

### Which coin is added

A confirmed coin of this wallet of the same type as the payer's inputs, preferably of a similar
size to the payment so it doesn't look unnecessary. It goes in at a random position. Your
payment output grows by its value less the fee for the extra input, which the payer's change
covers within the limit they allow.

## Who can pay your payjoin invoice

Wallets that support BIP78 payjoin to an onion address: Fully Noded, Sparrow and Wasabi, among
others. Any other wallet ignores `pj=` and pays the address normally.

## Requirements and limits

- A node connection (the node checks and finalizes transactions), and Tor for receiving.
- Receiving: single-sig P2WPKH or taproot wallets, with the signer on this device. The app must
  stay open while you wait to be paid.
- Paying: Fully Noded must be able to fully sign the payment by itself; a multisig payment that
  needs another device's signature is sent normally.

## Debugging

Debug builds log every step to Xcode's console as `[payjoin]` lines, and every node call as
`[rpc]`.

## Code

- `Wallet Logic/Payjoin.swift`: the sender (original PSBT, transport over Tor, the checklist,
  signing).
- `Wallet Logic/PayjoinReceiver.swift`: the receiver (loopback HTTP listener, checks, coin
  selection, proposal) and the per-invoice session.
- `Helpers/URL Requests/Tor/TorClient.swift`: `addOnionService` / `removeOnionService`.
