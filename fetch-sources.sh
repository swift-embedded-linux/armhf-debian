#!/bin/bash
set -e
source swift-define

mkdir -p ./downloads

# Fetch sources
cd ./downloads
if [[ -d "$SWIFT_SRCDIR" ]]; then
    cd swift-corelibs-foundation
    git stash

    echo "$SWIFT_SRCDIR exists"
    cd $SWIFT_SRCDIR
    git stash
else
    echo "Checkout Swift"
    git clone https://github.com/swiftlang/swift.git --depth 1
    cd $SWIFT_SRCDIR
fi

# Update checkout
./utils/update-checkout --clone --tag $SWIFT_VERSION \
    --skip-history \
    --skip-repository cmake \
    --skip-repository cmark \
    --skip-repository curl \
    --skip-repository icu \
    --skip-repository indexstore-db \
    --skip-repository llbuild \
    --skip-repository libxml2 \
    --skip-repository ninja \
    --skip-repository sourcekit-lsp \
    --skip-repository swift-asn1 \
    --skip-repository swift-async-algorithms \
    --skip-repository swift-atomics \
    --skip-repository swift-argument-parser \
    --skip-repository swift-build \
    --skip-repository swift-certificates \
    --skip-repository swift-crypto \
    --skip-repository swift-docc \
    --skip-repository swift-docc-render-artifact \
    --skip-repository swift-docc-symbolkit \
    --skip-repository swift-driver \
    --skip-repository swift-format \
    --skip-repository swift-installer-scripts \
    --skip-repository swift-integration-tests \
    --skip-repository swift-log \
    --skip-repository swift-llvm-bindings \
    --skip-repository swift-lmdb \
    --skip-repository swift-markdown \
    --skip-repository swift-nio \
    --skip-repository swift-nio-ssl \
    --skip-repository swift-numerics \
    --skip-repository swift-stress-tester \
    --skip-repository swift-system \
    --skip-repository swift-tools-support-core \
    --skip-repository swift-xcode-playground-support \
    --skip-repository swiftpm \
    --skip-repository tensorflow-swift-apis \
    --skip-repository wasi-libc \
    --skip-repository wasmkit \
    --skip-repository yams \
    --skip-repository zlib \

# Apply patches
echo "Apply CXX interop patch"
patch -d . -p1 <$SRC_ROOT/patches/0002-Add-arm-to-float16support-for-missing-symbol.patch

if [[ $SWIFT_VERSION == *"5.9"* ]] || [[ $SWIFT_VERSION == *"5.10-"* ]]; then
    echo "Apply Foundation strlcpy/strlcat patch"
    cd ../swift-corelibs-foundation
    patch -d . -p1 <$SRC_ROOT/patches/0002-Foundation-check-for-strlcpy-strlcat.patch
fi
