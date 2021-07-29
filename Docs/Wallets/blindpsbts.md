# Fully Noded p2p coinjoin - Blind psbts

Fully Noded v0.2.22 will include a new feature called "Blind psbts".

When this feature is toggled on from settings transactions will be created in a
way that breaks the common input output heuristic of 1 recipient output and 1
change output.

Blind psbts are different in that:

- no "change" outputs
- all address script types must match
- minimum 3 outputs
- minimum 3 inputs
- no address reuse allowed
- equal input amounts (for now)
- equal output amounts (for now)
- ⚠️ outputs will always have the mining fee deducted from them equally

## Initiating a blind psbt

In the simplest scenario User A wants to send a specific amount of btc to another
party who may or may not be a participant in the coinjoin. The idea being to make
every transaction a coinjoin.

User A adds an amount and address to the "Send" view as normal.

Fully Noded will find 3 identically denominated utxos that are under the control
of your wallet. utxos which are not `solvable` will not be consumed.

Fully Noded uses your change descriptor to derive 2 addresses and then creates 3
outputs utilizing the original receive address User A provided.

**The mining fee is equally deducted from the three outputs!**

This means whoever is on the receiving end of this transaction will be the one
paying at maximum 1/3 of the mining fee (the address User A originally provided
to initiate the tx).

Fully Noded will do its usual transaction analysis on the psbt and display all
the info to User A.

At this point User A may either sign the transaction and send it or optionally
export the psbt to User B.

## Peer to peer flow

At this point in time User A opts to export the blind psbt to User B.

- It will be exported fully encrypted, in [generic format](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-005-ur.md)
- Only Fully Noded will be able to decrypt the data into a psbt
- If the users wallet does not control the input the input data will be hidden

1. User A initiates the transaction as described in the first section
2. User A exports the psbt to User B
3. User B is automatically prompted to "add another blind psbt"
4. Fully Noded automatically creates another 3 inputs and 3 outputs as
described in the previous section as an independent psbt for user B
5. Fully Noded joins the two psbts with the `bitcoin-cli joinpsbt` command which
automatically shuffles all inputs and outputs
6. User B may either sign the transaction or export it to User C whereby the
above process can repeat indefinitely
7. User B opts to export the blind psbt to User C
8. User C opts to sign the the transaction
9. User C exports the psbt back to User B, who signs and exports to User A who
signs and broadcasts the transaction
10. All users rejoice in making the utxo set a bit more private for all parties involved 😄

## Dividing utxos

Fully Noded has a new "divide" feature for your utxos. Tap utxo(s) then tap ➗

You will be prompted to choose an amount (0.1, 0.5, 0.05, 0.001 for now). This will
trigger Fully Noded to create a transaction that divides the specified utxos into those
amounts. Users will always need 3 identically denominated utxos to be able to create a
blind psbt, this tool helps to prep your utxos for Fully Noded, Samourai and
Wasabi coinjoins which support similar denominations.

### General info

- **It is recommended to export the psbts in file format as animated QR codes can be slow.**
- ***Blind psbts are encrypted to protect your privacy against people who are not involved in the coinjoin.***
- The final recipient will gain knowledge of which inputs and outputs are not his own!
- If only two people are involved then both parties will be able to identify each others addresses!

The more people who are involved the more obfuscation there is. `bitcoin-cli joinpsbts` shuffles
all inputs and outputs each time the psbt is passed to a new user, making it exponentially
more difficult to deduce whose addresses belong to who.

Please offer feedback and feature tweaks/requests here as an issue or Telegram and Twitter.
