# Security - Best Practices

- As a start read our [Backup-Recovery-Best-Practices](https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Backup-Recovery-Best-Practices.md)

Fully Noded uses extremely defensive code to protect your data from attackers.

### 2FA (two factor authentication)

It is recommended to utilize `Sign in with Apple` as a form of 2fa for the application.
When enabled you will be prompted for 2FA wherever you go in the app that may cause
damage or loss of privacy.

To enable this feature: `Settings` > `Security` > `Enable 2FA`

This prevents an evil maid or disgruntled spouse from picking up your unlocked device
and wreaking havoc on your precious sats.

### Unlock password

It is recommended to always utilize the unlock password as simple pins and biometrics can be all too
easily used or brute forced.

To add a password: `Settings` > `Security` > `App unlock password`

It is recommended to use a 6 random words (half of a dummy signer) that you have saved offline somewhere.

The app password persists between app deletions. As does the timeout period between allowed attempts
at inputting the password. Fully Noded uses your keychain in a clever way to ensure your unlock password is impossible to brute force.

If you forget the unlock password you can tap the `reset app` button which will prompt your for 2fa
and only upon successful 2fa will allow you to delete the local data for the app and wipe the keychain.
This means your encrypted iCloud backup will still be intact and accessible if you have the original
encryption key for the backup.

***It is strongly recommended to use this password, it can prevent most any attacker from gaining access***

### Biometrics

It is recommended to keep biometrics *disabled* if you are concerned about any attacker
easily gaining access to your device and potentially your btc. It is far to easy
for an attacker to immobilize you and simply point your phone at your face to unlock it.

### iCloud Encryption

For hard core users or sticky situations it is advised to use a 12 word signer as an
encryption password for your encrypted iCloud backups. Save the 12 words offline!
Create the back up and delete your HODL wallet so it does not even exist on your
device, only recovering it when you *need* it.
