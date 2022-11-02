# NOSTR
Nostr is a simple protocol where we can send and receive messages in a more decentralized,
censorship resistant way. I recommend reading [this blog post](https://dev.to/melvincarvalho/the-nostr-protocol-nip01-5ach) by Melvin Carvalho
for an introduction to what Nostr is.

## Nostr Clients
Code that allows you to send/receive messages via a Nostr relay.

## Nostr relays
You can think of them as servers that are simple to run, barely use any resources
and have only one job, take in your message and forward it to the desired recipient.

## How to use it in Fully Noded?
You can follow this [youtube tutorial](https://www.youtube.com/watch?v=idcpRlTR1Do).

- Subscribe Mac to iPhone
  - In FN Mac open Node Manager.
  - Tap the plus button and opt to create a Nostr node.
  - For best results connect your Mac to a local Bitcoin Core node, LAN works.
  - Open your iPhone and create a Nostr node.
  - Tap the QR button on the iPhone "Nostr Public Key" field.
  - On Mac scan the QR by tapping the scan button on the "Subscribe to" field.

- Subscribe iPhone to Mac
  - On your Mac tap the QR button to export the "Nostr Public Key".
  - Scan it with your iPhone to "Subscribe to" your Mac "Nostr Pubic Key".
  - Now your iPhone is subscribed to your Mac.

- Click Save on your Mac.
- Tap Save on your iPhone.
- Tapping save automatically connects you to the Nostr relay and lets them know
  who you are subscribed to.
- Activate the nodes.
- Go to the home screen, pull to refresh on your iPhone to see the data load
  blazingly fast.

## How to trouble shoot
If you see a spinner spinning in the top right on the home screen, try to pull to
refresh as that force reconnects to the relay. If that doesn't work make sure your
Nostr node was indeed saved and activated and that the mac has a valid connection
to your node. If it was try rebooting FN on both devices. Lastly, ensure your relay
is alive! You can always switch relays or run your own.

## How FN utilizes Nostr
In v0.4.0 Nostr functionality was added. FN iPhone and FN Mac both became Nostr clients.
When a user navigates to Node manager and adds a node you will now have the option
to create a Nostr node. The Nostr credentials are in the same format that bitcoin
private and public keys are in. FN generates a random one for you, encrypts it and
saves it. If you paste in your own private key the new public key will be derived
automatically. You can add a relay url and subscribe to other Nostr public keys.

For now Nostr only works via the FN mobile app <-> Mac app. It is trivial to write
up a script that would allow you to communicate to any node running on any machine.
I plan to do so in the very near future, it will be called Nostr Node.

There are two Nostr client types in FN. The mobile device client and the Mac client.
The mobile device client sends encrypted `bitcoin-cli` commands and params to the Mac
Nostr client. The Mac Nostr client decrypts the commands/params and forwards
them to Bitcoin Core. Bitcoin Core responds to your Mac, FN Mac then encrypts the
response, sends it back, the mobile client then decrypts the response
and behaves as normal... Just much much much much faster!

FN uses the ephemeral message type, relays are not supposed to store the messages
at all. The Bitcoin related content is encrypted by a private key only FN knows
about.
