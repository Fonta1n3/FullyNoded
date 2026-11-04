# Troubleshooting

## Can't connect

1. **Is your node running** and fully started? Check it on the computer.
2. **Check the node's details** (Settings → Node Manager → ✎):
   - the address has the right port (`8332` mainnet, `18332` testnet3, `48332` testnet4,
     `38332` signet, `18443` regtest)
   - the RPC username and password match `bitcoin.conf`, and you restarted your node after
     adding the `rpcauth=` line
3. **Over Tor**: wait for **Tor connected** on the home screen (the first connection can take a
   minute). Restart Tor on your node, then force quit and reopen Fully Noded.
4. **With Tor authentication** on: the public key from Fully Noded must be in the hidden service's
   `authorized_clients` folder, then restart Tor. See [Tor authentication](./Tor/Authentication.md).
5. **On your local network**: your node must accept RPC from your network (`rpcbind`,
   `rpcallowip`, see [bitcoin.conf](./Bitcoin-Core/bitcoin-conf.md)).
6. **Nostr Connect**: Fully Noded Server must be running and paired. Re-pair from the node's
   details if needed.

## Balance or history missing

- **After a recovery or import** your node is rescanning. Wait, then pull down to refresh.
- **Pruned node**: coins older than your node's pruned blocks can't be found by a rescan.
- **Silent payments** only show once Fully Noded Server's scanner finds them
  ([SilentPayments.md](../SilentPayments.md)).
- **Wrong wallet**: check which wallet is active (wallet tab → switch).

## Can't sign

- The wallet's seed words must be in the Signers tab, with the right passphrase.
- Hardware wallet or multisig cosigner? Export the PSBT and sign it there.

## Still stuck?

Tap a home screen tile to see your node's raw response, and ask in the
[Fully Noded Telegram group](https://t.me/FullyNoded) or open a
[GitHub issue](https://github.com/Fonta1n3/FullyNoded/issues).
