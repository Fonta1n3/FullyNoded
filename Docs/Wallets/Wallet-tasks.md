#Wallet tasks

 - [Create](#create)
 - [Backup](#Backup)
 - [Delete](#Delete)
 - [Sending](#Sending)
    -[Transaction fee](#Transaction-fee)
    -[⚡️](#⚡️)
    -[♥️](#♥️)
    -[Sweeping](#Sweeping)
    -[Batching +](#Batching-+)
    -[BIP21](#BIP21)
    -[Currencies](#Currencies)
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

You can cross reference *Fully Noded Wallets* by tapping the "info" button from the "Active Wallet" tab and looking for the `Filename` field:
<img src="./Images/fn_filename.png" alt="" width="400"/>

You can cross reference *Bitcoin Core Wallets* filenames by navigating to `advanced` > `Bitcoin Core Wallets`, the text you see is the wallets filename:
<img src="./Images/bitcoincore_filenames.png" alt="" width="400"/>


## Sending

Sending and receiving is as simple as tapping send from the "Active Wallet" tab, inputting an amount, a recipient address and tapping the 🔗 button to create a normal (onchain) Bitcoin transaction. 

### Transaction fee

At the bottom of the screen you will see a "Confirmation target" slider:
<img src="./Images/fee_slider.png" alt="" width="400"/><br/>
The slider can be used to change the number of blocks in which we want our transaction to be confirmed (mined) in. Since each block takes about ten minutes to mine we can convert blocks to time, therefore setting the slider to two blocks will create a fee for your transaction which aims to get the transaction mined into a block within twenty minutes. The lower the number of blocks the higher your fee will be. **This is a rough target! It is not an exact science.** If you need the transaction to be confirmed quickly set it to the minimum target which is two blocks. This uses your node's built in fee estimation algorithm. Transactions are always RBF enabled in Fully Noded, however you always **need a balance** to utilize RBF. If you sweep your wallet (spend everything) and that transaction is not getting confirmed you will **NOT** be able to use RBF because you have no funds with which to RBF the transaction. Fully Noded is not yet capable of CPFP so please exercise caution when sweeping by setting a high mining fee.

### ⚡️

You will see the lightning button in a few places. On the "Receiving address" field the ⚡️ button will fetch a funding address for your lighnting wallet. You can think of this as a way to deposit funds to your lightning wallet.

The larger ⚡️ button in the top right is for withdrawing funds from your lightning wallet to whichever address you specify.

### ♥️

The heart button is for generating a donation address, this address is derived from a hard coded xpub in the app which I control and hold the seed words to. Your donations are greatly appreciated and support ontinued development of the app.

### Sweeping

The sweep button will automatically sweep all your finuds to the address provided. It is highly recommended to use a high fee setting when sweeping wallets as you will not be able to use RBF if fees spike while your transaction is uncomfirmed.

### Batching +

The plus button is for batching transactions, You can add a recipient address, an amount then tap the + button to add multiple outputs. This is great if you need to send multiple transactions at once and want to save on fees. Once you have added all the outputs you want just tap the 🔗 button to create the transaction.

### BIP21

You can tap the QR scanner to scan BIP21 invoices or addresses. Generally if you are paying for something with btc on a website they will provide you with a QR code, this can be scanned or uploaded by tapping the QR button. Just tap the 🔗 button to create the transaction after scanning the invoice.

### Currencies

You can select denominations of `btc` (Bitcoin), `sats` (satoshis) and `usd`. Selecting `usd` will trigger the app to refresh the exchange rate and convert the dollar specified amount to an amount in btc, please be aware of Bitcoin's volatility and that by the time someone receives the btc the exchange rate may have changed.

## Receiving

Receiving is as simple as tapping "invoice" from the "Active Wallet" tab. 

An address will be fetched from your node using `bitcoin-cli getnewaddress` for the "Active Wallet". 

By default these invoices are BIP21 compatible, you may add a BIP21 amount and label by filling out the respective text fields.

If you have added a c-lightning node you can tap the ⚡️ button to create a bolt11 invoice, editing the amount andlabel for lightning invoices does not happen in "real time" like the bitcoin invoices do. To edit the label and amount you will need to always tap the ⚡️ for the new values to take effect by creating a new invoice. By default lightning invoices are "any" ypes meaning no amount is specified. Some lightning wallets are not compatible with "any" invoices, so if you have an issue specify an amount then tap the ⚡️ button. Amounts will always get converted to milli satoshis on the backend, so you may either select btc or satoshis and the app will convert the amount accordingly.

Advanced users have the option to derive different different address scripts by navigating to "Active Wallet" tab > `advanced` > `Address script type` however this should used with caution, it is comaptible with your nodes default wallet, Fully Noded single signature wallets and Coldcard single signature wallets. It will also always work if your wallet has a Fully Noded signer associated with it. To be safe stick with the defaults!
