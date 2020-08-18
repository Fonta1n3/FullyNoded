


# <img src="./Images/fn_logo.png" alt="" width="100"/> Fully Noded™️

Self sovereign, secure, powerful, easy to use **wallet** that utilizes your own node as a backend. Powered by PSBT's and descriptors. Acts as an offline signer using your node as a watch-only wallet. [C-Lightning](https://github.com/ElementsProject/lightning) compatible for instant, unfairly cheap payments.

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

# Why Fully Noded?

To answer that question, you need to know your goals. These are the objectives Fully Noded supports:

  - I would like to manage my Bitcoin node with a handy GUI
  - I would like to sovereignly manage my crypto assets myself
  - I would like to comply with the latest bitcoin security practices 
  - I would like to get to know and test the latest Bitcoin developments
  - I would like to contribute to open public developments in bitcoin

 FN is not:

 - an easy to use novice-proof bitcoin wallet to hodl cryptovalue; use Trezor, Ledger, KeepKey; etc. 
 - an anonymous coinjoin tool; use Samourai or Wasabi instead
 - a dedicated tool with ease of use in mind to control a bitcoin node, use Gordian Wallet (too)
 - a tool to manage your Decentralised ID; use Gordian Wallet (too)

# For who is Fully Noded?

Fully Noded is a multi-purpose tool for power user. It is aimed at an [experienced Bitcoin specialist](#Personal-preparation), who runs a testnet (and eventually mainnet) Bitcoin node and recognises his/her goals in why to use FN and is willing to use an iOS device like iPhone or iPad.

## Contributing

Please let us know if you have issues.

PR's welcome.

## Built With

- [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.
- [Libwally-Swift](https://github.com/Fonta1n3/libwally-swift) which relies on [Libwally-Core v0.7.7](https://github.com/Fonta1n3/libwally-swift/tree/master/CLibWally/libwally-core) for converting cryptographically secure entropy to BIP39 words, deriving HD keys and most importantly signing psbt's.

## Docs

For more relevant reading see the [docs](./Docs)
