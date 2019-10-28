# FullyNoded BETA

A feature rich Bitcoin app which is 100% powered by your own Full Node. Allows you to connect to and control multiple nodes using a client side native Tor thread making calls to your nodes rpcport via a hidden service.

There may be bugs, always decode your transaction and study it before broadcasting, ideally get comfortable with it on testnet first, I am not responsible for loss of funds. It is not even possible to broadcast transactions in the app.

## Connect your Nodl

Go to nodl browser based UI, tap the Fully Noded link and Fully Noded will open, add and connect to your nodl over Tor, it is optional for users to add a V3 auth key. This enables worldwide access to your nodl from your iPhone with a native integrated Tor thread running in the app. 

## Connect something else

- Create a hidden service that controls your nodes rpcport (there is a mac guide below on how to do that). 
- Go to "settings" -> "node manager" -> "+" and add a Tor node. 
- Find your bitcoin.conf and input your rpcuser and rpcpassword and a label into the app. See "bitcoin.conf settings" below.
- Input the hidden services hostname with the port at the end (njcnewicnweiun.onion:8332)
- Go back to "Settings" ->"Node Manager" and make sure the node is switched on
- Go to home screen and it will automatically connect

## What can Fully Noded do?

- Full coin control
- Full integrated Tor
- Raw Transaction's
- PSBT's
- HWW Paring
- Easy HD Multisig capability
- Easy Cold Storage
- Coldcard wallet compatibilty for building unsigned transactions
- Most of the Bitcoin Core JSON-RPC API is covered
- Encrypt your wallet.dat file
- So much more
- BIP39 compatiblity for your Node

## Join the Testflight

