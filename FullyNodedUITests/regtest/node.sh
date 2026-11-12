#!/bin/zsh
# Regtest nodes for the UI tests, one Bitcoin Core / Knots build at a time on 127.0.0.1:18443
# (the port FN-Server's silent payment scanner uses for regtest).
#
#   node.sh list                      builds found (FN-Server's installs, Homebrew, $BITCOIN_BIN)
#   node.sh <build> start|stop        e.g. core-32.1, knots-29.3, brew
#   node.sh <build> fresh             wipe that build's regtest data, start, fund a "miner" wallet
#   node.sh <build> cli <args…>       bitcoin-cli against it
#   node.sh <build> mine [n]          mine n blocks (default 1) to the miner wallet
#   node.sh <build> pay <address> <btc>   send from the miner wallet and mine a block
#   node.sh <build> deletewallet <name>   unload a wallet and delete its files (recovery tests)
#
# Each build keeps its own data in $FNUI_WORK/<build> (default $TMPDIR/fnui). The RPC user
# "fntest" gets a random password on first use, in $FNUI_WORK/fntest.secret (never printed);
# run.sh passes it to the tests. FNUI_FNS_RPCAUTH=1 also copies FN-Server's rpcauth lines from
# your bitcoin.conf, so FN-Server can scan this regtest node for silent payments.
set -e
WORK=${FNUI_WORK:-${TMPDIR%/}/fnui}; mkdir -p $WORK; chmod 700 $WORK

builds() {
  for d in $HOME/.fullynoded/BitcoinCore/bitcoin-*(N/) $HOME/.fullynoded/BitcoinKnots/bitcoin-*(N/); do
    [[ -x $d/bin/bitcoind ]] || continue
    n=${d:t}; [[ $d == *Knots* ]] && n="knots-${${n#bitcoin-}%%.knots*}" || n="core-${n#bitcoin-}"
    echo "$n $d/bin"
  done
  [[ -x /opt/homebrew/bin/bitcoind ]] && echo "brew /opt/homebrew/bin"
  [[ -n $BITCOIN_BIN && -x $BITCOIN_BIN/bitcoind ]] && echo "custom $BITCOIN_BIN"
  return 0
}

[[ $1 == list || -z $1 ]] && { builds; exit 0; }
NAME=$1; shift
B=$(builds | awk -v n=$NAME '$1==n {print $2}')
[[ -n $B ]] || { echo "no build named $NAME (node.sh list)"; exit 1; }
D=$WORK/$NAME

secret() {
  [[ -f $WORK/fntest.secret ]] && return
  python3 - "$WORK" <<'PY'
import secrets,hmac,hashlib,os,sys
w=sys.argv[1]; pw=secrets.token_urlsafe(24); salt=secrets.token_hex(16)
h=hmac.new(salt.encode(),pw.encode(),hashlib.sha256).hexdigest()
open(f"{w}/fntest.secret","w").write(pw); os.chmod(f"{w}/fntest.secret",0o600)
open(f"{w}/rpcauth.fntest","w").write(f"rpcauth=fntest:{salt}${h}\n")
PY
}

conf() {
  secret; mkdir -p $D
  { echo "regtest=1"; echo "[regtest]"; echo "server=1"; echo "rpcbind=127.0.0.1"; echo "rpcallowip=127.0.0.1"
    echo "rpcport=18443"; echo "port=18444"; echo "listen=0"; echo "fallbackfee=0.0001"; echo "txindex=1"; echo "debug=rpc"
    cat $WORK/rpcauth.fntest
    if [[ $FNUI_FNS_RPCAUTH == 1 ]]; then grep "^rpcauth=FullyNoded-Server:" "$HOME/Library/Application Support/Bitcoin/bitcoin.conf" || true; fi
  } > $D/bitcoin.conf; chmod 600 $D/bitcoin.conf
}

CLI=($B/bitcoin-cli -datadir=$D -rpcwait -rpcwaittimeout=60)
up() { $CLI getnetworkinfo >/dev/null 2>&1; }
start() {
  conf
  # Only one regtest node can own 18443: stop whichever build has it.
  for other in $WORK/*/regtest/bitcoind.pid(N); do
    od=${other:h:h}; [[ $od == $D ]] && continue
    ob=$(builds | awk -v n=${od:t} '$1==n {print $2}'); [[ -n $ob ]] && $ob/bitcoin-cli -datadir=$od stop >/dev/null 2>&1 || true
    while [[ -f $other ]]; do sleep 0.5; done
  done
  up || $B/bitcoind -datadir=$D -daemon >/dev/null
  # bitcoin-cli's -rpcwait doesn't wait for a cookie file that isn't there yet.
  for i in {1..120}; do [[ -f $D/regtest/.cookie ]] && break; sleep 0.5; done
  echo $NAME > $WORK/current
  $CLI getnetworkinfo | python3 -c 'import sys,json;d=json.load(sys.stdin);print("up",d["version"],d["subversion"])'
}
miner() { $CLI -rpcwallet=miner getwalletinfo >/dev/null 2>&1 || $CLI loadwallet miner >/dev/null 2>&1 || $CLI createwallet miner >/dev/null; }

case $1 in
  start) start;;
  stop) $CLI stop;;
  fresh)
    up && $CLI stop >/dev/null && while [[ -f $D/regtest/bitcoind.pid ]]; do sleep 0.5; done
    rm -rf $D/regtest; start; miner
    $CLI generatetoaddress 150 $($CLI -rpcwallet=miner getnewaddress) >/dev/null
    echo "miner balance $($CLI -rpcwallet=miner getbalance)";;
  cli) shift; $CLI "$@";;
  mine) miner; $CLI generatetoaddress ${2:-1} $($CLI -rpcwallet=miner getnewaddress) | tail -1;;
  pay) miner; $CLI -rpcwallet=miner -named sendtoaddress address=$2 amount=$3 fee_rate=2; $CLI generatetoaddress 1 $($CLI -rpcwallet=miner getnewaddress) >/dev/null;;
  deletewallet)
    $CLI unloadwallet "$2" >/dev/null 2>&1 || true
    rm -rf "$D/regtest/wallets/$2"; echo "deleted wallet $2";;
  *) echo "unknown command $1"; exit 1;;
esac
