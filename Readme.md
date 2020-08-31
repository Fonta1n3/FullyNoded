
# [Fully Noded™️](https://fullynoded.app)

Self sovereign, secure, powerful, easy to use **wallet** that utilizes your own [Bitcoin Core](https://github.com/bitcoin/bitcoin) node as a backend. Providing an easy to use interface to interact with your nodes non wallet capabilities. Fully Noded™️ wallets are powered by PSBT's and descriptors. Fully Noded acts as an offline signer using your node as a watch-only wallet as well as giving you full unfettered access to every wallet.dat in your nodes `.bitcoin` directory. [C-Lightning](https://github.com/ElementsProject/lightning) compatible for instant, unfairly cheap payments.

<img src="./Images/fn_logo.png" alt="" width="100"/><br/>
[<img src="./Images/appstore.png" alt="download fully noded on the app store" width="100"/>](https://apps.apple.com/us/app/fully-noded/id1436425586)<br/>

## Cost

### Redistributing Fully Noded™️ Code on the App Store

Even though this project is open source, this does not mean you can reuse this code when distributing closed source commercial products. Please [contact us](mailto:dentondevelopment@protonmail.com) to discuss licensing options before you start building your product.

If you are an open source project, please [contact us](mailto:dentondevelopment@protonmail.com) to arrange for an App Store redistribution exception. For more information about why this is required, please read [this blog post](https://whispersystems.org/blog/license-update/) from Open Whisper Systems.

### Cost for End Users

Downloading the Fully Noded™️ iOS app is **100% free** because it is important that all people around the world have unrestricted access to a private, self sovereign means of using Bitcoin.
However, developing and supporting this project is hard work and costs real money. Please help support the development of this project!

* [GitHub Sponsors](https://github.com/sponsors/fonta1n3)
* ⚡️ [Tor lightning donation](http://56uo4htoxdt2tgh6zui5v2q7c4ax43dd3fwueiurgqdw7lpunn2cikqd.onion:5599/donation) (Tor browser required)
* 🔗 [Bitcoin](bitcoin:bc1q6xw40gsm86yk78dlfun70nt7meh2nq9j7sc7ym?message=FullyNoded%20Donations) `bc1q6xw40gsm86yk78dlfun70nt7meh2nq9j7sc7ym`
* The preferred method of donation is via the app itself, simply tap the ♥️ button when creating a transaction and it will automatically load a donation address which is derived from a hard coded xpub within the app:<br/><br/>
<img src="./Images/donation.jpg" alt="download fully noded on the app store" width="250"/><br/>


## Why Fully Noded™️?

* **Privacy.** Majority of existing Bitcoin wallets are powered by someone else's node, this causes complete and utter loss of privacy. By running your own node and utilizing it via a Tor hidden service you are maintaining a high level of privacy.
* **Security.** All communications to your node are done within the Tor network, this means your IP is never exposed, your communications to your node are heavily encrypted, this is by default and not possible to opt out of. The app allows you to utilize Tor V3 authentication for first in class security, in short this means you self authenticate your device and no other device will be able to connect to your node. The app by default never uses your node as a hot wallet and instead keeps your seed heavily encrypted and securely stored on your iOS device, private keys never touch a network request, Tor or otherwise. With Fully Noded™️ architecture you can always keep your node completely behind a firewall and access it securely from anywhere in the world.
* **Sovereignty.** You are in total control, you run a self hosted server which then powers your mobile wallet. There is no middle man which can deny you access to your own server. You are in control of your private keys and utxo's.
* **Censorship Resistance.** If you rely on a companies' server to power your wallet you are inherently relying on them, they can at any time disable your connection to their servers, shut them off or be forced to deny you service. When using Fully Noded™️ you never have to be concerned about a third party censoring your payments, you are quite literally your own bank.
* **Recovery.** Users may recover any wallet with the app, simply create a Recovery wallet with BIP39 seed words and automatically recover every popular wallet in one fell swoop. For advanced users you may create a descriptor of any type and import it with the app, this allows every wallet type imaginable to be recovered. If you have existing wallets on your node which are watch-only you may add BIP39 seed words to the app to make them spendable.

## Prerequisites

* [Bitcoin Core](https://bitcoincore.org/en/releases/), recommended v0.20.1
* [Tor](https://www.torproject.org/download/)
* An understanding of basic Bitcoin concepts, you can read this [overview](./Docs/What-is-a-node.md). It greatly helps to have a basic understanding of `bitcoin-cli` commands, what they do and how they work to grasp how the app works under the hood. [Learning Bitcoin from the Command Line](https://github.com/BlockchainCommons/Learning-Bitcoin-from-the-Command-Line) is an excellent in depth reference.

## Getting Setup Proper

- After downloading the app you need to first connect a node - see the guides
    - On macOS by far the easiest way (one click setup) is to use *Gordian-Server*, download [here](https://github.com/BlockchainCommons/GordianServer-macOS/raw/master/GordianServer-macOS-v0.1.2.dmg)
    - For linux you can use this [script](https://github.com/BlockchainCommons/Bitcoin-Standup-Scripts/blob/master/Scripts/StandUp.sh)
    - [Connect your existing node](./Docs/Bitcoin-Core/Connect.md#connect-your-own-node)
        - [Bitcoin Core settings](./Docs/Bitcoin-Core/bitcoin-conf.md)
    - To connect a node box see our guides:
        - [BTCPayServer](./Docs/Bitcoin-Core/Connect.md#connect-btcpayserver)
        - [Nodl](./Docs/Bitcoin-Core/Connect.md#connect-nodl)
        - [Raspiblitz](./Docs/Bitcoin-Core/Connect.md#connect-raspiblitz)
        - [Embassy](./Docs/Bitcoin-Core/Connect.md#connect-embassy)
        - [myNode](../Docs/Bitcoin-Core/Connect.md#connect-mynode)
- In order to connect to your own node you need to expose its functionality to a Tor Hidden Service:
    - [macOS](./Docs/Tor/Tor.md#connecting-over-tor-macos)
    - [Windows 10](./Docs/Tor/Tor.md#connecting-over-tor-windows-10)
    - [Debian 10](./Docs/Tor/Tor.md#connecting-over-tor-linux-debian-10)
- Once you are connected for best in class security practices you ought to take full advantage of the apps ability to authenticate over native Tor V3:
    - [Tor V3 Authentication](./Docs/Tor/Authentication.md)
- [Troubleshooting](./Docs/Troubleshooting.md)
    - [Q and A](https://fullynoded.app/faq/)
    - [Telegram](https://t.me/FullyNoded)

## Docs

* [Wallet usage](./Docs/Wallets)
* [Bitcoin Core (node) related](./Docs/Bitcoin-Core)
* [Connecting your node](./Docs/Bitcoin-Core/Connect.md)
* [Importing a wallet from Specter](./Docs/Wallets/Specter.md)
* [Build From Source](./Docs/Build-from-source.md)
* [Quick Connect uri](./Docs/Quick-Connect-QR.md)
* [How does it work?](./Docs/How-does-it-work.md)
* [Recovery](./Docs/Wallets/Recovery.md)
* [Lightning](./Docs/Lightning.md)
* [Tor](./Docs/Tor)

## Medium Posts

* [Intoducing Fully Noded Wallets](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102)
* [Introducing Fully Noded PSBT Signers](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558?sk=fa56fa3939136f269f0ca2a4fcdeee38)

## Youtube Tutorials

* [Coldcard Single Signature wallet](https://www.youtube.com/watch?v=W0vwgzIrPoY)
* [Coldcard Multi Signature wallet](https://www.youtube.com/watch?v=daXvAcHy8H0)
* [Create, spend from and recover a multisig wallet](https://www.youtube.com/watch?v=-Eh-OdtFRmI)

## Contributing

Thank you for your interest in contributing to Fully Noded™️! To avoid potential legal headaches and to allow distribution on Apple's App Store please sign our CLA (Contributors License Agreement).

1. Sign the [CLA](./CLA.md), and email it to [dentondevelopment@protonmail.com](mailto:dentondevelopment@protonmail.com).
2. [Fork](https://github.com/Fonta1n3/FullyNoded/fork) the project and (preferably) work in a feature branch.
3. Open a [pull request](https://github.com/Fonta1n3/FullyNoded/pulls) on GitHub adding your signed CLA [here](./CLA-signed).
4. All commits must be pgp signed, see [this guide](https://docs.github.com/en/enterprise/2.14/user/articles/signing-commits).
5. Thank you!

## License


    Software License Agreement (GPLv3+)

    Copyright (c) 2018, Peter Denton. All rights reserved.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

If you would like to relicense this code to distribute it on the App Store,
please contact me at [dentondevelopment@protonmail.com](mailto:dentondevelopment@protonmail.com).

## Third-party Libraries

This software additionally references or incorporates the following sources
of intellectual property, the license terms for which are set forth
in the sources themselves:

* Credit to [Chat-Secure](https://github.com/ChatSecure/ChatSecure-iOS/blob/master/README.md) Readme.md for inspiring the layout/format and some of the text of this document.
* Credit to [Blockchain Commons](https://github.com/BlockchainCommons) for the format of the CLA.

The following dependencies are bundled with the Fully Noded™️, but are under
terms of a separate license:

* [Tor](https://github.com/iCepa/Tor.framework) for connecting to your node more privately and securely.
* [Libwally-Swift](https://github.com/Fonta1n3/libwally-swift) which relies on [Libwally-Core v0.7.7](https://github.com/Fonta1n3/libwally-swift/tree/master/CLibWally/libwally-core) for converting cryptographically secure entropy to BIP39 words, deriving HD keys and most importantly signing psbt's.
* [DescriptorParser.swift](https://github.com/BlockchainCommons/GordianWallet-iOS/blob/master/XCode/GordianWallet/Helpers/DescriptorParser.swift) from [Blockchain Commons](https://github.com/BlockchainCommons) which is under the [spdx:BSD-2-Clause Plus Patent License](https://spdx.org/licenses/BSD-2-Clause-Patent.html).
* [Base32](https://github.com/norio-nomura/Base32/blob/master/Sources/Base32) built by [@norio-nomura](https://github.com/norio-nomura) - for Tor V3 authentication key encoding which is licensed under The MIT License (MIT).
* [Base58](https://github.com/wavesplatform/Base58/tree/master/Source) from [@LukeDash-jr](https://github.com/luke-jr) and the [Waves Platform](https://github.com/wavesplatform) which is licensed under The MIT License (MIT). Used for converting Slip0132 extended keys to xpubs/xprvs.

