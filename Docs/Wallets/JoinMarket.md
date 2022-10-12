# Join Market - Wallet Usage

General Join Market usage guide can be found [here](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md).
Privacy minded Join Market guide can be found [here](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_private_flow.md).

The following describes how to use FN with JM and how it interacts with your JM server.

## Deposit to JM

First you need to deposit a utxo to a JM wallet that was created by FN:
- Ensure you have setup and connected to a JM server ([setup guide](ccc), [connecting JM guide]()).
- Toggle the JM node on via the node manager in FN.
- Toggle on an existing FN wallet you want to deposit to JM.
- Navigate to "utxos" via the active wallet view.
- Tap the mix button on an existing utxo:
    - FN looks for any JM servers that have been added to the node manager.
    - FN checks for any existing JM wallets that were created by FN.
    - You will be prompted to select an existing JM wallet to deposit to, or create a new one.
    - FN will fetch a deposit address from a new mixdepth.
    - You will then be presented with the transaction creator with the JM deposit address already filled in the recipient field.
    - It is recommended to sweep the entire utxo to your JM wallet for best privacy practices.
    - Once the transaction is broadcast you can navigate back to your active wallet view and toggle on the newly created JM wallet.
    
## Single Coinjoins (aka Taker)

One off coinjoins are not "private" but careful utxo management and successive coinjoins can be beneficial.

If you are familiar with JM this is the equivalent of `sendpayment.py` which is a single coinjoin transaction.
- Toggle on an exisitng JM wallet you created with FN which holds a balance.
- Navigate to utxos.
- Tap the mix button (it is in a different location then normal FN wallets)
- *Coin control does not work for single coinjoins at this time unless you manually lock your utxos via your JM server.
- *For that reason each JM utxo does not have a mix button, JM will handle utxo selection for us.
- You will be asked to select the mixdepth you want to spend from, the default is the first mixdepth that holds a balance.
- You will be presented with the transaction creator as normal at which point you can input any address you'd like.
- For best privacy you ought to keep the recipient address script to bech32 single sig.
- Tapping "create tx" will then run the `sendpayment.py` script, FN automatically selects a random number of peers as well as a random fee within a reasonable range so as to avoid creating a fingerprint for the tx.
- You now need to wait to see if the coinjoin transaction succeeds or not, to do that refresh your active wallet view and you will see new transactions, you can also view your JM log for troubleshooting. If at first you don't succeed, try again.

## Create a Fidelity Bond

In order to be a successful "maker" it is recommended to create a fidelity bond. This is a timelocked address where you deposit funds. 
Choose an amount and a time period for the funds to be locked. The more you deposit, the longer the duration, the higher your potential earning power.

⚠️ Creating a Fidelity Bond has many factors to consider. Please read [this](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/fidelity-bonds.md) before creating a FB.

- Toggle on an exisitng JM wallet you created with FN which holds a balance.
- Navigate to utxos.
- Tap each utxo you'd like to deposit to the fidelity bond, it is always recommended to sweep the entire utxo and only use utxos which have been previously coinjoined.
- Tap the 􀗕 with the desired utxos selected.
- Select an expiry date, after this date you will be able to spend the funds as a "direct send" after "unfreezing" them.
- A timelocked address is fetched from JM and the transaction creator is shown as normal with the timelocked address filled in.

⚠️ WARNING: You should send coins to this address only once. Only single biggest value UTXO will be announced as a fidelity bond. Sending coins to this address multiple times will not increase fidelity bond value. 
⚠️ WARNING: Only send coins here which are from coinjoins or otherwise not linked to your identity.

- It is best to "sweep all funds" to the fidelity bond address.
- You will then be shown the transaction verifier as normal before broadcasting it.
- Broadcast the transaction and that's it.

## Spend a Fidelity Bond

According to [this document](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/7ed57d17ca52cc4a18d985db6f1da352d07c8357/docs/fidelity-bonds.md?plain=1#L154):
```
NB You cannot export the private keys (which is always disadvised, anyway) of timelocked addresses to any other wallets, as they use custom scripts. You must spend them from JoinMarket itself.
```
You need the JM server/wallet in order to spend the timelocked funds (for now)!

To spend the expired timelocked funds using FN: 
- Toggle on your JM node.
- Toggle on an exisitng JM wallet you created with FN which holds a balance and an expired FB.
- Navigate to utxos.
- Tap the 􀗕.
- The Fidelity Bond utxo is always frozen, you must unfreeze it to spend it.
- Tap the 􀗕.
- Direct send from mixdepth 0 to spend the utxo.

## Maker (earn sats)

You should only used previously coinjoined funds as a maker, and you ought to create a fidelity bond first.
- In FN just toggle the maker switch on and the `yieldgenerator.py` script will run continuously until you toggle it off
- Be patient and you ought to see your utxos transform with a few extra sats in your balance.

## Recovery

JM wallet recovery ought to be done with the JM software directly using [these instructions](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md#recovering-a-wallet-from-mnemonic).

FN does save the seed words locally so it has the ability to spend JM funds (other then a Fidelity Bond) on its own.

A dedicated recovery option in FN (using only Bitcoin Core) for JM wallets is a work in progress.



