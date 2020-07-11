# Fully Noded™️

A feature rich Bitcoin app which is 100% powered by your own Full Node. Allows you to connect to and control multiple nodes using a client side native Tor thread making calls to your nodes rpcport via a V3 hidden service with optional Tor V3 authentication whereby the app can either create key for you (out of band) or you may supply your own private key.

## Supported Nodes

- Nodl
- myNode
- BTCPayServer
- Bitcoin Core (a Tor V3 hidden service controlling your rpcport is required)
- Raspiblitz
- Embassy

## Connect your own node

- Create a hidden service that controls your nodes rpcport (there is a mac guide below on how to do that). 
- Go to `settings` > `node manager` > `+` > `manually`
- Find your bitcoin.conf and input your rpcuser and rpcpassword and a label into the app. See "bitcoin.conf settings" below. **No special characters allowed! Only alphanumeric**
- Input the hidden services hostname with the port at the end (njcnewicnweiun.onion:8332)
- Tap `save`, you will be alerted it if was saved successfully, it will automatically start connecting to it. Optionally, if you have authentication setup you will need to create V3 auth keys in the app by going to `settings` > `security center` > `Tor V3 Authentication` > `tap the refresh button to create keys out of band or add your own private key by pasting it in` > `tap the export button to export your public key`

## Troubleshooting
- `Unknown error`: restart your node, restart Fully Noded, if that does not work make sure your `rpcpassword` and `rpcuser` do not have any special characters, only alphanumeric is allowed, otherwise you will not connect as it breaks the url to your node.
- `Internet connection appears offline`: reboot Tor on your node, force quit and reopen Fully Noded, this works every single time.
- If you can not connect and you have added Tor V3 auth to your node then ensure you added the public key correctly as Fully Noded exports it, reboot Tor, force wuit Fully Noded and reopen.
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
- 100% self soveriegn Bitcoin use, Fully Noded is 95% powered by your own node with some additional code for smartly creating wallets and signing psbt's offline, a very minimized third party.

## Download from App Store

