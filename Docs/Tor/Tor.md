# Tor setup

To reach your node over Tor, your node's computer runs a Tor **hidden service** that forwards an
onion address to your node's RPC port. Fully Noded has Tor built in, so nothing is needed on the
phone.

Fully Noded keeps its Tor traffic on separate circuits: your node, exchange rates, payjoin and
Esplora each use their own, so a relay or server that sees one can't link it to the others.

Every third-party service it uses is an onion service: exchange rates from mempool.space's onion
(USD, EUR, GBP, CAD, CHF, AUD and JPY), and Esplora from mempool.space's onion, or your own Esplora
onion if you set one in Settings ▸ Esplora. Requests say nothing about your device: no app name or version, iOS
version or language.

While the active node is an onion, Fully Noded goes further, automatically: Tor connects only to
onion services, never through an exit relay to a clearnet site, and a payjoin is only tried with
receivers that have an onion. A local, LAN or Nostr Connect node isn't affected.

[Fully Noded Server](https://github.com/Fonta1n3/FullyNoded-Server) does all of this for you on a
Mac. To do it by hand:

## 1. Install Tor

- **macOS**: `brew install tor` ([Homebrew](https://brew.sh))
- **Debian / Ubuntu**: `sudo apt install tor`
- **Windows**: download the Tor Expert Bundle from
  [torproject.org](https://www.torproject.org/download/tor/) and unzip it to `C:\Tor`

## 2. Add a hidden service

Open your `torrc`:

- macOS: `$(brew --prefix)/etc/tor/torrc` (copy `torrc.sample` there if it doesn't exist)
- Linux: `/etc/tor/torrc`
- Windows: create `C:\Tor\torrc`

Add these lines (mainnet shown; use your network's RPC port, e.g. `18443` on regtest):

```
HiddenServiceDir <folder>/fullynoded/
HiddenServicePort 8332 127.0.0.1:8332
```

where `<folder>` is:

- macOS: `$(brew --prefix)/var/lib/tor` (write out the full path, e.g. `/opt/homebrew/var/lib/tor`)
- Linux: `/var/lib/tor`
- Windows: `C:/Tor`

## 3. Start Tor

- macOS: `brew services restart tor`
- Linux: `sudo systemctl restart tor`
- Windows (PowerShell as admin): `C:\Tor\tor.exe --service install -options -f C:\Tor\torrc`,
  then `C:\Tor\tor.exe --service start`

## 4. Get your onion address

Tor writes it to the `hostname` file in the folder you chose:

```
cat /opt/homebrew/var/lib/tor/fullynoded/hostname   # macOS (Apple silicon)
sudo cat /var/lib/tor/fullynoded/hostname           # Linux
```

In Fully Noded, [add the node](../Bitcoin-Core/Connect.md#adding-a-node-manually) with that
address plus the port, e.g. `abc…xyz.onion:8332`.

Optional, but recommended: [Tor authentication](./Authentication.md), so only your phone can use
the onion address.

## Not working?

- Check Tor's log: `sudo journalctl -u tor@default -n 40` (Linux), or
  `tail $(brew --prefix)/var/log/tor.log` if you set a log file (macOS).
- On Linux, the hidden service folder must belong to the Tor user (`debian-tor`) with mode `700`.
- See [Troubleshooting](../Troubleshooting.md).
