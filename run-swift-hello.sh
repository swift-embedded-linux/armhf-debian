#!/bin/bash

set -e
source swift-define

# Run swift-hello
./run-swift-package.sh swift-hello

# Run swift-hello package tests if they exist
SWIFT_PACKAGE_TESTS_BINARY=$SWIFT_PACKAGE_BUILDDIR/${SWIFTPM_CONFIGURATION}/swift-helloPackageTests.xctest
if [ -f $SWIFT_PACKAGE_TESTS_BINARY ]; then
    ./run-swift-package.sh swift-helloPackageTests.xctest
fi
