# Fully Noded p2p coinjoin - Blind psbts

* Fully Noded v0.2.22 new feature set; "Blind psbts"

Comments, feedback, complaints, critiques, requests are always welcome. Reach out.

Functionality:
1. coordinator-less (p2p) coinjoin type transaction (strict policy)
2. flexible transaction type that easily allows multiple people to mix their utxos even if 
input/output amounts are not equal (flexible policy)
3. divide utxos

You can think of this feature set as step 0 in the evolution of privacy related features
for Fully Noded. 

⚠️ This is not an end all privacy solution!

⚠️ These are new features and have not been tested or critiqued by anyone other then myself!

blind psbts are collaborative transactions, part of a larger privacy ecosystem. 
blind psbts allow peers to join in on each others real world transactions (or simple mixes) to make spending 
your btc and the utxo set itself a bit more private. The more participants the better! You can test the new 
features out with yourself, to gain privacy you should always get others involved.

Please read more about onchain privacy [here](https://en.bitcoin.it/wiki/Privacy#Blockchain_attacks_on_privacy).

When `Blind psbts` are toggled on transactions will be created in a
way that breaks the common input output heuristic of  1 input, 1 recipient output and 1
change.

Users will be prompted to choose a `strict` or `flexible` policy when initiating a
blind psbt.

⚠️ Whenever Fully Noded creates a blind psbt it will automatically label the consumed utxos as 
`*consumed by blind*`. It will never add a utxo to a blind psbt which has this label, for testing
or failed psbts you may need to manually edit the label via the utxos view (tap the paperclip).
If you toggle off `blind psbts` in settings Fully Noded will consume those utxos regardless of
the label and revert to Bitcoin Core coin selection.

### strict policy

- no "change" outputs
- all address script types must match
- minimum 3 outputs
- minimum 3 inputs
- no address reuse allowed
- equal input amounts
- ~equal output amounts
- ⚠️ outputs will always have the mining fee deducted from them equally

### flexible policy

- change is possible! you should always lock your change outputs (tap the lock button on the utxo)
- all address script types must match
- minimum 3 outputs
- minimum 3 inputs
- no address reuse allowed
- inputs not always equal denomination
- outputs not always equal denomination
- mining fee should be deducted from the change output

Always study each and every transaction Fully Noded creates. Do not trust, verify.
If you have a question stop, ask and wait.

## Initiating a blind psbt (strict policy)

In the simplest scenario User A wants to send a specific amount of btc to another
party who may or may not be a participant in the coinjoin. The idea being to make
every transaction a coinjoin or to simply make it easier for peers to mix their utxos
without a coordinator.

User A adds an amount and address to the "Send" view as normal.

Fully Noded will find 3 identically denominated utxos that are under the control
of your wallet. utxos which are not `solvable` will not be consumed.

Fully Noded uses your change descriptor to derive 2 addresses and then creates 3
outputs utilizing the original receive address User A provided.

**The mining fee is equally deducted from the three outputs!** (only for strict policy)

This means whoever is on the receiving end of this transaction will be
paying at maximum 1/3 of the mining fee (the address User A originally provided
to initiate the tx).

Fully Noded will analyze the psbt as usual allowing User A confirm all is well.

User A may either sign the transaction and send it or optionally
export the psbt to User B.

## Peer to peer flow

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

- psbts will be exported fully encrypted, in [generic format](https://github.com/BlockchainCommons/Research/blob/master/papers/bcr-2020-005-ur.md)
- Only Fully Noded will be able to decrypt the data into a psbt
- If the users wallet does not control the input the input data will be hidden

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
- All users will gain knowledge of which inputs and outputs are not his own!
- If only two people are involved then both parties will be able to identify each others addresses!

The more people involved the greater the obfuscation. `bitcoin-cli joinpsbts` shuffles
all inputs and outputs each time the psbt is passed to a new user, making it exponentially
more difficult to deduce whose addresses belong to who.

Please offer feedback and feature tweaks/requests here as an issue or Telegram and Twitter.
