#!/bin/bash

set -e

SRC_ROOT=$(pwd)
ARTIFACTS_DIR=$SRC_ROOT/artifacts
TARGET_ARCH=${TARGET_ARCH:=armv7}
TARGET_TRIPLE=${TARGET_ARCH}-unknown-linux-gnueabihf

function print_usage() {
    echo "$0 <swift-tag> <distribution>"
    exit 1
}

SWIFT_TAG=$1
if [ -z $SWIFT_TAG ]; then
    echo "The Swift version tag must be provided. This is needed to be able to identify the SDK once"
    echo "it is generated. The version should match one of the official release tags versions from"
    echo "https://www.swift.org/download/#releases and look like this: swift-5.10.1-RELEASE"
    print_usage
    exit 1
fi

DISTRIBUTION=$2
if [ -z $DISTRIBUTION ]; then
    echo "Distribution name must be provided. This is needed to be able to identify the cross-compilation"
    echo "toolchain for the target. The sysroot should be generated using the ./build-sysroot.sh script."
    print_usage
    exit 1
fi
SYSROOT=${SYSROOT:=$SRC_ROOT/sysroot-$DISTRIBUTION}

# Create SDK directory
SDK_NAME=${SWIFT_TAG}-${DISTRIBUTION}-${TARGET_ARCH}
SDK_DIR=$ARTIFACTS_DIR/$SDK_NAME
SDK_INSTALL_PREFIX=${SDK_INSTALL_PREFIX:=/opt}
mkdir -p $SDK_DIR

# Install directories
INSTALL_DESTDIR=${INSTALL_DESTDIR:=$SRC_ROOT/build/swift-install}
INSTALLABLE_SDK_PACKAGE=${INSTALLABLE_SDK_PACKAGE:=$ARTIFACTS_DIR/$SDK_NAME.tar.gz}

# Copy sysroot into target SDK dir
echo "Copying $DISTRIBUTION sysroot into $SDK_DIR..."
TARGET_SDK_DIR=$SDK_DIR/$DISTRIBUTION
mkdir -p $TARGET_SDK_DIR
cp -rf $SYSROOT/* $TARGET_SDK_DIR

# Copy swift build into target SDK dir
echo "Copying Swift install into $TARGET_SDK_DIR..."
cp -rf $INSTALL_DESTDIR/* $TARGET_SDK_DIR

# Annoying but helpful for Swift versions < 6.1.1
if [[ $SWIFT_VERSION == *"5."* ]] || [[ $SWIFT_VERSION == *"6.0"* ]]; then
    echo "Creating SDKSettings.json to silence cross-compilation warnings"
    cat <<EOT > $TARGET_SDK_DIR/SDKSettings.json
{
  "SupportedTargets": {},
  "Version": "0.0.1",
  "CanonicalName": "linux"
}
EOT
fi

# Create destination.json file
echo "Creating $DISTRIBUTION.json file for SDK..."
SDK_INSTALL_DIR="$SDK_INSTALL_PREFIX/$SDK_NAME/$DISTRIBUTION"
STAGING_DIR=$SDK_INSTALL_DIR \
SWIFT_TARGET_ARCH=$TARGET_ARCH \
SWIFTPM_DESTINATION_FILE=$SDK_DIR/$DISTRIBUTION.json \
    ./generate-swiftpm-toolchain.sh

echo "Creating $DISTRIBUTION-static.json file for SDK..."
SDK_INSTALL_DIR="$SDK_INSTALL_PREFIX/$SDK_NAME/$DISTRIBUTION"
STAGING_DIR=$SDK_INSTALL_DIR \
SWIFT_TARGET_ARCH=$TARGET_ARCH \
STATIC_SWIFT_STDLIB=1 \
SWIFTPM_DESTINATION_FILE=$SDK_DIR/$DISTRIBUTION-static.json \
    ./generate-swiftpm-toolchain.sh

# Create README.md with instructions on usage
echo "Creating README.md with instructions for usage..."
cat << EOT > $SDK_DIR/README.md
# Cross-Compilation SDK: $SDK_NAME

This is an old-style Swift cross-compilation SDK that provides the needed sysroot and Swift libraries
to compile for the given distribution and architecture. These SDKs require that they be installed at
an absolute path for them to work. This SDK is built to be installed at /opt like this:

 - /opt/$SDK_NAME

If you desire to install it to a different location, simply edit the $DISTRIBUTION.json or 
$DISTRIBUTION-static.json file in this directory to change all the "/opt" paths to your new location.

The SDK also assumes that your host Swift toolchain is installed at /usr/bin, but this can also be
changed in the $DISTRIBUTION.json/$DISTRIBUTION-static.json files. PLEASE NOTE: You *MUST* use the
exact same version of the host Swift toolchain ($SWIFT_TAG) for this SDK to work. If you have a
version mismatch you will be unable to cross-compile using this SDK. You have been warned!

To use the SDK, simply provide the "--destination" param on the command line when building a Swift
app:

> swift build --destination /opt/$SDK_NAME/$DISTRIBUTION.json

Or, to compile a binary with the static Swift stdlib included, use the $DISTRIBUTION-static.json
file instead, like this:

> swift build --destination /opt/$SDK_NAME/$DISTRIBUTION-static.json --static-swift-stdlib

Of course, if you have installed the SDK to a different path, use that path instead.
EOT

# Compress installable SDK for distribution
echo "Compressing installable SDK package for distribution..."
cd $ARTIFACTS_DIR
tar -czf $INSTALLABLE_SDK_PACKAGE $SDK_NAME
