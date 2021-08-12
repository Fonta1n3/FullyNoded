# Backups & Recovery - Best Practices

- Use a dummy 12 word signer as your iCloud encryption password and save it offline.
- Test your backup by actually deleting and recovering data!
- Use iCloud backups as your primary method of storing backups.
- Use wallet files for backing up wallet meta data such as transaction labels, memos and capital gains info.
- Always store signers offline in plain text in a safe, preferably in multiple secure locations.

***TEST YOUR BACKUPS***

## iCloud

Since v0.2.24 Fully Noded allows users to create an encrypted iCloud backup.

iCloud backups currently encompass the following entities:
- Wallets
- Nodes
- Signers
- Tor V3 Auth Keys

⚠️ Transaction labels, memos and capital gains info are not currently included in iCloud backups ⚠️

You can view the following video demos for utilizing iCloud backups and recovery:
- [Creating a backup, deleting and recovering individual items](https://www.youtube.com/watch?v=_oPdYw8V0hg)
- [Recovering data after app deletion and installation](https://www.youtube.com/watch?v=Jx46NxfCbJY)

### How to use iCloud

- Creating a backup: `Settings` > `Create/update iCloud backup`
  - At that point you will be prompted to enter in an encryption password and confirm it.
- Recover your nodes, signers, wallets and Tor auth keys: `Setting` > `Recover from iCloud`
  - At that point you will be prompted to enter the same encryption password you used to create the backup.
- Deleting a backup: `Settings` > `Delete iCloud backup`
  - No password is required to delete the backup, that is incase you forgot the original password.

### How it works under the hood

Fully Noded will take the encryption password you provide and sha256 hash it.
The resulting hash is then used to encrypt your data before being stored.
Fully Noded will never remember this hash, it immediately forgets it. What it does
remember is the double sha256 hash of your encryption key so that when the user goes to
recover and decrypt data we can compare the double sha256 hash to what was used
when the original backup was created. Otherwise it would be too easy for users to
accidentally brick a backup or create one backup with multiple encryption keys.
If the original encryption password is lost just delete the backup and create a
new one.

## Wallet files

***Wallet backup files do not contain private keys***

Users may navigate to `Settings` > `Wallet backup` to create a plain text wallet export file
which stores your xpubs, transactions, utxos, labels, memos and capital gains meta data.
It is recommended to use GPG or a similar tool to encrypt these files otherwise an attacker will
gain intimate knowledge of your holdings, transaction history, utxos etc...

You can test that the wallet backup file works by creating a backup file, deleting a memo
on a random transaction and then recovering that file. If the recovery worked the
label or memo you just deleted will reappear after loading the wallet that is associated
with that `txid`. Or simply delete the app, add a node and import the recovery file and
all wallet data should return instantly.

## Wallet QR codes

***Wallet backup QR codes do not hold private keys***

The simplest and quickest recovery method is scanning a wallet backup QR code.
This recovers one wallet at a time and does *not* include meta data about transactions
or utxos. This is ideal for people who worry about losing xpubs for their multi-sig wallets.

## Signers

***Signers must be backed up offline on a piece of paper or metal***

To make a wallet spendable you can either recover via iCloud, QR code or wallet file
and then simply add the appropriate signer to the app by navigating to `Signers` >
`+` and inputting the words one at a time or pasting all of them in one go. Of course you
must pay special attention to whether you added a passphrase to that seed in order for
the wallet to actually sign transactions.
