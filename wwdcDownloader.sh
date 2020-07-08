#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)

# /usr/bin/swiftc "$SCRIPT_DIR/wwdcDownloader.swift" && ./wwdcDownloader "$@"

[ ! -d ./out ] && mkdir out
swiftc wwdcDownloader.swift -o out/wwdc && ./out/wwdc "$@"