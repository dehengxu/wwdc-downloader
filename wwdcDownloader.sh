#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)

# /usr/bin/swiftc "$SCRIPT_DIR/wwdcDownloader.swift" && ./wwdcDownloader "$@"

# [ ! -d ./out ] && mkdir out
# swiftc wwdcDownloader.swift -o out/wwdc && ./out/wwdc "$@"

[ ! -f $(which swift) ] && echo "Swift compiler is not ready!!" && exit 0
[ ! -f $SCRIPT_DIR/wwdc ] && swift build -c release && cp .build/release/wwdc $SCRIPT_DIR
[ -f $SCRIPT_DIR/wwdc ] && ./wwdc "$@"