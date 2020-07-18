# Q&A about Fully Noded
Inspired by questions asked on the open Telegram *Fully Noded* group [here](https://t.me/FullyNoded).

Beware: A Q&A is always *work in progress*. Tips & help welcome.

### Disclaimer
None of the respondents in the **open** Telegram group have been explicitly named as a source, except for ***@Fonta1n3***. For practical reasons educational images uploaded by Telegram group members have been downloaded to [Imgbb](http://imgbb.com), we de-personalised them by giving images a new name. Under these new names these images have been used in the Q&A to clarify the questions and answers.

> We've done our best to protect the privacy of the Telegram group members by investigating the images we used. We haven't come across personal identifiable information (pii). However, should we have made a mistake after all, please let us know and we'll correct this immediately.

## Explanation of the Q&A

The answers are given by ***@Fonta1n3***. If not than an explicit source is referenced.

## Recommended reading

1. [Introducing Fully Noded Wallets](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102) July 2020 - @Fonta1n3
> Topics:<br/>
   > a. wallets, bitcoin core versus Fully Noded wallets<br/>
   > b. import public keys, derivation paths and address scripts<br/>
   > c. recover every possible popular derivation across a number of wallet vendors<br/>
   > d. Samourai wallet special treatment<br/>
   > e. activate, deactivate and delete
2. [Introducing Fully Noded PSBT Signers](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558) July 2020 - @Fonta1n3
   > Topics:<br/>
   > a. libwally<br/>
   > b. add psbt signers<br/>
   > c. signed raw transaction over psbt <br/>
   > d. airdrop psbt as a raw data BIP174 file<br/>
   > e. add BIP39 seed words as a signer<br/>
   > f. analyze the base64 encoded text of the psbt<br/>
   > g. filters through all the signers stored on your device and signs the psbt
## Definitions

- FN : Fully Noded app
- FN2 : Fully Noded 2 app, misnaming because it is a different app than FN. This Q&A tries to explain the differences. A new name for FN2 will be invented in the future.
- satoshi: 0.000000001 BTC. A satoshi is the smallest unit of a bitcoin, equivalent to 100 millionth of a bitcoin.
- UTXO's: Unspend transaction Outputs; UTXO stands for the unspent output from bitcoin transactions. Each bitcoin transaction begins with coins used to balance the ledger. UTXOs are processed continuously and are responsible for beginning and ending each transaction. Confirmation of transaction results in the removal of spent coins from the UTXO database. But a record of the spent coins still exists on the ledger. **for newbies**: UTXO is unspent bitcoin that you can "see" in your wallet and on the blockchain. It is an address and amount of sathosis. As soon as you spend the money, it won't add to your wallet balance anymore and therefore will only.
- signed raw transaction : [Wikipage](https://en.bitcoin.it/wiki/Raw_Transactions) explains it all
- psbt: Partially signed bitcoin transactions (PSBTs) Also covering BIP174. Partially Signed Bitcoin Transactions (PSBTs) are a data format that allows wallets and other tools to exchange information about a Bitcoin transaction and the signatures necessary to complete it.
- rbf; Replace-By-Fee (RBF) is a node policy that allows an unconfirmed transaction in a mempool to be replaced with a different transaction that spends at least one of the same inputs and which pays a higher transaction fee. **For newbies:** a transaction that can't get through because of too low fee, can be overridden (replaced) with a higher fee to maybe succeed instead.
- pure bitcoin core wallets: traditional bitcoin wallet, that has to be manually backed up, recovered etc using bitcoin-cli. Your node will sign transactions and will hold the private key.
- Fully Noded wallets: support BIP39 recovery words, the seed is encrypted and stored on your device **not** on the node. The node will only ever hold public keys. Your node will build psbt for us that FN will sign (not your Node). Your node verifies the UTXO's
- Libwally : an open source library (https://github.com/ElementsProject/libwally-core) used by Fully Noded, (https://github.com/blockchain/libwally-swift/blob/master/README.md) which allows us to utilize BIP39 directly in the app meaning you can easily recover your Fully Noded wallet with Electrum for example. Now when you create a wallet you will get a 12 word recovery phrase (no passphrase by default) to backup and keep safe.
- legacy bitcoin address (p2pkh): refers to the accepted common standard to derive non segwit addresses. These addresses always begin with a 1.
- bech32  bitcoin address(p2wpkh):BIP49 refers to the accepted common standard of deriving segwit "compatibility" addresses. These addresses begin with a 3.
- segwit wrapped  bitcoin address (p2sh-p2wpkh) : BIP49 refers to the accepted common standard of deriving segwit "compatibility" addresses. These addresses begin with a 3.
- BIP84 keys : BIP84 refers to the accepted common standard of deriving native segwit addresses. These addresses always begin with bc1 - and are referred to bech32 addresses.
- Segwit addresses: – Segregated Witness – or SegWit in short – reduced the transaction data’s size to allow for faster transactions, better scalability and decreased fees. Native SegWit (bech32) enhanced this even further and includes even lower fees. Not all exchanges and wallet providers support sending Bitcoin to a Native SegWit address yet, which is why you are presented both options in Ledger Live. Transactions between all 3 address types are possible
- keypool : The keypool is a collection of unused addresses in your wallet. The keypool parameter tells the client how many unused addresses to keep in its pool. The original purpose of the keypool is to allow you to backup your wallet file less frequently and still have access to all your funds in the event of a hard drive failure. However since the invention of Hierarchical Deterministic Wallets (HD wallets, [BIP32](https://en.bitcoin.it/wiki/Deterministic_wallet)): If you have a HD wallet (check the icon on the bottom-right corner in Bitcoin Core), it doesn't matter. If you've created your wallet in an older version of Bitcoin Core, it's not an HD wallet. If that's the case, your keypool is important for backups: your backup has the same 1000 keys, which means you only need to make a new backup after using many different new addresses. If you would limit the keypool size to 20, you'll quickly run out of addresses, and you need to make new backups very often. That's the reason the keypool was increased from 100 to 1000. An important distinction with regrads to FN and Bitcoin Core is that Bitcoin Core is not able to add multisig addresses to the keypool, therefore we rely on the `bitcoin-cli` command `deriveaddresses` to derive multisig addresses on the fly using your multisig descriptors.
- Output descriptors: Descriptors are a clever way of importing specific keys into your node from any derivation, for any (or all) address types, single or multi signature, along with a fingerprint so offline psbt signers like a Coldcard and Fully Noded can sign the psbt if they hold the correct seed.
- coldcard : a type of hardware wallet to store, send and receive crypto currencies
- ledger Nano S/X: types of hardware wallets to store, send and receive crypto currencies
- Keepkey : a type of hardware wallet to store, send and receive crypto currencies
- Trezor : a type of hardware wallet to store, send and receive crypto currencies
- Tor:Tor is free and open-source software for enabling anonymous communication. The name derived from the acronym for the original software project name "The Onion Router". [Read more in Wikipedia](https://en.wikipedia.org/wiki/Tor_(anonymity_network))
- Node: A bitcoin full Node is a independent entity in a peer to peer ecosystem. A Node independently checks and verifies all protocol rules for incoming broadcasted transactions. A full node does not trust, but verifies. Technically speaking a *node* is a computer connected to other computers which follows rules and shares information. A *'full node'* is a computer in Bitcoin's peer-to-peer network which hosts and synchronises a copy of the entire Bitcoin blockchain. [Here](https://medium.com/@gloriazhao/map-of-the-bitcoin-network-c6f2619a76f3) is an excellent read on nodes, what they are and the differences between types of nodes.

## Knowledge you should be confidently applying
- The definitions above
- Output Descriptors : https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
- BIP 32, BIP39, BIP44, BIP47, BIP49, BIP84, BIP174
- derivation paths, keypools
## Actions you should to be comfortable with
- Amend knowledge and keep existing knowledge up to date
- recover from a seed
- sweep to a new wallet
- use bitcoin-cli
- install, sync, start and stop your own full node
- connect your TOR V3


# Q&A

## Question : This button should bring up info and allow me to make changes?
<img src="https://i.ibb.co/N1FKq50/refresh-info.jpg" alt="refresh-info" border="0" width="200">

### Answer - It does only for Fully Noded wallets. Does not do anything for pure bitcoin core wallets. Fully Noded allows you to manually create wallets and access all your nodes wallets. If a user were to create a wallet externall from the app then there is now way for the app to know the required information about that wallet to be able to display these details. It is only possible for FN to show wallet details when the wallet was created via the `+` button on the `Active Wallet` tab. With these Fully Noded wallets the app will remember the public key descriptors that were used to create the wallet, its derivation, its keypool size so that the user may easily increase the size of the keypool, the wallets editable label, the wallets filename on your node, an in app unique ID so that we can delete the wallet from the app. If the user adds an independent signer in the form of BIP39 words then the app will cross check the derived xpubs match the xpubs in the descriptor used to create the wallet and show the user whichever signer is able to sign for this wallet.


## Question: why can't I see the label I gave the change address? When I have wallet loaded and go to List Labels under settings I can only see the name I have the wallet, not the label I gave the change address?

### Answer - When importing change keys *and* adding them to the keypool you can not add a label to change keys, this is a Bitcoin Core limitation. However if you do not add the keys to the keypool (multisig for example) yet you wish to designate your imported descriptor or extended key as deriving change keys then you can assign them a label. This would be useful if you are recreating an external wallet from say a Coldcard or a Ledger and you want to identify change outputs from receive outputs. There are multiple ways to see your keys labels. They will be shown in each transaction by default, in the utxo view or you can do it manually by going to `tools` > `Wallet` > `List Address Groups/List Labels/Get Address Info/Addresses by Label`. If your wallet conforms to BIP44/84/49/48 then you can always look at the utxo info view and see the change path in the descriptor for that utxo, for example a BIP44 receive path is `m/44'/0'/0'/0/0` and a change key would be `m/44'/0'/0'/1/0`


## Question : I'd like to recover a wallet using FN without revealing seed words, is that possible?

### Answer - The recovery wallet is specifically for recovering wallet and making them spendable. However it is an extremely easy way to import wallets into FN, if you want to make it watch-only you can always delete the seed words by navigating to `Active Wallet` > `squares button` > `signers button` > `tap the signer` > `you will see a delete button`. The proper way to import a wallet as watch-only is to import either the `xpub` or the `descriptor` for that wallet via `Active Wallet` > `import` > `xpub/descriptor`. If importing an `xpub` you will need to know its derivation path, and ideally import it twice once using the receive path and once designating it as change to ensure all transactions/utxos show. ***To do, create a pictorial explaining how to do this with accurate instructions***


## Question : How to import my BRD wallet?

### Answer - You can go to the “active wallet” tab > + button > recovery > input your BRD seed words and optional BIP39 passphrase, then tap recover or you can import the `xpub` via `Active Wallet` > `import` > `xpub`


## Question : `.txn` files, is there anyway to open on iPhone?

### Answer - A `.txn` file is a signed raw transaction as exported by Coldcard. Fully Noded has registered the file extension `.txn` so that when you airdrop or tap a .txn file in the iOS Files app FN will automatically launch a `Broadcaster` allowing you to broadcast that transaction with your node. You can always copy and paste the raw transaction and go to `Tools` > `Transactions` > `Broadcast` to do it manually.


## Question : how to verify all outputs of a raw transaction? I verified the Send  address.  I would like to verify the Change address. How?

### Answer - Copy and paste the raw transaction in hex formate `02004849494...`, go to `Tools` > `Transactions` > `Verify`, this tool will go through each input and output fetching all the addresses associated with each input and output. You can from their copy and paste the address and `Tools` > `Wallet` > `Get Address Info` to verify whether the address belongs to your nodes current active wallet.


## Question : Why doesn't broadcast work via my Node?

### Answer - You can only broadcast signed raw transactions. The only purpose of psbt's is to end up with a signed raw transaction. e.g. The `.txn` file from Coldcard.


## Question : Why did you choose iOS to build on? Any advantage compared to Android?

### Answer - Only because that is what I know how to code with the best and what I am a user of.


## Question: please elaborate on the seemingly *contradictory* statements about '100% offline signing'
"Fully Noded now acts like a hardware wallet, it can sign anything 100% locally with no internet required at all." says the *Introduction FN Wallets* Medium post July 1 2020 [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102).

"This works without internet connection but we do make a few commands to the node so it is not offline optimized. Perhaps in the future we will move to 100% offline." <br/>
says the *Introduction to FN psbt signers* a week later [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558).

**Could you pls elaborate on that. My question is about the two medium posts of @Fonta1n3, that seem to have *contradictory* statements in it.**
### Answer - It's not contradictory, it does sign 100% offline. FN makes other commands that require an internet connection though, its possible to enhance that in the future. The 'online' commands that the signing process generates, do not reveal any sensitive data.

#### Further elaboration on the answer / issue
In order to make the signing functionality work as reliably as possible the app first passes it to your node for processing `bitcoin-cli walletprocesspsbt`, if for some reason the `psbt` you passed to the app does not hold all the `bip32_derivs` then that command will get your node to fill out the `bip32_derivs` for us (our offline signer needs the `bip32_derivs` in order to sign as they tell us what derivation path the private key needs to be at). The process command also gets your node to sign the psbt if it can, it is always possible a user has imported an `xprv` themselves into their node without FN knowing about it (FN2 for example makes your node a signer), so that command accounts for that possibility.

All of the above can not be done offline, if its going to be 100% offline we can't sign with your node and cant fill the `bip32_derivs` with your node.

After that we then loop through all the signers that are stored on the device, decrypting them and seeing if its possible to sign the `psbt` with each. It then signs locally using the Libwally library.

From here we could use LibWally to finalize the `psbt` offline but there is a bug (its been fixed but waiting for it to be released) where if there are a certain number of inputs finalizing the `psbt` offline causes a crash. So again we pass it to the node for finalizing. Once it's complete it can be converted to raw transaction and broadcast.


## Question : My transaction still says 0 confirm?

### Answer - You can set a mining fee target in `settings`, if you want it to be confirmed quickly adjust this setting accordingly. Otherwise all transactions are `replace by fee` enabled in FN. To bump the fee simply tap the transaction and you will see a button for bumping the fee. If FN does not hold a signer for the wallet and the node can not sign then FN will allow you to export the new transaction as a `psbt` which you will need to pass back to your signer and broadcast again as utilizing `rbf` means you create an entirely new transaction.

## Question : Any suggestion about this problem? All the username, password, and onion address are OK<br/>
<img src="https://i.ibb.co/WFpFtXm/err-network-conn.jpg" alt="err-network-conn" border="0" width="200">

### Answer - Force quitting FN and rebooting `tor` on your `node` always works. Sometimes Tor can get "stuck" especially if your node's machine has gone offline or been put to sleep.


## Question : How do I troubleshoot connection issues over Tor between FN and Bitcoin Core Nodes on a Mac?

### Answer - Here are some [common issues and fixes](https://github.com/Fonta1n3/FullyNoded#troubleshooting). You can troubleshoot Tor issues on the mac by opening a terminal and running `open /usr/local/var/log/tor.log`, read the Tor log and make sure there is nothing obvious going wrong there, most common Tor issues revolve around permissions, ensure your `HiddenServiceDir` has the correct permissions by running `chmod 700 <HiddenServiceDir>` where `HiddenServiceDir` represents the path to your `HiddenServiceDir` that is specified in your `torrc` file, your `torcc` file can be found at `/usr/local/etc/tor/torrc`. The Bitcoin Core log can be helpful too, however you must have the `debug=tor` line added to your `bitcoin.conf` file. Then you can run `open ~/Library/Application Support/Bitcoin/debug.log`

**You are also better off launching Tor as a service**<br/>
1. first ensure tor has stopped
2. then open a terminal and paste in `brew services start tor`, this will ensure Tor always launches automatically when your mac starts, if you want to stop tor run `brew services stop tor`


## Question : How can I test the network connection between them (FN and Node)?

***Big Disclaimer:***
> This is not great for security, so I would refresh your HS hostname after trouble shooting this and change your rpcpassword. All you have to do is delete the ‘HiddenServiceDir’ folder and restart tor and you'll get a brand new url.

> Before doing the below, try rebooting Tor on the node server side, force quitting FN and see if it connects, double check you added your tor v3 url correctly with the right port at the end, typically `:8332` for mainnet.

### Answer - Recreate your hidden service url like so: `http//:rpcuser:rpcpassword@xxx.onion:8332`, paste it in to a Tor browser as if you were visiting a website, if your connection is alive and functioning properly you will get a `server only responds to POST requests` error in the Tor browser. If you do not get that error then something is very wrong, again check the Tor and Bitcoin Core logs to debug the issue.


## Question: What is the best of breed desktop wallet to connect to your node?

### Answer - [Specter](https://github.com/cryptoadvance/specter-desktop), for me the easiest way to get it running is the following commands in a terminal:

```
git clone https://github.com/cryptoadvance/specter-desktop.git
cd specter-desktop
virtualenv --python=python3 .env
source .env/bin/activate
pip3 install -r requirements.txt
pip3 install -e .
python3 -m cryptoadvance.specter server
```
Seeing the progress being made at Specter Desktop is 🔥🔥🔥 by far my favorite desktop wallet and a perfect match for Fully Noded. Highly recommended for using your own node as a wallet.
#### Further elaboration on the answer
1. To export a wallet from **Specter** click your `wallet > settings > export`<br/>
<img src="https://i.ibb.co/PtnjHdt/Specter-export.jpg" alt="Specter-export" border="0" width="200">
<img src="https://i.ibb.co/ZmNs9vN/QRcode-specter.jpg" alt="QRcode-specter" border="0" width="200"><br/>
2. To import into FN: active wallet tab > + > import<br/>
<img src="https://i.ibb.co/P9PnC3y/crea-wallet-FN.jpg" alt="crea-wallet-FN" border="0" width="200">
<img src="https://i.ibb.co/ZhFPNLv/importing.jpg" alt="importing" border="0" width="200">
<img src="https://i.ibb.co/s9FLCtM/import-succes-FN.jpg" alt="import-succes-FN" border="0" width="200"><br/>
3. This always **recreates a watch-only wallet** on your node with Fully Noded, to make it spendable just add a signer and the app will automatically sign the `psbt` your node creates with that wallet.<br/>
4. To **export a wallet** just tap the export button from the active wallet tab in FN:<br/>
<img src="https://i.ibb.co/BCBMrkg/FN-wallet-export.jpg" alt="FN-wallet-export" border="0" width="200">
