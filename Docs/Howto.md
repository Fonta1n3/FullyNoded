# Preparatory work for Fully Noded users
## Personal preparation
 - Knowledge
 - Gear
 - Skills
## Available info
 - Course material
 - Tutorials
 - Troubleshooting
 - Questions and Answers

## Requirements
- At least [Bitcoin Core 0.20.0](https://bitcoincore.org/bin/bitcoin-core-0.20.0/) for "Fully Noded Multisig" wallet compatibility, Bitcoin Core wallets will of course work with any version.
- [Tor](https://www.torproject.org/download/)
- [C-Lightning](https://github.com/ElementsProject/lightning) (optional, currently built to work with v0.9.0-1)


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

