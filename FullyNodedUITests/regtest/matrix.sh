#!/bin/zsh
# Every flow on every installed node build, on two simulators.
#
#   matrix.sh <simulator A> <simulator B> [build …]     (default: every build node.sh lists)
#
# For each build: a fresh regtest chain, RegtestTests on each simulator in turn (they share the
# node, and one mining would confirm a transaction the other expects in the mempool), then
# payjoin both ways (A receives from B, B receives from A). A summary is printed at the end
# and kept in $FNUI_WORK/matrix-<time>.txt; full logs and .xcresult bundles in $FNUI_WORK.
set -e
HERE=${0:A:h}
WORK=${FNUI_WORK:-${TMPDIR%/}/fnui}
A=$1; B=$2; shift 2
BUILDS=("$@"); [[ ${#BUILDS} == 0 ]] && BUILDS=($($HERE/node.sh list | awk '{print $1}'))
OUT=$WORK/matrix-$(date +%Y%m%d-%H%M).txt
$HERE/run.sh build
for b in $BUILDS; do
  echo "=== $b" | tee -a $OUT
  FNUI_FNS_RPCAUTH=${FNUI_FNS_RPCAUTH:-0} $HERE/node.sh $b fresh | tee -a $OUT
  $HERE/run.sh test $A RegtestTests > $WORK/single-A.txt || true
  FNUI_TOR_PORT_OFFSET=10 $HERE/run.sh test $B RegtestTests > $WORK/single-B.txt || true
  { echo "-- simulator A"; grep -E "Test Case.*(passed|failed|skipped)|error:" $WORK/single-A.txt
    echo "-- simulator B"; grep -E "Test Case.*(passed|failed|skipped)|error:" $WORK/single-B.txt; } | tee -a $OUT
  echo "-- payjoin: A receives, B pays" | tee -a $OUT
  $HERE/run.sh payjoin $A $B | grep -E "Test Case.*(passed|failed|skipped)|error:" | tee -a $OUT
  echo "-- payjoin: B receives, A pays" | tee -a $OUT
  $HERE/run.sh payjoin $B $A | grep -E "Test Case.*(passed|failed|skipped)|error:" | tee -a $OUT
done
echo "summary: $OUT"
