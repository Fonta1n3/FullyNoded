# Tor Authentication
 - [On the device running FN](#On-the-device-running-FN)
 - [Tor V3 Authentication](#Tor-V3-Authentication)
 - [QuickConnect URL Scheme](#QuickConnect-URL-Scheme)
## On the device running FN
 - Now in Fully Noded go to `Settings` > `Node Manager` > `+` and add a new node by inputting your RPC credentials and copy and paste your onion address with the port at the end `qndoiqnwoiquf713y8731783rgd.onion:8332`.
 - You should never type (password) fields manually, just copy and paste between devices. Between Apple Mac, iphone and iPad, the clipboard will be synced as soon as you *put on bluetooth* on at least two of the devices. Once bluetooth is on on your mac and ipad then it should automatically paste over from the computer to iPad and back. Same should work for iPhone.
 - Add *mainnet*, *testnet*, *regtest net* and / or *lightning* at your convenience. You can run all three and connect to all three.

 - Restart Tor on your nodes computer `brew services restart tor`, and check that your node is **on**; that it's really running. Hard stop FN app on your device and reopen FN.
 - And you should be able to connect to your V3 hidden service from anywhere in the world with your node completely behind a firewall and no port forwarding
 
## Tor V3 Authentication

**THIS IS OPTIONAL** It ensures that even if an attacker got your `rpcport` hidden service's hostname and `bitcoin.conf` rpc creds (the quick connect QR) they would still not be able to access your node. For an explainer on how this generally works read [this](https://matt.traudt.xyz/p/FgbdRTFr.html)

##### Preparatory work:
First get your connection going. **Resolve the connection issue first then add the keypair**, to keep things simple. Some double checks ( A more extensive guide [here](./Readme.md#connecting-over-tor-macos)).

###### On your device running node
- Your node is running either mainnet, testnet or regtest
- Your node is **on**, it's really running (check that it's running)
- You've made the appropriate HiddenService -Dir, -Version and -Port declaration in your `torrc` file for at least the matching port (respectively 8332, 18332, 18443 and /or 1312).
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
I will happily share my entire RPC-url and -password with anyone, there is no way they can hack this Tor V3 auth, granted they can not get the private key obviously. Fully Noded creates the private key offline, encrypts it heavily and stores it in the most secure way possible.

## QuickConnect URL Scheme
Fully Noded has uri deep links registered with the following prefixes  `btcstandup://`, `btcrpc://` for connecting Bitcoin Core and `clightning-rpc://` for you guessed it C-Lightning.

If you are a node manufacturer you can embed such a link to your web based UI that allows a user who has Fully Noded installed on their device to add and connect to their node with a single tap from the web based UI.

The url can also be displayed as a QR Code and a user can simply scan it when they go to add a node in Fully Noded.

The format of the URI is:

`btcrpc://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>?label=<optional node label>`

Example with node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?label=Your%20Nodes%20Name`

Example without node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?`

For C-Lightning simply specify the correct prefix and FN will do the rest:<br/>
`clightning-rpc://rpcuser:rpcpassword@kjhfefe.onion:1312?label=BTCPay%20C-Lightning`
For more info on supporting c-lightning see [Lightning.md](./Docs/Lightning.md)

**The rpcuser and rpcpassword are the http-user (lightning by default) and http-pass you specify in the clightning config when using the supported c-lightning http [plugin](https://github.com/Start9Labs/c-lightning-http-plugin), 1312 is the HS port, again you may customize the port with http-port in the lightning config in conjunction with the http plugin.**

Fully Noded is compatible with V3 authenticated hidden services, the user has the option in the app to add a V3 private key for authentication.

## Security and Privacy

- All network traffic is encrypted by default using Tor.
- Fully Noded NEVER uses another server or uploads data or requires any data (KYC/AML) from you whatsoever, your node is the only back end to the app.
- Any sensitive data (seed words, credentials) the app saves onto the device locally is encrypted to AES standards and the encryption key is stored on the devices secure enclave (iCloud sync disabled). DYOR regarding iPhone security.
