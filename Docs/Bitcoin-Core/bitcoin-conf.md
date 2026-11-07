# bitcoin.conf

Fully Noded only needs your node's RPC server on, and a user it can log in with.

`bitcoin.conf` is in your node's data folder:

- macOS: `~/Library/Application Support/Bitcoin/bitcoin.conf`
- Linux: `~/.bitcoin/bitcoin.conf`
- Windows: `%LOCALAPPDATA%\Bitcoin\bitcoin.conf`

```
# Accept RPC commands
server=1

# The line Fully Noded shows when you add a node (Node Manager → + → Manually → RPC auth → Copy).
# It stores a salted hash, never the password itself.
rpcauth=FullyNoded:<salt>$<hash>

# Optional. A pruned node works with Fully Noded too.
# prune=1000

# Optional: faster initial sync, set to about half your RAM in MB.
# dbcache=4000
```

Restart your node after editing it.

Prefer a plain username and password? Use `rpcuser=` and `rpcpassword=` instead of `rpcauth=`,
and type the same values into Fully Noded. Letters and numbers only.

Your node only accepts RPC from the same computer by default, which is what Tor and Fully Noded
Server need. To connect over your local network, also add `rpcbind=` and `rpcallowip=` for that
network (for example `rpcbind=0.0.0.0` and `rpcallowip=192.168.1.0/24`), and only on a network you
trust.
