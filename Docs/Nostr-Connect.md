# Nostr Connect

**The fast way to connect Fully Noded to your node.** Fully Noded talks to Bitcoin Core through
[Fully Noded Server](https://github.com/Fonta1n3/FullyNoded-Server) over a nostr relay instead of
Tor. There's no onion circuit to build, so the home screen loads in about a second, at home, over a
VPN like Tailscale, or anywhere through a public relay.

Your node's RPC is never exposed: every request and response is end-to-end encrypted between this
phone and your server, and the relay only passes on ciphertext.

## How it works

```
Fully Noded  ──encrypted event──▶  nostr relay  ──▶  Fully Noded Server  ──RPC──▶  Bitcoin Core
             ◀──encrypted event──              ◀──                      ◀──────
```

1. **Pairing.** Fully Noded Server gives each phone its own key in a one-time pairing link
   (`nostr+fullynoded://…`, shown as a QR). The link holds the server's public key, the relay
   address(es), the phone's secret key, and the network.
2. **A request.** When Fully Noded calls your node (say `getblockchaininfo`), it encrypts the
   JSON-RPC request to the server's key with **NIP-44 v2**, signs it (BIP340), and publishes it as an
   **ephemeral** nostr event (kind `28388`). Relays forward ephemeral events and never store them.
   Large requests (a big PSBT) are compressed and split into numbered ~24 KB frames, so every
   event fits the size limit of public relays.
3. **The server.** Fully Noded Server listens on the relay, decrypts the request, checks it came
   from a paired phone, passes it to your local Bitcoin Core, and sends the encrypted answer back
   the same way.

**What a relay can see:** that two keys exchanged messages, and when. Never what they said.

**Encrypted connections.** With **Encrypt connections (wss://)** on in Fully Noded Server (the
default for new setups), the Mac's relay also uses TLS with a certificate it made for itself. Its
fingerprint is in the pairing link, so Fully Noded accepts exactly that certificate, and others on
your network can't even see which keys are talking. The node's page shows the pinned certificate.

**Who can use your node:** only paired phones. Fully Noded Server keeps just each phone's public key,
so removing a pairing cuts that phone off for good. Its built-in relay only accepts events from
paired phones.

## Set it up

### 1. In Fully Noded Server (Mac)

Open **Nostr Connect** in the sidebar.

- **At home or over a VPN:** turn on **Run a relay on this Mac** (port 7777 by default). Its local
  network address is listed, and so is a Tailscale/VPN address if you have one, so the phone can
  reach the relay wherever the VPN works. macOS may ask once whether Fully Noded Server may accept
  incoming connections: allow it.
- **Encrypt connections (wss://)** (on by default for new setups, macOS 15 or later): the Mac's
  relay uses TLS with a certificate it made for itself, and the pairing link pins it. Leave it on
  unless you have a reason not to.
- **Away from home without a VPN:** under **Relays the bridge listens on**, add a public relay
  (`wss://…`), or give the Mac's relay an outside address (ngrok, or a router port forward).
- Choose the **network**, then tap **Pair Fully Noded**. A QR appears, shown once.

Add or change relays, and choose wss:// or ws://, *before* pairing: the link only includes the
relays and certificate set up at the time. If you change them later, pair again.

### 2. In Fully Noded (iPhone)

- **New install:** in the welcome guide, choose **Nostr Connect** and scan the QR.
- **Any time:** Settings › **Node Manager** › **+** › **Scan QR**, and scan it.

Fully Noded recognises the link, saves the node as **NOSTR** and makes it active. Pull down on the
home screen to load it.

The node's page shows its relays, network, the server's key and the **relay certificate** (pinned,
with its SHA-256, when the Mac's relay uses wss://), with **Re-pair** to scan a new link and
**Copy relay**. There's no RPC password to manage: the pairing replaces it.

## Tips and troubleshooting

- **Nothing loads at home:** check the phone is on the same network as the Mac (or on the VPN), and
  that **Run a relay on this Mac** is on. If you added Tailscale after pairing, pair again so the
  link includes the VPN address.
- **Works at home but not away:** the link only has your Mac's local address. Add a public relay
  or an outside address in Fully Noded Server and pair again.
- **"Couldn't reach a Nostr Connect relay":** the relay in the link is down or unreachable. Re-pair
  with a relay that works.
- **Stopped connecting after changing "Encrypt connections":** switching between wss:// and ws://
  changes the relay's addresses. Pair the phone again.
- **TLS refused for the Mac's relay** (shown in the debug log): the certificate isn't the one in the
  pairing link, which happens if the Mac's relay certificate changes. Pair again.
  Fully Noded never accepts a different certificate for that relay.
- **A lost or old phone:** remove it from **Paired devices** in Fully Noded Server. It can't connect
  again without a new pairing.
- **Tor still works:** Nostr Connect is an alternative, not a replacement. You can keep a Tor
  (Quick Connect) node and a Nostr Connect node for the same server and switch in Node Manager.

## Technical summary

| | |
|---|---|
| Transport | NIP-01 over WebSocket: `wss://` to the Mac's relay with its pinned self-signed certificate (or `ws://` if encryption is off), `wss://` with normal TLS to public relays |
| Encryption | NIP-44 v2 (secp256k1 ECDH, ChaCha20, HMAC-SHA256) |
| Signatures | BIP340 Schnorr |
| Event kind | `28388` (ephemeral) addressed with a `p` tag |
| Payload | JSON-RPC body, DEFLATE-compressed when that helps, base64 in numbered 24,000-character frames (each event under ~40 KB) |
| Delivery | The server acks a complete request; with no ack or answer the phone resends it (duplicates are ignored, or answered from the stored reply). Either side asks for missing frames; relay rate limits are retried with backoff |
| Pairing link | `nostr+fullynoded://<server pubkey>?relay=<url>[&relay=…]&secret=<client key>[&label=…][&chain=…][&cert=<sha256>]` |
