
# Fully Noded™️

Self sovereign, secure, powerful, easy to use **wallet** that utilizes your own [Bitcoin Core](https://github.com/bitcoin/bitcoin) node as a backend as well as providing an easy to use interface to interact with your nodes non wallet capabilities. Fully Noded wallets are powered by PSBT's and descriptors. Fully Noded acts as an offline signer using your node as a watch-only wallet as well as giving you full unfettered access to every wallet.dat in your nodes `.bitcoin` directory. [C-Lightning](https://github.com/ElementsProject/lightning) compatible for instant, unfairly cheap payments.

<img src="./Images/fn_logo.png" alt="" width="100"/><br/>
[<img src="./Images/appstore.png" alt="download fully noded on the app store" width="100"/>](https://apps.apple.com/us/app/fully-noded/id1436425586)<br/>
[https://fullynoded.app](https://fullynoded.app) (work in progress)

## Cost

### Redistributing Fully Noded Code on the App Store

Even though this project is open source, this does not mean you can reuse this code when distributing closed source commercial products. Please [contact us](mailto:dentondevelopment@protonmail.com) to discuss licensing options before you start building your product.

If you are an open source project, please [contact us](mailto:dentondevelopment@protonmail.com) to arrange for an App Store redistribution exception. For more information about why this is required, please read [this blog post](https://whispersystems.org/blog/license-update/) from Open Whisper Systems.

### Cost for End Users

Downloading the Fully Noded iOS app is **100% free** because it is important that all people around the world have unrestricted access to a private, self sovereign means of using Bitcoin.
However, developing and supporting this project is hard work and costs real money. Please help support the development of this project!

* [GitHub Sponsors](https://github.com/sponsors/fonta1n3)
* ⚡️[Tor lightning donation](http://56uo4htoxdt2tgh6zui5v2q7c4ax43dd3fwueiurgqdw7lpunn2cikqd.onion:5599/donation)
* [Bitcoin](bitcoin:bc1q6xw40gsm86yk78dlfun70nt7meh2nq9j7sc7ym?message=FullyNoded%20Donations) `bc1q6xw40gsm86yk78dlfun70nt7meh2nq9j7sc7ym`
* The preffered method of donation is via the app itself, simply tap the ♥️ button when creating a transaction and it will automatically load a donation address which is derived from a hard coded xpub within the app itself.
<img src="./Images/donation.jpg" alt="download fully noded on the app store" width="250"/><br/>


# Table of Contents

### Introduction table of contents
1. [Why Fully Noded](#Why-Fully-Noded)
2. [For who is Fully Noded?](#For-who-is-Fully-N-oded?)
3. [Contributing](#contributing)
4. [Built With](#built-with)
5. [The docs](#docs)
### Workflow table of contents
0. [Overview Fully Noded](./Overview.md)
1. [Requirements](./Howto.md#requirements)
1. [Preparation](./Preparation.md)
2. [Supported Nodes](./Connect-node.md#supported-nodes)
3. [Connect your own node](./Connect-node.md#connect-your-own-node)
4. [Connect BTCPayServer](./Connect-node.md#connect-btcpayserver)
5. [Connect Nodl](./Connect-node.md#connect-nodl)
6. [Connect Raspiblitz](./Connect-node.md#connect-raspiblitz)
7. [Connect Embassy](./Connect-node.md#connect-embassy)
8. [Connect myNode](./Connect-node.md#connect-mynode)
9. [Importing a wallet from Specter](./Connect-node.md#importing-a-wallet-from-specter)
10. [Troubleshooting](./Connect-node.md#troubleshooting)
11. [What can Fully Noded do?](./Howto.md#what-can-fully-noded-do)
12. [Download from App Store](./Howto.md#download-from-app-store)
13. [Telegram](./Howto.md#telegram)
14. [Q and A](./Howto.md#q-and-a)
15. [Tutorials](./Howto.md#tutorials)
16. [Build From Source](./Howto.md#build-from-source)
17. [Connecting over Tor macOS](./Tor.md#connecting-over-tor-macos)
18. [Connecting over Tor Windows 10](./Tor.md#connecting-over-tor-windows-10)
19. [Connecting over Tor Linux Debian 10](./Tor.md#connecting-over-tor-linux-debian-10)
20. [Bitcoin Core settings](./Howto.md#bitcoin-core-settings)
21. [Tor V3 Authentication](./Authentication.md#tor-v3-authentication)
22. [QuickConnect URL Scheme](./Authentication.md#quickconnect-url-scheme)
23. [Security and Privacy](./Authentication.md#security-and-privacy)
24. [How does it work?](./Howto.md#how-does-it-work)
25. [Recover FN Wallets](./Recovery.md#Fully-Noded-Wallets)
26. [Recover Anything else](./Recovery.md#Anything)

# Why Fully Noded?

To answer that question, you need to know your goals. These are the objectives Fully Noded supports:

  - I would like to manage my Bitcoin node with a handy GUI
  - I would like to sovereignly manage my crypto assets myself
  - I would like to comply with the latest bitcoin security practices 
  - I would like to get to know and test the latest Bitcoin developments
  - I would like to contribute to open public developments in bitcoin

 FN is less:

 - an easy to use novice-proof bitcoin wallet to hodl cryptovalue; use Trezor, Ledger, KeepKey; etc. 
 - an anonymous coinjoin tool; use Samourai or Wasabi instead
 - a dedicated tool with ease of use in mind to control a bitcoin node, use Gordian Wallet (too)
 - a tool to manage your Decentralised ID; use Gordian Wallet (too)

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

# Overview and workflow
 - [Overview](./Overview.md)
 - [Workflow](./Howto.md)

 
# For who is Fully Noded?

Fully Noded is a multi-purpose tool for power users. It is aimed at an [experienced Bitcoin specialist](#Personal-preparation), who runs a testnet (and eventually mainnet) Bitcoin node and recognises his/her goals in why to use FN and is willing to use an iOS device like iPhone or iPad.

## Contributing

Please let us know if you have issues.

 - Pull Requests (PRs) welcome.
 - Participate in the open [Telegram-group](https://t.me/FullyNoded)
 - Core test team members welcome too. Just drop us a line (DM or [Telegram-group](https://t.me/FullyNoded)) and we'll invite you to the Core Test group. 

## Built With

- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.
- [Libwally-Swift](https://github.com/Fonta1n3/libwally-swift) which relies on [Libwally-Core v0.7.7](https://github.com/Fonta1n3/libwally-swift/tree/master/CLibWally/libwally-core) for converting cryptographically secure entropy to BIP39 words, deriving HD keys and most importantly signing psbt's.

## Docs

For more relevant reading see the [docs](./Docs)
