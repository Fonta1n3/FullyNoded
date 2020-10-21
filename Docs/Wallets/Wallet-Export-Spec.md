# Wallet Export and Import - Account Map

Fully Noded utilizes a QR code (and .json file) aka "Account Map" to allow users to seamlessly export and import wallets. This also serves as a handy back up. The below description is a brief spec defining the scheme and the motivation so that others may incorporate it into their projects.

### Overview
A wallet export/import QR is a simple `json` serialized dictionary that consists of three parts;

1. `descriptor` - string, required. This is a Bitcoin Core compatible output descriptor which utilizes `h` to denote hardened path components and does not include a checksum.
2. `blockheight` - int, required. This is the blockheight which is associated with the first ever transaction or birthdate of the account. Client software should automatically initiate a rescan from this blockheight so that users may seamlessly view balances and transaction history when going importing accounts. If the birthdate is not known then a 0 can be used which will initiate a rescan from the genesis block.
3. `label` - string, required. This can be an empty string or consist of a user added  label for the account, so that end users may easily recognize what it is they are importing.
4. `watching` - array of strings, optional. In case the wallet has had anything imported into it or is watching other keys outside of the keypool then they can be added here as an array of descriptors. They follow the format of the `descriptor` yet nothing is assumed, we simply take the watching descriptors verbatim and import them as "watching" descriptors. This can be useful when recovering wallets using a single seed but multiple derivations or script types.

### Motivation
Recovering a wallet can be  a daunting task with little cross wallet compatibility. Bitcoin Core output descriptors are used so that there is no ambiguity between wallets and the account which is being recovered will derive the correct keys with certainty.

JSON was chosen as it is widely adopted and used in all programming languages, its simple to serialize and parse.

Wallet export/import QR's prove to be incredibly useful especially in the case of multi signature wallets, a huge amount of information is easily and unambiguously accessed. It allows users to easily back up all of their public keys and scripts which are needed to recreate multi signature accounts. This is of course made possible by Bitcoin Core output descriptors which you can read more about [here](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md).

### Change keys
Client side software needs to deduce the how the change keys will be derived from the supplied descriptor. As a general guideline Fully Noded will parse the `descriptor` to see if it contains `/0/*`, which denotes receive keys. *Fully Noded* automatically generates a change descriptor by simply replacing `/0/*` with `/1/*`. Users ought to be warned if they are not utilizing a standard extended key descriptor as the client side software will have no way of knowing with certainty how to derive change keys if the supplied descriptor is not HD and does not include `/0/*`.

### Examples

1. Single sig, testnet, BIP84 account

- JSON:
```
{
"descriptor":
"wpkh([c258d2e4\/84h\/1h\/0h]tpubDD3ynpHgJQW8VvWRzQ5WFDCrs4jqVFGHB3vLC3r49XHJSqP8bHKdK4AriuUKLccK68zfzowx7YhmDN8SiSkgCDENUFx9qVw65YyqM78vyVe\/0\/*)",
"blockheight":1782088,
"label":"testnet"
}
```
- Plain text:
```
"descriptor":
"wpkh([c258d2e4/84h/1h/0h]tpubDD3ynpHgJQW8VvWRzQ5WFDCrs4jqVFGHB3vLC3r49XHJSqP8bHKdK4AriuUKLccK68zfzowx7YhmDN8SiSkgCDENUFx9qVw65YyqM78vyVe/0/*)",
"blockheight":1782088,
"label":"testnet"
```

- QR (json serialized):
<img src="./Images/single_sig_map.png" alt="" width="400"/>

2. Multi sig, testnet, BIP67, m48', p2wsh, 2 of 3 account

- JSON:
```
{
"descriptor":"wsh(sortedmulti(2,[119dbcab\/48h\/1h\/0h\/2h]tpubDFYr9xD4WtT3yDBdX2qT2j2v6ZruqccwPKFwLguuJL99bWBrk6D2Lv1aPpRbFnw1sQUU9DM7ScMAkPRJqR1iXKhWMBNMAJ45QCTuvSZbzzv\/0\/*,[e650dc93\/48h\/1h\/0h\/2h]tpubDEijNAeHVNmm6wHwspPv4fV8mRkoMimeVCk47dExpN9e17jFti12BdjzL8MX17GvKEekRzknNuDoLy1Q8fujYfsWfCvjwYmjjENUpzwDy6B\/0\/*,[bcc3df08\/48h\/1h\/0h\/2h]tpubDFLAjoM9CeEsvZp3UEakCW9jGpx1MgVJP9eteh8Qyr8XN9ASDJoMz58D5YNqm4oRbuBr5LFjfzv6SzsQYUPNWHHYUxvsPimak1tU3cMUhqv\/0\/*))",
"blockheight":1781992,
"label":"warm test"
}
```

- Plain text:
```
{
"descriptor":"wsh(sortedmulti(2,[119dbcab/48h/1h/0h/2h]tpubDFYr9xD4WtT3yDBdX2qT2j2v6ZruqccwPKFwLguuJL99bWBrk6D2Lv1aPpRbFnw1sQUU9DM7ScMAkPRJqR1iXKhWMBNMAJ45QCTuvSZbzzv/0/*,[e650dc93/48h/1h/0h/2h]tpubDEijNAeHVNmm6wHwspPv4fV8mRkoMimeVCk47dExpN9e17jFti12BdjzL8MX17GvKEekRzknNuDoLy1Q8fujYfsWfCvjwYmjjENUpzwDy6B/0/*,[bcc3df08/48h/1h/0h/2h]tpubDFLAjoM9CeEsvZp3UEakCW9jGpx1MgVJP9eteh8Qyr8XN9ASDJoMz58D5YNqm4oRbuBr5LFjfzv6SzsQYUPNWHHYUxvsPimak1tU3cMUhqv/0/*))",
"blockheight":1781992,
"label":"warm test"
}
```

- QR (json serialized):
<img src="./Images/msig_map.png" alt="" width="400"/>

### Supported by
- [Gordian Wallet](https://testflight.apple.com/join/RNvBmjB3)
- [Specter-Desktop](https://github.com/cryptoadvance/specter-desktop)
- [Fully Noded](https://apps.apple.com/us/app/fully-noded/id1436425586)
- [Magical Bitcoin Wallet](https://github.com/MagicalBitcoin/magical-bitcoin-wallet)
