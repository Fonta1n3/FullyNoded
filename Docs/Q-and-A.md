# Q&A about Fully Noded
Inspired by questions asked on the open Telegram *Fully Noded* group [here](https://t.me/FullyNoded) and [Twitter](https://twitter.com/FullyNoded).

Beware: A Q&A is always *work in progress*. Tips & help welcome.


### Disclaimer
None of the respondents in the **open** Telegram group have been explicitly named as a source, except for ***@Fonta1n3***. For practical reasons educational images uploaded by Telegram group members have been downloaded. We de-personalised them by giving images a new name. Under these new names these images have been uploaded to github and used in the Q&A to clarify the questions and answers.

> We've done our best to protect the privacy of the Telegram group members by investigating the images we used. We haven't come across personal identifiable information (pii). However, should we have made a mistake after all, please let us know and we'll correct this immediately.

## Explanation of the Q&A

The answers are given by ***@Fonta1n3***. If not than an explicit source is referenced.

## Recommended reading

1. For basic usage of the app make sure to read the websites FAQ first [here](https://fullynoded.app/faq/)

2. [Introducing Fully Noded Wallets](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102) July 2020 - @Fonta1n3
> Topics:<br/>
   > a. wallets, bitcoin core versus Fully Noded wallets<br/>
   > b. import public keys, derivation paths and address scripts<br/>
   > c. recover every possible popular derivation across a number of wallet vendors<br/>
   > d. Samourai wallet special treatment<br/>
   > e. activate, deactivate and delete
3. [Introducing Fully Noded PSBT Signers](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558) July 2020 - @Fonta1n3
> Topics:<br/>
   > a. libwally<br/>
   > b. add psbt signers<br/>
   > c. signed raw transaction over psbt <br/>
   > d. airdrop psbt as a raw data BIP174 file<br/>
   > e. add BIP39 seed words as a signer<br/>
   > f. analyze the base64 encoded text of the psbt<br/>
   > g. filters through all the signers stored on your device and signs the psbt

# Table of contents
- [Definitions](#definitions-1)
  * [Apple id](#apple-id)
  * [bech32  bitcoin address(p2wpkh)](#bech32--bitcoin-address-p2wpkh-)
  * [BIP84 keys](#bip84-keys)
  * [bitcoin.conf](#bitcoinconf)
  * [Bitcoin-cli](#bitcoin-cli)
  * [Bitcoin Core (Wallet) App, also known as `Bitcoin-qt`](#bitcoin-core--wallet--app--also-known-as--bitcoin-qt-)
  * [Bitcoin-qt](#bitcoin-qt)
  * [bitcoind](#bitcoind)
  * [bitcoind](#bitcoind-1)
  * [coldcard](#coldcard)
  * [Datadir](#datadir)
  * [Esplora](#esplora)
  * [FN](#fn)
  * [FN2](#fn2)
  * [Fully Noded wallets](#fully-noded-wallets)
  * [GW](#gw)
  * [gap limit](#gap-limit)
  * [Initial block download (IBD)](#initial-block-download--ibd-)
  * [Keepkey](#keepkey)
  * [keypool](#keypool)
  * [legacy bitcoin address (p2pkh)](#legacy-bitcoin-address--p2pkh-)
  * [Libwally](#libwally)
  * [ledger Nano S/X](#ledger-nano-s-x)
  * [Nano](#nano)
  * [Node](#node)
  * [Nodl](#nodl)
  * [Output descriptors](#output-descriptors)
  * [psbt](#psbt)
  * [pure bitcoin core wallets](#pure-bitcoin-core-wallets)
  * [rbf](#rbf)
  * [RPC](#rpc)
  * [segwit wrapped  bitcoin address (p2sh-p2wpkh)](#segwit-wrapped--bitcoin-address--p2sh-p2wpkh-)
  * [Segwit addresses](#segwit-addresses)
  * [SSH](#ssh)
  * [Standup app](#standup-app)
  * [satoshi](#satoshi)
  * [signed raw transaction](#signed-raw-transaction)
  * [Trezor](#trezor)
  * [Tor](#tor)
  * [UTXO's](#utxo-s)
  * [Knowledge you should be confidently applying](#knowledge-you-should-be-confidently-applying)
  * [Actions you should be comfortable with](#actions-you-should-be-comfortable-with)
- [Jump table to categories](#jump-table-to-categories)
- [Q&A](#q-a)
  * [Userinterface](#userinterface)
      - [Question : This button should bring up info and allow me to make changes?](#question---this-button-should-bring-up-info-and-allow-me-to-make-changes-)
      - [Question : why can't I see the label I gave the change address? When I have wallet loaded and go to List Labels under settings I can only see the name I have the wallet, not the label I gave the change address?](#question--why-can-t-i-see-the-label-i-gave-the-change-address--when-i-have-wallet-loaded-and-go-to-list-labels-under-settings-i-can-only-see-the-name-i-have-the-wallet--not-the-label-i-gave-the-change-address-)
      - [Question : I'd like to recover a wallet using FN without revealing seed words, is that possible?](#question---i-d-like-to-recover-a-wallet-using-fn-without-revealing-seed-words--is-that-possible-)
      - [Question : how to verify all outputs of a raw transaction? I verified the Send address. I would like to verify the Change address. How?](#question---how-to-verify-all-outputs-of-a-raw-transaction--i-verified-the-send-address-i-would-like-to-verify-the-change-address-how-)
      - [Question : how do I figure out what version of fully noded I'm using on my IOS device?](#question---how-do-i-figure-out-what-version-of-fully-noded-i-m-using-on-my-ios-device-)
      - [Question : Made 2 single sig wallets in FN.  Both have same signer words?](#question---made-2-single-sig-wallets-in-fn--both-have-same-signer-words-)
      - [Further elaboration on the answer](#further-elaboration-on-the-answer)
      - [Question : Why is camera always active in the wallet?](#question---why-is-camera-always-active-in-the-wallet-)
      - [Question : Why might the app be crashing for me?](#question---why-might-the-app-be-crashing-for-me-)
      - [Question : Is airdropping a requirement?](#question---is-airdropping-a-requirement-)
      - [Question : I experience crashes, and I want it fixed. How?](#question---i-experience-crashes--and-i-want-it-fixed-how-)
      - [Question : What are the assurances that the developer can't push out software that will steal my seed say in a single sig wallet?](#question---what-are-the-assurances-that-the-developer-can-t-push-out-software-that-will-steal-my-seed-say-in-a-single-sig-wallet-)
        * [Further question:  how can I load that code directly to my iOS device without the appstore? What assurances are there that the github code is exactly what is sent and installed via apple appstore?](#further-question---how-can-i-load-that-code-directly-to-my-ios-device-without-the-appstore--what-assurances-are-there-that-the-github-code-is-exactly-what-is-sent-and-installed-via-apple-appstore-)
  * [Import](#import)
      - [Question : I got the zpub from electrum. I thought that if you use a bech32 wallet, you get a zpub not xpub?](#question---i-got-the-zpub-from-electrum-i-thought-that-if-you-use-a-bech32-wallet--you-get-a-zpub-not-xpub-)
      - [Question : Why does importmulti not support zpub and ypub?](#question---why-does-importmulti-not-support-zpub-and-ypub-)
      - [Question : I am not sure, I forgot, So have I basically at some point imported a bunch of addresses?](#question---i-am-not-sure--i-forgot--so-have-i-basically-at-some-point-imported-a-bunch-of-addresses-)
      - [Question : How to import my BRD wallet?](#question---how-to-import-my-brd-wallet-)
      - [Question : `.txn` files, is there anyway to open on iPhone?](#question----txn--files--is-there-anyway-to-open-on-iphone-)
      - [Question : How are you transferring the txs from the Coldcard to the iPhone - microSD card reader?](#question---how-are-you-transferring-the-txs-from-the-coldcard-to-the-iphone---microsd-card-reader-)
      - [Further question : what the added benifit of going through the iPhone?](#further-question---what-the-added-benifit-of-going-through-the-iphone-)
      - [Question : Gordian wallet. There is no “add manually” like in FullyNoded?](#question---gordian-wallet-there-is-no--add-manually--like-in-fullynoded-)
        * [Can I import a multisig wallet from Electrum into Fully Noded?](#can-i-import-a-multisig-wallet-from-electrum-into-fully-noded-)
  * [Export](#export)
      - [Question : Why doesn't broadcast work via my Node?](#question---why-doesn-t-broadcast-work-via-my-node-)
      - [Question : Hardware wallet support?](#question---hardware-wallet-support-)
      - [Question : How to export your single sig wallet from Coldcard to Fully Noded using your own node?](#question---how-to-export-your-single-sig-wallet-from-coldcard-to-fully-noded-using-your-own-node-)
      - [Question : Is there  a way to export the multisig.txt file anytime after the initial prompt when exiting the Multisig Creator flow?](#question---is-there--a-way-to-export-the-multisigtxt-file-anytime-after-the-initial-prompt-when-exiting-the-multisig-creator-flow-)
      - [Question : How export and backup my wallet into a QR code?](#question---how-export-and-backup-my-wallet-into-a-qr-code-)
      - [Question : Are there any security risks associated with export / backup? Loss of privacy (watch only), loss of funds?](#question---are-there-any-security-risks-associated-with-export---backup--loss-of-privacy--watch-only---loss-of-funds-)
        * [Further question : No need to touch my external signing device again? So then FullyNoded would be the signer??](#further-question---no-need-to-touch-my-external-signing-device-again--so-then-fullynoded-would-be-the-signer--)
      - [How can I import a 12 word mnemonic from Coldcard into FN wallet?](#how-can-i-import-a-12-word-mnemonic-from-coldcard-into-fn-wallet-)
  * [General](#general)
      - [Question : What’s the difference between Gordian Wallet (GW) and Fully Noded (FN)?](#question---what-s-the-difference-between-gordian-wallet--gw--and-fully-noded--fn--)
        * [Teamplayers Gordian Wallet and Fully Noded](#teamplayers-gordian-wallet-and-fully-noded)
        * [Addition to point 1: example](#addition-to-point-1--example)
      - [Question : Why is there no version for Android yet?](#question---why-is-there-no-version-for-android-yet-)
      - [Further question : Why would Apple not make Tor easier?](#further-question---why-would-apple-not-make-tor-easier-)
      - [Question : What is your privacy policy and how to comply with GPDR?](#question---what-is-your-privacy-policy-and-how-to-comply-with-gpdr-)
      - [Question : Why did you choose iOS to build on? Any advantage compared to Android?](#question---why-did-you-choose-ios-to-build-on--any-advantage-compared-to-android-)
      - [Question: please elaborate on the seemingly *contradictory* statements about '100% offline signing'](#question--please-elaborate-on-the-seemingly--contradictory--statements-about--100--offline-signing-)
      - [Further elaboration on the answer / issue](#further-elaboration-on-the-answer---issue)
      - [Question : My transaction still says 0 confirm?](#question---my-transaction-still-says-0-confirm-)
      - [Question : Any suggestion about this problem? All the username, password, and onion address are OK](#question---any-suggestion-about-this-problem--all-the-username--password--and-onion-address-are-ok)
      - [Question : "Transaction invalid: some outputs that it attempts to spend have been already spent or ... Did I set my fee's too low?](#question----transaction-invalid--some-outputs-that-it-attempts-to-spend-have-been-already-spent-or--did-i-set-my-fee-s-too-low-)
      - [Question : FN latest: “Added ability to share your node”. Please explain?](#question---fn-latest---added-ability-to-share-your-node--please-explain-)
      - [Question : Have you been able to overwrite other apps associations?](#question---have-you-been-able-to-overwrite-other-apps-associations-)
      - [Question :  Does this imply that using my node is not private?](#question----does-this-imply-that-using-my-node-is-not-private-)
      - [Question : Do you have a lightning node? to send donations? The fees are currently high for a mainnet transaction.](#question---do-you-have-a-lightning-node--to-send-donations--the-fees-are-currently-high-for-a-mainnet-transaction)
        * [Further question : About donations : how are the addresses generated?](#further-question---about-donations---how-are-the-addresses-generated-)
      - [Question : How to do c-lightning on mac with pruned node?](#question---how-to-do-c-lightning-on-mac-with-pruned-node-)
        * [Further Question: As far as I know c-lightning doesn’t fully support pruned nodes.](#further-question--as-far-as-i-know-c-lightning-doesn-t-fully-support-pruned-nodes)
      - [How could I connect Casa Node and FN?](#how-could-i-connect-casa-node-and-fn-)
      - [Can I turn on my LND server on MyNode to use FN as a lightning wallet in conjunction with an onchain wallet?](#can-i-turn-on-my-lnd-server-on-mynode-to-use-fn-as-a-lightning-wallet-in-conjunction-with-an-onchain-wallet-)
      - [How should I organise my signing with devices and multisigs?](#how-should-i-organise-my-signing-with-devices-and-multisigs-)
      - [Question : Checking total supply. This is taking an inordinate amount of time for me and my screen eventually turns off.](#question---checking-total-supply-this-is-taking-an-inordinate-amount-of-time-for-me-and-my-screen-eventually-turns-off)
        * [Further question : I do wish the app would cache the reply so that you can come back and tell you when it was cached...](#further-question---i-do-wish-the-app-would-cache-the-reply-so-that-you-can-come-back-and-tell-you-when-it-was-cached)
      - [Question : I’m trying to connect to a ‘mynode` *community edition*. Is that still an option?](#question---i-m-trying-to-connect-to-a--mynode---community-edition--is-that-still-an-option-)
      - [Question : Why does the `tor` service persist in the background even after I've shut down Gordian Server? Why doesn't Gordian Server shut down its service that it initiated?](#question---why-does-the--tor--service-persist-in-the-background-even-after-i-ve-shut-down-gordian-server--why-doesn-t-gordian-server-shut-down-its-service-that-it-initiated-)
        * [Further question: Most people would expect it to stop itself when pressing `cmd+q`? Most people think of apps in macOS as a self contained monolith.](#further-question--most-people-would-expect-it-to-stop-itself-when-pressing--cmd-q---most-people-think-of-apps-in-macos-as-a-self-contained-monolith)
        * [Further answer:](#further-answer-)
  * [Connection](#connection)
      - [Question : How do I connect my node?](#question---how-do-i-connect-my-node-)
      - [Could not connect to the server... What to do?](#could-not-connect-to-the-server-what-to-do-)
      - ["The internet connection appears to be offline..." but I am online, what to do?](#-the-internet-connection-appears-to-be-offline--but-i-am-online--what-to-do-)
      - [Can I connect FN  to my node over local wifi?](#can-i-connect-fn--to-my-node-over-local-wifi-)
      - [Question : how risky is to open port 22 to connect from anywhere outside my local lan?](#question---how-risky-is-to-open-port-22-to-connect-from-anywhere-outside-my-local-lan-)
      - [Question : I get a channel alocation error when I try to add a Xpub. What could go wrong?](#question---i-get-a-channel-alocation-error-when-i-try-to-add-a-xpub-what-could-go-wrong-)
      - [Question : In true airgapped situation: no need for a Coldcard? Just create signed TXs on the airgapped laptop?](#question---in-true-airgapped-situation--no-need-for-a-coldcard--just-create-signed-txs-on-the-airgapped-laptop-)
      - [Question : Do I have to be in the same network?](#question---do-i-have-to-be-in-the-same-network-)
      - [Question : How do we get the rpc credentials on the nodl?](#question---how-do-we-get-the-rpc-credentials-on-the-nodl-)
      - [Question : RPC credentials are mandatory. FN is forcing good behaviour?](#question---rpc-credentials-are-mandatory-fn-is-forcing-good-behaviour-)
      - [Question : Do you use a terminal app in iOS on the iPhone that you ssh into your network with?](#question---do-you-use-a-terminal-app-in-ios-on-the-iphone-that-you-ssh-into-your-network-with-)
      - [Question : How do I troubleshoot connection issues over Tor between FN and Bitcoin Core Nodes on a Mac?](#question---how-do-i-troubleshoot-connection-issues-over-tor-between-fn-and-bitcoin-core-nodes-on-a-mac-)
        * [Further question : Maybe I need to do some changes on my firewall due to the tor service?](#further-question---maybe-i-need-to-do-some-changes-on-my-firewall-due-to-the-tor-service-)
      - [Question : How can I test the network connection between them (FN and Node)?](#question---how-can-i-test-the-network-connection-between-them--fn-and-node--)
      - [Question: What is the best of breed desktop wallet to connect to your node?](#question--what-is-the-best-of-breed-desktop-wallet-to-connect-to-your-node-)
      - [Question : Can't seem to locate the torrc file to connect via Tor using Nano. What's wrong?](#question---can-t-seem-to-locate-the-torrc-file-to-connect-via-tor-using-nano-what-s-wrong-)
      - [Question : Looks like I'm connected. But no homescreen, what's wrong?](#question---looks-like-i-m-connected-but-no-homescreen--what-s-wrong-)
      - [Question : what's this about *Tor V3 Authentication Public key* in settings > security center > Tor V3 Authentication?](#question---what-s-this-about--tor-v3-authentication-public-key--in-settings---security-center---tor-v3-authentication-)
        * [Troubleshooting](#troubleshooting)
      - [Question : C-lightning - I added details of node. Clicked gear icon - got 'method not found' error. What to do?](#question---c-lightning---i-added-details-of-node-clicked-gear-icon---got--method-not-found--error-what-to-do-)
      - [Question : App gets backgrounded and then when I foreground it a few times it eventually crashes. What is wrong?](#question---app-gets-backgrounded-and-then-when-i-foreground-it-a-few-times-it-eventually-crashes-what-is-wrong-)
      - [Question : I get confused when reading pubkey and privkey in Tor context; an onion address consists of tor public and private keys?](#question---i-get-confused-when-reading-pubkey-and-privkey-in-tor-context--an-onion-address-consists-of-tor-public-and-private-keys-)
      - [Question :  FN requires RPC creds inputted in order to create a hot wallet that will then provide Tor v3 auth, is that correct?](#question----fn-requires-rpc-creds-inputted-in-order-to-create-a-hot-wallet-that-will-then-provide-tor-v3-auth--is-that-correct-)
      - [With myNode, over `tor`, i'm always getting "network connection was lost" right after tor connected. What to do?](#with-mynode--over--tor---i-m-always-getting--network-connection-was-lost--right-after-tor-connected-what-to-do-)
      - [Question :  I am connected to my raspiblitz node and I get this Lightning "Method not found" error.](#question----i-am-connected-to-my-raspiblitz-node-and-i-get-this-lightning--method-not-found--error)
      - [Question : Do you use wireguard to connect to your nodes?](#question---do-you-use-wireguard-to-connect-to-your-nodes-)
        * [Further Question: Where does the keypair fit in?](#further-question--where-does-the-keypair-fit-in-)
        * [Further answer:](#further-answer--1)
      - [Question : What is a good local network connection set-up to your nodes?](#question---what-is-a-good-local-network-connection-set-up-to-your-nodes-)
        * [Further Question: Where does the keypair fit in?](#further-question--where-does-the-keypair-fit-in--1)
        * [Further answer:](#further-answer--2)
      - [Question : Can I connect FN on iPhone to my own node via FN on Mac?](#question---can-i-connect-fn-on-iphone-to-my-own-node-via-fn-on-mac-)
      - [Question : How to run your own node and connect to it with Fully Noded macOS?](#question---how-to-run-your-own-node-and-connect-to-it-with-fully-noded-macos-)
  * [Wallets](#wallets)
      - [Question : How do I create a wallet in FN?](#question---how-do-i-create-a-wallet-in-fn-)
      - [Question : How I can erase a wallet in Fullynoded? or modify a name?](#question---how-i-can-erase-a-wallet-in-fullynoded--or-modify-a-name-)
      - [Question : what is the recovery wallet?](#question---what-is-the-recovery-wallet-)
      - [Question : can fullynoded recover mycelium wallets?](#question---can-fullynoded-recover-mycelium-wallets-)
      - [Question : Which faucet works the most reliable for testnet:](#question---which-faucet-works-the-most-reliable-for-testnet-)
      - [Question : So where is the private key stored then? On disk somewhere?](#question---so-where-is-the-private-key-stored-then--on-disk-somewhere-)
      - [Further elaboration on the question: and since everything on iOS is sandboxed its pretty difficult for a different process or thread to peek at the contents of fully noded; right?](#further-elaboration-on-the-question--and-since-everything-on-ios-is-sandboxed-its-pretty-difficult-for-a-different-process-or-thread-to-peek-at-the-contents-of-fully-noded--right-)
      - [Question : The keychain encryption key is stored on the secure enclave?](#question---the-keychain-encryption-key-is-stored-on-the-secure-enclave-)
      - [Question : What’s the diff in importing Xpub and import descriptor under wallet?](#question---what-s-the-diff-in-importing-xpub-and-import-descriptor-under-wallet-)
      - [Question : how to create a 2 of 2 multisig wallet with my Coldcard and FullyNoded?](#question---how-to-create-a-2-of-2-multisig-wallet-with-my-coldcard-and-fullynoded-)
      - [Question : In `wallet - invoice`: Is there a way I can go back to a previous receive wallet address?](#question---in--wallet---invoice---is-there-a-way-i-can-go-back-to-a-previous-receive-wallet-address-)
      - [Question : I recovered from Greenwallet and didn't get a balance, Iim wondering if FN scans all the BIP lines?](#question---i-recovered-from-greenwallet-and-didn-t-get-a-balance--iim-wondering-if-fn-scans-all-the-bip-lines-)
        * [Further question : So the wallet I recovered is a single sig based on same multi seed? Given that fact...best to create a fresh FN wallet and go from there? I don't want to confuse myself any further. I like the privacy of FN. I basically want to switch from Green Wallet to FN for my daily driver.](#further-question---so-the-wallet-i-recovered-is-a-single-sig-based-on-same-multi-seed--given-that-factbest-to-create-a-fresh-fn-wallet-and-go-from-there--i-don-t-want-to-confuse-myself-any-further-i-like-the-privacy-of-fn-i-basically-want-to-switch-from-green-wallet-to-fn-for-my-daily-driver)
      - [Question : Are wallets enabled on the config page of bitcoin in the Embassy App?](#question---are-wallets-enabled-on-the-config-page-of-bitcoin-in-the-embassy-app-)
      - [Question : I clicked on the file again and now I have 2 cold cars records in the FN app. Would I see 2 wallets in FN that showed the same exact info?](#question---i-clicked-on-the-file-again-and-now-i-have-2-cold-cars-records-in-the-fn-app-would-i-see-2-wallets-in-fn-that-showed-the-same-exact-info-)
        * [Further Answer:](#further-answer-)
      - [Question : Does fully noded need the wallet from bitcoin core?](#question---does-fully-noded-need-the-wallet-from-bitcoin-core-)
      - [Question : This wallet was created on FullyNoded why would I be getting this error.   I want to delete via “I” button](#question---this-wallet-was-created-on-fullynoded-why-would-i-be-getting-this-error---i-want-to-delete-via--i--button)
      - [Question : How do I delete a (FN) wallet?](#question---how-do-i-delete-a--fn--wallet-)
      - [Question : What’s the diff between FN wallets and bitcoin core wallets in the app?](#question---what-s-the-diff-between-fn-wallets-and-bitcoin-core-wallets-in-the-app-)
      - [Question : I tried to spend UTXO from multiSig wallet - running Bitcoin 0.20.1 and got an error. What's wrong?](#question---i-tried-to-spend-utxo-from-multisig-wallet---running-bitcoin-0201-and-got-an-error-what-s-wrong-)
      - [Question : How to have a watch-only wallet to track BTCPayserver incoming funds?](#question---how-to-have-a-watch-only-wallet-to-track-btcpayserver-incoming-funds-)
        * [Further question : how do I know it's time to increase the `gap limit`?](#further-question---how-do-i-know-it-s-time-to-increase-the--gap-limit--)
      - [Question : Why would a new Fully Noded wallet be watch-only when it should have a private key at least.](#question---why-would-a-new-fully-noded-wallet-be-watch-only-when-it-should-have-a-private-key-at-least)
        * [Further question: But I'm trying to encrypt the wallet on device. I just created wallet, go-to settings, security, encrypt - error...](#further-question--but-i-m-trying-to-encrypt-the-wallet-on-device-i-just-created-wallet--go-to-settings--security--encrypt---error)
        * [Further answer :](#further-answer--)
      - [Question: Private keys are by default encrypted in the device. But there is no password in the app. How's the seed protected?](#question--private-keys-are-by-default-encrypted-in-the-device-but-there-is-no-password-in-the-app-how-s-the-seed-protected-)
        * [Further question : But it shows the seed phrase without any authentication. Regardless of the Biometrics setting. How can that be secure?](#further-question---but-it-shows-the-seed-phrase-without-any-authentication-regardless-of-the-biometrics-setting-how-can-that-be-secure-)
        * [Further answer :](#further-answer---1)
      - [Question : Can I sweep an old paper wallet?](#question---can-i-sweep-an-old-paper-wallet-)
  * [Standup](#standup)
      - [Question : where can I download this?](#question---where-can-i-download-this-)
      - [Question : what kind of compromises would standup have to make in order to be distributed via the mac app store?](#question---what-kind-of-compromises-would-standup-have-to-make-in-order-to-be-distributed-via-the-mac-app-store-)
      - [Question : If I allready have a full node running on my Mac. Can I use the standup app with it?](#question---if-i-allready-have-a-full-node-running-on-my-mac-can-i-use-the-standup-app-with-it-)
      - [Question :  I am about to start a full node on mac. Can I change the directory to an External SSD with the standApp?](#question----i-am-about-to-start-a-full-node-on-mac-can-i-change-the-directory-to-an-external-ssd-with-the-standapp-)
  * [Transactions](#transactions)
      - [Question : How do I specify a fee rate in FN?](#question---how-do-i-specify-a-fee-rate-in-fn-)
      - [Question : Can I create transactions in USD?](#question---can-i-create-transactions-in-usd-)
  * [Node](#node-1)
      - [Question : I changed bitcoin.conf according to guideline, why is it still not working?](#question---i-changed-bitcoinconf-according-to-guideline--why-is-it-still-not-working-)
      - [Question : how to create a Tor V3 hidden service to control your node?](#question---how-to-create-a-tor-v3-hidden-service-to-control-your-node-)
      - [Question : Anyway to connect node via bitcoin core QT? Can't get to find any QR code from the QT core on Mac OS.](#question---anyway-to-connect-node-via-bitcoin-core-qt--can-t-get-to-find-any-qr-code-from-the-qt-core-on-mac-os)
      - [Question : Is there currently a way to execute bitcoin-cli rescanblockchain with the start/stop height parameters from within fully Noded?](#question---is-there-currently-a-way-to-execute-bitcoin-cli-rescanblockchain-with-the-start-stop-height-parameters-from-within-fully-noded-)
      - [Question : Is there an ability to add peers and remove peers?](#question---is-there-an-ability-to-add-peers-and-remove-peers-)
      - [Question : So the order of fully noded is 1. Node 2. Wallet? Correct? Without a node, you can't scan in a wallet?](#question---so-the-order-of-fully-noded-is-1-node-2-wallet--correct--without-a-node--you-can-t-scan-in-a-wallet-)
      - [Question : If you start rescan of blockchain does the app have to stay open the whole time for it to rescan?](#question---if-you-start-rescan-of-blockchain-does-the-app-have-to-stay-open-the-whole-time-for-it-to-rescan-)
      - [Further Question : If I add an xpub I assume I need to rescan. Does rescanning take hours/days on a pi?](#further-question---if-i-add-an-xpub-i-assume-i-need-to-rescan-does-rescanning-take-hours-days-on-a-pi-)
      - [Question : Can I use a pruned node with FN?](#question---can-i-use-a-pruned-node-with-fn-)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

# Definitions
##### Apple id
: a login and password to keep your settings and Apple services up to date on all of your devices. Just sign in with the same Apple ID everywhere.
##### bech32 bitcoin address(p2wpkh)
: segwit addresses. These addresses begin with a bc1.
##### BIP84 keys
: BIP84 refers to the accepted common standard of deriving native segwit addresses. These addresses always begin with bc1 - and are referred to bech32 addresses.
##### bitcoin.conf
: The bitcoin configuration file is a list of 'setting=value' pairs, one per line, with optional comments starting with the '#' character.
##### bitcoin-cli
: Bitcoin *CommandLine Interface*; just like Bitcoin Core app the CLI uses RPC calls to give your node and the bitcoin network commands and get results back.
##### Bitcoin Core (Wallet) App, also known as `Bitcoin-qt`
: Software running on MacOS, Windows and Linux that offers a **Graphical User Interface** to your Bitcoin Wallet and, if you wish, to your node. Just like Bitcoin CLI the Core app uses RPC calls to give your node and the bitcoin network commands and get results back.
##### Bitcoin-qt
: another name for Bitcoin Core (Wallet) App.
##### bitcoind
: Bitcoin Deamon, background process running a bitcoin node. Bitcoind is a program that implements the Bitcoin protocol for remote procedure call (RPC) use. It is also the second Bitcoin client in the network's history. It is available under the MIT license in 32-bit and 64-bit versions for Windows, GNU/Linux-based OSes, and Mac OS X. [Read more](https://en.bitcoin.it/wiki/Bitcoind)
##### bitcoind
: Bitcoin Deamon, background process running a bitcoin node. Bitcoind is a program that implements the Bitcoin protocol for remote procedure call (RPC) use. It is also the second Bitcoin client in the network's history. It is available under the MIT license in 32-bit and 64-bit versions for Windows, GNU/Linux-based OSes, and Mac OS X. [Read more](https://en.bitcoin.it/wiki/Bitcoind)
##### coldcard
: a type of hardware wallet to store, send and receive crypto currencies
##### Datadir
: The data directory is the location where Bitcoin's data files are stored, including the wallet data file.
##### Esplora
: Name of Blockstream's Tor V3 api to broadcast, it falls back to the users node if the api is unavailable. More info [here](https://github.com/Blockstream/esplora)
##### FN
: Fully Noded app
##### FN2
: see GW
##### Fully Noded wallets
: support BIP39 recovery words, the seed is encrypted and stored on your device **not** on the node. The node will only ever hold public keys. Your node will build psbt for us that FN will sign (not your Node). Your node verifies the UTXO's
##### GW
: Gordian Wallet, formerly known as `Fully Noded 2` app, The original name FN2 was a misnaming because it is a different app than FN from its inception. [This comparison](http://github.com/henkvancann/FNcompGordian/FN2_Comparison.md) tries to explain the differences between Fully Noded and Gordian Wallet.
##### gap limit
: This means you ended with more than 20 consecutive unused addresses in your bitcoin wallet. This could have have happened due to various reasons. [What it is and how to get over it](https://blog.blockonomics.co/bitcoin-what-is-this-gap-limit-4f098e52d7e1)
##### Initial block download (IBD)
: The Bitcoin Core initial block download code makes sure that the block headers you are downloading (from a single peer) passes certain, hard-coded "checkpoints.
##### Keepkey
: a type of hardware wallet to store, send and receive crypto currencies
##### keypool
: The keypool is a collection of unused addresses in your wallet. The keypool parameter tells the client how many unused addresses to keep in its pool. The original purpose of the keypool is to allow you to backup your wallet file less frequently and still have access to all your funds in the event of a hard drive failure. However since the invention of Hierarchical Deterministic Wallets (HD wallets, [BIP32](https://en.bitcoin.it/wiki/Deterministic_wallet)): If you have a HD wallet (check the icon on the bottom-right corner in Bitcoin Core), it doesn't matter. If you've created your wallet in an older version of Bitcoin Core, it's not an HD wallet. If that's the case, your keypool is important for backups: your backup has the same 1000 keys, which means you only need to make a new backup after using many different new addresses. If you would limit the keypool size to 20, you'll quickly run out of addresses, and you need to make new backups very often. That's the reason the keypool was increased from 100 to 1000. An important distinction with regrads to FN and Bitcoin Core is that Bitcoin Core is not able to add multisig addresses to the keypool, therefore we rely on the `bitcoin-cli` command `deriveaddresses` to derive multisig addresses on the fly using your multisig descriptors.
##### legacy bitcoin address (p2pkh)
: refers to the accepted common standard to derive non segwit addresses. These addresses always begin with a 1.
##### Libwally
: an open source library (https://github.com/ElementsProject/libwally-core) used by Fully Noded, (https://github.com/blockchain/libwally-swift/blob/master/README.md) which allows us to utilize BIP39 directly in the app meaning you can easily recover your Fully Noded wallet with Electrum for example. Now when you create a wallet you will get a 12 word recovery phrase (no passphrase by default) to backup and keep safe.
##### ledger Nano S/X
: types of hardware wallets to store, send and receive crypto currencies
##### Nano
: famous text GUI editor to start from command line, not to be confused with Ledger Nano S/X, which is a cold storage.
##### Node
: A bitcoin full Node is a independent entity in a peer to peer ecosystem. A Node independently checks and verifies all protocol rules for incoming broadcasted transactions. A full node does not trust, but verifies. Technically speaking a *node* is a computer connected to other computers which follows rules and shares information. A *'full node'* is a computer in Bitcoin's peer-to-peer network which hosts and synchronises a copy of the entire Bitcoin blockchain. [Here](https://medium.com/@gloriazhao/map-of-the-bitcoin-network-c6f2619a76f3) is an excellent read on nodes, what they are and the differences between types of nodes.
##### Nodl
: A hardware box with to run a non-preloaded bitcoin node on it, [commercial site](https://www.nodl.it/).
##### Output descriptors
: Descriptors are a clever way of importing specific keys into your node from any derivation, for any (or all) address types, single or multi signature, along with a fingerprint so offline psbt signers like a Coldcard and Fully Noded can sign the psbt if they hold the correct seed.
##### psbt
: Partially signed bitcoin transactions (PSBTs) Also covering BIP174. Partially Signed Bitcoin Transactions (PSBTs) are a data format that allows wallets and other tools to exchange information about a Bitcoin transaction and the signatures necessary to complete it.
##### pure bitcoin core wallets
: traditional bitcoin wallet, that has to be manually backed up, recovered etc using bitcoin-cli. Your node will sign transactions and will hold the private key.
##### rbf
: Replace-By-Fee (RBF) is a node policy that allows an unconfirmed transaction in a mempool to be replaced with a different transaction that spends at least one of the same inputs and which pays a higher transaction fee. **For newbies:** a transaction that can't get through because of too low fee, can be overridden (replaced) with a higher fee to maybe succeed instead.
##### RPC
: Remote Procedure Calls
##### segwit wrapped  bitcoin address (p2sh-p2wpkh)
: BIP49 refers to the accepted common standard of deriving segwit "compatibility" addresses. These addresses begin with a 3.
##### Segwit addresses
: – Segregated Witness – or SegWit in short – reduced the transaction data’s size to allow for faster transactions, better scalability and decreased fees. Native SegWit (bech32) enhanced this even further and includes even lower fees. Not all exchanges and wallet providers support sending Bitcoin to a Native SegWit address yet, which is why you are presented both options in Ledger Live. Transactions between all 3 address types are possible
##### SSH
: Secure Shell (SSH) is a cryptographic network protocol for operating network services securely over an unsecured network.[1] Typical applications include remote command-line, login, and remote command execution, but any network service can be secured with SSH.
##### Standup app
: is a personal one-click Mac OS installer for Bitcoin Core and Tor that will present a QuickConnect QR code that can be used to pair mobile wallets for remote use over Tor V3. [Read more](https://github.com/BlockchainCommons/GordianSystem)
##### satoshi
: 0.000000001 BTC. A satoshi is the smallest unit of a bitcoin, equivalent to 100 millionth of a bitcoin.
##### signed raw transaction
: [Wikipage](https://en.bitcoin.it/wiki/Raw_Transactions) explains it all
##### Trezor
: a type of hardware wallet to store, send and receive crypto currencies
##### Tor
:Tor is free and open-source software for enabling anonymous communication. The name derived from the acronym for the original software project name "The Onion Router". [Read more in Wikipedia](https://en.wikipedia.org/wiki/Tor_(anonymity_network))
##### UTXO's
: Unspent transaction Outputs; UTXO stands for the unspent output from bitcoin transactions. Each bitcoin transaction begins with coins used to balance the ledger. UTXOs are processed continuously and are responsible for beginning and ending each transaction. Confirmation of transaction results in the removal of spent coins from the UTXO database. But a record of the spent coins still exists on the ledger. **for newbies**: UTXO is unspent bitcoin that you can "see" in your wallet and on the blockchain. It is an address and amount of sathosis. As soon as you spend the money, it won't add to your wallet balance anymore and therefore will only.

## Knowledge you should be confidently applying
- The definitions above
- Output Descriptors : https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md
- BIP32, BIP39, BIP44, BIP47, BIP49, BIP84, BIP174
- derivation paths, keypools
## Actions you should be comfortable with
- Amend knowledge and keep existing knowledge up to date
- recover from a seed
- sweep to a new wallet
- use bitcoin-cli
- install, sync, start and stop your own full node
- connect your TOR V3


# Jump table to categories
1. [General](#General)
2. [Standup](#Standup)
3. [Userinterface](#Userinterface)
4. [Import](#Import)
5. [Export](#Export)
6. [Wallets](#Wallets)
7. [Connection](#Connection)
8. [Transactions](#Transactions)
9. [Node](#Node)

# Q&A

## User Interface

#### Question : This button should bring up info and allow me to make changes?
<img src="./Images/refresh-info.png" alt="refresh-info" border="0" width="200">

It does, but only for Fully Noded wallets. It does not do anything for wallets created on your node externally from FN. FN allows you to manually create wallets and access all your nodes wallets. It is only possible for FN to show wallet details when the wallet was created via the `+` button on the `Active Wallet` tab. With FN wallets the app will remember the public key descriptors that were used to create the wallet, it's derivation, it's keypool range, the wallet label, the wallet filename, and a unique identifier.


#### Question: why can't I see the label I gave the change address? When I have wallet loaded and go to List Labels under settings I can only see the name I have the wallet, not the label I gave the change address?

When importing change keys *and* adding them to the keypool you can not add a label to change keys, this is a Bitcoin Core limitation. However if you do not add the keys to the keypool (multisig for example) yet you wish to designate your imported descriptor or extended key as deriving change keys then you can assign them a label. This would be useful if you are recreating an external wallet from say a Coldcard or a Ledger and you want to identify change outputs from receive outputs. There are multiple ways to see your keys labels. They will be shown in each transaction by default, in the utxo view or you can do it manually by going to `tools` > `Wallet` > `List Address Groups/List Labels/Get Address Info/Addresses by Label`. If your wallet conforms to BIP44/84/49/48 then you can always look at the utxo info view and see the change path in the descriptor for that utxo, for example a BIP44 receive path is `m/44'/0'/0'/0/0` and a change key would be `m/44'/0'/0'/1/0`

#### Question : I'd like to recover a wallet using FN without revealing seed words, is that possible?

There is a big difference between "recovery" and "importing". Recovering a wallet implies you would want to be able to spend the btc which means either seed words, an xprv or a WIF is needed. For importing and creating a watch-only wallet only an xpub is needed. The recovery wallet is specifically for recovering wallets and making them spendable. However it is an extremely easy way to import wallets into FN as we can do all the complex derivations for you when you supply seed words, if you want to make it watch-only you can always delete the seed words by navigating to `Active Wallet` > `squares button` > `signers button` > `tap the signer` > `you will see a delete button`. The proper way to import a wallet as watch-only is to import either the `xpub` or the `descriptor` for that wallet via `Active Wallet` > `import` > `xpub/descriptor`. If importing an `xpub` you will need to know its derivation path, and ideally import it twice once using the receive path and once designating it as change to ensure all transactions/utxos show. ***To do, create a pictorial explaining how to do this with accurate instructions***

#### Question : how to verify all outputs of a raw transaction? I verified the Send address. I would like to verify the Change address. How?

Copy and paste the raw transaction in hex formate `0200011200...`, go to `Tools` > `Transactions` > `Verify`, this tool will go through each input and output fetching all the addresses associated with each input and output. You can from their copy and paste the address and go to `Tools` > `Wallet` > `Get Address Info` to verify whether the address belongs to your nodes current active wallet. To verify an address belongs to your node's wallet check the `solvable` field `=1`, if it `=0` it does not belong to your wallet.

#### Question : how do I figure out what version of fully noded I'm using on my IOS device?

Nowhere, will add it to the header of settings

#### Question : Made 2 single sig wallets in FN.  Both have same signer words?

<img src="./Images/double-same-sig-wallets-FN.png" alt="double-same-sig-wallets-FN" border="0" width="200"><br/>
Ignore wallet manager<br/>
Tap the squares button on the active wallet view<br/>
Use your Fully Noded wallets from there<br/>
After deleting wallets via powershell make sure you restart your node<br/>
Just use the one you’ve got in the Fully Noded wallets, Delete the other one from your node, that originally failed<br/>

#### Further elaboration on the answer
TBW<br/>

#### Question : Why is camera always active in the wallet?
<img src="./Images/camera-active-wallet.png" alt="camera-active-wallet" border="0" width="200"><br/>
should only be active when you are scanning a QR code...<br/>
when you swipe down or close the QR scanner it dismisses all camera related code<br/>
For now, i guess if you do not want it to use the camera just disable that in the devices settings<br/>
I will look into it, give it more though and see what I can do<br/>
If the camera is dismissed and not being used, it makes no sense that the light would stay on.

Update: Think it should be fixed now, please try again when next update goes live.<br/>

#### Question : Why might the app be crashing for me?

MD: What is your node setup like? And what is the last thing you are doing before it crashes?

Matt Hill: Please make sure you are running `Bitcoin 0.20.0` on the `Embassy`. And that you have the "wallet" feature in your config file enabled.

Fonta1n3: Looks like you never actually connected? If your connection is successful you’ll see the home screen look like this:<br/>
<img src="./Images/opening-screen.png" alt="opening-screen" border="0" width="200">

Occasionally you’ll get a crash if you race around the app not allowing things to finish loading or if you put it into background before `tor` connects and back into foreground very quickly and vice versa. Important to let things load and go slow. Other then that there really should not be crashes, only way i can troubleshoot that is release on Testflight again and ask that you share the crash report.
For starters ensure you are connected to your node, can you confirm it successfully connects? Actually connecting is only successful when the home screen has loaded.

**Problem solving**
1. Are you absolutely sure the rpc password and username and onion are 100% correct? rpcpassword that's in your `bitcoin.conf`.
2. Have you tried rebooting the node?
3. Are there any special characters in the RPC password? Only alphanumeric is allowed but the app should warn you about that. Make sure your rpc credentials do not have any special characters
4. Generally rebooting Tor on the node would solve this issue if everything else is correct.
5. is there any possibility your isp is blocking `tor` (On your phone)?

#### Question : Is airdropping a requirement?
*I dont have a mac but i have saved the file on my iphone. is there a way to tell fully noded about that file?*

Airdrop is not a must. You can save the files in `iphone` using the native file application.

#### Question : What are the assurances that the developer can't push out software that will steal my seed say in a single sig wallet?

There isn’t any, that’s why you should use multisig or build the app from source.

HvC: Only if we are able to containerize the build environment (for example with Docker) then a hash of that "authenticity test" container proofs that the container has not been altered and will therefore most likely produce the exactly the same executable of FN + dito hash.

##### Further question:  how can I load that code directly to my iOS device without the appstore? What assurances are there that the github code is exactly what is sent and installed via apple appstore?

Again there isn’t any, the code is open sourced so you can build it yourself. Its actually not very difficult to do.

 If you'd like to build the app from source and heads-up compare the build follow the instruction:<br/>
 - Download the signed and tagged tarball (in this example `fullynoded.tar.gz`), and compare versions in github, App Store and Testflight 0.1.69
  - Verify the signature with the developers public PGP key : all you have to do is
 	`gpg --verify fullynoded.tar.gz.asc` (or whatever exact signature filename you downloaded)
  - Untar and build
     1. `brew install carthage automake autoconf libtool gnu-sed` (if you have not already)
     2. untar the tarball
     3. `cd <untarred dir>/XCode`
     4. `carthage build`
 	5. open `FullyNoded.xcodeproj`
 	6. run the project in a simulator or device

 If you'd like to import @Fonta1n3's [public key](https://github.com/Fonta1n3/FullyNoded#fully-noded%EF%B8%8F) to send encrypted messages follow the instruction:
    1. import @Fonta1n3's [public key](https://github.com/Fonta1n3/FullyNoded#fully-noded%EF%B8%8F) to gpg on mac: `gpg --import key.asc` (make sure `key.asc` contains the full pub key)
	2. If you don't have the full public key: try to use gpg --recv-keys \<fingerprint\> whether it'll be found depends on the keyserver configured on a local machine.

Instead of cloning the repo you can just download that tarball, I think it automatically unpacks and I will add my `pgp` key to the `readme`.

## Import

#### Question : I got the zpub from electrum. I thought that if you use a bech32 wallet, you get a zpub not xpub?

Fully Noded only takes `xpub` (from what i can tell you can not import `zpub` into bitcoin core)

If you have the `xpub` just select `bip84` in settings and it will derive bip84 addresses (bc1). You can use an xpub to generate `bech32` addresses, electrum does things a bit differently...

I think the reason electrum (and some wallets use zpub ypub etcc) is so the wallet knows which type of address to create, **at the end of the day what your are dealing with are private keys**, and there is only one type of private key, just different address types which are derived from the private key

Unless you opted in to using `BIP39` in electrum, your electrum `xpub` will not work in Fully Noded for now. You can create a new wallet in electrum, opt in to BIP39 and then it should work.

If you want to read about it from Peter Wuille [here](https://github.com/bitcoin/bitcoin/blob/master/doc/descriptors.md) it is (for what you can import into bitcoin core).

I got a good answer from Andrew Chow [here](https://bitcoin.stackexchange.com/questions/89261/why-does-importmulti-not-support-zpub-and-ypub)

#### Question : Why does importmulti not support zpub and ypub?

As far as I can tell importmulti does not work with zpub/ypub.

*Why not?*<br/>
I prefer only to deal with xpubs, but I am curious. Basically zpub,ypub is not part of bitcoin but an add on for wallets

Max: Lopp has a nice tool for switching an XPUB to a YPUB or ZUB and vice versa, [here](https://jlopp.github.io/xpub-converter/)

#### Question : I am not sure, I forgot, So have I basically at some point imported a bunch of addresses?
Your node(e.g. `nodl`) should see that too though.<br/>
The best way to do it is create new wallets in the node<br/>
In the app you go to utilities and create new wallet, and you import your `xpub` then. That way you can have multiple wallets that are dedicated for individual xpubs. <br/>


#### Question : How to import my BRD wallet?

You can go to the “active wallet” tab > + button > recovery > input your BRD seed words and optional BIP39 passphrase, then tap recover or you can import the `xpub` via `Active Wallet` > `import` > `xpub`


#### Question : `.txn` files, is there anyway to open on iPhone?

A `.txn` file is a signed raw transaction as exported by Coldcard. Fully Noded has registered the file extension `.txn` so that when you airdrop or tap a .txn file in the iOS Files app FN will automatically launch a `Broadcaster` allowing you to broadcast that transaction with your node. You can always copy and paste the raw transaction and go to `Tools` > `Transactions` > `Broadcast` to do it manually.

#### Question : How are you transferring the txs from the Coldcard to the iPhone - microSD card reader?
So on your coldcard you go to “dump wallet summary” in the sd card section<br/>
And get either your bip44 or bip84 xpub<br/>
Make a qr code with it or copy and paste it<br/>
In Fully Noded you go to settings<br/>
<img src="./Images/QR-settings.png" alt="QR-settings" border="0" width="200"><br/>
Inout your master fingerprint and the correct settings, then scan the qr-code of the `xpub`, and it will import whatever range of addresses you specified<br/>
You have to take the sd-card and put it into a computer and create the qr.
#### Further question : what the added benifit of going through the iPhone?
*It is just that if someone is signing a tx on their coldcard, then going to SD, they may as well broadcast from their computer rather than move it to their phone?*

Once you've done this, you can build `PSBT` and unsigned transactions and receive to your hw wallet.<br/>
My ideal setup is to have an airgapped laptop<br/>
And that SD card only ever touches the coldard wallet and the airgapped laptop<br/>
So its a true airgap.<br/>
Then you create your qr codes on the airgapped laptop, and scan signed txs with the phone<br/>
Build your unsigned transactions on your phone, and send them to airgapped laptop via QR code scanning.

#### Question : Gordian wallet. There is no “add manually” like in FullyNoded?

You can view node details in FN, there is an export button, it gives you a QR that you can scan or upload with Gordian Wallet.

##### Can I import a multisig wallet from Electrum into Fully Noded?  
*I want to use it as a watch only wallet*

Follow these steps:
1. You’ll want to tap “create multisig”.
2. Then you can paste your xpubs from electrum, FullyNoded wants fingerprints too thats bc some HWW require them. If you don’t know it you can input a fake one as it is not actually required for anything other then Coldcard. `00000000` will do the trick
3. I forgot to add ability to convert `Zpub` to `xpub` in the current version so you will need to use https://jlopp.github.io/xpub-converter/ to convert your Electrum Zpub into xpubs
4. Just paste in the xpub and add fingerprint, tap +, then when all have been added tap “create now”
5. The derivation is hardcoded to the most widely used default `m/48’/0’/0’/2’`, which from Electrum would be a `Zpub`.

## Export

#### Question : Why doesn't broadcast work via my Node?

You can only broadcast signed raw transactions. The only purpose of psbts is to end up with a signed raw transaction. e.g. The `.txn` file from Coldcard.

#### Question : Hardware wallet support?
<img src="./Images/Hardware-wallets.png" alt="Hardware-wallets" border="0" width="200"><br/>

They should all work with Fully Noded too. You can import your `xpub` directly into your node from your hardware wallets. I import my `coldcard` wallet xpub with Fully Noded, then build `PSBTs` with it.

#### Question : How to export your single sig wallet from Coldcard to Fully Noded using your own node?

See this instruction of 33 secs [here](https://www.youtube.com/watch?v=W0vwgzIrPoY). This is super cool, super easy. <br/>
Video is obviously edited, the spinner will take longer then that, just wait a bit

#### Question : Is there  a way to export the multisig.txt file anytime after the initial prompt when exiting the Multisig Creator flow?

Not right now... if you tap the `export` button from the `active wallet` tab you’ll get a wallet export QR, it holds all the info you need to manually create that txt.

I can add a .txt button there that converts it, that would prob make the most sense. To do it manually you'll need to tap that `export` button and extract the xpubs and fingerprints and put them into this format:
```
Name: Fully Noded
Policy: 2 of 3
Derivation: m/48'/0'/0'/2'
Format: P2WSH

fingerprint:xpub
fingerprint:xpub
fingerprint:xpub
```

You can also get that info by tapping the info button on the active wallet tab. You will see your "receive keypool descriptor" it also holds all xpubs/fingerprints needed.

#### Question : How export and backup my wallet into a QR code?

To make your life easier, you should save your wallet export QR code <br/>
Then if you delete the app you can always easily recreate the wallet from the QR<br/>
No need to touch your external signing device (like CC) again<br/>
In wallet details you'll see the export button in the top right corner.<br/>
Tap it and save that QR, if you need to recover the wallet just tap the `+ > "import" > scan said QR`

#### Question : Are there any security risks associated with export / backup? Loss of privacy (watch only), loss of funds?

Loss of privacy. Not loss of funds. It holds pubkeys only. More info [here](https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Wallet-tasks.md)

##### Further question : No need to touch my external signing device again? So then FullyNoded would be the signer??

No, signers are seperate, the QR is pubkey only. You have to add signer manually as words, if you'd like to spend the funds involved.

#### How can I import a 12 word mnemonic from Coldcard into FN wallet?
*FN defaults to a camera but the coldcard doesnt have QR codes on the screen (I'm using the BIP85 feature)*

Create a recovery wallet instead. More info in [troubleshooting](https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Troubleshooting.md) section.

## General

#### Question : What’s the difference between Gordian Wallet (GW) and Fully Noded (FN)?

1. GW is more focused on easy to use wallets, it will automatically create a 2/3 multisig wallet for you where your node is a signer as well as your device. Then you can keep one seed in offline backup to restore either your nodes signer or devices signer. So GW will give you your nodes seed words to back up and the purely offline seed words and of course you can access the devices words to back them up as well.
Much redundancy and flexibility
2. FN never adds a private key to your node unless you manually import an wif or xprv
3. GW does not give you access to every wallet on the node, FN does
4. GW does not have all the pure node functionality, again its a focused wallet
5. GW is account based it only signs with account xprv, FN keeps your master seed to sign with
6. GW has iCloud sync and sign in with apple, FN does not
7. FN has lightning, GW does not
8. Also GW is not released on mainnet or on the app store

##### Teamplayers Gordian Wallet and Fully Noded
The general idea is `multisig` is by far the most secure way to use bitcoin, both GW and FN are excellent multsig wallets, it’s generally a good idea to use many wallets for your multisig setup, with that in mind the two together make an excellent team.

##### Addition to point 1: example
So for example if your node dies or you lose your device you are well covered to recover the 2/3. What I do is add one set of words to other apps on other devices (as this diagram points out), so no one device can fully sign and spend.
<img src="./Images/FinalSolution.png" alt="Final FN multisig solution" border="0" width="600">

#### Question : Why is there no version for Android yet?

It is a budget issue. Android has bigger security issues. Tor is easier on Android.

#### Further question : Why would Apple not make Tor easier?
I wouldn’t say its Apple intentionally making it difficult. Its just the go to tor framework for iOS is not easy to get working.

I have `Tor` running fine and you can make normal url requests over `Tor` in the app. But when it comes to making url requests to onion sites (eg your nodes hidden service) it only works on simulator. I know its possible but I also know i am not the only one who has had this issue, very frustrating bc using your node as a backend via a hidden service is badass.

Onion Browser has the solution, worst case scenario I can fork it and include the entire codebase in Fully Noded, but I want to try and find a proper solution before I do that.

On android they have `orbot` and the path to getting tor working to onion sites for devs is easier.

#### Question : What is your privacy policy and how to comply with GPDR?

[Here](https://fonta1n3.github.io/privacy-policy/) is the privacy policy. It inherently complies with GDPR.

#### Question : Why did you choose iOS to build on? Any advantage compared to Android?

Only because that is what I know how to code with and what I am a user of.

#### Question: please elaborate on the seemingly *contradictory* statements about '100% offline signing'

"Fully Noded now acts like a hardware wallet, it can sign anything 100% locally with no internet required at all." says the *Introduction FN Wallets* Medium post July 1 2020 [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102).

"This works without internet connection but we do make a few commands to the node so it is not offline optimized. Perhaps in the future we will move to 100% offline." <br/>
says the *Introduction to FN psbt signers* a week later [Link Medium post](https://medium.com/@FullyNoded/introducing-fully-noded-psbt-signers-8f259c1ec558).

**Could you pls elaborate on that. My question is about the two medium posts of @Fonta1n3, that seem to have *contradictory* statements in it.**
It's not contradictory, it does sign 100% offline. FN makes other commands that require an internet connection though, it's possible to enhance that in the future. The 'online' commands that the signing process generates, do not reveal any sensitive data.

#### Further elaboration on the answer / issue
In order to make the signing functionality work as reliably as possible the app first checks if the psbt is fully signed, if it is it will finalize it right away and allow you to broadcast, if not then it passes the psbt to your node for processing with `bitcoin-cli walletprocesspsbt`, if for some reason the `psbt` you passed to the app does not hold all the `bip32_derivs` then that command will get your node to fill out the `bip32_derivs` (our offline signer needs the `bip32_derivs` in order to sign as they tell us what derivation path the private key needs to be derived with). The process command also gets your node to sign the psbt if it can, it is always possible a user has imported an `xprv` themselves into their node without FN knowing about it (FN2, now called Gordian Wallet, for example makes your node a signer), so that command accounts for that possibility.

All of the above can not be done offline, if it is going to be 100% offline we can't sign with your node and cant fill the `bip32_derivs` with your node.

We then loop through each signer on the device, decrypting them and seeing if its possible to sign the `psbt` with each. It then signs locally using the Libwally library.

#### Question : My transaction still says 0 confirm?

You can set a mining fee target in `settings`, if you want it to be confirmed quickly adjust this setting accordingly. Otherwise all transactions are `replace by fee` enabled in FN. To bump the fee simply tap the transaction and you will see a button for bumping the fee. If FN does not hold a signer for the wallet and the node can not sign then FN will allow you to export the new transaction as a `psbt` which you will need to pass back to your signer and broadcast again as utilizing `rbf` means you create an entirely new transaction.

#### Question : Any suggestion about this problem? All the username, password, and onion address are OK
<img src="./Images/err-network-conn.png" alt="err-network-conn" border="0" width="200">

Force quitting FN and rebooting `tor` on your `node` usually works. Sometimes Tor can get "stuck" especially if your node's machine has gone offline or been put to sleep. This issue may also be encountered if you connect to multiple nodes and switch between them, simply force quitting FN and reopening it resolves the issue and force refreshes the connection to the new node.

#### Question : "Transaction invalid: some outputs that it attempts to spend have been already spent or ... Did I set my fee's too low?

It probably was not `RBF` enabled to begin with.

#### Question : FN latest: “Added ability to share your node”. Please explain?

Embassy allows you to add your Node credentials manually, but I had come up with a url scheme that converts your node's credentials into a "Quick Connect QR" https://github.com/Fonta1n3/FullyNoded#quickconnect-url-scheme.

Standup, BTCPayServer, Nodl, myNode and Raspiblitz are supporting the QR. The "Share" button on your "node details" just takes your current node credentials and puts them into that QR format so anyone can scan the QR and connect to your node.

I talk about **Tor V3 auth, this should definitely be used, if you want to share your node** as if that QR gets leaked and you do not have auth setup anyone can access your node (your trusted others may share without you knowing for example). However with auth you need to explicitly add their pubic key to your nodes tor config, for example I can give you my QR codes but they are useless to you.

#### Question : Have you been able to overwrite other apps associations?

If you airdrop FN gives a choice

#### Question :  Does this imply that using my node is not private?

<img src="./Images/use-my-node.png" alt="use-my-node" border="0" width="200"><br/>
*I think it should say third party service or use my own node. In fact this should be a setting that you opt in right?*<br/>
Javier: I think that option is in case your node is not running Tor. If your bitcoind instance is not running over Tor each tx propagated is more likely to be deanonymized.   That’s the reason to choose propagate Esplora API.

#### Question : Do you have a lightning node? to send donations? The fees are currently high for a mainnet transaction.

Nope, lightning not ideal for large transactions anyway. Joking joking :)
I mean i can give you a lightning invoice if you’d like. I did get one set up with `electrum`

##### Further question : About donations : how are the addresses generated?
*does it fetch em? or are they hard coded in?*

Random address generated from an `xpub`.

#### Question : How to do c-lightning on mac with pruned node?

As long as you have bitcoin core already running and have brew installed (properly). C-lightning is pretty cool, you do not even to to "deposit" btc to your node anymore, you can fund any channel direct from any btc wallet.

##### Further Question: As far as I know c-lightning doesn’t fully support pruned nodes.   
*If bitcoind prunes a block that c-lightning has not processed yet, e.g., c-lightning was not running for a prolonged period, then bitcoind will not be able to serve the missing blocks, hence c-lightning will not be able to synchronize anymore and will be stuck)?*

C-lighting does support pruned nodes with this: https://github.com/Start9Labs/c-lightning-pruning-plugin. Works well and easy to setup, c-lightning does support pruned nodes out of the box, but this plug makes it very reliable, can be any pruned size as far as I know.

	lightning-cli fundchannel_start <node_id> <satoshi_amount>

Returns a segwit multisig address to send btc to<br/>
Does not matter where the btc comes from, as far as I can tell<br/>
I sent from my onchain wallet in FN and it worked.

#### How could I connect Casa Node and FN?

You have to enable ssh on the node (using keyboard and monitor), tehn ssh in, and setup a v3 hidden service.<br/>
More info on enabling ssh on Casa Node 1 [here](https://support.keys.casa/hc/en-us/articles/360045445811-Enabling-SSH-Casa-Node-1-) and 2 [here](https://support.keys.casa/hc/en-us/articles/360045007012-Enabling-SSH-Casa-Node-2-).

HenkvanCann: Be aware that Casa is no longer supporting their node. On social media like Reddit, it becomes clear that people move away from Casa node 1+2, and sometimes use the old Casa node to convert it into a myNode. <br/>
In the Casa site the Casa Node 2 is "sold out" ...


#### Can I turn on my LND server on MyNode to use FN as a lightning wallet in conjunction with an onchain wallet?

LND won’t work, And no, I won’t add it.

LND is written in Go code, which is owned by google, to talk to it remotely you need to use GRPC which also is also owned by google, you can not simply run a hidden service and speak to a LND node via http post request if i understand correctly, not great for ease of use.

Instead, c-lightning is built in C (an open language not owned by google), and is highly modular and flexible, super easy to build on top of with python plugins, very easy to talk to remotely and add powerful plugins to adapt to your needs. Fits into the Fully Noded architecture seamlessly.

#### How should I organise my signing with devices and multisigs?

If your using multisig but only use one codebase you're doing it wrong, in my opinion.

<img src="./Images/SingleSign.png" alt="Common Single Sign situation" border="0" width="500">
<img src="./Images/FNmutlisign.png" alt="Intermediate FN multisig" border="0" width="700"><br/>
<img src="./Images/FinalSolution.png" alt="Final FN multisig solution" border="0" width="1000">

HvC: This example is of course a 1 of 3, a 2 of 3 or 3 of 3, but in general it could be anything m out of n. The idea is that the CREATE diagram leaves an "unfinished / unsafe" state, THe EDIT is the final solution and "Proper FN multisign".

#### Question : Checking total supply. This is taking an inordinate amount of time for me and my screen eventually turns off.
<img src="./Images/Loading-data.png" alt="node-added" border="0" width="200">

*Can I return to this after the data has been fetched from the node or FullyNoded must remain active during the process? Also, my node is pruned so not sure if that’s contributing to the long delay.*

It should take about 3 minutes.

##### Further question : I do wish the app would cache the reply so that you can come back and tell you when it was cached...

Depends on the ram on your node, for me 8gb takes a minute, 2gb ram can take 7 min i heard. node must be on, prune doesnt matter.

The whole point is it changes every ten minutes. Tor gets killed immediately when the app goes into background. However, I have seen we can keep it alive for 3 minutes in the background though, will get around to taking advantage of that, would be nice for when quickly switching between apps to get invoices and stuff.

#### Question : I’m trying to connect to a ‘mynode` *community edition*. Is that still an option?

I dont know, better to ask on `mynode` group for a definitive answer, not sure exactly how `mynode` operates.

Have a feeling its a paywalled feature on mynode. i think all mynode does it puts a paywall around the convenience of automatically showing the `QR`, but again I am not sure. If they block you from `ssh`'ing and creating your Hidden services, that would be lame.

#### Question : Why does the `tor` service persist in the background even after I've shut down Gordian Server? Why doesn't Gordian Server shut down its service that it initiated?

[Answer in Gordian Server Q&A](Link to be supplied)

## Connection

#### Question : How do I connect my node?

Click to look up the answer in [the FAQ](https://fullynoded.app/faq/#How-Do-I-Connect-My-Node)

#### Could not connect to the server... What to do?

Follow the steps [here](../Readme.md#connecting-over-tor-mac). Always remember you will have to brew services restart tor, you will have to force quit and reopen FN to connect again, for the authentication to take effect.

#### "The internet connection appears to be offline..." but I am online, what to do?

This response is often related to failing authentication. Have a look at [this section](../Readme.md#connecting-over-tor-mac) in the *Readme.md* for an extensive guide and a double check section [here](../Readme.md#preparatory-work)

#### Can I connect FN  to my node over local wifi?

FN only connects over Tor so its not possible in the app for now to connect over local wifi. It’s something that could be added fairly easily but is not there now (in July 2020).


#### Question : how risky is to open port 22 to connect from anywhere outside my local lan?

First off I am not a security expert. But from what I have read SSH is generally very secure. However there are some simple steps you can take to make it much more secure.  You can read more from the Fully Noded github [here](https://github.com/FontaineDenton/FullyNoded/blob/master/Readme.md#security)

The goal of this app is to avoid `SSH` altogether and use Tor so you can keep your node firewalled off completely, its working if you build the app from source, We've got mobile fixed by now.
Its also more secure if you use an RSA public key / private key to authenticate SSH which is also possible in Fully Noded
I would just do your own research on `SSH` security and see what you come up with, let me know what you find.

#### Question : I get a channel alocation error when I try to add a Xpub. What could go wrong?

Means the ssh channel closed. Just go to home screen and pull to reconnect.<br/>
It takes around 20-30 seconds when you import an xpub, so just wait for it to finish

#### Question : In true airgapped situation: no need for a Coldcard? Just create signed TXs on the airgapped laptop?

Some people would argue that its more secure to create keys on the `coldcard`. Also getting software onto the airgapped laptop without compromising the security of it, is another factor.

Max: I wouldn’t be so worried about an air gapped laptop. As it’d only be handling transactions that had been signed.

#### Question : Do I have to be in the same network?

Best way to find out is try. FN over Tor v3 should allow you to access from anywhere.

#### Question : How do we get the rpc credentials on the nodl?

You have to log in like this [link](https://docs.lightning-solutions.eu/nodl-box/advanced/how-to-access-bitcoin-cli-and-lncli) shows you.
And open up the bitcoin.conf file. You need to add RPC credentials. <br/>
*Is it on the UI?*<br/>
Jamie Lim: Ssh into the `nodl`, The ssh host user should be “bitcoin”

#### Question : RPC credentials are mandatory. FN is forcing good behaviour?

Just keep it in mind because if you have not added RPC credentials: the node won't connect. <br/>
Honestly, just way better code wise. And allows you to connect over local network with no internet which is cool if you like doing stuff offline. Also should make connecting in general more robust and work on all systems even better.

#### Question : Do you use a terminal app in iOS on the iPhone that you ssh into your network with?
I use NMSSH framework in the app<br/>
There are apps though, i think `iterm` has an app that also uses the same framework -> <br/>
iTerminal - SSH Telnet Client by ComcSoft Corporation https://apps.apple.com/us/app/iterminal-ssh-telnet-client/id581455211<br/>

#### Question : How do I troubleshoot connection issues over Tor between FN and Bitcoin Core Nodes on a Mac?

Here are some [common issues and fixes](https://github.com/Fonta1n3/FullyNoded#troubleshooting). You can troubleshoot Tor issues on the mac by opening a terminal and running `open /usr/local/var/log/tor.log`, read the Tor log and make sure there is nothing obvious going wrong there. Most Tor issues revolve around permissions. Ensure your `HiddenServiceDir` has the correct permissions by running `chmod 700 <HiddenServiceDir>` where `<HiddenServiceDir>` represents the path to your `HiddenServiceDir` as specified in your `torrc` file which can be found at `/usr/local/etc/tor/torrc`. The Bitcoin Core log can be helpful too, however you must have the `debug=tor` line added to your `bitcoin.conf`. You can run `open ~/Library/Application\ Support/Bitcoin/debug.log`

**You are also better off launching Tor as a service**<br/>
1. first ensure tor has stopped
2. then open a terminal and paste in `brew services start tor`, this will ensure Tor always launches automatically when your mac starts, if you want to stop tor run `brew services stop tor`<br/>

**Possible problems during installation and configuration**
1. It may just not have permissions to create directories which would explain the lib folder not existing.
2. Running without `brew`. You can defo do it without brew, its just more complicated.
3. You really should *edit* the file and *save* it too. Double checked?

##### Further question : Maybe I need to do some changes on my firewall due to the tor service?

The beauty of tor is your node can be 100% behind a firewall

#### Question : How can I test the network connection between them (FN and Node)?

***Big Disclaimer:***
> This is not great for security, so I would refresh your HS hostname after trouble shooting this and change your rpcpassword. All you have to do is delete the ‘HiddenServiceDir’ folder and restart tor and you'll get a brand new url.

> Before doing the below, try rebooting Tor on the node server side, force quitting FN and see if it connects, double check you added your tor v3 url correctly with the right port at the end, typically `:8332` for mainnet.

Recreate your hidden service url like so: `http://rpcuser:rpcpassword@xxx.onion:8332`, paste it in to a Tor browser as if you were visiting a website, if your connection is alive and functioning properly you will get a `server only responds to POST requests` error or `JSONRPC server handles only POST requests` error in the Tor browser. If you do not get that error then something is wrong, again check the Tor and Bitcoin Core logs to debug the issue.

#### Question: What is the best of breed desktop wallet to connect to your node?

[Specter](https://github.com/cryptoadvance/specter-desktop), to build from source use following commands in a terminal:
```
git clone https://github.com/cryptoadvance/specter-desktop.git
cd specter-desktop
virtualenv --python=python3 .env
source .env/bin/activate
pip3 install -r requirements.txt
pip3 install -e .
python3 -m cryptoadvance.specter server
```

That will install and launch Specter, once installed the only commands you need to launch it:
```
cd specter-desktop
virtualenv --python=python3 .env
source .env/bin/activate
python3 -m cryptoadvance.specter server
```
See [this](https://github.com/Fonta1n3/FullyNoded#importing-a-wallet-from-specter) for instructions on exporting a wallet from Specter to FN.


#### Question : Can't seem to locate the torrc file to connect via Tor using Nano. What's wrong?
*I did try directly entering the nano in cmd but it is blank. Okay, I  realised that the file name is torrc.sample instead. Weird. nothing inside this nano as well.*

When you make the nano command what exactly are you typing? the torrc.sample is just that a sample, it's possible when Tor has not yet been started that it does not auto generate the torrc? You can always use the torrc.sample to create a torrc, just copy and paste it and delete the .sample extension and then follow the guide to edit it.

When you use nano you either need to be in the directory of the file you are trying to use nano on or include the path nano `/usr/local/etc/tor/torcc.sample` for example. If nano is not working just use whatever text editor youd like to.
Try starting Tor, it'll generate the `torrc` then.

	brew services start tor

To be honest this makes it really easy and works with your existing node: [Gordian](https://github.com/BlockchainCommons/GordianNode-macOS/blob/master/GordianNode_0.1.1.dmg)

You can download the dmg right on the link, just open it and it does everything for you.

If you want to do it manually that works too :)

#### Question : Looks like I'm connected. But no homescreen, what's wrong?

*It says it connects successfully but no matter how long i let the app run it never looks like your pic.*<br/>
<img src="./Images/node-added.png" alt="node-added" border="0" width="200">
<img src="./Images/node-added2.png" alt="node-added2" border="0" width="200">

It says successfully **added**. Actually connecting is only successful when the home screen has loaded.<br/>
Are you absolutely sure the rpc password and username and onion are 100% correct?<br/>
Have you tried rebooting the node?<br/>
Are there any special characters in the RPC password? Only alphanumeric is allowed but the app should warn you about that now..<br/>
Generally rebooting Tor on the node would solve this issue if everything else is correct<br/>

I definitely need to reboot tor on my MacBook sometimes but only after it is asleep... servers should not have that issue, occasionally I’ve had users (and myself) need to reboot tor on the initial connection attempt.<br/>
W is there any possibility your isp is blocking tor? That has also been an issue before. (On your phone i mean)<br/>

For starters ensure you are connected to your node, can you confirm it successfully connects?

If your connection is successful you’ll see the home screen look like this:<br/>
<img src="./Images/opening-screen.png" alt="opening-screen" border="0" width="200"><br/>


####  Question : what's this about *Tor V3 Authentication Public key* in settings > security center > Tor V3 Authentication?

Tor V3 hidden services have the ability for “out of band” authentication. Meaning you FullyNoded can create a private key offline and you can export the pub key to your node to authorize your device. It makes the connection super secure and in the words of the tor devs “superencrypted”<br/>
It means only your device can ever access your node even if someone go that RPC QR code. Highly recommended to do that.<br/>

In order to add the auth key you need to use the following command:<br/>
`sudo nano /var/lib/tor/theNodlTorDirectoryName/authorized_clients/fullynoded.auth`<br/>
Then paste the pubkey and save the file (type ctrl X and enter)

##### Troubleshooting
A user had to create the HS directories manually first, then change the DIR owner to toranon user. Reportedly, reading the tor log files helped a lot.<br/>
`StandUp.app` makes it super easy if you have a mac or the StandUp scripts also make it incredibly easy.

You can confirm the authentication is in effect by looking at your hiddenservicedir authorized_client dir and see if any files are in there which will end in `.auth` and contain your pubkey descriptor. To remove `auth` -> remove all files from that dir.

#### Question : C-lightning - I added details of node. Clicked gear icon - got 'method not found' error. What to do?

Did you install the http plugin In lightningd?

Follow this guide. It is a new way of connecting and controlling `clightning`
You’ll need to ask `mynode` to implement it, nodl, BTCPay etc...

I’ll write a script that makes it easy but you will still need to be comfortable with a script. If you’ve already got `clightning` running its quite simple: [guide](https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Lightning.md).


#### Question : App gets backgrounded and then when I foreground it a few times it eventually crashes. What is wrong?

Thats `Tor` being responsible, it'll happen occassionally. I will eventually get this fixed by keeping `tor` alive for 3 minutes would go a long way to prevent that crash.

#### Question : I get confused when reading pubkey and privkey in Tor context; an onion address consists of tor public and private keys?

The auth has nothing to do with wallet creation. [Here](https://matt.traudt.xyz/posts/creating-private-v3-FgbdRTFr.html) is a decent explainer by Matt Traudt.

If you'd like to deepdive into the subject: [here](https://github.com/torproject/torspec/blob/master/rend-spec-v3.txt) the *Tor Rendezvous Specification - Version 3*

#### Question :  FN requires RPC creds inputted in order to create a hot wallet that will then provide Tor v3 auth, is that correct?

`Rpc` has nothing to do with `tor auth`. Rpc credentials are needed to make commands to your `node`.

FN just generates a public private key pair that adheres to Tor V3 auth spec. Totally independently of anything on your node. It’s purely tor Hidden service related. Hidden service just happens to control bitcoin core rpcport.

HowTo: <br/>
<a href="../Videos/IMG_3130.MP4" target="_blank"><img src="./Images/Video3130-screen.png" alt="Tor-Hidden-Service-configuration" border="0" width="200"></a>

FN never creates a hot wallet on your node unless you explicitly go to `“advanced” > “bitcoin core wallets” > + > hot`. The Tor auth has nothing to do with wallet creation.

#### With myNode, over `tor`, i'm always getting "network connection was lost" right after tor connected. What to do?

You have reboot tor on mynode. Without having to reboot the whole node, use<br/>
`systemctl restart tor`<br/>

#### Question :  I am connected to my raspiblitz node and I get this Lightning "Method not found" error.
<img src="./Images/lightning-raspiblitz-error.jpg" alt="lightning-raspiblitz-error-screen" border="0" width="200"><br/>
*I got that message just by clicking on the lightning icon here on the main screen. I can access my node but not the lightning* <br/>
<img src="./Images/verification-progress.jpg" alt="verification-progress-screen" border="0" width="200"><br/>

Javier: You need to follow this guide. https://github.com/Fonta1n3/FullyNoded/blob/master/Docs/Lightning.md
@Fonta1n3: there is difference now. To add the lightning node tap the lighting button on home screen then the settings button, it should also automatically prompt you.

#### Question : Do you use wireguard to connect to your nodes?
*All it is is a vpn right? Just need to add an IP:port to connect? - Raised by Fonta1n3*

Max: Need a VPN server obviously but yes, an IP and port with the WireGuard app together with a keypair.

##### Further Question: Where does the keypair fit in?
*Adding ability to connect to localhost, and it dawned on me it would be very trivial to allow people to connect using their VPNs*

##### Further answer:
Max: each device you have has a separate key pair for authentication. So basically your router has a bunch of public keys
 and you can generate the private keys on each client, just like tor v3 auth.<br/>
If you added the ability to connect to your local host and someone was connected to their WireGuard, it should just work as they would be local

1. If we just add abilty to use a normal IP instead of only onion, that should work.
2. Also for OpenVPN users too
3. And the traffic over VPN is always encrypted, from your client to your router

Benefits:
- Could make it a whole lot more accessible
- And less latency
- And dont have to rely on Tor

#### Question : What is a good local network connection set-up to your nodes?

Max: I generally recommend people to have a config that allows them to set up DuckDNS<br/>
So basically they will have a `Pi` or something similar running the `WireGuard` server. Their router will not be a fixed IP.

So folk can register a domain for free like `fontaine.duckdns.org` and an an app will check the IP address the router has
 and update the corresponding IP with `DuckDNS`.

##### Further Question: Where does the keypair fit in?
*Fonta1n3: So for the nodes side, say your `nodl` Do you expose it to something other then localhost? Other then the `vpn` obviously... T<br/>here is nothing stopping people from doing something really dumb
Like exposing their node to the entire internet unencrypted*

##### Further answer:
Max: Only `Tor`<br/>
The Home Assistant UI where I can administer my `BItwarden`, `DuckDNS`, `VPN` and `Adblocker` I can access over a userinterface. <br/>
So ports are forwarded and I have a `letsencrypt` certificate for that.
About doing something really dumb:<br/>
You wouldn't actually be doing anything there right, though? People's nodes will be accessible on their local network anyway.
For example by `SSHing` into the network (just not using `FullyNoded`).

#### Question : Can I connect FN on iPhone to my own node via FN on Mac?

Yes, no need for the user to worry about `Tor` at all. just use `macOS` FN which runs its own tor node embedded in the app, it hosts a hidden service itself. **This obviously only works if you have Bitcoin Core running on the same macbook.**

Next macOS update (in Sept 2020) will have a new button on the node credentials view for showing a QR code for connecting your iOS device.

#### Question : How to run your own node and connect to it with Fully Noded macOS?

Just follow the easy steps in this [instruction video](https://www.youtube.com/watch?v=_7MZd0weDis) on youtube.


## Wallets

#### Question : How do I create a wallet in FN?

Lookup the answer in the FAQ [here](https://fullynoded.app/faq/#How-Do-I-Create-a-Wallet)

#### Question : How I can erase a wallet in Fullynoded? or modify a name?

If your node is on a mac you will need to navigate to

	⁨Root ▸ Users⁩ ▸ ⁨Arkad ▸ ⁨Library⁩ ▸ ⁨Application Support⁩ ▸ ⁨Bitcoin⁩ ▸ Wallets

BUT as Satoshi says, you should never delete a wallet, instead much better to move it, just incase.

On your `nodl` I am not 100% sure of the path to find the wallets, but it is in the main bitcoin directory, shouldnt be too difficult to find.
To modify the name just right click the wallet on your mac and rename, in `nodl` you have to find the path to your wallet and use `mv` command, heres an example:

	mv /home/user/oldname /home/user/newname

More info in the site's [FAQ](https://fullynoded.app/faq/#How-Do-I-Delete-a-Wallet)


#### Question : what is the recovery wallet?

Read the manual [here](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102)

#### Question : can fullynoded recover mycelium wallets?

Mycelium on iOs is not maintained. But yes, FN should be able to recover your wallets. According to walletsrecovery.org they are bip44/49/84, if thats correct then it certainly will

#### Question : Which faucet works the most reliable for testnet:

https://bitcoinfaucet.uo1.net/; accepts bech32 multisig

#### Question : So where is the private key stored then? On disk somewhere?

If you create a “Fully Noded Wallet” the words are encrypted and stored on the devices keychain which is yet again encrypted
Then we derive the child. Private key on the fly everytime you go to send or sign a tx from the words

#### Further elaboration on the question: and since everything on iOS is sandboxed its pretty difficult for a different process or thread to peek at the contents of fully noded; right?

Further elaboration on the answer :  Should be “impossible “
The worst malware i can find are adware where an app gets you to click invisible ads.

#### Question : The keychain encryption key is stored on the secure enclave?
*So its very hard to crack that open once you have the device, which bricks itself without the icloud password?*<br/>

On FN its stored on the local keychain (secure enclave) only, no icloud support. Gordian Wallet (formerly known as 'FN2') account `xprv` can be synced to icloud. But again its encrypted three times by then.

#### Question : What’s the diff in importing Xpub and import descriptor under wallet?

`Descriptor` has the derivation, address range, path and address format in it, can also specify multisig and `bip67`
A descriptor can hold an `xpub` and derive specific addresses

An `xpub` is very generic and you need more info to go with it <to do what? - TBW>
`Descriptor` is a very specific way of telling a wallet to derive these very specific keys, `xpub` is not specific at all and up for lots of interpretation with possibility of really messing it up.

The coldcard export and the txt file are basically `descriptors`.... when you import an `xpub` into FN it gets converted onto a `descriptor`. When you create a multisig wallet it creates a `descriptor` for you and the wallet uses the `descriptor` to derive keys.

#### Question : how to create a 2 of 2 multisig wallet with my Coldcard and FullyNoded?

Video on how to easily create a 2 of 2 multisig wallet with your Coldcard and FullyNoded: https://m.youtube.com/watch?v=daXvAcHy8H0

#### Question : In `wallet - invoice`: Is there a way I can go back to a previous receive wallet address?

Not really... its possible if you imported multisig descriptors manually though.<br/>
We should discourage the re-use of receiving addresses for the sake of privacy protection.<br/>

#### Question : I recovered from Greenwallet and didn't get a balance, Iim wondering if FN scans all the BIP lines?
*Green is a compatibility wallet in default. Am I missing some between BIP 32 and 49?*

Green wallet is a 2 of 2.The recovery wallet is for single sig. You can recover any multisig with the FN multisig wallet “creator” just add your own seeds or xpubs.

##### Further question : So the wallet I recovered is a single sig based on same multi seed? Given that fact...best to create a fresh FN wallet and go from there? I don't want to confuse myself any further. I like the privacy of FN. I basically want to switch from Green Wallet to FN for my daily driver.

Yes, i think you are very locked into their wallet (Green Wallet) and can only really recover with them? Not sure though. <br/>
Also, you can not recover any multisig with the multisig creator, currently it keeps the derivation hard coded. We will definitely update that in the future. It is a start for now.<br/>
Nice that you want to use Fn on a dally bases, yea for simplicity id recommend the single sig!

#### Question : Are wallets enabled on the config page of bitcoin in the Embassy App?

FN works with walletdisabled=1, home screen doesn’t include any wallet rpc calls.


#### Question : I clicked on the file again and now I have 2 cold cars records in the FN app. Would I see 2 wallets in FN that showed the same exact info?
*Each is appended with some sort of unique code. I would think that they should say the same thing, but one "has" the 10 bucks i sent to it and the other has nothing. shouldn't they match exactly since they are the same?*

No. When you import a wallet it first creates a new wallet on your node with a random string at the end, if that import fails as yours did (it happens rarely) `the wallet.dat` filename in your nodes.<br/>
`.bitcoin` directory will hold different wallets, also if it fails you can not have any idea what was actually imported. <br/>

So you should tap the "squares" and only ever work with that wallet.<br/>
If the wallet is there in the "Fully Noded Wallets" section then you know it is all good.

##### Further Answer:
You should really completely ignore your "Bitcoin Core Wallets", unless you are a bitcoin-cli expert and know exactly what you are doing and why.

It's really just there to help people recover wallets that exist on their node. Really need to make some tutorials and add an "advanced" button in settings that shows and hides some features, like accessing non Fully Noded Wallets.

By far the best way to use the app is stick 100% with FN wallets.

Aka use these two buttons to create and switch between wallets<br/>
<img src="./Images/switch-buttons-wallets.png" alt="switch-buttons-wallets" border="0" width="200"><br/>
FN wallets will always show as COLD because your node never holds a private key<br/>
<img src="./Images/switch-wallets2.png" alt="switch-wallets2" border="0" width="200">

#### Question : Does fully noded need the wallet from bitcoin core?

It should work with it disabled. But it’s been awhile since i tested that.

#### Question : This wallet was created on FullyNoded why would I be getting this error.   I want to delete via “I” button
<img src="./Images/Oops-wallet.jpg" alt="standup-screen" border="0" width="200"><br/>

Please stop using the "Bitcoin Core Wallets" and use the "Fully Noded Wallets"<br/>
You need to tap the *squares* button, from *active wallet* tab. those are your fully noded wallets<br/>
There is a huge difference between a `wallet.dat` file that exists on your node and a "Fully Noded Wallet"<br/>
You can only delete` wallet.dat` wallets, by going onto your node and deleting them.

#### Question : How do I delete a (FN) wallet?

Look up the answer in [the FAQ](https://fullynoded.app/faq/#How-Do-I-Delete-a-Wallet)

#### Question : What’s the diff between FN wallets and bitcoin core wallets in the app?  
*When added to bitcoin core it doesn’t show up in FN wallets but when add a FN wallet it shows up in bitcoin core.*

The first section [of this link](https://medium.com/@FullyNoded/introducing-fully-noded-wallets-9fc2e4837102) explains it in detail.

FN is powered by your node. You can create wallets on your node without FN. Either with your node (using `bitcoin-cli` or the `Core app`) directly or other apps.

FN lets you access those wallets and in the app refers to them as "Bitcoin Core Wallets". FN *does not know anything about them* other then that they exist, FN is just a user interface between you and your node for those wallets.

For "Fully Noded Wallets", they MUST be created in FN. That way FN can remember certain things about the wallet, for example everything you see in "Wallet Details" is only possible to see, because the wallet was created in the app.

So FN has its own database it stores you descriptors, label etc. for that wallet, which is why you can edit the label, refill the keypool, have an address explorer etc.

If you create a wallet using electrum or Join Market or bitcoin-qt, FN has no clue how that wallet was created or what was added to it.

F**N wallets are of course also created on your node**, the only difference is the app knows more about them and they are created in a "smart" way.

Generally, if you are not familiar with `bitcoin-cli`, then you should ignore your "Bitcoin Core Wallets" in FN, hence why they are in *advanced* tab.

One of the really cool things about FN is you can add seed words as a "signer" to FN, and then spend from any watch-only "Bitcoin Core Wallet" wallet on your node. This great for all kinds of ([recovery](./Recovery.md) scenarios.

#### Question : I tried to spend UTXO from multiSig wallet - running Bitcoin 0.20.1 and got an error. What's wrong?

Electrum is broken it seems ( [here](https://github.com/spesmilo/electrum/issues/6503) : *Electrum rejects Bitcoin Core 0.20.1 psbt's · Issue #6503 · spesmilo/electrum*.

In the latest Bitcoin Core release psbt's may include both `non_witness_utxo` and `witness_utxo` to mitigate the vulnerability Trezor found recently.

To fix it you can revert to bitcoin core 0.20.0.

Aug 2020 : MOST PROBABLE THIS ISSUE WILL BE SOLVED SOON AND IF YOU WON'T EXPERIENCE THE ERROR ANYMORE

#### Question : How to have a watch-only wallet to track BTCPayserver incoming funds?
*...without running into `gap-limit` problem. What kind of wallet should I use, Bitcoin core or Fully Noded wallet?*

Fully Noded, because you can always easily increase the gap limit with a Fully Noded wallet. And it also by default watches 1.5x more addresses.

##### Further question : how do I know it's time to increase the `gap limit`?
Youll get an alert from FN. You need to really use a ton of addresses before that happens. <br/>
After you create the wallet → Tap the info button → Youll see your current index and the max index <br/>
You can at anytime edit the max index.

#### Question : Why would a new Fully Noded wallet be watch-only when it should have a private key at least.

Because it keeps the signer on your device, not on your node. Pls read the docs from [here](https://github.com/Fonta1n3/FullyNoded)

##### Further question: But I'm trying to encrypt the wallet on device. I just created wallet, go-to settings, security, encrypt - error...

##### Further answer :
Your seed is already encrypted. The command you are using is the bitcoin-cli encryption. That error you're getting is for your node.<br/>
```
bitcoin-cli encryptwallet
```

If there is nothing to encrypt it won't encrypt. Your wallets private keys are by default encrypted in the device. No private key ever goes to your node.

#### Question: Private keys are by default encrypted in the device. But there is no password in the app. How's the seed protected?

The first thing the FN app does is create a private key it uses for encryption. It gets encrypted itself and stored on your devices secure enclave.
When you go to create a FN wallet or add a signer it *always* gets encrypted before it gets saved.<br/>
This is obvious in the code, which is open source and signed off by me. A checksum is available. See [the asnwer to this question]()
if you like to learn the nuances of these security proofs and what they are worth.

##### Further question : But it shows the seed phrase without any authentication. Regardless of the Biometrics setting. How can that be secure?

##### Further answer :
It's done programmatically. If you don't want someone to open the app -> add a password or biometrics. It's setup so that if a hacker got your device, they would not be able to jail break it and get your seeds. You should definitely use the password to lock the app.

If you are security conscious, you can also just delete the signer for that wallet. Then when you want to spend, add it again. It's easy to do.

#### Question : Can I sweep an old paper wallet?
<img src="./Images/paper-wallet-sweep.jpg" alt="paper-wallet-sweep-screen" border="0" width="200"><br/>

Yes, but Fully Noded wallets are not capable of that. You will need to use the nodes default wallet `"advanced" > Core wallets > default`

Sweep it and then spend it to your Coldcard Fully Noded Wallet (or whatever you want to do). You will need to rescan before balances show up as usual.

## Standup

#### Question : where can I download this?

[Answer in Gordian Server Q&A](https://github.com/BlockchainCommons/Docs/q-and-a.md)

#### Question : what kind of compromises would standup have to make in order to be distributed via the mac app store?

[Answer in Gordian Server Q&A](https://github.com/BlockchainCommons/Docs/q-and-a.md)

#### Question : If I allready have a full node running on my Mac. Can I use the standup app with it?

[Answer in Gordian Server Q&A](https://github.com/BlockchainCommons/Docs/q-and-a.md)

#### Question :  I am about to start a full node on mac. Can I change the directory to an External SSD with the standApp?
[Answer in Gordian Server Q&A](https://github.com/BlockchainCommons/Docs/q-and-a.md)

## Transactions

#### Question : How do I specify a fee rate in FN?

You can just set the min relay fee (smallest possible amount) and if the transaction doesn't get confirmed, you can "bump" it, i.e. use Replace By Fee transaction. That is a new transaction with a higher fee using the same `UTXOs` as an input.

#### Question : Can I create transactions in USD?
Yes, you can create transactions which are denominated in USD, this video shows the new look for the transaction builder, how to switch to fiat denominations and then how to confirm the transaction before you broadcast it:<br/>
<a href="../Videos/IMG_3025.MP4" target="_blank"><img src="./Images/fiat-curr-transaction.png" alt="fiat-curr-transaction" border="0" width="200"></a>

## Node

#### Question : I changed bitcoin.conf according to guideline, why is it still not working?

Did you restart your node? If you change config file you need to restart `bitcoind`.

#### Question : how to create a Tor V3 hidden service to control your node?

I have updated the github with easy to follow instructions on how to create a Tor V3 hidden service to connect to and control your node with on a mac [here](https://github.com/FontaineDenton/FullyNoded/blob/master/Readme.md#connecting-over-tor-mac-edition).

#### Question : Anyway to connect node via bitcoin core QT? Can't get to find any QR code from the QT core on Mac OS.

This is a good guide this is a good guide : https://github.com/Fonta1n3/FullyNoded#connecting-over-tor-mac

#### Question : Is there currently a way to execute bitcoin-cli rescanblockchain with the start/stop height parameters from within fully Noded?
*especially with some slick autocomplete for commands and parameters. rpc syntax can be a pain sometimes.*

No, I need to add that to FN app. It should automatically rescan from prune height though *if* your pruned.<br/>
Anyway, doing it the way Fully Noded does it adds a layer of complexity too. Extra need for escaping characters, absolutely stuff that’s not needed, if doing it straight via terminal.

Definitely something to be said about a cool UX where it autosuggests the rpc call and then shows a UI for the params with explainers.

#### Question : Is there an ability to add peers and remove peers?
Not yet, but I think it is an important thing to add as far as "direct rpc calls" are concerned.<br/>
There’s a cool project that lists a bunch of trusted tor nodes, so you can add them if you want to use your node 100% behind tor without getting attacked by chain analysis.

Would need to start simple and expand... sigh so much to do so little time. Wish there were other swift devs who would help out.

#### Question : So the order of fully noded is 1. Node 2. Wallet? Correct? Without a node, you can't scan in a wallet?

You **can not do anything in FN without connecting to your node** first.

#### Question : If you start rescan of blockchain does the app have to stay open the whole time for it to rescan?

No, your node will keep rescanning, the only way it will stop is if you tell it to stop or it naturally finishes

#### Further Question : If I add an xpub I assume I need to rescan. Does rescanning take hours/days on a pi?
It depends how far back you want to rescan, you can set any custom date to scan from. If it's 2gb ram and a full rescan it'll prob take ~two hours? <br/>
N8r: about 4 hrs on pi3

#### Question : Can I use a pruned node with FN?

Of course, I use with pruned only. There is a few areas where a pruned node lacks the functionality needed that FN requires, so it smartly checks for that and if the node is pruned it falls back on `Esplora` over Tor v3; essentially only for parsing every input in your transactions for the verifier, if one of the inputs does not belong to you we fall back on `esplora` to fetch the raw transaction associated with that `txid`

just set `prune=550` in your `bitcoin.conf` when you go to get the `rpc` credentials. A pruned node only needs 500 megabytes.
