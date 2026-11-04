# FAQ

**Do I need my own node?**
Yes: Bitcoin Core or Knots, on a computer you control. A pruned node works.
[Fully Noded Server](https://github.com/Fonta1n3/FullyNoded-Server) sets one up on a Mac.
Without a node, a nodeless sweep is possible for some coins (see below).

**Where are my private keys?**
On your phone only, encrypted, in the Signers tab. Your node only gets public keys. See
[Signers](./Wallets/Signers.md).

**Is my seed backed up to iCloud?**
No. Write your seed words down. See [best practices](./Backup-Recovery-Best-Practices.md).

**How do I connect?**
See [Connect your node](./Bitcoin-Core/Connect.md). Quickest: scan Fully Noded Server's Quick
Connect or Nostr Connect QR.

**Tor or Nostr Connect?**
Both are private and encrypted. Tor works with any node but takes a moment to connect. Nostr
Connect needs Fully Noded Server and loads in about a second. See
[Nostr-Connect.md](./Nostr-Connect.md).

**Can I connect over my local network?**
Yes: add the node with its LAN address and port, and let your node accept RPC from your network
([bitcoin.conf](./Bitcoin-Core/bitcoin-conf.md)).

**Can I use a hardware wallet?**
Yes. Import its wallet file or QR as a watch-only wallet, then export each PSBT to the device to
sign and bring it back to broadcast. See [Send](./Wallets/Sending.md).

**Does it do multisig?**
Yes, Segwit or Taproot, with cosigners from this phone, other devices or other people. See
[Create a wallet](./Wallets/Creating-Wallets.md#multi-sig).

**Can I use my node's existing wallets?**
Yes: wallet tab → **+** → **Bitcoin Core Wallets**.

**Why is my balance zero after recovering?**
Your node is rescanning the blockchain. Wait, then pull down to refresh.

**What's a payjoin?**
A payment both sides put coins into, which breaks a key chain-analysis assumption. Fully Noded can
pay and receive them. See [Payjoin.md](./Payjoin.md).

**What's a silent payment address?**
A reusable `sp1…` address where each payment still lands on a new, unlinkable output. See
[SilentPayments.md](../SilentPayments.md).

**Can I spend without my node?**
For silent payment coins whose tweak you've saved, yes: *Sweep without node (Nodeless)* on the UTXO
screen, over Tor to Esplora.

**Does Fully Noded support Lightning or JoinMarket?**
Not any more. For Core Lightning, see [Plasma](https://github.com/Fonta1n3/Plasma).

**How do I see what the app asks my node?**
Tap any home screen tile, or ⓘ on a transaction, for the raw RPC response. See
[How it works](./How-does-it-work.md).

**Which version am I running?**
At the bottom of **Settings**.

**How can I check the app is the open source code?**
[Build it from source](../Readme.md#build-from-source) and install it yourself.

**Something's wrong.**
See [Troubleshooting](./Troubleshooting.md), ask in the
[Telegram group](https://t.me/FullyNoded), or open a
[GitHub issue](https://github.com/Fonta1n3/FullyNoded/issues).
