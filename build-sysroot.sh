#!/bin/bash

set -e

SRC_ROOT=$(pwd)

DISTRIBUTION_NAME=$1
DISTRIUBTION_VERSION=$2
SYSROOT=$3

if [ -z $SYSROOT ]; then
    SYSROOT=sysroot-$DISTRIBUTION_NAME-$DISTRIUBTION_VERSION
fi
SYSROOT=$(pwd)/$SYSROOT

# These are only for armhf Debian sysroots. Expand to support more architectures if needed.
MULTILIB_DIR=arm-linux-gnueabihf
MULTILIB_LIBRARIES=(libanl.so.1
libBrokenLocale.so.1 \
libc_malloc_debug.so.0 \
libc.so.6 \
libdl.so.2 \
libgcc_s.so.1 \
libmemusage.so \
libm.so.6 \
libnsl.so.1 \
libnss_compat.so.2 \
libnss_dns.so.2 \
libnss_files.so.2 \
libnss_hesiod.so.2 \
libpcprofile.so \
libpthread.so.0 \
libresolv.so.2 \
librt.so.1 \
libthread_db.so.1 \
libutil.so.1 \
)
MUTLILIB_LD=ld-linux-armhf.so.3

DISTRIBUTION="$DISTRIBUTION_NAME:$DISTRIUBTION_VERSION"

case $DISTRIUBTION_VERSION in
    "focal")
        INSTALL_GCC_VERSION=9
        ;;
    "bullseye")
        INSTALL_GCC_VERSION=10
        ;;
    "jammy" | "bookworm")
        INSTALL_GCC_VERSION=12
        ;;
    "mantic" | "noble")
        INSTALL_GCC_VERSION=13
        ;;
    "trixie")
        INSTALL_GCC_VERSION=14
        ;;
    *)
        echo "Unsupported distribution $DISTRIBUTION!"
        echo "If you'd like to support it, update this script to add the apt package list for it."
        exit
        ;;
esac

INSTALL_DEPS_CMD=" \
    apt-get install -y \
        libc6-dev \
        libgcc-$INSTALL_GCC_VERSION-dev \
        libicu-dev \
        libstdc++-$INSTALL_GCC_VERSION-dev \
        libstdc++6 \
        linux-libc-dev \
        zlib1g-dev \
        libcurl4-openssl-dev \
        libxml2-dev \
        libsystemd-dev \
"

if [[ $DISTRIBUTION_NAME = "raspios" ]]; then
    INSTALL_DEPS_CMD="$INSTALL_DEPS_CMD symlinks"
fi

if [ ! -z $EXTRA_PACKAGES ]; then
    echo "Including extra packages: $EXTRA_PACKAGES"
    INSTALL_DEPS_CMD="$INSTALL_DEPS_CMD && apt-get install -y $EXTRA_PACKAGES"
fi

