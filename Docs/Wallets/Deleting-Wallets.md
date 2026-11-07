# Remove a wallet

Wallet tab → ⓘ → 🗑 (top right) → **Remove**.

This only makes Fully Noded forget the wallet. It is **not** deleted:

- **Your node keeps it.** Re-add it any time with **+ → Bitcoin Core wallets**, or by recovering
  from the seed or a backup (Fully Noded finds the existing node wallet).
- **The signer stays** in the Signers tab. Delete the seed words there separately, only if you
  have them backed up.

## Deleting it from your node

Fully Noded can't delete a wallet from your node. To do that, unload it and delete its folder
from your node's `wallets` directory:

- macOS: `~/Library/Application Support/Bitcoin/wallets`
- Linux: `~/.bitcoin/wallets`
- Windows: `%LOCALAPPDATA%\Bitcoin\wallets`

The folder's name is the wallet's file name, shown on the wallet detail screen (wallet tab → ⓘ),
for example `FullyNoded-0f35aa52…`.

**Only delete it if you have the seed words and a backup.**
