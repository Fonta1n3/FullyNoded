# Wallet tasks

 - [Create](#create)
 - [Backup](#Backup)
 - [Delete](#Delete)
 - [Sending](#Sending)
    - [Transaction fee](#Transaction-fee)
    - [Lightning](#Lightning)
    - [Donation](#Donation)
    - [Sweeping](#Sweeping)
    - [Batching](#Batching)
    - [BIP21](#BIP21)
    - [Currencies](#Currencies)
    - [PSBT](#PSBT)
    - [Raw Transaction](#Raw-Transaction)
    - [Replace By Fee](#Replace-By-Fee)
 - [Receiving](#Receiving)

A seperate page is dedicated to Recovery:

 - [Recovery](./Recovery.md)

## Create

Read the instruction on the site [here](https://fullynoded.app/faq/#How-Do-I-Create-a-Wallet) to create

## Backup

When creating a single signature wallet Fully Noded will always display 12 BIP39 seed words you should **write down** and store safely. You may at anytime recover the wallet by simply adding them as a signer to the app. If you are completely recovering the wallet from scratch you can create a "Recovery Wallet" using those BIP39 words.

There are many sources to learn and practise smart custodianship for your seed words, for example:

 - [The Smart Custody Book](https://github.com/BlockchainCommons/SmartCustodyBook)
 - Several articles by Pamela Morgan on Medium [here](https://medium.com/@pamelawjd)

## Delete

There are differences in *Fully Noded Wallets* versus *Bitcoin Core Wallets*, you can read a detailed explanation on the website [here](https://fullynoded.app/faq/#How-Do-I-Delete-a-Wallet).

The TLDR is you can not completely delete a *Bitcoin Core Wallet* from the Fully Noded app, you must do it on your node.

For *Fully Noded Wallets* you can delete the apps database for the wallet by tapping the "trash" button from the "Wallet Detail" view which will cause the app to forget about the wallet, however it can still be accessed as a *Bitcoin Core Wallet* by tapping `advanced` > `Bitcoin Core Wallets`.

To delete the `Bitcoin Core Wallet` you need to navigate to your nodes wallets directory which can generally be found in your Bitcoin Core's default data directory:
* Linux: `~/.bitcoin/wallets`
* macOS: `~/Library/Application Support/Bitcoin/wallets`
* Windows: `%APPDATA%\Bitcoin\wallets`

You can cross reference *Fully Noded Wallets* by tapping the "info" button from the "Active Wallet" tab and looking for the `Filename` field:<br/>
<img src="./Images/fn_filename.png" alt="" width="400"/><br/>

You can cross reference *Bitcoin Core Wallets* filenames by navigating to `advanced` > `Bitcoin Core Wallets`, the text you see is the wallets filename:<br/>
<img src="./Images/bitcoincore_filenames.png" alt="" width="400"/><br/>

## Sending

<br/><img src="./Images/send_view.png" alt="sending view" width="600"/><br/>

Sending and receiving is as simple as tapping send from the "Active Wallet" tab, inputting an amount, a recipient address and tapping the 🔗 button to create a normal (onchain) Bitcoin transaction.

### Transaction fee

At the bottom of the screen you will see a "Confirmation target" slider:<br/>
<img src="./Images/fee_slider.png" alt="" width="600"/><br/>

The slider can be used to change the number of blocks in which we want our transaction to be confirmed (mined) in. Since each block takes about ten minutes to mine we can convert blocks to time, therefore setting the slider to two blocks will create a fee for your transaction which aims to get the transaction mined into a block within twenty minutes. The lower the number of blocks the higher your fee will be. **This is a rough target! It is not an exact science.** If you need the transaction to be confirmed quickly set it to the minimum target which is two blocks. This uses your node's built in fee estimation algorithm. Transactions are always RBF enabled in Fully Noded, however you always **need a balance** to utilize RBF. If you sweep your wallet (spend everything) and that transaction is not getting confirmed you will **NOT** be able to use RBF because you have no funds with which to RBF the transaction. Fully Noded is not yet capable of CPFP so please exercise caution when sweeping by setting a high mining fee.

### Lightning

You will see the ⚡️ button in a few places.

<img src="./Images/receiving_field.png" alt="receiving field" width="600"/><br/>

On the "Receiving address" field the ⚡️ button will fetch a funding address for your lightning wallet. You can think of this as a way to deposit funds to your lightning wallet.

<img src="./Images/top_buttons.png" alt="top buttons" width="300"/><br/>

The larger ⚡️ button in the top right is for withdrawing funds from your lightning wallet to whichever address you specify.

### Donation

<img src="./Images/receiving_field.png" alt="receiving field" width="600"/><br/>

The ♥️ button is for generating a donation address, this address is derived from a hard coded xpub in the app which I control and hold the seed words to. Your donations are greatly appreciated and support continued development of the app.

### Sweeping

<img src="./Images/sweep_button.png" alt="sweep button" width="600"/><br/>

The sweep button will automatically sweep all your funds to the address provided. It is highly recommended to use a high fee setting when sweeping wallets as you will not be able to use RBF if fees spike while your transaction is uncomfirmed.

### Batching

<img src="./Images/top_buttons.png" alt="top buttons" width="300"/><br/>

The + button is for batching transactions, You can add a recipient address, an amount then tap the + button to add multiple outputs. This is great if you need to send multiple transactions at once and want to save on fees. Once you have added all the outputs you want just tap the 🔗 button to create the transaction.

<img src="./Images/batching.png" alt="batching" width="600"/><br/>

### BIP21

<img src="./Images/top_buttons.png" alt="top buttons" width="300"/><br/>

You can tap the QR scanner to scan BIP21 invoices or addresses. Generally if you are paying for something with btc on a website they will provide you with a QR code, this can be scanned or uploaded by tapping the QR button. Just tap the 🔗 button to create the transaction after scanning the invoice.

### Currencies

<img src="./Images/currencies.png" alt="currencies" width="600"/><br/>

You can select denominations of `btc` (Bitcoin), `sats` (satoshis) and `usd`. Selecting `usd` will trigger the app to refresh the exchange rate and convert the dollar specified amount to an amount in btc, please be aware of Bitcoin's volatility and that by the time someone receives the btc the exchange rate may have changed.

### PSBT

Fully Noded is capable of creating either a fully signed raw transaction or a psbt depending on whether the wallet is watch-only, hot multisig which can not be fully signed by the app itself.

If Fully Noded and your node do not hold the private keys necessary to fully sign the transaction you will get presented with a psbt and have the option to export it in a number of formats:<br/>
<img src="./Images/psbt_export.png" alt="" width="600"/><br/>

You may also airdrop a `.psbt` file to Fully Noded and it will attempt to sign the psbt and will either allow you to export the updated psbt again or if it is complete will finalize it and ocnvert it to a raw transaction which can be broadcast, automatically presenting you with that option.

### Raw Transaction

If the transaction can be signed and is complete then Fully Noded will instead present you with a signed raw transaction in hex format:<br/>
<img src="./Images/broadcast.png" alt="" width="600"/><br/>

It is recommended to always use the "verify" button:<br/>
<img src="./Images/verify.png" alt="" width="600"/><br/>

The verify button inspects and parses each input and output individually, displaying the amount and address associated with each as well as manually calculating the mining fee and the usd amount for each. Usually there will always be a change output. You can confirm the change address is yours by copying it > "tools" tab > "wallet" > "get address info" > it will automatically paste in and fetch the address info, if the "solvable" field `solvable=1` then you can rest assured the address is yours.

At this point you can tap "broadcast" and you may either broadcast the transaction with your own node, or by using Blockstream's Esplora API over Tor. Using someone else's node to broadcast your transactions is much more private than broadcasting it with your own node even though this may seem counterintuitive. Once the transaction has been successfully broadcast you will get a valid transaction ID and a success message and the transaction will appear in your transaction history.

### Replace By Fee

**You always need a balance to utilize RBF, RBF will not work when you sweep a wallet**

By default all transactions created by Fully Noded are [RBF](https://en.bitcoin.it/wiki/Replace_by_fee) enabled. To take advantage of this tap the transaction from the "Active Wallet" tab and then tap "bump fee" button.

<img src="./Images/bump_button.png" alt="bump button" width="600"/><br/>

Under the hood an entirely new transaction is created with a higher fee, if Fully Noded can not completely sign the transaction it will present you with a psbt as normal, you will need to pass it to your signer and then back to Fully Noded to broadcast the higher fee transaction again and overwrite the original low fee transaction. 

<img src="./Images/bump_broadcast.png" alt="bump broadcast" width="600"/><br/>

If FN can complete the transaction it will automatically sign and broadcast the transaction at this point.

The final result will be multiple almost identical (only the fee will have changed) transactions on your "Active Wallet" tab as seen below:

<img src="./Images/bumped_tx.png" alt="bumped transaction" width="600"/><br/>


## Receiving

<img src="./Images/invoice.png" alt="invoice" width="600"/><br/>

Receiving is as simple as tapping "invoice" from the "Active Wallet" tab.

An address will be fetched from your node using `bitcoin-cli getnewaddress` for the "Active Wallet".

By default these invoices are BIP21 compatible, you may add a BIP21 amount and label by filling out the respective text fields.

If you have added a c-lightning node you can tap the ⚡️ button to create a bolt11 invoice, editing the amount and label for lightning invoices does not happen in "real time" like the bitcoin invoices do. To edit the label and amount you will need to always tap the ⚡️ for the new values to take effect by creating a new invoice. By default lightning invoices are "any" types meaning no amount is specified. Some lightning wallets are not compatible with "any" invoices, so if you have an issue specify an amount then tap the ⚡️ button. Amounts will always get converted to milli satoshis on the backend, so you may either select btc or satoshis and the app will convert the amount accordingly.

Advanced users have the option to derive different address scripts by navigating to "Active Wallet" tab > `advanced` > `Address script type` however this should be used with caution, it is compatible with your nodes default wallet, Fully Noded single signature wallets and Coldcard single signature wallets. It will also always work if your wallet has a Fully Noded signer associated with it. **IF IN DOUBT STICK WITH THE DEFAULTS**
