#!/bin/zsh
# Drive Fully Noded on one simulator step by step (RemoteDriver.swift), for writing new tests.
#
#   drive.sh <device> start          start the driver (in the background) and wait until ready
#   drive.sh <device> '<json>'       run one command, print the result and the screenshot path
#   drive.sh <device> stop
#
# <device> is a simulator UDID. Run `run.sh build` first.
set -e
WORK=${FNUI_WORK:-${TMPDIR%/}/fnui}
DEV=$1; DIR=$WORK/drive-$DEV
case $2 in
  start)
    rm -rf $DIR; mkdir -p $DIR
    FNUI_COMMAND_DIR=$DIR nohup ${0:A:h}/run.sh test $DEV RemoteDriver/testRemoteControl > $DIR/xcodebuild.log 2>&1 &
    for i in {1..240}; do [[ -f $DIR/ready ]] && { echo "ready"; exit 0; }; sleep 1; done
    echo "driver didn't start, see $DIR/xcodebuild.log"; exit 1;;
  stop) $0 $DEV '{"op":"quit"}' >/dev/null || true; echo stopped;;
  *)
    # One writer at a time: the counter is the next command number the driver expects.
    n=$(( $(cat $DIR/counter 2>/dev/null || echo 0) + 1 )); echo $n > $DIR/counter
    print -r -- "$2" > $DIR/cmd-$n.tmp && mv $DIR/cmd-$n.tmp $DIR/cmd-$n.json
    for i in {1..900}; do
      [[ -f $DIR/out-$n.txt ]] && break
      # The driver test ended (an app crash or a failed interaction): say so rather than wait.
      grep -q "TEST EXECUTE\|Testing started" $DIR/xcodebuild.log 2>/dev/null && grep -q "TEST EXECUTE" $WORK/last-test-$DEV.log 2>/dev/null && { echo "driver stopped:"; grep -E "error:|crashed" $WORK/last-test-$DEV.log | tail -3; exit 1; }
      sleep 0.2
    done
    cat $DIR/out-$n.txt 2>/dev/null || echo "no result yet ($DIR)"
    [[ -f $DIR/out-$n.png ]] && echo "screenshot: $DIR/out-$n.png";;
esac
