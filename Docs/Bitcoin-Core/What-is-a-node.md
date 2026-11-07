# What is in a node?

To understand *FullyNoded* one needs to understand some basics of how Bitcoin Core itself works. In the below sections I will try and describe the basics in a concise way to help you understand *FullyNoded* and your own node a bit better and how to use them.

### The basics

Your node has all kinds of complex functionality built into it, I will only be explaining what your node is capable of as far as *Fully Noded* is concerned.

When you install Bitcoin Core you will notice a few different programs that you can use:

- `bitcoind`
- `bitcoin-cli`
- `bitcoin-qt`

`bitcoind` is the Bitcoin Core daemon. You can run this program and your node will just do everything it needs to do in the background without you ever noticing a thing. It will boot up, connect to peers and start validating transactions and communicating with its peers over the bitcoin p2p (peer to peer) network. Running a node is as simple as opening a terminal and typing `bitcoind` and just letting it run.

If you actually want to use your node you have the option of running `bitcoin-qt` instead of `bitcoind`, this is a graphical interface to Bitcoin Core and lets you utilize the Bitcoin Core wallet through a graphical user interface. It allows you to send and receive bitcoin, see your balances and utilize multiple wallets. It gives you direct access to your config files and the console where you can use some more advanced commands.

That brings us to `bitcoin-cli`, this is Bitcoin Core's `command line interface`, it is essentially the same thing as the console which can be accessed via `bitcoin-qt`, in order to use it you need to launch `bitcoind` first. With `bitcoin-cli` a user can simply open a terminal and start typing commands which get issued to `bitcoind`, if you are lucky and you type the command in correctly you will get a valid response from `bitcoind` about whatever command you just issued.

An example would be:

`bitcoin-cli getblockchaininfo`

which would return (shortened):

```
{
  "chain": "main",
  "blocks": 921042,
  "headers": 921042,
  "verificationprogress": 0.9999987,
  "pruned": false,
  "warnings": []
}
```

Anything you can do in `bitcoin-qt` you can do with `bitcoin-cli` and much more, `bitcoin-cli` really lets you have full access to the power of your node and all the information it can give you about the Bitcoin network.

**The killer app here is the ability to access your nodes functionality remotely.**

There are two completely separate realms of functionality that can be accessed remotely via your node. In order to speak to your node remotely you need a port to talk to. Bitcoin Core dedicates port 8333 to the peer to peer network and port 8332 is used for `rpc`.

`rpc` stands for `remote procedural call`, all you need to know is that it is a way to programmatically issue commands to your node so that it can give us information back or do things for us, like send bitcoins to a specified address.

`rpc` is the tool *Fully Noded* uses to issue commands to it and to get information from it.

Bitcoin Core's `rpc` port is designated as `8332` which we mentioned previously. When you issue commands to your node via `bitcoin-cli` you are actually issuing commands via `rpc` to port `8332` via your `localhost` or your computers local IP address `127.0.0.1`. So it is in its very nature designed to be accessed remotely via the `http` protocol but by default is setup to only allow your local computer to access the `rpc` port. In simple terms you can think of this as kind of like visiting a website, instead of typing http://www.bitcoincore.org into a web browser you are opening a terminal and issuing a command like http://username:password@127.0.0.1:8332.

In order to fully understand this we need to talk about your config file. Which can either be accessed via `bitcoin-qt` or by navigating into the bitcoin directory in your computers file system and finding a file called `bitcoin.conf`. In this conf file you set the RPC credentials (an `rpcauth=` line, or `rpcuser` and `rpcpassword`). They're needed for every remote command to your node. See [bitcoin.conf](./bitcoin-conf.md).

### Wallets

Bitcoin Core also has a wallet, and can load many wallets at once (`createwallet`, `loadwallet`,
`listwallets`). Modern Core wallets are **descriptor wallets**: they hold output descriptors,
which describe exactly which keys and scripts the wallet watches, e.g.
`wpkh([fingerprint/84h/0h/0h]xpub…/0/*)`.

A wallet can hold private keys, or only public keys (**watch-only**). Fully Noded uses watch-only
wallets: your node gets the public descriptors, so it can find your coins, track balances and
build transactions, while the private keys stay on your phone. See
[How it works](../How-does-it-work.md).
