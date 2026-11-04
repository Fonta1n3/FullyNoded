# Quick Connect QR

Fully Noded adds a node from a single link, scanned as a QR (**Settings → Node Manager → + →
Scan QR**) or tapped on the phone.

## `btcrpc://`: connect over Tor or your network

```
btcrpc://<rpcuser>:<rpcpassword>@<host>:<port>?label=<optional label>
```

Example:

```
btcrpc://fullynoded:aStrongPassword@abc…xyz.onion:8332?label=My%20Node
```

- `host` is an onion address, or a LAN address or hostname.
- `port` is the RPC port (`8332` mainnet, `18332` testnet3, `48332` testnet4, `38332` signet,
  `18443` regtest).
- URL-encode the label. Keep the username and password to letters and numbers, so the link stays
  valid.

If you make node software, show this link as a QR (or a tappable link on iOS) so your users can
connect in one step. `btcstandup://` is accepted as an older name for the same format.

## `nostr+fullynoded://`: Nostr Connect

Pairing links made by Fully Noded Server's **Nostr Connect → Pair Fully Noded**. Each one is
single-use and holds a key for one phone. See [Nostr-Connect.md](./Nostr-Connect.md).

**Treat both kinds of link like a password**: anyone who has one can use your node.
