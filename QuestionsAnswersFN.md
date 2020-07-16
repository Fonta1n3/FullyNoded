# Q&A about Fully Noded
Selected from the open Telegram *Fully Noded* group [here](https://t.me/FullyNoded), from July 2020. 

Beware: A Q&A is always *work in progress*. Tips & help welcome.

### Disclaimer
None of the respondents in the **open** Telegram group have been explicitely named as a source, except for ***@Fonta1n3***. For practical reasons educational images uploaded by Telegram group members have been downloaded to [Imgbb](http://imgbb.com), we de-personalised them (by giving a new name) and under this new name these images have been used in the Q&A to clarify the questions and answers.

> We've done our uttermost to ensure the protection of privacy of the Telegram group members by checking the images for personal identifiable information (pii). However, should we after all have made a mistake, please let us know and we'll correct it immedeately.

## Explanation of the Q&A

The answers are given by ***@Fonta1n3***. If not than an explicit source is referenced.

I adjusted the text to the Q&A format and added rating for how sure the respondent is about the answer:
- ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure` <br/>
- ![#1589F0](https://via.placeholder.com/15/1589F0/000000?text=+) `pretty sure`<br/>
- ![#f03c15](https://via.placeholder.com/15/f03c15/000000?text=+) `not sure`

Explanation:<br/>
> ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`: respondent is sure about the answer given; at that point in time!<br/>
> ![#1589F0](https://via.placeholder.com/15/1589F0/000000?text=+) `pretty sure` : could be wrong, but that's the respondents understanding<br/>
> ![#f03c15](https://via.placeholder.com/15/f03c15/000000?text=+) `not sure` : just a fair guess, no garantuee<br/>

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
- legacy (p2pkh): NOT YET FILLED OUT
- bech32 (p2wpkh):NOT YET FILLED OUT 
- segwit wrapped (p2sh-p2wpkh)
- BIP84 keys : NOT YET FILLED OUT
- keypool : NOT YET FILLED OUT
- Output descriptors: Descriptors are a clever way of importing specific keys into your node from any derivation, for any (or all) address types, single or multi signature, along with a fingerprint so offline psbt signers like a Coldcard and Fully Noded can sign the psbt if they hold the correct seed.
- coldcard : a type of hardware wallet to store, send and receive crypto currencies
- ledger Nano S/X: types of hardware wallets to store, send and receive crypto currencies
- Keepkey : a type of hardware wallet to store, send and receive crypto currencies
- Trezor : a type of hardware wallet to store, send and receive crypto currencies
- Tor:NOT YET FILLED OUT
- Node:NOT YET FILLED OUT

## Knowledge you need to be confidently applying
- The definitions above
- Output Descriptors : https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
- BIP 32, BIP39, BIP44, BIP47, BIP49, BIP84, BIP174
- derivation paths, keypools
## Actions you need to be comfortable with
- Amend knowledge and Keep existing knowledgde up to date
- recover from a seed
- sweep to a new wallet
- use bitcoin-cli
- install, sync, start and stop your own full node
- connect your TOR V3


# Q&A July 2020
## Question
### Answer - XXXX


## Question

This button should bring up info and allow me to make changes?
<img src="https://i.ibb.co/N1FKq50/refresh-info.jpg" alt="refresh-info" border="0" width="200">

### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
It does.<br/>
But only for fully noded wallets.<br/>
Does not do anything for pure bitcoin core wallets.

## Question
When I have wallet loaded and go to List Labels under settings I can only see the name I have the wallet, not the label I gave the change address?
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
It should give the label you gave the change keys.<br/>
“List address groups” also does the trick<br/>
Or just try creating a tx, youll get an error if there are no change keys<br/>
If in doubt just import them again.

## Question
I'd like to recover a wallet using FN. Really don’t wanna put my seed words anyplace but my ColdCard if that’s possible.
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
It is a recovery wallet so it needs your seed words and optional passphrase. When you add them youll be prompted that they are valid and can then tap recover.
#### Further elaboration on the answer / issue
Words are encrypted and saved locally, your node only holds public keys and can not spend on its own.<br/>
Your device will be able to spend though by acting as a psbt signer for the psbts your node creates.<br/>
You should opt out of Samourai when prompted as it takes a lot longer.<br/>
You can always delete your seed words from the device if you dont want to be able to spend<br/>

## Question
I managed to get my node connected over TOR, could someone point me in the right direction to import my BRD wallet?
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
You can go to the “active wallet” tab > + button > recovery

## Question
.txn files, is there anyway to open on iPhone?
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
i think if you change the .txn to .txt files app will let you actually open the text and copy it
#### Further elaboration on the answer / issue
its kind of annoying though, if an app has "registered" (with Apple) a specific extension it just automatically always launches that app rather then for example letting you simply view the contents. Changing the extension fixes that. Tt would be much better if multiple apps have the extension registered (e.g. .txn) and you then have a choice of what to do next.

## Question
I verified the Send  address.  I would like to verify the Change address. How?
#### Further elaboration on the question / issue
So verify is see (1) input and 2 outputs and I see the change address input the data-final.txn into verify raw. So I proceed and copy the Change address and paste it into “get address info”?
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
You can go to `tools` - `Transactions`<br/>
Verify tool works with signed raw transactions: *data-final.txn*

> You want the raw transaction, not the psbt!

FN has no ability to auto open raw transactions yet... so tapping it won’t work.<br/>
You need to open it and copy and paste the actual encoded transaction.

Just copy the address, No empty spaces, No punctuation.<br/>

You will see your fingerprint in there. Those steps are really extra paranoia level, but definitely nice to be able to be absolutely sure everything is on point direct from the horses mouth; you hear it from the Node who has direct (personal) knowledge of it.



## Question

I've broadcast this via my node:
<img src="https://i.ibb.co/mcNRr49/psbt-not-raw.jpg" alt="psbt-not-raw" border="0"  width="200">

Why doesn't it work?

### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
That’s a psbt, you can only broadcast signed raw transactions. <br/>
The only purpose of psbt's is to end up with a signed raw transaction.<br/>
E.g. The .txn file from coldcard. i think if you change the .txn to .txt files app will let you actually open the text and copy it

<img src="https://i.ibb.co/VHBqqWz/psbt-example-files.jpg" alt="psbt-example-files" border="0"  width="200">


## Question
I try to connect my **RaspiBlitz** (v1.5.1) with your App (iOS). And after the process my RaspiBlitz get the issue “The bitcoind service is not running”

### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
Nope, better to ask about that error in the raspiblitz group. ***Fully Noded is not capable of turning things on and off on your node.***

## Question
Why did you choose iOS to build on? Any advantage compared to Android?

### Answer - ![#1589F0](https://via.placeholder.com/15/1589F0/000000?text=+) `pretty sure`
More secure. for example with android I was explained by an expert android dev that what FN does and how it uses Tor is not even possible (currently), but he is writing his own Tor libraries to fix that. For example orbot shares hidden service urls with other apps, that is a total show stopper for FN<br/>
I could be wrong, but thats my understanding<br/>
i do not think there is any android app that supports native Tor V3 authentication.. I do not think orbot even supports Tor V3
again, could be completely wrong.<br/>

## Question
"Fully Noded now acts like a hardware wallet, it can sign anything 100% locally with no internet required at all." says the *Introduction FN Wallets* Medium post July 1 2020 [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102).

"This works without internet connection but we do make a few commands to the node so it is not offline optimized. Perhaps in the future we will move to 100% offline." <br/>
says the *Introduction to FN psbt signers* a week later [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558).

**Could you pls elaborate on that. My question is about the two medium posts of @Fonta1n3, that seem to have *contradictory* statements in it.**
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
It's not contradictory, it does sign 100% offline. it makes other commands that require an internet connection though, its possible to enhance that in the future. The 'online' commands that the signing process generates, do not reveal any sensitve data.
#### Further elaboration on the answer / issue
In order to make the signing functionality work as reliably as possible the app first passes it to your node for processing bitcoin-cli walletprocesspsbt, if for some reason the psbt you passed to the app does not hold all the bip32_derivs then that command will get your node to fill out the bip32_derivs for us (our offline signer needs the bip32_derivs in order to sign as they tell us what derivation path the private key needs to be at). The process command also gets your node to sign the psbt if it can, its always possible a user has imported an xprv themselves into their node without FN knowing about it (FN2 makes your node a signer), so that command also takes crae of that possibility.

All of the above can not be done offline, if its going to be 100% offline we cant sign with your node and cant fill the bip32derivs with your node.

After that we then loop through all the signers that are stored on the device, decrypting them and seeing if its possible to sign the psbt with each. It then signs locally using the Libwally library.

From here we could use LibWally to finalize the psbt offline but there is a bug (its been fixed but waiting for it to be released) where if there are a certain number of inputs finalizing the psbt offline causes a crash. So again we pass it to the node for finalizing. And then obviously once its all complete and converted to raw transaction it can be broadcast.


## Question
When I look at my FN wallet (CC) and see the trans made yesterday it still says 0 confirm?
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
Whats your mining fee target? It lives in `settings`.

## Question
Can I bump the fee? And what do I need to do.<br/>
<img src="https://i.ibb.co/tQrV0dN/bump-fee.jpg" alt="bump-fee" border="0" width="200">
### Answer - ![#1589F0](https://via.placeholder.com/15/1589F0/000000?text=+) `pretty sure`
Dont think it'll work but by all means try. It creates an entirely new transaction, so needs to be signed again
#### Further elaboration on the answer / issue
You can now do `rbf` with `psbt`s.<br/>
I added ability for you to `rbf` that and export to cc for signing<br/>
<img src="https://i.ibb.co/KNbDmKW/send-psbt-cc.jpg" alt="send-psbt-cc" border="0" width="200"><br/>
Currently only works if the app has the signer

If the signer is on the device it'll work or if it's a hot wallet.<br/>
for what it's worth by *"work"* i mean that if the device can not sign, it should allow you to export a `psbt` back to your `coldcard` that needs to be signed, if it does not currently do that it will on the next update. This functionality only works with bitcoin core 0.20.0.<br/>

## Question
Any suggestion about this problem? All the username, password, and onion address are OK<br/>
<img src="https://i.ibb.co/WFpFtXm/err-network-conn.jpg" alt="err-network-conn" border="0" width="200">
### Answer - ![#c5f015](https://via.placeholder.com/15/c5f015/000000?text=+) `sure`
Force quiting, and rebooting `tor` on your `node` always works