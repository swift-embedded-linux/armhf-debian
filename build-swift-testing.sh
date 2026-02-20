#!/bin/bash
set -e
source swift-define

echo "Create Testing build folder ${SWIFT_TESTING_BUILDDIR}"
mkdir -p $SWIFT_TESTING_BUILDDIR
rm -rf $SWIFT_TESTING_INSTALL_PREFIX
mkdir -p $SWIFT_TESTING_INSTALL_PREFIX

# TODO: Exit testing still does not build properly in 6.1.1 snapshots
if [[ $SWIFT_VERSION == *"swift-6.1.1-DEVELOPMENT"* ]]; then
    SWIFTC_FLAGS="${SWIFTC_FLAGS} -D SWT_NO_EXIT_TESTS"
fi

echo "Configure Testing"
rm -rf $SWIFT_TESTING_BUILDDIR/CMakeCache.txt
cmake -S $SWIFT_TESTING_SRCDIR -B $SWIFT_TESTING_BUILDDIR -G Ninja \
    -DCMAKE_INSTALL_PREFIX=${SWIFT_TESTING_INSTALL_PREFIX} \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_BUILD_TYPE=${SWIFT_BUILD_CONFIGURATION} \
    -DCMAKE_C_COMPILER=${SWIFT_NATIVE_PATH}/clang \
    -DCMAKE_CXX_COMPILER=${SWIFT_NATIVE_PATH}/clang++ \
    -DCMAKE_C_FLAGS="${RUNTIME_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${RUNTIME_FLAGS}" \
    -DCMAKE_C_LINK_FLAGS="${LINK_FLAGS}" \
    -DCMAKE_CXX_LINK_FLAGS="${LINK_FLAGS}" \
    -DCMAKE_TOOLCHAIN_FILE="${CROSS_TOOLCHAIN_FILE}" \
    -DCF_DEPLOYMENT_SWIFT=ON \
    -DCMAKE_Swift_COMPILER=${SWIFT_NATIVE_PATH}/swiftc \
    -DCMAKE_Swift_FLAGS="${SWIFTC_FLAGS}" \
    -DCMAKE_Swift_FLAGS_DEBUG="" \
    -DCMAKE_Swift_FLAGS_RELEASE="" \
    -DCMAKE_Swift_FLAGS_RELWITHDEBINFO="" \
    -Ddispatch_DIR="${LIBDISPATCH_BUILDDIR}/cmake/modules" \
    -DFoundation_DIR="${FOUNDATION_BUILDDIR}/cmake/modules" \
    -DSwiftTesting_MACRO="${SWIFT_NATIVE_PATH}/../lib/swift/host/plugins/libTestingMacros.so" \

echo "Build & Install Testing"
(cd $SWIFT_TESTING_BUILDDIR && ninja install)
