#!/bin/zsh
# Build and run the UI tests against the regtest node node.sh started.
#
#   run.sh build                                  build FN + the UI tests once (build-for-testing)
#   run.sh test <device> [Class[/testMethod]] …   run tests on a simulator (name or UDID)
#   run.sh payjoin <receiver> <payer>             the two-simulator payjoin test, both at once
#
# Devices: any booted or bootable simulator, e.g. "iPhone 15 Pro", "iPhone SE (3rd generation)".
# Settings it passes to the tests (TEST_RUNNER_ prefix, see FNUI.swift):
#   FNUI_RPC_PASSWORD from $FNUI_WORK/fntest.secret, FNUI_SHARED_DIR for the payjoin handoff,
#   FNUI_TOR_PORT_OFFSET=$FNUI_TOR_PORT_OFFSET (set 10 for the second simulator).
set -e
ROOT=${0:A:h:h:h}
WORK=${FNUI_WORK:-${TMPDIR%/}/fnui}; mkdir -p $WORK/shared
DD=$WORK/dd

case $1 in
  build)
    LOG=$WORK/last-build.log
    # From the repository root, so wherever this is run from Xcode reuses one cached build plan.
    build() {
      (cd $ROOT && xcodebuild -workspace FullyNoded.xcworkspace -scheme FullyNodedUITests -destination 'generic/platform=iOS Simulator' \
        -derivedDataPath $DD build-for-testing > $LOG 2>&1)
    }
    if ! build; then
      # Two kinds of damaged build folder, both fixed by a clean build:
      # - macOS purges old files under $TMPDIR, which can leave a package's binary framework
      #   (bdk-swift) half deleted, and Xcode caches that in its build plans.
      # - Built for one specific simulator as well as for any simulator, the Tor pod's link
      #   step fails ("can't link a dylib with itself").
      if grep -q "There is no Info.plist found at '.*SourcePackages/artifacts\|can't link a dylib with itself" $LOG; then
        echo "the build folder is damaged: building from clean (a few minutes)…"
        rm -rf $DD/SourcePackages $DD/Build
        build && { echo "built"; exit 0; }
      fi
      grep -E "^(/[^ ].*: )?error:" $LOG | grep -v "exit code 0 but produced no further output" | sort -u | head -20
      echo "build failed, full log: $LOG"
      exit 1
    fi
    echo "built";;
  test)
    DEV=$2; shift 2
    [[ $DEV == *-*-*-*-* ]] && DEST="id=$DEV" || DEST="platform=iOS Simulator,name=$DEV"
    # Installing the new build kills a running Fully Noded, and its Tor aborts on the way out,
    # which XCTest counts as a crash in the test: close it first, and give Tor time to let go.
    if [[ $DEV == *-*-*-*-* ]] && xcrun simctl terminate $DEV com.fontaine.FullyNoded 2>/dev/null; then sleep 5; fi
    ONLY=(); for t in "$@"; do ONLY+=(-only-testing "FullyNodedUITests/$t"); done
    [[ ${#ONLY} == 0 ]] && ONLY=(-only-testing FullyNodedUITests)
    TEST_RUNNER_FNUI_RPC_PASSWORD="$(cat $WORK/fntest.secret)" \
    TEST_RUNNER_FNUI_SHARED_DIR=$WORK/shared \
    TEST_RUNNER_FNUI_TOR_PORT_OFFSET=$FNUI_TOR_PORT_OFFSET \
    TEST_RUNNER_FNUI_COMMAND_DIR=$FNUI_COMMAND_DIR \
    TEST_RUNNER_FNUI_APP_PASSWORD="$(cat $WORK/applock.secret 2>/dev/null)" \
    TEST_RUNNER_FNUI_NODE_DATADIR=$WORK/$(cat $WORK/current 2>/dev/null)/regtest \
    xcodebuild test-without-building -xctestrun $(ls $DD/Build/Products/*.xctestrun | head -1) \
      -destination "$DEST" $ONLY -test-timeouts-enabled NO \
      -resultBundlePath $WORK/results/$(date +%H%M%S)-${DEV// /_}.xcresult > $WORK/last-test-${DEV// /_}.log 2>&1 || true
    # Full log kept in $WORK/last-test-<device>.log.
    grep -E "Test Case|error:|failed|passed|skipped|\*\* TEST" $WORK/last-test-${DEV// /_}.log ;;
  payjoin)
    # The payer's Tor gets other ports: two simulators share the Mac's.
    $0 test $2 PayjoinTests/testReceive > $WORK/payjoin-receive.txt &
    FNUI_TOR_PORT_OFFSET=10 $0 test $3 PayjoinTests/testSend > $WORK/payjoin-send.txt &
    wait
    cat $WORK/payjoin-receive.txt $WORK/payjoin-send.txt;;
  *) sed -n 2,13p $0;;
esac
