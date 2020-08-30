# Tor V3 Authentication


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

