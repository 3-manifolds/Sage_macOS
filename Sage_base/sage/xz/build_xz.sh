#!/bin/bash
VERSION=5.8.2
SRC_DIR=xz-${VERSION}
SRC_ARCHIVE=${SRC_DIR}.tar.gz
URL=https://github.com/tukaani-project/xz/releases/download/v${VERSION}/${SRC_ARCHIVE}
HASH=7bf2d887bd0ad401e0a4787a9033d9235036b3bb
INSTALL_PREFIX=`pwd`/local
ARCH=`/usr/bin/arch`

set -e
cd xz

if ! [ -e ${SRC_ARCHIVE} ]; then
    echo "Downloading source archive ${SRC_ARCHIVE}..."
    curl -L -O ${URL}
    ACTUAL_HASH=`/usr/bin/shasum ${SRC_ARCHIVE}  | cut -f 1 -d' '`
    if [[ ${ACTUAL_HASH} != ${HASH} ]]; then
	echo Invalid hash value for ${SRC_ARCHIVE}
	exit 1
    fi
fi

if ! [ -d ${SRC_DIR} ]; then
    tar xfz ${SRC_ARCHIVE}
    pushd ${SRC_DIR}
    for patchfile in `ls ../patches`; do
	patch -p1 < ../patches/$patchfile
    done
    popd
fi

cd ${SRC_DIR}
if [ -e Makefile ]; then
    make distclean
fi

if [ $ARCH == "arm64" ]; then
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    CFLAGS="-mmacosx-version-min=11" \
    LDFLAGS="-Wl,-ld_classic"
else
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    CFLAGS="-mmacosx-version-min=10.13" \
    LDFLAGS="-Wl,-ld_classic"
fi
echo "Building xz ..."
gmake -j8
gmake install
