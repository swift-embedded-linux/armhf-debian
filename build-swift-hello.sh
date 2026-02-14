#!/bin/bash
set -e
source swift-define

# Build paths
export SWIFT_PACKAGE_SRCDIR=$SRC_ROOT/swift-hello
export SWIFT_PACKAGE_BUILDDIR=$SRC_ROOT/build/swift-hello-$SWIFT_TARGET_ARCH
./build-swift-package.sh
