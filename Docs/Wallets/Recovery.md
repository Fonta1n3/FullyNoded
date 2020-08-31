# Recovery

### Fully Noded Wallets

There is a recovery tool which can be accessed via the "Active wallet" tab by tapping the plus button in the top left. With this tool recovery is powerful and automated. You can input any BIP39 mnemonic with an optional passphrase and custom account number (default account number is 0). 

From that point on Fully Noded will import almost every conceivable (popular) derivation scheme into your nodes wallet so that you may sweep/spend the funds (BIP44/49/84, Samourai derivations, BRD, Coinomi to name a few) along with all three address types for each derivation including change and receive keys). The signing functionality of Fully Noded means it can sign for any derivation path, the only limitation is what is imported into your node. 

#### Walletsrecovery.org
To be clear we import *most* of the popular schemes from [walletsrecovery.org](https://walletsrecovery.org) into your node as watch-only wallets where your node simply holds public keys and is able to watch for the utxo's, for Samourai all derivations are imported except BIP47. 

The derivations (important to note these are the root derivation paths, we add `/0/*` for receive keys and `/1/*` for change keys as well as allowing testnet compatibility as per bip44/84/49 if you node is on testnet):

- m/44'/0'/0' (bip44)
- m/84'/0'/0' (bip84)
- m/49'/0'/0' (bip49)
- m/0' (BRD wallet)
- m/84'/0'/2147483644' (Samourai bad bank)
- m/84'/0'/2147483645 (Samourai pre mix)
- m/84'/0'/2147483646' (Samourai post mix)
- m/84'/0'/2147483647' (Samourai ricochet bip84)
- m/44'/0'/2147483647' (Samourai ricochet bip44)
- m/49'/0'/2147483647' (Samourai ricochet bip49)

The node will build psbt's for us and Fully Noded then uses the seed words to sign the psbt's. Whenever you recover or create a "Fully Noded Wallet" we use the `combo` prefix on your descriptors so that your node will see utxo's for every address type and be able to spend them. Fully Noded will recover the first 2500 keys for each derivation. Fully Noded automatically initiates a rescan either for the entire blockchain or for your pruned nodes pruned blockheight, you can monitor the rescan status from Tools > Get Wallet Info, you will not see balances until the scan has completed.

### Anything

Fully Noded is extremely powerful in that you can recover or import any derivation for any script type into your nodes hot wallet so that funds can be swept elsewhere.

You have a few options, you may at anytime go to "import" and import either a wif private key, xprv or [descriptor](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md#examples) to recover wallets.


#### Convert BIP39 to Xpriv
Generally speaking you would use a tool like [this](https://iancoleman.io/bip39/) to convert your BIP39 words to an xprv and then import that xprv into Fully Noded. You will need to ensure the wallet you are importing into was either created as a blank wallet or hot wallet via the Fully Noded "wallet manager". When importing xprv's you need to disable "keypool" and "change" during the import options. You will be prompted to choose a derivation scheme. Users may select BIP32 segwit, BIP32 wrapped segwit, BIP32 legacy. Doing so will treat your xprv as representing the entire path of your derivation scheme `xprv/<your private key index here>`.


#### BIP44/49/84
Or the user may choose BIP44/49/84. If making this choice the user will need to supply a fingerprint for their master key (xprv). If you do not know it you can input a dummy as it is not absolutely required for all use cases. You could for example input this fingerprint `5585785b` and it will still work. The reason for this is we create a Bitcoin Core descriptor whereby the xprv represents the account path and Bitcoin Core needs a fingerprint to be interoperable with offline signers. In this scenario you xprv represents the 0th account path m/44'/0'/0' as a BIP44 example.

##### Create your own descriptor
A far more flexible way to recover things is by creating your own descriptor. Then you can recover whatever you want. For example a segwit bip84 account 2000 would be:

`wpkh([5585785b/84'/0'/0']xprv73h7hr7rh/0/*)` as an example.

Or all address types would be `combo([5585785b/84'/0'/0']xprv73h7hr7rh/0/*)` 

To read more about what the above means check out this [explainer](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md).

Of course that means you need to understand the derivation, which xprv to use and have a fingerprint.
