# Tests

## Core Test group

Spring 2020 we installed a Core test group in Signal for FN2 (now called 'Gordian Wallet'). See [Contributing](../Readme.md#Contributing).

As soon as we have a Core Test group for FN installed, we'll add instructions in this section. For now we discuss FN tests in the [Telegram group](https://t.me/FullyNoded).

## Testing Checklist

#### To thoroughly test the app's functionality we recommend the following steps as a general guide.

### Objective

A group editable wiki-like checklist and full feature list. This matrix guides regression tests. Some activities are the same for every tester every test round, like connecting to the node and some activities can be split up among two or more individual testers, for example Lightning and Recovery.

### Step 0
- [ ] Connection: (re)establish connection of Gordian Wallet to your Node. In order to establish connection, ....
  - [ ] XXX
  - [ ] XXX
  - [ ] XXX
  - [ ] XXX

### Step 1
- [ ] Account Creation: create each possible account type. In order to access the advanced accounts, tap the expand button in the top right corner.
  - [ ] Hot (custom seed disabled)
  - [ ] Hot (custom seed enabled)
  - [ ] Warm (custom seed disabled)
  - [ ] Warm (custom seed enabled)
  - [ ] Cool (you will need the mnemonic used to derive the xpub, an account xpub, and master key fingerprint)
  - [ ] Cold (you will need the mnemonic used to derive the xpub, an account xpub, and master key fingerprint)

 Ensure you save the *Account Map QR* and *Seed words* for each account so that you can test recovery.

### Step 2
- [ ] Receive funds to each account.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 3
- [ ] Spend funds from each account. **Record the final balance, account name, and first few digits of the node wallet filename for verification later.**
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)

### Step 4
- [ ] Create a PSBT for the Cool and Cold accounts. Simply build another transaction for these accounts, and the app will export an incomplete PSBT. Try exporting it in all options. If you have an offline PSBT signer like a Coldcard, please try signing it and passing it back to the app for broadcasting. You can see a tutorial for that [here](https://www.youtube.com/watch?v=GEvQahorze8).
  - [ ] Cool
  - [ ] Cold

### Step 5
- [ ] Confirm the funds were received, and delete each wallet from the device and your node. (If you are repeating this step you can skip deleting the account from the node to test every possible scenario.)
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 6
- [ ] Recover the accounts by going to "Accounts" > "+" > "Recover" > "Scan Account Map" and scan the QR you backed up in step 1. This will recover each account as watch-only: bitcoins will not be spendable.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 7
- [ ] Make each account spendable by adding your mnemonic to each account. In "Accounts", activate the account you want to make spendable, tap the "wrench" button and select "Add a signer". Simply add your mnemonic for each account. In the case of warm and cool you will need to add two signers to make the account spendable as it is a 2 of 3.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 8
- [ ] Repeat steps 3 to 5 and then recover each account with seed words only. Once the accounts are recovered again, try and spend from each.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 9
- [ ] Now that all accounts are recovered by both methods you can test adding seeds independently of the accounts to make them spendable. Go to "Account" > "Tools" > "Backup Info" > and delete each seed on each account to make them all cold.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 10
- [ ] Go to "settings" > tap the bitcoin sign in the top right (yes it's hidden and obfuscated) > "+" > and add the seeds associated with the testing accounts one by one (you can paste all words in one go to save time).
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 11
- [ ] Activate each account one by one, check "Accounts" > "tools" > "backup info" and see if the seed is there. Also check that the UI updates and displays the correct "flame" or "warm" icons for each account, as well as the xprv fingerprints etc on home screen and "Accounts".
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 12
- [ ] Ensure each wallet is spendable yet again.
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 13
- [ ] Coin control: from the transaction UI, attempt to use the "manual coin control" button and lock/unlock UTXOs. Ensure that the "amount available" label updates with the correct amounts when locking and unlocking. Use the "do not spend change" and "do not spend dust" buttons and then "manual coin control" to check that your dust and change UTXOs get locked and unlocked accordingly. This does not need to be done with each wallet as it is the same code for all.

### Step 14
- [ ] Refill the keypool for each account: "Accounts" -> "tools" -> "refill keypool" (for multi-sig wallets you will need the offline recovery words in order to refill the keypool). When accounts are created on the app we import 0-2500 receive keys and 0-2500 change keys; if a user by chance used 2500 receive keys they would need to refill the keypool and the app prompts them to do so. Please ensure this function works for each account and that the UI updates accordingly. (On the "Accounts" view it shows the key range that has been imported to your node.)
  - [ ] Hot
  - [ ] Hot (custom seed)
  - [ ] Warm
  - [ ] Warm (custom seed)
  - [ ] Cool
  - [ ] Cold

### Step 15
- [ ] Utilize the "sweep to" tool. This can be done to and from accounts of your choice. Ideally do it with one single sig and one multisig account at minimum, as there are slight differences between the two.
  - [ ] Hot
  - [ ] Warm

### Step 16
- [ ] Utilize the "sweep to address" button for each wallet which is accessed on the "build a transaction" view. This can be done to and from accounts of your choice. Ideally do it with one single sig and one multisig account at minimum, as there are slight differences between the two.
    - [ ] Hot
    - [ ] Warm

### Step 17
- [ ] Try importing "anything". Currently the app supports importing any xpub based Bitcoin Core [descriptor](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md). It would be useful to try many varieties and see which ones cause UI or other bugs. This can be done by tapping the QR scanner button from "Accounts" and scanning a QR of a Bitcoin Core descriptor. There is a `DescriptorParser.swift` file we frequently use, for much of the functionality of the app; making this parser more robust, to work with any descriptor, will greatly increase the power of the app.

### Step 18
- [ ] Try "recovering" accounts using only the xpubs or seed words for accounts created outside of the app. Currently we only support BIP44/84/49/48. The app has the ability to create (recover) any "m of n" multisig account: try creating for example a "3 of 7" or "1 of 2" or any other non "2 of 3" combination and see if it causes any bugs in the UI or functionality. The app will automatically prompt you to add more xpubs or seed words to do this, asking you if you are finished adding seeds/xpubs. Ideally do this with xpubs for which you have the mnemonic, that way you can add signers or seeds to make the accounts spendable.

### Step 19
- [ ] Add memos to transactions when you broadcast them and check they are there when you tap the info button on the transaction via home screen. For transactions where a memo has not been added, add one retroactively, dismiss it, and reopen the transaction to ensure it is still there.
