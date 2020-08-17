


# <img src="./Images/logo.png" alt="" width="100"/> Fully Noded™️
[https://fullynoded.app](https://fullynoded.app) (work in progress)

pgp: 3B37 97FA 0AE8 4BE5 B440 6591 8564 01D7 121C 32FC

⚡️donation to support development of Fully Noded:<br/>
http://56uo4htoxdt2tgh6zui5v2q7c4ax43dd3fwueiurgqdw7lpunn2cikqd.onion:5599/donation

# Table of Contents
1. [Requirements](#requirements)
2. [Supported Nodes](#supported-nodes)
3. [Connect your own node](#connect-your-own-node)
4. [Connect BTCPayServer](#connect-btcpayserver)
5. [Connect Nodl](#connect-nodl)
6. [Connect Raspiblitz](#connect-raspiblitz)
7. [Connect Embassy](#connect-embassy)
8. [Connect myNode](#connect-mynode)
9. [Importing a wallet from Specter](#importing-a-wallet-from-specter)
10. [Troubleshooting](#troubleshooting)
11. [What can Fully Noded do?](#what-can-fully-noded-do)
12. [Download from App Store](#download-from-app-store)
13. [Telegram](#telegram)
14. [Q and A](#q-and-a)
15. [Tutorials](#tutorials)
16. [Build From Source](#build-from-source)
17. [Connecting over Tor macOS](#connecting-over-tor-macos)
18. [Connecting over Tor Windows 10](#connecting-over-tor-windows-10)
18. [Bitcoin Core settings](#bitcoin-core-settings)
19. [Tor V3 Authentication](#tor-v3-authentication)
20. [QuickConnect URL Scheme](#quickconnect-url-scheme)
21. [Security and Privacy](#security-and-privacy)
22. [How does it work?](#how-does-it-work)
23. [Contributing](#contributing)
24. [Built With](#built-with)
25. [The docs](#docs)

## Requirements
- At least [Bitcoin Core 0.20.0](https://bitcoincore.org/bin/bitcoin-core-0.20.0/) for "Fully Noded Multisig" wallet compatibility, Bitcoin Core wallets will of course work with any version.
- [Tor](https://www.torproject.org/download/)


## Supported Nodes
- Bitcoin Core (minimum 0.20.0 is recommended for full functionality)
- Nodl
- myNode
- BTCPayServer
- Raspiblitz
- Embassy

## Connect your own node
- Create a hidden service that controls your nodes rpcport (there is a mac guide below on how to do that).
- Go to `settings` > `node manager` > `+` > `manually`
- Find your bitcoin.conf and input your rpcuser and rpcpassword and a label into the app. See "bitcoin.conf settings" below. **No special characters allowed! Only alphanumeric**
- Input the hidden services hostname with the port at the end (njcnewicnweiun.onion:8332)
- Tap `save`, you will be alerted it if was saved successfully, it will automatically start connecting to it. Optionally, if you have authentication setup you will need to create V3 auth keys in the app by going to `settings` > `security center` > `Tor V3 Authentication` > `tap the refresh button to create keys out of band or add your own private key by pasting it in` > `tap the export button to export your public key`

## Connect BTCPayServer
- In BTCPay go to `Server Settings` > `Services` > click on `Full Node RPC`
<img src="./Images/btcpay.png" alt="" width="500"/>

- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR`
- Once you have scanned the QR the app will automatically connect and start loading the home screen, to ensure its working go home and see the table load. To troubleshoot any connection issue reboot your BTCPayServer and force quit and reopen Fully Noded.

## Connect Nodl
- In Nodl go to the Tor tile settings pane which will dsiplay:
<img src="./Images/nodl_1.JPG" alt="" width="250"/>

- Click `Details and settings`
<img src="./Images/nodl_2.JPG" alt="" width="250"/>

- If you are on your iPhone or iPad you can click `BTCRPC Link` and it will automatically launch Fully Noded and connect your node.
- If you are accessing the Nodl gui via a computer click `QR-Code`:
<img src="./Images/nodl_3.jpeg" alt="" width="250"/>

- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR`
- Once you have scanned the QR the app will automatically connect and start loading the home screen, to ensure its working go home and see the table load. To troubleshoot any connection issue reboot Tor on your Nodl and force quit and reopen Fully Noded.

You can always do this manually by inputting your `rpcuser` and `rpcpassword` along with the Tor hidden service url in Fully Noded. Just add `:8332` to the end of the onion url.

## Connect Raspiblitz
In Raspiblitz:
- Ensure Tor is running
- SSH-MAINMENU > FULLY_NODED
- follow the simple instructions

## Connect Embassy
- In Fully Noded go to `Settings` > `Node Manager` > `+` > `manually`
- Simply add the Tor onion url with `:8332` appended to it and your rpc username/password

## Connect myNode
- In myNode:
<img src="./Images/myNode_1.png" alt="" width="250"/>

1. From your dashboard, navigate to the Tor page
<img src="./Images/myNode_2.png" alt="" width="250"/>

2. At the bottom of the Tor page your will see the Fully Nodes button, press it.
<img src="./Images/myNode_3.png" alt="" width="250"/>

3. You will now see your connection QR.
This is for premium myNode users only.
- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR` and scan the QR

Non premium users can simply get their Tor V3 url for the RPC port add `:8332` to the end so it looks like `ufiuh2if2ibdd.onion:8332` and get your `rpcuser` and `rpcpassword` and add them all manually in Fully Noded:  `Settings` > `Node Manager` > `+` > `manually`

## Importing a wallet from Specter
- In Specter click the wallet of your choice, Fully Noded is compatible with all of them
- Click `Settings`
<img src="./Images/specter_1.png" alt="" width="250"/>

- Click `export`
<img src="./Images/specter_2.png" alt="" width="250"/>

- In Fully Noded go to the `Active Wallet` tab > `+`  > `import` > scan the Specter export QR code

## Troubleshooting
- `Unknown error`: restart your node, restart Fully Noded, if that does not work make sure your `rpcpassword` and `rpcuser` do not have any special characters, only alphanumeric is allowed, otherwise you will not connect as it breaks the url to your node.
- `Internet connection appears offline`: reboot Tor on your node, force quit and reopen Fully Noded, this works every single time.
- If you can not connect and you have added Tor V3 auth to your node then ensure you added the public key correctly as Fully Noded exports it, reboot Tor, force quit Fully Noded and reopen.
- The way Fully Noded works is very robust and reliable, if you have a connection issue there is a reason, don't lose hope :)

## What can Fully Noded do?
- Recover any wallet
- Import any wallet with xpubs/xprvs
- WIF import
- Create watch-only wallets on your node where the seed is encrypted and stored securely on your device so that you may sign the psbt's your node builds for you
- RBF
- Full coin control
- A suite of raw transaction tools: verify, broadcast, build, sign etc...
- A suite of PSBT tools: process, finalize, analyze, decode, join, combine etc...
- HWW Paring
- Easy HD Multisig capability
- Easy Cold Storage
- Coldcard, Ledger, Trezor, Wasabi wallet compatibilty for building psbt's/watch-only wallets or recovery
- Most of the Bitcoin Core JSON-RPC API is covered
- wallet.dat encryption for hot wallets
- So much more
- BIP39 compatiblity for your Node
- 100% self sovereign Bitcoin use, Fully Noded is 95% powered by your own node with some additional code for smartly creating wallets and signing psbt's offline, a very minimized third party.

## Download from App Store
[here](https://apps.apple.com/us/app/fully-noded/id1436425586)

## Telegram
[here](https://t.me/FullyNoded) is the open Telegram group.

## Q and A
For basic usage check out the website QA [here](https://fullynoded.app/faq/).

For a more in depth Q&A inspired by discussions on the telegram group check out our [Question and Answers](./Docs/QandA.md)

## Tutorials
- Soon ™️, for now read these medium posts which go over some basics:
1. [Intoducing Fully Noded Wallets](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102)
2. [Introducing Fully Noded PSBT Signers](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558?sk=fa56fa3939136f269f0ca2a4fcdeee38)
- Also going through the [questions & answers](./QuestionsAnswersFN.md) might be an instructional experience.

## Build From Source
- Install `Xcode command line tools`, in terminal: `xcode-select --install`
- Ensure you have Homebrew installed:
  - `brew --version`, if you get a valid response you have brew installed already. If not, install brew:
  ```
  cd /usr/local
  mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
  ```
- Install carthage and libwally dependencies:  `brew install automake autoconf libtool gnu-sed carthage`
- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- Create a free Apple developer account [here](https://developer.apple.com/programs/enroll/)
- In Terminal:
  - `git clone https://github.com/Fonta1n3/FullyNoded.git --recurse-submodules`
  - `cd FullyNoded`
  - `carthage build --platform iOS`, let it finish.
- That's it, you can now open `FullyNoded.xcodeproj` in Xcode and run it in a simulator or on your device.

## Connecting over Tor macOS
Run `brew --version` in a terminal, if you get a valid response you have brew installed already. If not, install brew:

```cd /usr/local
mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew
```
### On the device running your node:
- run `brew install tor` in a terminal
- Once Tor is installed you will need to create a Hidden Service.
- Now first locate your `torrc` file, this is Tor's configuration file. Open Finder and type `shift command h` to navigate to your home folder and  `shift command .` to show hidden files.
-  If you've not been able to locate the torrc file, you might have to create the torrc file manually first. Do this by copying the torrc.sample -file: `cp /usr⁩/local⁩/etc⁩/tor⁩/torrc.sample /usr⁩/local⁩/etc⁩/tor⁩/torrc` and give the file it's right permission `chmod 700 /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- The torrc file should be located at `‎⁨/usr⁩/local⁩/etc⁩/tor⁩/torrc`, to edit it you can open terminal and run `sudo nano /usr⁩/local⁩/etc⁩/tor⁩/torrc`
- Locate the section that looks like:

```
## Once you have configured a hidden service, you can look at the
## contents of the file ".../hidden_service/hostname" for the address
## to tell people.
##
## HiddenServicePort x y:z says to redirect requests on port x to the
## address y:z.

```

- And below it add one Hidden Service for each port:

```
HiddenServiceDir /usr/local/var/lib/tor/fullynoded/main
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/test
HiddenServiceVersion 3
HiddenServicePort 18332 127.0.0.1:18332

HiddenServiceDir /usr/local/var/lib/tor/fullynoded/regtest
HiddenServiceVersion 3
HiddenServicePort 18443 127.0.0.1:18443
```

The syntax is `HiddenServicePort xxxx 127.0.0.1:18332`, `xxxx` represents a synthetic port (virtual port), that means it doesn't matter what number you assign to `xxxx`. However, to make it simple just keep the ports the same.


- Save and close nano with `ctrl x` + `y` + `enter` to save and exit nano (follow the prompts)
- Start Tor by opening a terminal and running `brew services start tor`
- Tor should start and you should be able to open Finder and **navigate to** your onion address(es) you need for Fully Noded:
    * `/usr/local/var/lib/tor/fullynoded/main` (the directory for *mainnet* we added to the torrc file) and see a file called `hostname`, open it and copy the onion address, that you need for Fully Noded.
    * `/usr/local/var/lib/tor/fullynoded/test` (the directory for *testnet* we added to the torrc file), same: there is file called `hostname`, open it etc.
    * `/usr/local/var/lib/tor/fullynoded/regtest` (the directory for *regtest net* we added to the torrc file); same as `main` and `test`.

- The `HiddenServicePort` needs to control your nodes rpcport, by default for mainnet that is 8332, for testnet 18332 and for regtest 18443.

- All three `HiddenServiceDir`'s in `main`, `test` and `regtest` subdirectories of `/usr/local/var/lib/tor/fullynoded` need to have permission 700, You can check this yourself ([How to interpret file permissions](https://askubuntu.com/a/528433))If not, they must be changed to 700 with `chmod 700` command:
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/main`
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/test`
    * `chmod 700 /usr/local/var/lib/tor/fullynoded/regtest`

- A ready to use `torrc` file that conforms to the guidelines above is available [here](./Docs/torrc-tailored.md).
- Check that your node is **on**, that it's really running.

### On the device running FN:
- Now in Fully Noded go to `Settings` > `Node Manager` > `+` and add a new node by inputting your RPC credentials and copy and paste your onion address with the port at the end `qndoiqnwoiquf713y8731783rgd.onion:8332`.
- You should never type (password) fields manually, just copy and paste between devices. Between Apple Mac, iphone and iPad, the clipboard will be synced as soon as you *put on bluetooth* on at least two of the devices. Once bluetooth is on on your mac and ipad then it should automatically paste over from the computer to iPad and back. Same should work for iPhone.
- Add *mainnet*, *testnet*, and / or *regtest net* at your convenience. You can run all three and connect to all three.

- Restart Tor on your nodes computer `brew services restart tor`, and check that your node is **on**; that it's really running. Hard stop FN app on your device and reopen FN.
- And you should be able to connect to your V3 hidden service from anywhere in the world with your node completely behind a firewall and no port forwarding

Skip the Windows section to see the suggested `bitcoin.conf` settings for FN.

## Connecting over Tor Windows 10
If you already have the Tor Expert Bundle installed you can skip the first 3 steps.

### On the device running your node
- Download the Tor Expert Bundle [here](https://www.torproject.org/download/tor/)
- Unpack the "Tor" folder onto your C: drive.
- Open PowerShell as admin (Press Windows Key + X and then select PowerShell (Admin))

Now we have Tor on our drive, but we still have configure and install it.

Let's enter the directory in Powershell:
`cd C:\Tor`
Now we're in the Tor directory.
In order to configure Tor we'll have to generate a configuration file:
`echo > torrc`
Now we launch notepad and edit the file to fit our needs:
`notepad torrc`
Enter the following into the file:
```
HiddenServiceDir "C:/Tor/fullynoded/main/"
HiddenServiceVersion 3
HiddenServicePort 8332 127.0.0.1:8332

HiddenServiceDir "C:/Tor/fullynoded/test/"
HiddenServiceVersion 3
HiddenServicePort 18332 127.0.0.1:18332

HiddenServiceDir "C:/Tor/fullynoded/regtest/"
HiddenServiceVersion 3
HiddenServicePort 18443 127.0.0.1:18443
```

Save and exit the file.

Now we have to create the directories:
```
cd C:\Tor
mkdir fullynoded
mkdir fullynoded\main
mkdir fullynoded\test
mkdir fullynoded\regtest
```

Save and exit the file.
Now we install Tor as a service:
`C:\Tor\tor.exe --service install -options -f "C:\Tor\torrc"`

Now we can enable the service by typing:
`C:\Tor\tor.exe --service start`

After you start the service the hostname files will be generated in `C:\Tor\fullynoded\main`, `C:\Tor\fullynoded\test`, and `C:\Tor\fullynoded\regtest`, you can view them by typing:<br/>
`cat C:\Tor\fullynoded\main`<br/>
`cat C:\Tor\fullynoded\test`<br/>
`cat C:\Tor\fullynoded\regtest`<br/>

Next you need to ensure your `bitcoin.conf` has rpc credentials added (see next section).

Once you have rpc credentials added to your `bitcoin.conf` you can reboot Bitcoin-Core.

### On the device running FN:
- Now in Fully Noded go to `Settings` > `Node Manager` > `+` and add a new node by inputting your RPC credentials and copy and paste your onion address with the port at the end `qndoiqnwoiquf713y8731783rgd.onion:8332`.
- You should never type (password) fields manually, just copy and paste between devices. Between Apple Mac, iphone and iPad, the clipboard will be synced as soon as you *put on bluetooth* on at least two of the devices. Once bluetooth is on on your mac and ipad then it should automatically paste over from the computer to iPad and back. Same should work for iPhone.
- Add *mainnet*, *testnet*, and / or *regtest net* at your convenience. You can run all three and connect to all three.


## Bitcoin Core settings
- Here is an example `bitcoin.conf` file best suited for Fully Noded:

```
#forces your node to accept rpc commands
server=1

# Up to you if you want to prune or not, FN will work just the same. A pruned node is a Full Node!
# 1000 means the node will only take up around 1gb of space
prune=1000

#Choose any username or password, make the password very strong **DO NOT USE SPECIAL CHARACTERS**, it will break the uri to your node that FN uses.
rpcuser=yourUserName
rpcpassword=aVeryStrongPasswordSuchAs128dnc849vn9n7gSS

# This is redundant but only allows your computer to access your node
rpcallowip=127.0.0.1

# For a faster IBD use dbcach=half your ram - for 8gb ram set dbcache to 4000
dbcache=4000
```

## Tor V3 Authentication

**THIS IS OPTIONAL** It ensures that even if an attacker got your `rpcport` hidden service's hostname and `bitcoin.conf` rpc creds (the quick connect QR) they would still not be able to access your node. For an explainer on how this generally works read [this](https://matt.traudt.xyz/p/FgbdRTFr.html)

##### Preparatory work:
First get your connection going. **Resolve the connection issue first then add the keypair**, to keep things simple. Some double checks ( A more extensive guide [here](./Readme.md#connecting-over-tor-macos)).

###### On your device running node
- Your node is running either mainnet, testnet or regtest
- Your node is **on**, it's really running (check that it's running)
- You've made the appropriate HiddenService -Dir, -Version and -Port declaration in your `torrc` file for at least the matching port (respectively 8332, 18332 and/or 18443).
- You've started Tor for the changes to take effect
- You've looked up the hostname files

###### On your device running FN
- in Fully Noded, make sure you have added a node with this type of onion url:
	qsctzvoadnehtt5tpjtprudxrrx2b76kra7e2lkbyjpdksncbclrdk5l.onion:18332 (testnet example)

- You've force quit and reopened FN to connect again, you've had to `brew services restart tor`, for the authentication to take effect.
  As long as your `authorized _clients` dir of the matching `HiddenServiceDir` declaration in your `torrc` is empty you won’t need to add a keypair to connect. That's why V3 Auth Keypair generation is optional.

### How to add extra security by adding a V3 Auth Keypair to a already established (Tor Hidden Services) connection?

#### The easy way:

- Do it in FullyNoded: "settings" > "security center" > "tor v3 authentication" > "tap the refresh button" > export the pubkey to your nodes `HiddenServiceDir`/`authorized_clients` as a `FullyNoded.auth` file which contains the pubkey exactly as FN exports it.

#### From scratch:

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

Go to your hidden services driectory that you added to your torrc (/var/lib/tor/**theNodlTorDirectoryName**/authorized_clients/fullynoded.auth):

```
HiddenServiceDir /var/lib/tor/FullyNodedV3/  (**theNodlTorDirectoryName** is FullyNodedV3 in this example)
```

Open the example file:

`sudo nano /var/lib/tor/FullyNodedV3/authorized_clients/fullynoded.auth`

and paste in:

`descriptor:x25519:PHK2DFSCNNJ75U3GUA3SHCVEGPEJMZAPEKQGL5YLVM2GV6NORB6Q`

No space, no newline.<br/>
Save and exit and you have one of the most secure node/light client set ups possible. (assuming your server is firewalled off)

#### Final thoughts on security
I will happily share my enitre RPC-url and -password with anyone, there is no way they can hack this Tor V3 auth, granted they can not get the private key obviously. Fully Noded creates the private key offline, encrypts it heavily and stores it in the most secure way possible.

## QuickConnect URL Scheme
Fully Noded has a deep link registered with the following prefixes  `btcstandup://` and `btcrpc://` either prefix will work.

If you are a node manufacturer you can embed such a link to your web based UI that allows a user who has Fully Noded installed on their device to add and connect to their node with a single tap from the web based UI.

The url can also be displayed as a QR Code and a user can simply scan it when they go to add a node in Fully Noded.

The format of the URL is:

`btcrpc://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>?label=<optional node label>`

Example with node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?label=Your%20Nodes%20Name`

Example without node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?`

Fully Noded is compatible with V3 authenticated hidden services, the user has the option in the app to add a V3 private key for authentication.

## Security and Privacy

- All network traffic is encrypted by default using Tor.
- Fully Noded NEVER uses another server or uploads data or requires any data (KYC/AML) from you whatsoever, your node is the only back end to the app.
- Any sensitive data (seed words, credentials) the app saves onto the device locally is encrypted to AES standards and the encryption key is stored on the devices secure enclave (iCloud sync disabled). DYOR regarding iPhone security.

## How does it work?

Bitcoin Core includes a ton of functionality that is not shown to the user in the [GUI](https://www.computerhope.com/jargon/g/gui.htm), this functionality must be accessed by using the [command line](https://en.wikipedia.org/wiki/Command-line_interface) aka CLI, doing so can be quite tedious where tiny typos will return errors. Fully Noded does the hard work of issuing the CLI commands to your node in a programmatic and reliable way powered by the taps you make on your iPhone. The purpose of Fully Noded is to allow users a secure and private way to connect to and control their node, unlocking all the powerful features Bitcoin Core has to offer without needing to use CLI.

Fully Noded needs to connect to the computer that your node is running on in order to issue commands to your node. It does this using [Tor](https://lifehacker.com/what-is-tor-and-should-i-use-it-1527891029).

Connecting to your nodes computer is the first part, once connected Fully Noded then needs to be able to issue [RPC commands](https://en.bitcoin.it/wiki/API_reference_(JSON-RPC)) to your node. It issues these commands to your [local host](https://whatismyipaddress.com/localhost) over [curl](https://curl.haxx.se). In order to be able to do that Fully Noded needs to know your RPC credentials,  `rpcusername` and  `rpcpassword`.

Once Fully Noded is connected it will start issuing commands one at a time, here are some from the home table:

```
curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listwallets", "params":[] }' -H 'content-type: text/plain;' http://user:password@nwfwjfwjbefiu.onion:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "getbalance", "params":["*", 0, false] }' -H 'content-type: text/plain;' http://user:password@wfwjfwjbefiu.onion:18443/

curl --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "listtransactions", "params":["*", 50, 0, true] }' -H 'content-type: text/plain;' http://user:password@wfwjfwjbefiu.onion:18443/
```

The `method` is a `bitcoin-cli` command and you can use [this great resource](https://chainquery.com/bitcoin-cli) to dive deeper into what they all do.

[This is the code in Fully Noded from the Node Logic class](https://github.com/Fonta1n3/FullyNoded/tree/master/BitSense/Node%20Logic) which issues the above commands, if you look at it you will see a lot of commands that look like this:

`reducer.makeCommand(command: .listunspent, param: "0", completion: getResult)`

The `.listunspent` directly represents the `bitcoin-cli` commands we linked to just above and the `params` represent the options you can pass with those commands.  You can get the same functionality copying and pasting these commands into a terminal or using the Bitcoin-Qt console.

## Contributing

Please let us know if you have issues.

PR's welcome.

## Built With

- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.
- [Libwally-Swift](https://github.com/Fonta1n3/libwally-swift) which relies on [Libwally-Core v0.7.7](https://github.com/Fonta1n3/libwally-swift/tree/master/CLibWally/libwally-core) for converting cryptographically secure entropy to BIP39 words, deriving HD keys and most importantly signing psbt's.

## Docs

For more relevant reading see the [docs](./Docs)
