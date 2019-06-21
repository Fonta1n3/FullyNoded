# FullyNoded
A Bitcoin Core GUI for iOS devices. Allows you to connect to and control multiple nodes via SSH.

## Join the Testflight

[Download the testflight on your iOS device by tapping here](https://testflight.apple.com/join/PuFnSqgi)

## Build From Source

You will need Xcode and Carthage.

- Install [Xcode](https://itunes.apple.com/id/app/xcode/id497799835?mt=12)
- In XCode, click "XCode" -> "preferences" -> "Accounts" -> add your github account
- Go to [Fully Noded in GitHub](https://github.com/FontaineDenton/FullyNoded) click "Clone and Download" -> "Open in XCode"
- Once you have Fully Noded open in Xcode you will then need to download carthage. [Follow these simple instructions for installing carthage on mac](https://brewinstall.org/install-carthage-on-mac-with-brew/)
- Once Carthage is installed, open Terminal
- `cd Documents FullyNoded` (or wherever it downloaded to)
- run `carthage update --platform iOS` and let carthage do its thing
- When Carthage frameworks are installed run the app in Simulator.
- Add a node into Fully Noded (see below)

## Add a Node

You will need an instance of Bitcoin Core running on a computer that you can SSH into with a password, IP address, and username.

- In Fully Noded tap "Nodes" -> "+"

<img src="Images/addNode.PNG" height="500">

- Add a label and SSH credentials for your node then tap "Save"

<img src="Images/IMG_7887.PNG" height="500">

- Switch the node on

<img src="Images/switcher.PNG" height="500">

- In the "Home" screen pull the table down to connect to your node

## If using a mac

- Click Apple icon in top left of your computer
- Click "System Preferences"
- Click "Sharing"
- Follow below image for instructions:

<img src="Images/screenShot.png" width="800">

## Troubleshooting

- If you get an error along the lines of "bash: bitcoin-cli command not found" that means the default path we set in the app is not correct. On your computer where you have Bitcoin Core running open a terminal and type `where bitcoin-cli`, on a mac it would be `which bitcoin-cli`. That will output the path you need to set in Fully Noded. In Fully Noded go to "Settings" and and scroll down till you see the "PATH" section, tap it an add your custom path.

- If you get an "Unable to connect" error then ensure you input the correct IP, password, port and username into Fully Noded. Try and SSH into the node in terminal and issue a `bitcoin-cli getblockchaininfo` command to ensure rpc commands are working properly, that the node is on, etc... If you have an issue in your server running `bitcoin-cli` commands then it will not work in the app either.

- You will need to ensure your Bitcoin Core node instance is running on a machine that allows SSH log in via password. In order to enable that:

- `sudo nano /etc/ssh/sshd_config`

- Find the line that shows: `PasswordAuthentication no`

- and change it to: `PasswordAuthentication yes`

- Exit nano and ensure you saved the changes.

- Then run: `sudo service sshd restart`

- Back in Fully Noded pull the home screen to refresh it and it should connect.

- If you get a "Channel allocation" error, that means you need to go back to home screen and pull the table to reconnect to your node.

- I am always keen to help people run nodes and connect to them, if any issues at all just DM me on twitter @FullyNoded or raise an issue here.

## Security

- SSH is a secure way of connecting to your node. All traffic between your iPhone and the node are encrypted to a high standard. [You can read more here](https://www.howtogeek.com/118145/vpn-vs.-ssh-tunnel-which-is-more-secure/)

- We highly recommend using a very strong password for SSH log in. SSH can be a target for hackers, if you have a simple password it will greatly increase the chances of the hacker to get access to your computer.

- We highly recommend altering the port for SSH to a custom port, 22 is default. This will go a long way to prevent hackers from obtaining access to your computer. To do this:

- On your nodes machine run: `sudo nano /etc/ssh/sshd_config`

- Find the line that says: `# Port 22`

- And change it to something like: `Port 52120`

- Ensure your firewall allows incoming connections to this port. You can choose any unused port up to 65,535

- Exit nano, ensure you save the changes, then run: `sudo service sshd restart`

## Roadmap

- I am working on a macOS desktop app that will turn on SSH programmatically and display a QR code to the user that the user can scan with the app to connect it to their node.

- The next priority is getting the Tor.framework up and runnning to allow connecting to your bitcoind Tor hidden service.

## Contributing

Please let us know if you have issues, the app is designed to work with any node running on any machine and is not tailor made for one specific OS, therefore it is very flexible and different OS will have different nuances. We would like to know about them! Please share your experience.

Please feel free to build from source in xcode and submit PR's. I need help and my to do list is way too long. If you can not code then simply testing the app and making video tutorials would go a very long way.

## Capabilities

- Add/edit/remove multiple nodes
- Create raw transactions (RBF enabled by default)
- See statistics about your node
- See last 10 transactions
- Tap unconfirmed transaction to bump the fee
- Create batch transactions (multiple outputs)
- Create unsigned transactions with external keys or with the nodes wallet (input a custom address to spend from, change address and recipient address)
- Sign unsigned transactions with an external private key or with the nodes wallet
- Import BIP84 xpubs (will add the first 100 addresses)
- Import BIP84 xprvs (will add the first 100 addresses and private keys)
- Import stand alone addresses and private keys
- Tap individual UTXO's to spend them or consolidate them

## Built With

- [NMSSH](https://github.com/NMSSH/NMSSH) for SSHing into your node.
- [AES256CBC](https://github.com/SwiftyBeaver/AES256CBC) for encrypting your log in credentials
- [Swift Keychain Wrapper](https://github.com/jrendel/SwiftKeychainWrapper) for storing your nodes credentials on your iPhones secure enclave
