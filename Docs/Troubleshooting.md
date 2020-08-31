# Troubleshooting
 
 ## Fully Noded errors
 - `Unknown error`: restart your node, restart Fully Noded, if that does not work make sure your `rpcpassword` and `rpcuser` do not have any special characters, only alphanumeric is allowed, otherwise you will not connect as it breaks the url to your node.
 - `Internet connection appears offline`: reboot Tor on your node, force quit and reopen Fully Noded, this works every single time.
 - If you can not connect and you have added Tor V3 auth to your node then ensure you added the public key correctly as Fully Noded exports it, reboot Tor, force quit Fully Noded and reopen.
 - The way Fully Noded works is very robust and reliable, if you have a connection issue there is a reason, don't lose hope :)

 
