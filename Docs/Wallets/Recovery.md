# Recover a wallet

Wallet tab → **+** → **Import by pasting text** (copy what you want to recover first). Fully Noded
recognises:

| Pasted | Result |
|---|---|
| **BIP39 seed words** | Choose **Segwit** or **Taproot** single-sig. Check the first addresses it shows, then tap **Create Wallet**. The words are also saved as a signer, so the wallet can spend. |
| **A backup file's text** | Every descriptor in the backup is imported, including timelocks. |
| **A descriptor or xpub** | A watch-only wallet. Add the seed as a [signer](./Signers.md) to spend. |

Or use **Import a wallet file** / **Import by scanning a QR code** with a backup file or a wallet
export QR.

## What happens on your node

- If the wallet still exists on your node (same seed, same type), Fully Noded uses it, with its
  history and labels.
- Otherwise it creates the wallet on your node and starts a **rescan**, so balances and history
  can take a while to appear. On a pruned node, the rescan only goes back as far as your node has
  blocks.

To rescan again later: wallet tab → ⓘ → **Rescan**.

## Recovering anything else

Any key your node can watch can be imported as a descriptor. For example, an account at a
different path:

```
wpkh([fingerprint/84h/0h/5h]xpub…/0/*)
```

See Bitcoin Core's [descriptor docs](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md).
Fully Noded's signers sign for any path, as long as the seed matches.
