# Fully Noded

An app that allows you to connect to and control your own Bitcoin Core Node written in Swift.

## Getting Started

Download this project and run it in XCode.

The app allows users to connect to their full node via SSH (password log in) or via the built in RPC API.

If using SSH:

    1. When prompted for username input your host server username (e.g. "root")
    2. When prompted for password input your SSH password
    3. Port is irrelevant for SSH
    4. When prompted for IP Address input your servers IP

If connecting via RPC:

    1. When prompted for username input your RPC username (e.g. "bitcoin")
    2. When prompted for password input your RPC password
    3. When prompted for port use 8332 for mainnet and 18332 for testnet
    4. When prompted for IP Address input your servers IP address

If the user does not have a full node the app allows the user to purchase an instance of a Bitcoin Core 0.17.0 node running on a VPS to power the app as a backend.

### Prerequisites

MacOS and XCode.

## Built With

* [NMSSH](https://github.com/NMSSH/NMSSH) - To allow users to SSH into their node
* [Swifty Beaver](https://github.com/SwiftyBeaver/AES256CBC) - For encrypting log in credentials
* [Swift Keychain Wrapper](https://github.com/jrendel/SwiftKeychainWrapper) - For securely storing encrypted keys locally

## Authors

* **Peter Denton** - *Initial work* - [Fully Noded](https://github.com/FontaineDenton/FullyNoded)

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details