# This is for supporting armv6
if [[ $DISTRIBUTION_NAME = "raspios" ]]; then
    echo "Installing host dependencies..."

    if [ $(cat /etc/os-release | grep -c "Ubuntu") -gt 0 ]; then
        sudo apt update && sudo apt install -y qemu-user-static debootstrap
    elif [ $(cat /etc/os-release | grep -c "Fedora") -gt 0 ]; then
        sudo dnf install -y apt qemu-user-static debootstrap
    else
        echo "Unsupported host distribution! Please install qemu-user-static and debootstrap manually."
        exit 1
    fi

    mkdir artifacts && true
    cd artifacts

    SYSROOT_BUILD_DIR=sysroot-$DISTRIUBTION_VERSION

    echo "Building raspios sysroot for $DISTRIUBTION_VERSION..."
    sudo debootstrap --arch armhf $DISTRIUBTION_VERSION $SYSROOT_BUILD_DIR http://raspbian.raspberrypi.com/raspbian/

    echo "Setting up chroot for raspios sysroot..."
    sudo mount --bind /dev $SYSROOT_BUILD_DIR/dev
    sudo mount --bind /proc $SYSROOT_BUILD_DIR/proc
    sudo mount --bind /sys $SYSROOT_BUILD_DIR/sys
    QEMU_BINARY=/usr/bin/qemu-arm-static
    if [ ! -f $QEMU_BINARY ]; then
        QEMU_BINARY=/usr/bin/qemu-arm
    fi
    sudo cp $QEMU_BINARY $SYSROOT_BUILD_DIR/usr/bin

    echo "Installing needed dependencies..."
    sudo chroot $SYSROOT_BUILD_DIR /bin/bash -c "$INSTALL_DEPS_CMD"

    echo "Fixing broken symlinks..."
    sudo chroot $SYSROOT_BUILD_DIR /bin/bash -c "symlinks -cr /usr/include && symlinks -cr /usr/lib"

    echo "Copying files from sysroot to $SYSROOT..."
    rm -rf $SYSROOT && mkdir -p $SYSROOT/lib/$MULTILIB_DIR $SYSROOT/usr
    cp -P $SYSROOT_BUILD_DIR/lib/$MULTILIB_DIR/$MUTLILIB_LD $SYSROOT/lib/$MULTILIB_DIR/$MUTLILIB_LD
    cp -P $SYSROOT_BUILD_DIR/lib/$MUTLILIB_LD $SYSROOT/lib/$MUTLILIB_LD
    for lib in "${MULTILIB_LIBRARIES[@]}"; do
        cp -P $SYSROOT_BUILD_DIR/lib/$MULTILIB_DIR/$lib $SYSROOT/lib/$MULTILIB_DIR/
    done
    cp -r $SYSROOT_BUILD_DIR/usr/include $SYSROOT/usr/include
    cp -r $SYSROOT_BUILD_DIR/usr/lib $SYSROOT/usr/lib

    echo "Umounting and cleaning up..."
    sudo umount $SYSROOT_BUILD_DIR/dev
    sudo umount $SYSROOT_BUILD_DIR/proc
    sudo umount $SYSROOT_BUILD_DIR/sys
    sudo rm -rf $SYSROOT_BUILD_DIR
else
    echo "Starting up qemu emulation"
    docker run --privileged --rm tonistiigi/binfmt --install all

    CONTAINER_NAME=swift-armhf-sysroot-$DISTRIUBTION_VERSION

    echo "Building $DISTRIBUTION distribution for sysroot"
    docker rm --force $CONTAINER_NAME
    docker run \
       --platform linux/armhf \
       --name $CONTAINER_NAME \
       $DISTRIBUTION \
       /bin/bash -c "apt-get update && $INSTALL_DEPS_CMD"

    echo "Extracting sysroot folders to $SYSROOT"
    rm -rf $SYSROOT
    mkdir -p $SYSROOT/lib $SYSROOT/lib/$MULTILIB_DIR $SYSROOT/usr
    docker cp $CONTAINER_NAME:/lib/$MULTILIB_DIR/$MUTLILIB_LD $SYSROOT/lib/$MULTILIB_DIR/$MUTLILIB_LD
    docker cp $CONTAINER_NAME:/lib/$MUTLILIB_LD $SYSROOT/lib/$MUTLILIB_LD
    for lib in "${MULTILIB_LIBRARIES[@]}"; do
        docker cp $CONTAINER_NAME:/lib/$MULTILIB_DIR/$lib $SYSROOT/lib/$MULTILIB_DIR/
    done
    docker cp $CONTAINER_NAME:/usr/include $SYSROOT/usr/include
    docker cp $CONTAINER_NAME:/usr/lib $SYSROOT/usr/lib

    # Find broken links, re-copy
    cd $SYSROOT
    pwd
    if [[ $OSTYPE == 'darwin'* ]]; then
        BROKEN_LINKS=$(find . -type l)
    else
        BROKEN_LINKS=$(find . -xtype l)
    fi
    while IFS= read -r link; do
        # Ignore empty links
        if [ -z "${link}" ]; then continue; fi

        link=$(echo $link | sed '1,/./ s/.//')
        newdest=$(dirname .$link)
        echo "Replacing broken symlink: $link, new dest: $newdest"
        docker cp -L $CONTAINER_NAME:$link $newdest
    done <<< "$BROKEN_LINKS"

    echo "Cleaning up"
    docker rm $CONTAINER_NAME
fi
