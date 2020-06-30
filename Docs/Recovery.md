# Recovery

### Fully Noded Wallets

There is a recovery tool which can be accessed via the "Active wallet" tab by tapping the plus button in the top left. With this tool recovery is much simpler. You can input any BIP39 words with an optional passphrase and custom account number. From that point on Fully Noded will import almost every conceivable (popular) derivation scheme into your nodes wallet so that you may sweep/spend the funds (BIP44/49/84 and Samourai derivations). The signing functionality of Fully Noded means it can sign for any derivation path at all, the only limitation is what is imported into your node. To be clear we import most of the popular schemes from [walletsrecovery.org](https://walletsrecovery.org). Onlyinto your node as watch-only wallets where your node simply holds public keys and is able to watch for the utxo's. The node will build psbt's for us and Fully Noded then uses the seed words to sign the psbt's. Wehenever you recover or create a "Fully Noded Wallet" we use the `combo` prefix on your descriptors so that your node will see utxo's for every address type and be able to spend them. Fully Noded will recover the first 500 keys for each derivation. When the initial import is complete you will need to intiate a rescan to see the utxo's and balances.

### Anything

Fully Noded is extremely powerful in that you can recover or import any derivation for any script type into your nodes hot wallet so that funds can be swept elsewhere.

You have a few options, you may at anytime go to "import" and import either a wif private key, xprv or [descriptor](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md#examples) to recover wallets.

Generally speaking you would use a tool like [this](https://iancoleman.io/bip39/) to convert your BIP39 words to an xprv and then import that xprv into Fully Noded. You will need to ensure the wallet you are importing into was either created as a blank wallet or hot wallet via the Fully Noded "wallet manager". When importing xprv's you need to disable "keypool" and "change" during the import options. You will be prompted to choose a derivation scheme. Users may select BIP32 segwit, BIP32 wrapped segwit, BIP32 legacy. Doing so will treat your xprv as representing the entire path of your derivation scheme `xprv/<your private key index here>`.

Or the user may choose BIP44/49/84. If making this choice the user will need to supply a fingerprint for their master key (xprv). If you do not know it you can input a dummy as it is not absolutely required for all use cases. You could for example input this fingerprint `5585785b` and it will still work. The reason for this is we create a Bitcoin Core descriptor whereby the xprv represents the account path and Bitcoin Core needs a fingerprint to be interoperable with offline signers. In this scenario you xprv represents the 0th account path m/44'/0'/0' as a BIP44 example.

A far more flexible way to recover things is by creating your own descriptor. Then you can recover whatever you want. For example a segwit bip84 account 2000 would be:

`wpkh([5585785b]84'/0'/2000')/xprv73h7hr7rh/0/*)` as an example.

Or all address types would be `combo([5585785b]84'/0'/2000')/xprv73h7hr7rh/0/*)` 

To read more about what the above means check out this [explainer](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md).

Of course that means you need to understand the derivation, which xprv to use and have a fingerprint.