[here](https://apps.apple.com/us/app/fully-noded/id1436425586)

## Telegram

[here](https://t.me/FullyNoded)

## Tutorials

- Soon ™️, for now read these medium posts which go over some basics:
1. [Intoducing Fully Noded Wallets](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102)
2. [Introducing Fully Noded PSBT Signers](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558?sk=fa56fa3939136f269f0ca2a4fcdeee38)

## Build From Source - Mac

Run `brew --version` in a terminal, if you get a valid response you have brew installed already. If not install brew:

`cd /usr/local`
`mkdir homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip 1 -C homebrew`

Wait for bew to finish.

- Install carthage and libwally dependencies:  `brew install automake autoconf libtool gnu-sed carthage`
- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- You will need a free Apple developer account create one [here](https://developer.apple.com/programs/enroll/)
- In Xcode, click "Xcode" > "preferences" > "Accounts" > add your github account
- Go to [Fully Noded in GitHub](https://github.com/Fonta1n3/FullyNoded) click "Code" -> "Open in Xcode"
- Once open quit Xcode
- Open Terminal
- `cd FullyNoded`
- `carthage build libwally-swift` and let carthage do its thing

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

# Up to you if you want to prune or not
prune=1000

#Choose any username or password, make the password very strong
rpcuser=yourUserName
rpcpassword=aVeryStrongPasswordSuchAs128dnc849vn9n7gSS

#if you only want to accept connections over tor the following settings are needed
bind=127.0.0.1
proxy=127.0.0.1:9050
listen=1
debug=tor

# This is redundant but only allows your computer to access your node
rpcallowip=127.0.0.1

# For a faster IBD use dbcach=half your ram - for 8gb ram set dbcache to 4000
dbcache=4000
```

## V3 Auth Keypair generation (optional)

#### The easy way:

- Do it in FullyNoded

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

Go to your hidden services driectory that you added to your torrc:

```
HiddenServiceDir /var/lib/tor/FullyNodedV3/
```

as an example:

`sudo nano /var/lib/tor/FullyNodedV3/authorized_clients/fullynoded.auth`

and paste in:

`descriptor:x25519:PHK2DFSCNNJ75U3GUA3SHCVEGPEJMZAPEKQGL5YLVM2GV6NORB6Q`

Save and exit and you have one of the most secure node/light client set ups possible. (assuming your server is firewalled off)

## QuickConnect URL Scheme

Fully Noded has a deep link registered with the following prefix `btcstandup://`

If you are a node manufacturer you can embed such a link to your web based UI that allows a user who has Fully Noded installed on their device to add and connect to their node with a single tap from the web based UI.

The url can also be displayed as a QR Code and a user can simply scan it when they go to add a node in Fully Noded.

The format of the URL is:

`btcstandup://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>?label=<optional node label>`

Example with node label:

`btcstandup://rpcuser:rpcpassword@kjhfefe.onion:8332?label=Your%20Nodes%20Name`

Example without node label:

`btcstandup://rpcuser:rpcpassword@kjhfefe.onion:8332?`

Fully Noded is compatible with V3 authenticated hidden services, the user has the option in the app to add a V3 private key for authentication.

## Security & Privacy

- All network traffic is encrypted by default using Tor.
- Fully Noded NEVER uses another server or uploads data or requires any data (KYC/AML) from you whatsoever, your node is the only back end to the app.
- Any information the app saves onto the device locally is encrypted to AES standards and the encryption key is stored on the secure enclave. DYOR regarding iPhone security.

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

```
reducer.makeCommand(command: .listunspent,
                    param: "0",
                    completion: getResult)

```

The `.listunspent` directly represents the `bitcoin-cli` commands we linked to just above and the `params` represent the options you can pass with those commands.  You can get the same functionality copying and pasting these commands into a terminal or using the Bitcoin-Qt console.

## Specter Pairing

Specter will give you a wallet import QR code, you can convert that manually to a bitcoin core descriptor then simply import that descriptor to FN1.

This is an example from specter:

```
Key_123&wsh(sortedmulti(2,[fe23bc9a/48h/1h/0h/2h]tpubDEzBBGMH87CU5rCdo7gSaByN6SVvJW7c4WDkMuC6mKS8bcqpaVD3FCoiAEefcGhC4TwRCtACZnmnTZbPUk4cbx6dsLnHG8CyG8jz2Gr6j2z,[e120e47b/48h/1h/0h/2h]tpubDEvTHKHDhi8rQyogJNsnoNsbF8hMefbAzXFCT8CuJiZtxeZM7vUHcH65qpsp7teB2hJPQMKpLV9QcEJkNy3fvnvR6zckoN1E3fFywzfmcBA,[f0578536/48h/1h/0h/2h]tpubDE5GYE61m5mx2WrgtFe1kSAeAHT5Npoy5C2TpQTQGLTQkRkmsWMoA5PSP5XAkt4DBLgKY386iyGDjJKT5fVrRgShJ5CSEdd66UUc4icA8rw))
```

for Fully Noded just convert it to:

```
wsh(sortedmulti(2,[fe23bc9a/48h/1h/0h/2h]tpubDEzBBGMH87CU5rCdo7gSaByN6SVvJW7c4WDkMuC6mKS8bcqpaVD3FCoiAEefcGhC4TwRCtACZnmnTZbPUk4cbx6dsLnHG8CyG8jz2Gr6j2z/0/*,[e120e47b/48h/1h/0h/2h]tpubDEvTHKHDhi8rQyogJNsnoNsbF8hMefbAzXFCT8CuJiZtxeZM7vUHcH65qpsp7teB2hJPQMKpLV9QcEJkNy3fvnvR6zckoN1E3fFywzfmcBA/0/*,[f0578536/48h/1h/0h/2h]tpubDE5GYE61m5mx2WrgtFe1kSAeAHT5Npoy5C2TpQTQGLTQkRkmsWMoA5PSP5XAkt4DBLgKY386iyGDjJKT5fVrRgShJ5CSEdd66UUc4icA8rw/0/*))
```

All that is needed is to remove the `Key_123&` prefix and add `/0/*` to the end of each xpub.

You will also want a change descriptor so modify slightly by replacing `/0/*` with `/1/*` and import it as your change descriptor.

In Fully Noded, `incomings` > `import` > `descriptor`, and paste or scan it as a QR, thats it, do this twice once for the receive keys and once for the change keys.
...

## Contributing

Please let us know if you have issues.

PR's welcome.

## Built With

- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.
- [LibWally-Swift](https://github.com/blockchain/libwally-swift) for generating BIP39 seed words, deriving keys and signing psbt's.
