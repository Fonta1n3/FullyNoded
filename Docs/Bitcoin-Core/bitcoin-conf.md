# bitcoin.conf

These are the recommended settings for Fully Noded functionality.

```
#forces your node to accept rpc commands
server=1

# Up to you if you want to prune or not, FN will work just the same. A pruned node is a Full Node!
# 1000 means the node will only take up around 1gb of space
prune=1000

#Choose any username or password, make the password very strong **DO NOT USE SPECIAL CHARACTERS**, it will break the uri to your node that FN uses.
rpcuser=yourUserName
rpcpassword=aVeryStrongPasswordSuchAs128dnc849vn9n7gSS

# This is redundant but only allows your computer to access your node
rpcallowip=127.0.0.1

# For a faster IBD use dbcach=half your ram - for 8gb ram set dbcache to 4000
dbcache=4000
```
