# Join Market

## Setup Guide

### Installation
- the below commands are meant to be made in a terminal, this guide only works for macos and Linux
- download the project `git clone https://github.com/JoinMarket-Org/joinmarket-clientserver`
- make sure to check the signature in git using `git log --show-signature`
- if you are on macos make sure you have Homebrew and Xcode command line tools
- for homebrew `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- for Xcode command line tools `xcode-select --install`
- ensure you are in the `joinmarket-clientserver` directory in a terminal
- `./install.sh` (follow instructions on screen; provide sudo password when prompted, you can opt out of installing the QT/GUI dependencies as FN does not need them)

### Setup the wallet daemon
- first you need to create an ssl cert if one does not already exist and save it in your JM data directory (usually HOME/user/.joinmarket/ssl)
- `cd /HOME/user/.joinmarket`
- `mkdir ssl`
- `cd ssl`
- `openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -sha256 -days 365`
- when prompted just press enter to leave answers blank, when asked for a FQDN or domain just type in `localhost`

### Start the wallet daemon
- start the JM virtual env with `source jmvenv/bin/activate`
- `cd scripts`
- `python jmwalletd.py`
- enter the password you used to create the cert with

### Configure Tor
- open your `torrc` file, usually located at `/etc/tor/torrc`
- add the following to it and save it:
    ```
    HiddenServiceDir /HOME/user/hidden_services/jmwalletd (any path where you want your tor hostname to be saved for the jmwalletd)
    HiddenServiceVersion 3
    HiddenServicePort 28183 127.0.0.1:28183
    ```
- restart tor

🎉 Congrats you've done the hard part!

### Add your JM node to Fully Noded
- In FN add a node manually, it needs the cert you created and the tor hostname
- to get the cert text: `cat /HOME/user/.joinmarket/ssl/cert.pem`
- to get the hostname: `cat /HOME/user/hidden_services/jmwalletd/hostname`
- paste the cert
- paste the address which is the hostname and port: `yourhostname.onion:28183`
- tap done
- ensure you have an onchain node activated then attempt to activate your new JM node

🚀 That's it! You can now access JM with all the power of a FN wallet and so much more!

## Usage

Fully Noded allows you to either create a new JM wallet or use an existing wallet. If using an existing wallet that has not yet been seen by FN you will need to 
input the lock/unlock password that you used to create the JM wallet with.

All JM functionality in FN is accessed in the UTXO view. Your non JM wallets will show a mix button on each utxo. If you have added a JM node you can use this button
to sweep the utxo to a JM wallet, if no JM wallet exists on FN it will prompt you to first create or recover an JM wallet. If a JM wallet exists it will simply fetch a deposit address 
from that JM wallet and present the transaction creator as normal.

During the insitial JM wallet creation/recovery process it encrypts and saves the seed words locally on FN to ensure FN can always spend
from your JM wallet. **Fully Noded can not spend Fidelity Bonds on its own, only JM can do that.** 

Now you have a FN/JM wallet which can be used just like any other FN wallet, even if you lose your JM server.

After activating the newly created JM wallet and navigating to your UTXO view FN will start communicating with your JM server, from that point you can start/stop the maker, create or
spend from a Fidelity Bond, do direct sends or create a coinjoin transaction by tapping the mix button.

JM coin selection depends upon you freezing utxos you do not want spent, you must do this in JM itself. In FN full coin selection works as normal but not for coinjoin transactions, they
must be direct sends whereby you sweep one utxo to another address.

For the above reason JM coinjoin transactions are limited to mix depths in the FN UI. FN will determine the lowest mixdepth that holds a balance and offer you as the default mixdepth to
join from, you may also specify a mix depth to join from manually. Once you have chosen the mix depth to join from you will be presented with the transaction creator as normal, just add 
an address and amount, for best privacy sweep the entire amount to avoid change.

In order to be a successful maker you need to create a (Fidelity Bond)[], just tap the bitcoin button in the top bar to create one, you will need to select a date of expiry. This utxo
will not be able to be spent until the first if that month at midnight. **Only Join Market can spend this utxo! Ensure you have the JM wallet backed up incase something goes wrong.**

Useful resources:
- [Joinmarket API](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/JSON-RPC-API-using-jmwalletd.md)
- [Fidelity Bonds](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/fidelity-bonds.md)
- [General usage](https://github.com/JoinMarket-Org/joinmarket-clientserver/blob/master/docs/USAGE.md)
- [Best practices](https://github.com/openoms/bitcoin-tutorials/blob/master/joinmarket/joinmarket_private_flow.md)



