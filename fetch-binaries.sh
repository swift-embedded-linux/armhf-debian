#!/bin/bash
set -e
source swift-define

mkdir -p $SRC_ROOT/build
mkdir -p $SRC_ROOT/downloads

if [[ "$DOWNLOAD_SWIFT_RUNTIME" == "1" ]]; then

    # Download prebuilt Swift for Armv7
    DOWNLOAD_FILE=$INSTALL_TAR
    SRCURL=https://github.com/colemancda/swift-armv7/releases/download/0.6.0/swift-armv7.tar.gz
    if test -f "$DOWNLOAD_FILE"; then
        echo "swift-armv7.tar.gz exists"
    else
        echo "Download swift-armv7.tar.gz"
        wget -q $SRCURL -O $DOWNLOAD_FILE
    fi

    # Extract Swift runtime
    if [[ -d "$SWIFT_INSTALL_PREFIX" ]]; then
        echo "Swift runtime exists"
    else
        echo "Extract Swift runtime"
        rm -rf $SWIFT_INSTALL_PREFIX
        mkdir -p $SWIFT_INSTALL_PREFIX
        cd $SWIFT_INSTALL_PREFIX
        tar -xf $INSTALL_TAR
        cd $SRC_ROOT
    fi
fi

if [[ -d "$STAGING_DIR/usr/lib" ]]; then
    echo "Use existing Sysroot"
else
    # Build Debian 12 sysroot
    ./build-sysroot.sh debian bookworm
fi

if [[ $OSTYPE == 'darwin'* ]]; then

    # Download Swift Xcode toolchain
    DOWNLOAD_FILE=$PREBUILT_XCTOOLCHAIN
    SRCURL="https://download.swift.org/swift-5.10-release/xcode/${SWIFT_VERSION}/${SWIFT_VERSION}-osx.pkg"
    if test -f "$DOWNLOAD_FILE"; then
        echo "${SWIFT_VERSION}-osx.pkg exists"
    else
        echo "Download ${SWIFT_VERSION}-osx.pkg"
        wget -q $SRCURL -O $DOWNLOAD_FILE
    fi
fi
