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

which would return:

```
{
  "chain": "main",
  "blocks": 316384,
  "headers": 619407,
  "bestblockhash": "00000000000000002402a9e247679cc177145d032a8342eb68662c7e8867284b",
  "difficulty": 19729645940.57713,
  "mediantime": 1408415880,
  "verificationprogress": 0.08531021486557458,
  "initialblockdownload": true,
  "chainwork": "0000000000000000000000000000000000000000000131ca6208627d8b7677bb",
  "size_on_disk": 25477883056,
  "pruned": false,
  "softforks": {
    "bip34": {
      "type": "buried",
      "active": true,
      "height": 227931
    },
    "bip66": {
      "type": "buried",
      "active": false,
      "height": 363725
    },
    "bip65": {
      "type": "buried",
      "active": false,
      "height": 388381
    },
    "csv": {
      "type": "buried",
      "active": false,
      "height": 419328
    },
    "segwit": {
      "type": "buried",
      "active": false,
      "height": 481824
    }
  },
  "warnings": ""
}
```

Anything you can do in `bitcoin-qt` you can do with `bitcoin-cli` and much more, `bitcoin-cli` really lets you have full access to the power of your node and all the information it can give you about the Bitcoin network.

**The killer app here is the ability to access your nodes functionality remotely.**

There are two completely separate realms of functionality that can be accessed remotely via your node. In order to speak to your node remotely you need a port to talk to. Bitcoin Core dedicates port 8333 to the peer to peer network and port 8332 is used for `rpc`.

`rpc` stands for `remote procedural call`, all you need to know is that it is a way to programmatically issue commands to your node so that it can give us information back or do things for us, like send bitcoins to a specified address.

`rpc` is the tool *Fully Noded* uses to issue commands to it and to get information from it.

Bitcoin Core's `rpc` port is designated as `8332` which we mentioned previously. When you issue commands to your node via `bitcoin-cli` you are actually issuing commands via `rpc` to port `8332` via your `localhost` or your computers local IP address `127.0.0.1`. So it is in its very nature designed to be accessed remotely via the `http` protocol but by default is setup to only allow your local computer to access the `rpc` port. In simple terms you can think of this as kind of like visiting a website, instead of typing http://www.bitcoincore.org into a web browser you are opening a terminal and issuing a command like http://username:password@127.0.0.1:8332.

In order to fully understand this we need to talk about your config file. Which can either be accessed via `bitcoin-qt` or by navigating into the bitcoin directory in your computers file system and finding a file called `bitcoin.conf`. In this conf file you can set an `rpcpassword` and `rpcusername`. You need to input these credentials into the `http` command whenever making remote commands to your node.

### Wallets

Bitcoin Core includes its own wallet functionality which again can be accessed via `bitcoin-qt` or `bitcoin-cli`.

By default your node has a `default` wallet enabled. This is a nameless wallet and can usually be found in the bitcoin directory on your computer as a `wallet.dat` file. By default the default wallet generates 2,000 keys (1,000 primary keys and 1,000 change keys). If you use `bitcoin-qt` this is the wallet you will be interacting with, it holds all the private keys for the wallet. You can send and receive to it, fetch balances and do anything you would need to do with a bitcoin wallet. Bitcoin Core does not work with addresses, you need to think of your wallet as holding keys, these are either private keys for a hot wallet or public keys for a cold wallet. Bitcoin Core has the ability to convert any public key into any format of address you would want to use, e.g. bech32 (bc1), nested segwit (3) or legacy (1) addresses. This is an important distinction to make as many people get confused with different wallet types, its important to just keep in mind your node can create any type of address for any public key it holds.

This is why in FullyNoded you can select an "invoice address format" in the "Incomings" section.

Besides the default wallet Bitcoin Core also includes `multiwalletrpc` functionality. Meaning you can create and use as many wallets as you want. The `bitcoin-cli createwallet` command is a powerful one. Here is the help text straight from Bitcoin Core:

```
createwallet "wallet_name" ( disable_private_keys blank "passphrase" avoid_reuse )

Creates and loads a new wallet.

Arguments:
1. wallet_name             (string, required) The name for the new wallet. If this is a path, the wallet will be created at the path location.
2. disable_private_keys    (boolean, optional, default=false) Disable the possibility of private keys (only watchonlys are possible in this mode).
3. blank                   (boolean, optional, default=false) Create a blank wallet. A blank wallet has no keys or HD seed. One can be set using sethdseed.
4. passphrase              (string) Encrypt the wallet with this passphrase.
5. avoid_reuse             (boolean, optional, default=false) Keep track of coin reuse, and treat dirty and clean coins differently with privacy considerations in mind.

Result:
{
  "name" :    <wallet_name>,        (string) The wallet name if created successfully. If the wallet was created using a full path, the wallet_name will be the full path.
  "warning" : <warning>,            (string) Warning message if wallet was not loaded cleanly.
}

Examples:
> bitcoin-cli createwallet "testwallet"
> curl --user myusername --data-binary '{"jsonrpc": "1.0", "id":"curltest", "method": "createwallet", "params": ["testwallet"] }' -H 'content-type: text/plain;' http://127.0.0.1:8332/
```

As you can see you can name your wallet, encrypt it and create different wallet types.

This is useful if you do not want to create a hot wallet on your node and prefer to use cold storage or multi-sig or if you want to be in complete control over which keys your wallet holds which should be the case if you are importing keys into your node as a watch-only wallet.
