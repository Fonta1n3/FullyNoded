#!/usr/bin/env sh
set -e # abort if any command fails

LIBWALLYCORE="CLibWally/libwally-core/src/.libs/libwallycore.a"
VALIDLIBWALLYCORE=0
REQUIREDARCHS="armv7 armv7s i386 x86_64 arm64 arm64e"
LIPO_CMD="lipo $LIBWALLYCORE -verify_arch $REQUIREDARCHS"

if [ -e "$LIBWALLYCORE" ]; then
    echo "$LIBWALLYCORE exists"
    if $LIPO_CMD; then
        VALIDLIBWALLYCORE=1
        echo "libwallycore.a contains $REQUIREDARCHS"
    else
        echo "libwallycore.a does not contain $REQUIREDARCHS"
        lipo "$LIBWALLYCORE" -info
    fi
else
    echo "$LIBWALLYCORE does not exists"
fi

if ((VALIDLIBWALLYCORE == 0)); then
    echo "Rebuilding libwallycore.a"
    sh ./build-libwally.sh -csd
else
    echo "Skip rebuild"
fi

exit 0
