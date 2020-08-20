#Connect Node

## Supported Nodes
- Bitcoin Core (minimum 0.20.0 is recommended for full functionality)
- Nodl
- myNode
- BTCPayServer
- Raspiblitz
- Embassy

## Connect your own node
- Create a hidden service that controls your nodes rpcport (there is a mac guide below on how to do that).
- Go to `settings` > `node manager` > `+` > `manually`
- Find your bitcoin.conf and input your rpcuser and rpcpassword and a label into the app. See "bitcoin.conf settings" below. **No special characters allowed! Only alphanumeric**
- Input the hidden services hostname with the port at the end (njcnewicnweiun.onion:8332)
- Tap `save`, you will be alerted it if was saved successfully, it will automatically start connecting to it. Optionally, if you have authentication setup you will need to create V3 auth keys in the app by going to `settings` > `security center` > `Tor V3 Authentication` > `tap the refresh button to create keys out of band or add your own private key by pasting it in` > `tap the export button to export your public key`

## Connect BTCPayServer
- In BTCPay go to `Server Settings` > `Services` > click on `Full Node RPC`
<img src="./Images/btcpay.png" alt="" width="500"/>

- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR`
- Once you have scanned the QR the app will automatically connect and start loading the home screen, to ensure its working go home and see the table load. To troubleshoot any connection issue reboot your BTCPayServer and force quit and reopen Fully Noded.

## Connect Nodl
- In Nodl go to the Tor tile settings pane which will dsiplay:
<img src="./Images/nodl_1.JPG" alt="" width="250"/>

- Click `Details and settings`
<img src="./Images/nodl_2.JPG" alt="" width="250"/>

- If you are on your iPhone or iPad you can click `BTCRPC Link` and it will automatically launch Fully Noded and connect your node.
- If you are accessing the Nodl gui via a computer click `QR-Code`:
<img src="./Images/nodl_3.jpeg" alt="" width="250"/>

- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR`
- Once you have scanned the QR the app will automatically connect and start loading the home screen, to ensure its working go home and see the table load. To troubleshoot any connection issue reboot Tor on your Nodl and force quit and reopen Fully Noded.

You can always do this manually by inputting your `rpcuser` and `rpcpassword` along with the Tor hidden service url in Fully Noded. Just add `:8332` to the end of the onion url.

## Connect Raspiblitz
In Raspiblitz:
- Ensure Tor is running
- SSH-MAINMENU > FULLY_NODED
- follow the simple instructions

## Connect Embassy
- In Fully Noded go to `Settings` > `Node Manager` > `+` > `manually`
- Simply add the Tor onion url with `:8332` appended to it and your rpc username/password

## Connect myNode
- In myNode:
<img src="./Images/myNode_1.png" alt="" width="250"/>

1. From your dashboard, navigate to the Tor page
<img src="./Images/myNode_2.png" alt="" width="250"/>

2. At the bottom of the Tor page your will see the Fully Nodes button, press it.
<img src="./Images/myNode_3.png" alt="" width="250"/>

3. You will now see your connection QR.
This is for premium myNode users only.
- In Fully Noded go to `Settings` > `Node Manager` > `+` > `Scan Quick Connect QR` and scan the QR

Non premium users can simply get their Tor V3 url for the RPC port add `:8332` to the end so it looks like `ufiuh2if2ibdd.onion:8332` and get your `rpcuser` and `rpcpassword` and add them all manually in Fully Noded:  `Settings` > `Node Manager` > `+` > `manually`

## Importing a wallet from Specter
- In Specter click the wallet of your choice, Fully Noded is compatible with all of them
- Click `Settings`
<img src="./Images/specter_1.png" alt="" width="250"/>

- Click `export`
<img src="./Images/specter_2.png" alt="" width="250"/>

- In Fully Noded go to the `Active Wallet` tab > `+`  > `import` > scan the Specter export QR code

## Troubleshooting
- `Unknown error`: restart your node, restart Fully Noded, if that does not work make sure your `rpcpassword` and `rpcuser` do not have any special characters, only alphanumeric is allowed, otherwise you will not connect as it breaks the url to your node.
- `Internet connection appears offline`: reboot Tor on your node, force quit and reopen Fully Noded, this works every single time.
- If you can not connect and you have added Tor V3 auth to your node then ensure you added the public key correctly as Fully Noded exports it, reboot Tor, force quit Fully Noded and reopen.
- The way Fully Noded works is very robust and reliable, if you have a connection issue there is a reason, don't lose hope :)

