# Join Market

## Wallet creation

#### Single-sig wallets 

* BIP84 account for deriving the primary descriptors (invoice address generation and change)
* Join Market native segwit standard 5 mixdepth accounts (0 to 4)
* Utxos on the BIP84 keys will have a `mix` button which allows you to deposit to external addresses for any JM mixdepth

WIP
* Confirmation of a utxo on external deposit address will trigger...
* This is clearly better suited for desktop environments as the taker bot will run on the device
* If using a mobile device plug it in and disable auto lock


Example `bitcoin-cli` command for new Fully Noded single sig default wallet:

```
{"jsonrpc":"1.0","id":"80758B3E-CEF0-4330-A2E4-49D29F553C74","method":"importdescriptors","params":[[{"desc": "wpkh([e15fb5b0/84'/1'/0']tpubDCw9rnRn7vdJGRLHxc67Keq4NUqFLbWpRxMsBf9YFvstLjJkis2pdNsPwAAA25zGLYrkRHDEjZ2DJhxK9qFiFJQf7P7qLSdHYunUpQZtgLa/0/*)#mu3n5jxf", "active": true, "range": [0,2500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/84'/1'/0']tpubDCw9rnRn7vdJGRLHxc67Keq4NUqFLbWpRxMsBf9YFvstLjJkis2pdNsPwAAA25zGLYrkRHDEjZ2DJhxK9qFiFJQf7P7qLSdHYunUpQZtgLa/1/*)#2g5jf8k3", "active": true, "range": [0,2500], "next_index": 0, "timestamp": "now", "internal": true}, {"desc": "wpkh([e15fb5b0/0/0]tpubDBbCP4LCwv2oyomaDcPMSEk7twZ4YTZ84a9YACUSgbMnAPUmMtWgucRLJiqYqJF12MaQBj177wDTYVSzSkv1eyFJuK2neqNWzb9vDw8X5Sw/0/*)#a42mvpmy", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/0/0]tpubDBbCP4LCwv2oyomaDcPMSEk7twZ4YTZ84a9YACUSgbMnAPUmMtWgucRLJiqYqJF12MaQBj177wDTYVSzSkv1eyFJuK2neqNWzb9vDw8X5Sw/1/*)#vp0635tu", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": true}, {"desc": "wpkh([e15fb5b0/0/1]tpubDBbCP4LCwv2p2YaZezC3bNAWhJAMxYfqWhtQ9ZURqoZEduVA4K2zHuaiZDZprCVBzK7wD1g9soRUPJ72N9geerQdQTiZhWS9cP5ecmQ77n3/0/*)#vlperyly", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/0/1]tpubDBbCP4LCwv2p2YaZezC3bNAWhJAMxYfqWhtQ9ZURqoZEduVA4K2zHuaiZDZprCVBzK7wD1g9soRUPJ72N9geerQdQTiZhWS9cP5ecmQ77n3/1/*)#atyc730u", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": true}, {"desc": "wpkh([e15fb5b0/0/2]tpubDBbCP4LCwv2p3Co7G9qCCeb3BiGNrVb7mqXuxoGpxvZzRD8uCgGKXihMGghRVes7Ap4KP3bZK2qeJRgUA1uSwKbFNQDjGhtD1Zc1g6or2i3/0/*)#t030xyh8", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/0/2]tpubDBbCP4LCwv2p3Co7G9qCCeb3BiGNrVb7mqXuxoGpxvZzRD8uCgGKXihMGghRVes7Ap4KP3bZK2qeJRgUA1uSwKbFNQDjGhtD1Zc1g6or2i3/1/*)#6m5wm38l", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": true}, {"desc": "wpkh([e15fb5b0/0/3]tpubDBbCP4LCwv2p79hw74vN9EM7GTDwkEibPoTFwAwe2h7sERPdrATMXv3bMQ1HWebtRzk7Kjz1yHWnUDyvHftEy1AR15uE2bn5Nmqx8jeYq8R/0/*)#3cu9u32t", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/0/3]tpubDBbCP4LCwv2p79hw74vN9EM7GTDwkEibPoTFwAwe2h7sERPdrATMXv3bMQ1HWebtRzk7Kjz1yHWnUDyvHftEy1AR15uE2bn5Nmqx8jeYq8R/1/*)#qveypy6n", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": true}, {"desc": "wpkh([e15fb5b0/0/4]tpubDBbCP4LCwv2p9ihQnbevHgEP7exoHXVeS6JNjkYk1YfvetaYLxop2RFxurbbac6tm7nf1kSt9dow4m9wKsTrEx5xHgkozw7rb1PeiTA8HF7/0/*)#7j5up4xr", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": false}, {"desc": "wpkh([e15fb5b0/0/4]tpubDBbCP4LCwv2p9ihQnbevHgEP7exoHXVeS6JNjkYk1YfvetaYLxop2RFxurbbac6tm7nf1kSt9dow4m9wKsTrEx5xHgkozw7rb1PeiTA8HF7/1/*)#0x3auqkm", "active": false, "range": [0,500], "next_index": 0, "timestamp": "now", "internal": true}]]}
```
