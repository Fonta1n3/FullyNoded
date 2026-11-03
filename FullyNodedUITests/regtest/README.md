# UI tests against regtest

`FullyNodedUITests` drives the real app in the simulator against a local regtest node, so
a new Bitcoin Core or Knots release (or a change to Fully Noded) can be checked end to end:
connecting the node, creating, funding and recovering wallets, sending, sending to a silent
payment address, and payjoin between two simulators.

Everything runs in the background: no screen control, nothing to tap.

## Quick start

```bash
cd FullyNodedUITests/regtest
./node.sh list                       # Core / Knots builds found (FN-Server's installs, Homebrew)
./node.sh core-32.1 fresh            # new regtest chain, funded "miner" wallet
./run.sh build                       # build Fully Noded and the tests once
./run.sh test "iPhone 15 Pro" RegtestTests
```

Every build on two simulators (one should be small, like an iPhone SE, to catch layout
problems):

```bash
./matrix.sh <simulator A UDID> <simulator B UDID>
```

`xcrun simctl list devices available` lists simulator UDIDs.

## What's tested

`RegtestTests` (one simulator, in order; later tests use the wallet the first creates):

| Test | Checks |
|---|---|
| `test1_ConnectNodeAndCreateWallet` | manual node setup (`127.0.0.1:18443`), home screen shows the node's version, single-sig wallet creation, receive address, balance after two payments |
| `test2_SendNormally` | Send → create, decode, sign, `testmempoolaccept`, broadcast; the tx is in the mempool and pays the recipient |
| `test3_SendToSilentPaymentAddress` | the wallet's own `tsp1…` address (after the heads-up), send to it; the tx has the taproot output |
| `test4_RecoverAfterDeletingWallet` | remove the wallet in Fully Noded, unload and delete it on the node, recover from the seed; same node wallet, same balance |

`PayjoinTests` (two simulators at once, `run.sh payjoin <receiver> <payer>`):
`testReceive` publishes a payjoin invoice from the receive screen and waits for the payment;
`testSend` pays it and checks the receiver's coin is in the broadcast transaction.

Not covered: FN-Server's silent payment scanner (a Mac app; see SilentPayments.md for the
manual steps) and hardware/air-gapped signing.

## How it fits together

- `node.sh` runs one build at a time on the regtest ports (`18443`/`18444`), each with its
  own data in `$FNUI_WORK/<build>` (default `$TMPDIR/fnui`). It creates an RPC user `fntest`
  with a random password in `$FNUI_WORK/fntest.secret`. `FNUI_FNS_RPCAUTH=1` also lets
  FN-Server's RPC user in, for testing its scanner on regtest.
- `run.sh` passes settings to the tests as `TEST_RUNNER_*` environment variables (nothing
  secret is in the scheme or the repo): the RPC password, the node's data folder (for the
  recovery test), a folder shared by the two simulators (payjoin invoice), and the app
  password if `$FNUI_WORK/applock.secret` exists (for a simulator whose app has a lock).
- Simulators share the Mac's network and home folder. In simulator builds each Fully Noded
  keeps its Tor data in `~/.tor_tmp-<simulator UDID>`, and the launch argument
  `-simTorPortOffset 10` moves its Tor ports, so two can run at once (`run.sh` adds it for
  the second simulator).
- The tests talk to the node directly over RPC (`RegtestNode.swift`) to fund wallets, mine and
  check results.
- `FNFlows.swift` holds the user-level steps; `FNUI.swift` finds elements by their visible
  text (the app has few accessibility identifiers) and answers Fully Noded's interstitial
  alerts. The first test of a run sets *Settings → Fully Noded → Paste from Other Apps →
  Allow*, since the paste prompt blocks the app while it's up.

## Writing new tests

`drive.sh` runs `RemoteDriver` on one simulator, so you can step through a screen and see what
the tests see:

```bash
./drive.sh <UDID> start
./drive.sh <UDID> '{"op":"tap","text":"bitcoinsign.square"}'   # result: visible elements + screenshot path
./drive.sh <UDID> '{"op":"type","field":"0.00 000 000","text":"0.1"}'
./drive.sh <UDID> stop
```

The commands are listed at the top of `RemoteDriver.swift`.

## Logs

`$FNUI_WORK/last-test-<device>.log` (full xcodebuild output), `$FNUI_WORK/results/*.xcresult`
(screenshots of failures), and the node's `debug.log` in `$FNUI_WORK/<build>/regtest/`
(`debug=rpc` lists every call Fully Noded made).
