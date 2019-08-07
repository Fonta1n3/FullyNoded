# FullyNoded BETA
A Bitcoin Core GUI for iOS devices. Allows you to connect to and control multiple nodes via SSH or a Tor V3  hidden service.

There may be bugs, always decode your transaction and study it before broadcasting, ideally get comfortable with it on testnet first, I am not responsible for loss of funds. It is not even possible to broadcast transactions in the app.

## Join the Testflight

[Download the testflight on your iOS device by tapping here](https://testflight.apple.com/join/PuFnSqgi)

## Telegram

If you have questions, suggestions, or just want to talk about Full Nodes join our Telegram https://t.me/FullyNoded

## Build From Source

[You can download the IPA file here](https://drive.google.com/open?id=1vYbHzTdTR3xYI0jAUixmX99PHpBwATIs) then all you need to do is drag and drop it into the simulator device of your choice in Xcode.

First things first see if you have brew installed by opening a terminal and running `brew help`, if you get a valid response you have brew installed already. If not in your terminal run:

`cd /usr/local`

then

`mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew`

Wait for bew to finish.

Next we will need to install carthage:  [Follow these simple instructions for installing carthage on mac](https://brewinstall.org/install-carthage-on-mac-with-brew/)

If you want to use Tor first you will need to use brew to install the dependencies for Tor.framework (if not you can skip to the next steps):

`brew install automake autoconf libtool gettext`

then

```
git clone git@github.com:iCepa/Tor.framework

cd Tor.framework

git submodule init
git submodule update

carthage build --no-skip-current --platform iOS

```

You will need Xcode.

- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- You will need a free Apple developer account [create one here](https://developer.apple.com/programs/enroll/)
- In XCode, click "XCode" -> "preferences" -> "Accounts" -> add your github account
- Go to [Fully Noded in GitHub](https://github.com/FontaineDenton/FullyNoded) click "Clone and Download" -> "Open in XCode"
- Open Terminal
- `cd Documents FullyNoded` (or wherever it downloaded to)
- run `carthage update --platform iOS` and let carthage do its thing
- When Carthage frameworks are installed (it takes awhile and its normal to get an error about xconfig something something) run the app in Simulator.


## If using a Nodl

- Gain root access to your Nodl by `ssh root@nodl.local` or `ssh root@<insert your IP>`
- Create a password for the bitcoin user (if you have not already) `sudo passwd bitcoin`
- The password you just set is the password you will need to add in Fully Noded as your SSH password
- Your Fully Noded SSH User will be `bitcoin`
- The SSH port in Fully Noded will be `22` (unless you customize it which is recommended)
- The SSH IP in Fully Noded will either be `nodl.local` or your Nodls IP
- Back to your Nodl
- Switch user to bitcoin user `su - bitcoin`
- Open your bitcoin.conf file `nano .bitcoin/bitcoin.conf`
- Now you can see your RPC credentials that you need for Fully Noded
- rpcpassword is the RPC password in Fully Noded and rpcuser is the RPC user in Fully Noded, easy right?
- RPC port in Fully Noded will be 8332 for mainnet, 18332 for testnet or 18443 for regtest.
- Thats it, you should be connected, if it gets stuck on connecting at home screen just force close the app and open again.

## If using a mac

- Click Apple icon in top left of your computer
- Click "System Preferences"
- Click "Sharing"
- Follow below image for instructions:

<img src="BitSense/Images/screenShot.png" width="800">

## Connecting over Tor (mac edition)

- This is only working if you build the app from source so first follow those instructions above.
- You will need to install Tor on your mac, you will need to install `brew` first if you don't already have it, the instructions are included in the build from source instructions above, once you have brew installed open terminal and run `brew install tor`
- Once Tor is installed you will need to create a Tor V3 Hidden service.
- First locate your `torrc` file, this is Tor's configuration file. Open Finder and type `shift command h` to navigate to your home folder and  `shift command .` to show hidden files on your mac.
- The torrc file should be located at `‎⁨/usr⁩/local⁩/etc⁩/tor⁩/torrc`, to edit it you can open terminal and run `sudo nano /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- Find the line that looks like:

```
## Once you have configured a hidden service, you can look at the
## contents of the file ".../hidden_service/hostname" for the address
## to tell people.
##
## HiddenServicePort x y:z says to redirect requests on port x to the
## address y:z.

```
- Then below it add:
```
HiddenServiceDir /Users⁩/yourName/Desktop⁩/tor/FullyNodedV3/
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:123456

```
- The `HiddenServiceDir` can be whatever you want, you will need to access it so put it somewhere you will remember.
- Save and close nano with `ctrl x` + `y` + `enter` to save and exit nano (follow the prompts)
- Start Tor by opening a terminal and running `tor`
- Tor should start and you should be able to open Finder and navigate to your `/Users⁩/yourName/Desktop⁩/tor/FullyNodedV3/` (the directory we added to the torrc file) and see a file called `hostname`, open it and that is the onion address you need for Fully Noded.
- The `HiddenServicePort` needs to control your nodes rpcport, by default for mainnet that is 8332 or for testnet 18332.
- Now in Fully Noded go to "Settings" -> "Node Manager" -> and add a new node choosing Tor and inputting your RPC credentials, then copy and paste your onion address with the port at the end `qndoiqnwoiquf713y8731783rg.onion:123456`
- Restart your node and you should be able to connect to your V3 hidden service from anywhere in the world with your node completely behind a firewall and no port forwarding! Pretty private, pretty secure and not that difficult to do.

## bitcoin.conf settings

- Here is an example bitcoin.conf file best suited for Fully Noded:

```
#forces your node to accept rpc commands
server=1

#Choose any username or password, make the password very strong
rpcuser=yourUserName
rpcpassword=yourPassword

#optionally you can add an rpc port, by default it will be 8332 for mainnet and 18332 for testnet, no need to add this unless you want to customize it or for regtest you may need to add it (regtest is 18443)
rpcport=8332

#forces your node to only accept rpc commands from your local host (this is the secure way to do it)
rpcallowip=127.0.0.1

#if you only want to accept connections over tor the following settings are needed (recommended)
bind=127.0.0.1
proxy=127.0.0.1:9050
listen=1
debug=tor
```

## Troubleshooting

- If you get an "Unable to connect" error then ensure you input the correct IP, password, port and username into Fully Noded. Try and SSH into the node in terminal and issue a `bitcoin-cli getblockchaininfo` command to ensure rpc commands are working properly, that the node is on, etc... If you have an issue in your server running `bitcoin-cli` commands then it will not work in the app either.

- You will need to ensure your Bitcoin Core node instance is running on a machine that allows SSH log in via password. In order to enable that:

- `sudo nano /etc/ssh/sshd_config`

- Find the line that shows: `PasswordAuthentication no`

- and change it to: `PasswordAuthentication yes`

- Exit nano and ensure you saved the changes.

- Then run: `sudo service sshd restart`

- Back in Fully Noded pull the home screen to refresh it and it should connect.

- If you get a "Channel allocation" error, that means you need to go back to home screen and pull the table to reconnect to your node.

- I am always keen to help people run nodes and connect to them, if any issues at all just DM me on twitter @FullyNoded or raise an issue here.

## Security

- SSH is a secure way of connecting to your node. All traffic between your iPhone and the node are encrypted to a high standard. [You can read more here](https://www.howtogeek.com/118145/vpn-vs.-ssh-tunnel-which-is-more-secure/)

- We highly recommend using a very strong password for SSH log in. SSH can be a target for hackers, if you have a simple password it will greatly increase the chances of the hacker to get access to your computer.

- We highly recommend altering the port for SSH to a custom port, 22 is default. This will go a long way to prevent hackers from obtaining access to your computer. To do this:

- On your nodes machine run: `sudo nano /etc/ssh/sshd_config`

- Find the line that says: `# Port 22`

- And change it to something like: `Port 52120`

- Ensure your firewall allows incoming connections to this port. You can choose any unused port up to 65,535

- Exit nano, ensure you save the changes, then run: `sudo service sshd restart`

## Roadmap

- I am working on a macOS desktop app that will turn on SSH programmatically and display a QR code to the user that the user can scan with the app to connect it to their node.

- Fix Tor on devices.

## Contributing

Please let us know if you have issues, the app is designed to work with any node running on any machine and is not tailor made for one specific OS, therefore it is very flexible and different OS will have different nuances. We would like to know about them! Please share your experience.

Please feel free to build from source in xcode and submit PR's. I need help and my to do list is way too long. If you can not code then simply testing the app and making video tutorials would go a very long way.

## Capabilities

- Add/edit/remove multiple nodes
- Create raw transactions (RBF enabled by default)
- See statistics about your node
- See last 10 transactions
- Tap unconfirmed transaction to bump the fee
- Create batch transactions (multiple outputs)
- Create unsigned transactions with external keys or with the nodes wallet (input a custom address to spend from, change address and recipient address)
- Sign unsigned transactions with an external private key or with the nodes wallet
- Import BIP84 and BIP44 xpubs
- Import BIP32  extended keys
- Create, process and finalize PSBT's
- Create watch-only wallet
- Load/unload wallets
- Rescan the blockchain
- Import stand alone addresses and private keys
- Tap individual UTXO's to spend them or consolidate them

## Built With

- [NMSSH](https://github.com/NMSSH/NMSSH) for SSH'ing into your node.
- [CryptoSwift](https://github.com/krzyzanowskim/CryptoSwift) for encrypting your nodes credentials.
- [keychain-swift](https://github.com/evgenyneu/keychain-swift) for storing your nodes credentials decryption key on your iPhones secure enclave.
- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.

## Changes v0.1.3
- Fix fee alert that showed 101% fee overpayment instead of 1%
- Fix UI issue when locking or unlocking your only remaining UTXO
- Improve UI/UX for "Multi Wallet Manager"
- Move settings for importin and invoices to "Incomings" where they belong

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
- Added the ability to use Tor in the app to connect to your nodes V3 hidden service, however this is only working in the simulator for now, if you can help debug why it is only working in the simulator please do reach out, if it does work on your device please do let us know about it.
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
- Add a label to display the name of your rpcwallet in home screen (top left) that you either created or manually loaded in utilities.
