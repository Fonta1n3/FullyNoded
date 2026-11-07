# Backups and recovery: best practices

- **Write your seed words on paper or metal.** Never in a screenshot, photo, note or cloud file.
- **Keep more than one copy**, in different places.
- **Write down the passphrase too**, if you used one. Without it the words recover a different,
  empty wallet.
- **Back up multisig and timelocked wallets' descriptors** (wallet tab → ⓘ → **Backup file** or
  **Wallet export**). Seed words alone can't recover them.
- **Export a fresh backup file after adding a timelock**: Fully Noded reminds you.
- **Keep backup files private.** They hold no private keys but reveal all your coins.
- **Test your backup**: on testnet or with a small amount, remove the wallet and recover it
  ([Recovery](./Wallets/Recovery.md)).

Fully Noded doesn't back up to iCloud. Your signers are stored only on your phone, so if you
lose the phone or delete the app, your written-down seed words are how you get your bitcoin back.

How to back up: [Backup-Wallets.md](./Wallets/Backup-Wallets.md).
