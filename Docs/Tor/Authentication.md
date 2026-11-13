# Tor authentication

Optional, recommended. With Tor client authorization (v3 auth), your node's onion address only
answers devices that hold a key you've authorized. Even someone with your onion address and RPC
password can't connect.

**Get your connection working first**, then add authentication.

## Steps

1. In Fully Noded: **Settings → Security Center → V3 Authentication Key**, then tap **Refresh**
   to make a key pair. The private key stays on your phone.
2. Copy the public key. It looks like `descriptor:x25519:PHK2DF…`.
3. On your node's computer, save it as a file in the hidden service's `authorized_clients`
   folder, e.g.:

   ```
   sudo nano /var/lib/tor/fullynoded/authorized_clients/fullynoded.auth
   ```

   Paste the public key exactly as copied, on one line.
4. Restart Tor on the node (`sudo systemctl restart tor` or `brew services restart tor`).
5. Force quit and reopen Fully Noded.

From now on, only devices whose public keys are in `authorized_clients` can reach the onion
address. To add another device, add its key as another `.auth` file.

**Careful:** making a new key pair in Fully Noded replaces the old one. Add the new public key to
your node, or you'll lose access over Tor.

Already have a key pair from elsewhere? You can paste your own private key on the same screen.
