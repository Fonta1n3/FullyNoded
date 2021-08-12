# Quick Connect QR

Fully Noded has uri deep links registered with the following prefixes  `btcstandup://`, `btcrpc://` for connecting Bitcoin Core and `clightning-rpc://` for you guessed it C-Lightning.

If you are a node manufacturer you can embed such a link to your web based UI that allows a user who has Fully Noded installed on their device to add and connect to their node with a single tap from the web based UI.

The url can also be displayed as a QR Code and a user can simply scan it when they go to add a node in Fully Noded.

The format of the URI is:

`btcrpc://<rpcuser>:<rpcpassword>@<hidden service hostname>:<hidden service port>?label=<optional node label>`

Example with node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?label=Your%20Nodes%20Name`

Example without node label:

`btcrpc://rpcuser:rpcpassword@kjhfefe.onion:8332?`

For C-Lightning simply specify the correct prefix and FN will do the rest:<br/>
`clightning-rpc://rpcuser:rpcpassword@xxxx.onion:8080?label=BTCPay%20C-Lightning`
For more info on supporting c-lightning see [Lightning.md](./Docs/Lightning.md)

**The rpcuser and rpcpassword are the http-user (lightning by default) and http-pass you specify in the clightning config when using the supported c-lightning http [plugin](https://github.com/Start9Labs/c-lightning-http-plugin), 1312 is the HS port, again you may customize the port with http-port in the lightning config in conjunction with the http plugin.**