[here](https://testflight.apple.com/join/PuFnSqgi)

## Download from App Store

[here](https://apps.apple.com/us/app/fully-noded/id1436425586)

## Telegram

[here](https://t.me/FullyNoded)

## Tutorials

Some are outdated but will give you a general idea:

- [Airgapped Signing and pairing with Coldcard](https://www.youtube.com/watch?v=WqKEPpSky2g)

- [Using Fully Noded for HD Multisig. creating, importing, receiving, spending](https://www.youtube.com/watch?v=zRMZJ4pKQ0Q)

## Build From Source - Mac

Run `brew --version` in a terminal, if you get a valid response you have brew installed already. If not:

`cd /usr/local`

then

`mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew`

Wait for bew to finish.

Install carthage:  [Follow these instructions](https://brewinstall.org/install-carthage-on-mac-with-brew/)

### Install Tor.Framework Dependencies

```
brew install automake
brew install autoconf
brew install libtool
brew install gettext
git clone git@github.com:iCepa/Tor.framework
cd Tor.framework
git submodule init
git submodule update
carthage build --no-skip-current --platform iOS
```
then

- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- You will need a free Apple developer account [create one here](https://developer.apple.com/programs/enroll/)
- In XCode, click "XCode" -> "preferences" -> "Accounts" -> add your github account
- Go to [Fully Noded in GitHub](https://github.com/Fonta1n3/FullyNoded) click "Clone and Download" -> "Open in XCode"
- Open Terminal
- `cd Documents FullyNoded` (or wherever it downloaded to)
- run `carthage update --platform iOS` and let carthage do its thing

That's it, you can now run the app in XCode.

## Connecting over Tor (mac)

- run `brew install tor` in a terminal
- Once Tor is installed you will need to create a Hidden Service.
- First locate your `torrc` file, this is Tor's configuration file. Open Finder and type `shift command h` to navigate to your home folder and  `shift command .` to show hidden files.
- The torrc file should be located at `‎⁨/usr⁩/local⁩/etc⁩/tor⁩/torrc`, to edit it you can open terminal and run `sudo nano /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- Find the line that looks like: `#ControlPort 9051` and delete the `#`
- Then locate the section that looks like:

```
## Once you have configured a hidden service, you can look at the
## contents of the file ".../hidden_service/hostname" for the address
## to tell people.
##
## HiddenServicePort x y:z says to redirect requests on port x to the
## address y:z.

```
- And below it add:
```
HiddenServiceDir /Users⁩/yourName/Desktop⁩/tor/FullyNodedV3/
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332
```

- The `HiddenServiceDir` can be whatever you want, you will need to access it so put it somewhere you will remember.
- Save and close nano with `ctrl x` + `y` + `enter` to save and exit nano (follow the prompts)
- Start Tor by opening a terminal and running `tor`
- Tor should start and you should be able to open Finder and navigate to your `/Users⁩/yourName/Desktop⁩/tor/FullyNodedV3/` (the directory we added to the torrc file) and see a file called `hostname`, open it and that is the onion address you need for Fully Noded.
- The `HiddenServicePort` needs to control your nodes rpcport, by default for mainnet that is 8332 or for testnet 18332.
- Now in Fully Noded go to "Settings" -> "Node Manager" -> and add a new node choosing Tor and inputting your RPC credentials, then copy and paste your onion address with the port at the end `qndoiqnwoiquf713y8731783rg.onion:8332`
- Restart your node and you should be able to connect to your V3 hidden service from anywhere in the world with your node completely behind a firewall and no port forwarding

## bitcoin.conf settings

- Here is an example bitcoin.conf file best suited for Fully Noded:

```
#forces your node to accept rpc commands
server=1

#To get the most out of Fully Noded you should use it with a fully indexed non pruned node
txindex=1
prune=0

#Choose any username or password, make the password very strong
rpcuser=yourUserName
rpcpassword=aVeryStrongPasswordSuchAs128dnc849vn9n7gSS

#if you only want to accept connections over tor the following settings are needed
bind=127.0.0.1
proxy=127.0.0.1:9050
listen=1
debug=tor
```

## Keypair generation (optional)

Install python3, pip3, virtualenv and then run the following commands in a terminal (do this on any machine):

```
virtualenv -p python3 ENV
source ENV/bin/activate
pip install pynacl
sudo nano createKeys.py
```

- Copy and paste this script into the terminals nano session:

```
#!/usr/bin/env python3
import base64
try:
    import nacl.public
except ImportError:
    print('PyNaCl is required: "pip install pynacl" or similar')
    exit(1)


def key_str(key):
    # bytes to base 32
    key_bytes = bytes(key)
    key_b32 = base64.b32encode(key_bytes)
    # strip trailing ====
    assert key_b32[-4:] == b'===='
    key_b32 = key_b32[:-4]
    # change from b'ASDF' to ASDF
    s = key_b32.decode('utf-8')
    return s


def main():
    priv_key = nacl.public.PrivateKey.generate()
    pub_key = priv_key.public_key
    print('public:  %s' % key_str(pub_key))
    print('private: %s' % key_str(priv_key))


if __name__ == '__main__':
    exit(main())
```
use `ctrl-x` to quit, `y` to save and `return` to exit nano

Then simply run:

`python3 createKeys.py`

and it returns your key pair:

```
public:  PHK2DFSCNNJ75U3GUA3SHCVEGPEJMZAPEKQGL5YLVM2GV6NORB6Q
private: DARUBG4CIQ4FMPTGUOE36P7DYCKHRBCCNPU5QWCSYBFPWBCA5RCQ
```

The private key is for Fully Noded (paste it or scan it as a QR code when you add your node). The public key is for your servers `authorized_clients` directory. 

To be saved in a file called `fullynoded.auth`

Go to your hidden services driectory that you added to your torrc:

```
HiddenServiceDir /var/lib/tor/FullyNodedV3/
```

as an example:

`sudo nano /var/lib/tor/FullyNodedV3/authorized_clients/fullynoded.auth`

and paste in:

`descriptor:x25519:PHK2DFSCNNJ75U3GUA3SHCVEGPEJMZAPEKQGL5YLVM2GV6NORB6Q`

Save and exit and you have one of the most secure node/light client set ups possible. (assuming your server is firewalled off)

## Security & Privacy

- All network traffic is encrypted by default.

- Fully Noded NEVER uses another server or uploads data or requires any data (KYC/AML) from you whatsoever, the node is the only back end to the app.

- Any information the app saves onto the device locally is encrypted to AES standards and the encryption key is stored on the secure enclave. DYOR regarding iPhone security.

## How does it work?

Bitcoin Core includes a ton of functionality that is not shown to the user in the [GUI](https://www.computerhope.com/jargon/g/gui.htm), this functionality must be accessed by using the [command line](https://en.wikipedia.org/wiki/Command-line_interface) aka CLI, doing so can be quite tedious where tiny typos will return errors. Fully Noded does the hard work of issuing the CLI commands to your node in a programmatic and reliable way powered by the taps you make on your iPhone. The purpose of Fully Noded is to allow users a secure and private way to connect to and control their node, unlocking all the powerful features Bitcoin Core has to offer without needing to use CLI.

Fully Noded needs to connect to the computer that your node is running on in order to issue commands to your node. It does this either using [SSH](https://en.wikipedia.org/wiki/Secure_Shell) or [Tor](https://lifehacker.com/what-is-tor-and-should-i-use-it-1527891029).

Connecting to your nodes computer is the first part, once connected Fully Noded then needs to be able to issue [RPC commands](https://en.bitcoin.it/wiki/API_reference_(JSON-RPC)) to your node. It issues these commands to your [local host](https://whatismyipaddress.com/localhost) over [curl](https://curl.haxx.se). In order to be able to do that Fully Noded needs to know your RPC credentials,  `rpcusername` and  `rpcpassword`. 

Once Fully Noded is connected it will start issuing commands one at a time, here are all the commands needed to load the home screen:

```
curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listwallets", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getbalance", "params":["*", 0, false] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getunconfirmedbalance", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listunspent", "params":[0] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getblockchaininfo", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getpeerinfo", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getnetworkinfo", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getmininginfo", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "uptime", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getmempoolinfo", "params":[] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listtransactions", "params":["*", 50, 0, true] }' -H 'content-type: text/plain;' http://user:password@127.0.0.1:18443/
```

The `method` is a `bitcoin-cli` command and you can use [this great resource](https://chainquery.com/bitcoin-cli) to dive deeper into what they all do.

[This is the code in Fully Noded from the Node Logic class](https://github.com/Fonta1n3/FullyNoded/tree/master/BitSense/Node%20Logic) which issues the above commands, if you look at it you will see a lot of commands that look like this:

```
reducer.makeCommand(command: .listunspent,
                    param: "0",
                    completion: getResult)

```

The `.listunspent` directly represents the `bitcoin-cli` commands we linked to just above and the `params` represent the options you can pass with those commands.  You can get the same functionality copying and pasting these commands into a terminal or using the Bitcoin-Qt console.

## Contributing

Please let us know if you have issues.

PR's welcome.

## Built With

- [NMSSH](https://github.com/NMSSH/NMSSH) for SSH'ing into your node.
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) for encrypting your nodes credentials.
- [keychain-swift](https://github.com/evgenyneu/keychain-swift) for storing your nodes credentials decryption key on your iPhones secure enclave.
- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.

## Changes v0.1.15
- Fix quick connect url so it is an actual url and parse it with URLComponents
- The updated format is: `btcrpc://rpcuser:rpcpassword@4bahfbimpqb5jolr.onion:8332?label=Node%20Label&v2password=HSHS6LRHJD7tSs/r9lx`
- Added QuickConnect class to handle deep link and QR code scanning

## Changes v0.1.14
- Fix bug where tor thread was not fully refreshing. Just pull home table to refresh your tor thread.
- Add V2 hidden service authentication
- Add two arguments to the btcrpc uri to allow server side to add a node label and v2 auth password

## Changes v0.1.13
- Add QR quick connect based on the btcrpc:// uri
- Add ability to generate and refresh V3 cookie auth keys in the app

## Changes v0.1.12
- Fix home table cell heights loading with incorrect height
- Add keypair generation and authkey authentication instructions

## Changes v0.1.11
- Fix bug where home table would load out of order and not show proper cell heights after choosing which loaded wallet to work with

## Changes v0.1.10
- Clean up TorClient code
- Fix bug where Tor would not connect on simulator due to multiple auth keys
- Fix bug where auth keys were not refreshing
- Fix keyboard should return on wallet creation
- Fix a crash when refreshing an existing tor thread
- Fix multiwallet rpc for Tor

## Changes v0.1.9
- Remove alert that was in wrong place when creating psbt
- Clear error bool and description when refreshing tor connection
- upgrade to swift 5.1 and XCode 11.1
- Fix bug where adding an ssh node caused a crash
- Fixed a bug where deleting nodes and then activating one caused a crash

## Changes v0.1.8
- Nodl deeplink
- Removed cocoapods

## Changes v0.1.7
- Clarifies whether user is importing BIP32 extended key or BIP44/BIP84
- Add ability to create a blank wallet incase users want to import their own private keys
- Add a "fee rate" label in Node Stats which displays the fee rate in satoshis per byte depending on the fee rate you set in settings (the app by default sets the lowest possible fee rate)
- Add ability to export and import descriptors, this is a benefit for users to reduce the confusion of derivation schemes for extended keys and especially HD multisig wallets
- The app now saves all HD wallet descriptors that you import into it so that you can easily recover them and import them into new nodes or other apps/bitcoin core.
- Fix UI bug where node credentials would dissapear when navigating back after saving or updating a node, sensitive info like RPC password and onion address will dissapear when you navigate away, feature not bug.
- The app now first checks for a list of your active wallets as its first node command, if there are mutliple wallets loaded that were not loaded using the app the user will be prompted to choose which one they want to work with
- The home screen will only reload wallet specific RPC calls when user changes to a different wallet (eg the balances and transactions)
- Major improvements to UX when user switches between multiple nodes and/or multiple wallets
- Now you can tap your balances and the app will connect to Tor and fetch the USD/BTC exchange rate and display your balances in fiat for a short time
- UI improvements and fixes
- Add more structs to clean up the code
- Add a "Reducer" class to reduce the amount of code and allow seamless Tor integration
- Wallet name is now displayed as the "balances" section header on home screen instead of in "node stats"
- Node label is now displayed as the title of the home screen instead of in "node stats"
- Add ability for user to disable biometrics
- Statusbar will now show white text throughout the app
- Fixed a bug where QR codes were not getting saved/shared when tapping them
- Fix a bug where getting an addresses info by label would not display the address info
- Add ability to sign and verify messages
- Add ability to encrypt your wallet, decrypt your wallet, and change the passphrase (this is not BIP39 passphrase)
- Remove sweep option in "Send from Wallet", if you want to sweep do it in UTXOs
- Add ability to add a V3 key auth as an extra layer of authentication for Tor nodes
- Add a dedicated testing Tor node
- Remove rpcport for tor nodes as its redundant
- Add a kill button that resets the app, removing all saved data
- Add ability to "clear bash history" which will clear all the Fully Noded related commands from your nodes server bash history
- Add label to UTXO's

## Changes v0.1.6
- Enable hd musig functionality
- Improve wallet manager UX
- Improve UTXO UX by adding an info button that displays all the info about that particular utxo
- Now the fee optimizer does not allow a fee less than minrelayfee
- Fixed a bug where editing the amount in "spend from wallet" would result in poor UX

## Changes v0.1.5
- General UI/UX improvements and fixes
- Code refactoring
- Fix multiple minor bugs assocated with the unlock screen
- Disallow simultaneous node commands when navigating the app
- Improve ssh reconnection if connection timed out
- Major rework to UX flow for importing keys

## Changes v0.1.4
- Update Tor functionality to work for Home screen
- Update Tor compatibility with MultiWallet rpc calls

## Changes v0.1.3
- Fix fee alert that showed 101% fee overpayment instead of 1%
- Fix UI issue when locking or unlocking your only remaining UTXO
- Improve UI/UX for "Multi Wallet Manager"
- Move settings for importing and invoices to "Incomings" where they belong
- Fixed a bug that would not present importing keys table when importing an xpub whilst "rescan" was toggled on and user selected an image of the xpub QR from photo library

## Changes v0.1.2

- Fix a bug where joinpsbt view did not display due to a missing constraint
- Add combinepsbt functionality
- Improve UI for UTXO's
- Fixed a bug that caused the app to crash when navigating from tabbar child view controllers, changing settings, then navigating back to main menu
- Simplified the code for passing the SSH and Tor classes to all view controllers
- Fixed a bug where amounts were not rounded returning an "Invalid amount" error from Bitcoin Core
- Simplified the code in settings, no longer alter cell labels outside of cellforrowat
- Add more utility functions in "Tools"
- Improve UX when toggling "Add to Keypool" and "Import as Change" in importing settings to only allow combinations that Bitcoin Core will accept
- Add ability to import public keys using importmulti descriptor based approach, wil import them as "combo" which imports all three address formats of the pubkey
- Add ability to lock and unlock specific UTXO's so that they are not selected by Bitcoin Core coin selection algorithm when "spending from wallet", "create psbt" or "process psbt"

## Changes v0.1.1

- Automatically reconnect to your node when using the app if the connection dies for some reason, you should not see "Channel allocation error" again
- Complete overhall of the UI, minimalist, cypherpunk ultra dark theme
- Add seperate utilities options for "Blockchain" and "Wallet" tools
- User can now utilize "getaddressinfo", "listaddressbygroupings", "getnetworkinfo", "getblockchaininfo", and "getwalletinfo" in Utilities
- General refactoring for efficiency
- Fixes a bug when creating a PSBT with a non default wallet.
- Improved UTXO manager. Add ability to spend any amount from a UTXO instead of only sweeping it. Add smart fee optimization to UTXO spends.
- Added ability to analyze PSBT's and Join PSBT's
- Add ability to create a hot wallet.
- Allows use of the app when disablewallet is set to true.
- Add ability to create and import P2SH, P2WSH and P2SH-P2WSH multisig
- Improve UI and UX
- Remove decode transaction button from raw displayer, instead add dedicated transaction decoder in outgoings
- Now when you import an xpub, the app will show you the addresses that will be imported before importing them and their index.
- Tapping a confirmed transaction on home screen now gives you detailed info about the transaction where you can also bump the fee if its unconfirmed
- Multiple minor bug fixes
- Enables spending from P2SH, P2WSH, and P2SH-P2WSH multisig (for best experience import the multisig first)
- Tap text fields to paste into them
- Creating unsigned transactions with wallet are now replaceable
- "Spend from wallet" now utilizes "fundrawtransaction" and take advantage of Bitcoin Cores coin selection algorithm and smart fee optimization
- Allow user to spend from watch-only when doing a "Spend from wallet" and "Create PSBT"
- Set a fee depending on a target number of blocks for "Spend from wallet" and "Create PSBT"
- Creating a PSBT will now automatically be processed with "walletprocesspsbt"
- Node statistics now show if you are reachable over Tor, difficulty, and the size of the blockchain
- Previously we fetched the latest block from a third party API to get the sync status, now we rely only on your nodes "verification progress"
- Mining fee is now set by a slider, based on target number of blocks (time) to get your transaction confirmed in. This utilizes Bitcoin Core smart fee estimation. The minimum fee possible (set by default) is 1008 blocks or 7 days, the maximum fee is 10-20 mins or the next 1 to 2 blocks. When signing a transaction in "Sign" the app will determine the fee for the transaction and then check it against your current settings and give you a warning if it is too high or too low based on your preference. All other transactions that you create in the app build in your preference to the transaction therefore no fee warning is necessary. All transactions built with the app have RBF enabled. The only caveat is if you build a transaction with inputs which are not part of the wallet (this is possible in "Spend with external"), in that case we add a buffer to the fee estimation when building transactions in this way so that it accounts for the added signature data.
- When you "Spend from external" all fields are mandatory now.
- You can now batch outputs from "Spend from wallet", tap the plus sign to add multiple outputs

## Changes v0.1.0

- Fixes buggy responses when changing settings for importing.
- Fix crash when SSH not connected when toggling importing settings.
- Now that home screen balance shows cold storage balance we check your utxos for spendable balance when sweeping during raw transaction creation.
- Simplify the smart fee alert.
- Issue all bitcoin-cli commands via curl over ssh instead of raw string in bash, this makes the app simpler and more reliable.
- Users can now create a local network connection with a computer that has a node on it, connect to that network with their device and control their Bitcoin Core node over the local network with no internet connection.
- Use importmulti instead of importaddress as importmulti gives better success/fail responses and adds more customization.
- Displays 🥶 cold storage balance seperately from 🔥 hot wallet balance.
- Display last 50 transactions instead of 10.
- Remove need to input bitcoin-cli path as we are using curl now.
- Fixes a bug that was not allowing user to tap QR codes to save/share them.
- Add ability to use your RSA private key and public key with an optional password to SSH into your nodes host.
- Error checking improvements.
- Enable RBF by default when creating a PSBT.

## Changes v1.49

- Harden PSBT's

## Changes v1.48

- Coldcard wallet compatibility for importing xpubs from your Coldcard wallet into your node.  On your Coldcard wallet you will need to insert an SD card, go to "Advanced" -> "Micro SD" -> "Dump Summary". Then create a QR code with either the BIP44 or BIP84 xpub, in Fully Noded inputting your master key fingerprint from Coldcard into Fully Noded settings. Go to "Incomings" -> "Import a key" and scan the xpub QR code, you will now be able to receive and create PSBTs for your Coldcard.
- Added a fingerprint cell in settings so you can add a fingerprint for your master public key.
- If you add a fingerprint the derivation will be xpub/0/0, if you do not add a fingerprint the xpub will be treated as a BIP32 extended key and your derivation will be xpub/0.

## Changes v1.47

- Bug fix where QR scanner did not self dismiss when scanning a QR while signing an unsigned transaction.
- Fixes layout issues for log in screen when switching from landscape to portrait.
- Add spinner view to PSBT tasks.
- Bug fix where user could create a node with both SSH and Tor disabled.

## Changes v1.46

- Update to Swift 5 / Xcode v10.2.1
- Replaced [AES256CBC](https://github.com/SwiftyBeaver/AES256CBC) with [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift)
- Replaced [Swift Keychain Wrapper](https://github.com/jrendel/SwiftKeychainWrapper) with [keychain-swift](https://github.com/evgenyneu/keychain-swift)
- The replaced libraries are not maintained/updated or as widely used, which is why we switched, this is a breaking change which forced us to delete all your previous node credentials and encryption key and use these updated libraries instead.
- Automatically add and connect to a testnet node so users may test the app properly before adding their own node.
- Added the ability to use Tor in the app to connect to your nodes hidden service, however this is only working in the simulator for now, if you can help debug why it is only working in the simulator please do reach out, if it does work on your device please do let us know about it.
- Added "Utilities" button on the home screen which allows users to take advantage of the "multiwalletrpc" which allows you to create wallets, load them and unload them. When you create a wallet it is automatically loaded and the app will call all wallet related rpc functions to this wallet only. If you want to revert to using another wallet you can unload them and load the wallet you would like to use or revert back to the default wallet by tapping that option in utilities.
- When the user creates a wallet in utilities it is by default a watch-only wallet with private keys disbaled and an empty keypool, which allows the user to import keys into the keypool and as receieve/change adresses making it very easy to create unsigned transactions (raw or PSBT) with the watch-only wallet.
- Supports importing of BIP32 extended xpub/xprv. Importing an xprv DOES NOT import private keys as of Bitcoin Core v0.18.0 this is going to change in v0.19.0.
- Allows users to enable or disable rescanning of the blockchain when imporitng xpubs.
- Allows users to specify a range of addresses to import. For example you would import 0 to 99 to the keypool with change addresses disabled then import 100 to 199 with change addresses enabled.
- PSBT functionality added, create (walletcreatefundedpsbt), process, and finalze.
- Updated UI for creating raw transactions, unsigned transactions and signing transactions.
- Updated the UI for home screen.
- Changed the minus button to a play button, once you have filled out the necessary info to build a transaction just tap the play button to create it.
- Updated the UI so that when you press the sweep button it diplsays the amount we will sweep from your wallet. We always deduct your mining fee plus 50,000 satoshis to the sweep amount to ensure we can bump the fee incase you set too low of a mining fee.
- Updated the Node management flow, for some wallet functionality (createwalletfundedpsbt and signrawtransactionwithkey) we must use a curl command via ssh to send the command as raw data instead of a string. Therefore we need your rpcusername and rpcpassword to issue the http command to your local host. For this reason when adding node it is optional to first add your rpc credentials, if you do not add the rpc credenitals 99% of the apps functionality will still work but createwalletfundedpsbt and signrawtransactionwithkey will not.
- Updated the error reporting, the error will now show up for 5 seconds and not blur out the entire screen, also the error is swipable so you can swipe it up to dismiss it.
- Add ability to manually rescan the blockchain in "Utilties"
- Add the 👀 emoji to any transaction that is controlled by watch-only addresses in the home screen.
- Add a label to display the name of your rpcwallet in home screen (top left) that you either created or manually loaded in utilities
