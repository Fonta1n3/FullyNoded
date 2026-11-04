# Create a wallet

A Fully Noded wallet is split in two:

- **Your node** holds the public keys (descriptors) as a watch-only wallet. It finds your coins,
  shows balances and builds transactions.
- **Fully Noded** holds the seed words as a [signer](./Signers.md), encrypted on your phone. It
  signs transactions. Your node never sees a private key.

Open the **wallet tab** (₿) and tap **+**:

<img src="../Images/app-create-wallet.jpg" alt="Create Wallet" width="300"/>

## Single-sig

1. **Create single-sig**, then pick **Segwit (BIP84)** or **Taproot (BIP86)**.
2. Fully Noded makes 12 seed words and creates the wallet on your node.
3. **Write the words down** on paper, then tap **I saved them**. They are the only way to recover
   your bitcoin. See [Backups](./Backup-Wallets.md).

The new wallet is active right away:

<img src="../Images/app-wallet.jpg" alt="Wallet" width="300"/>

From here: [Invoice](./Receiving.md) to receive, [Send](./Sending.md) to pay, **UTXOs** for coin
control.

## Multi-sig

**Create multi-sig** opens the multisig creator:

<img src="../Images/app-multisig.jpg" alt="Multisig creator" width="300"/>

1. Pick **Segwit** or **Taproot**.
2. Add each cosigner: **Derive from signer** (a signer on this phone), scan a QR, paste, or type
   the fingerprint, path and xpub and tap **Add cosigner**.
3. Tap **Create wallet** and choose how many signatures are required to spend.
4. Save the wallet export it shows. A multisig can't be recovered without every cosigner's
   xpub, so this backup matters as much as the seeds.

## Import

| Option | For |
|---|---|
| **Import by pasting text** | Seed words, a descriptor, an xpub, or a Fully Noded backup |
| **Import a wallet file** | Coldcard (single and multisig), Electrum multisig, Unchained and Fully Noded backup files |
| **Import by scanning a QR code** | A wallet export QR (UR or JSON), e.g. from Specter or another Fully Noded |
| **Bitcoin Core Wallets** | Use a wallet that already exists on your node |

Importing seed words also adds them as a signer, so the wallet can spend. Importing public
keys only gives a watch-only wallet: sign elsewhere, or add the seed as a signer later.

## Switching wallets

Tap the icon next to **+** on the wallet tab to switch wallets. All your wallets are also
listed in **Settings → Saved Wallets**.
