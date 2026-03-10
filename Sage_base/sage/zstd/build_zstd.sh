#!/bin/bash
VERSION=1.5.7
SRC_DIR=zstd-${VERSION}
SRC_ARCHIVE=${SRC_DIR}.tar.gz
URL=https://github.com/facebook/zstd/releases/download/v${VERSION}/${SRC_ARCHIVE}
HASH=eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3
INSTALL_PREFIX=`pwd`/local

set -e
cd zstd

if ! [ -e ${SRC_ARCHIVE} ]; then
    echo "Downloading source archive ${SRC_ARCHIVE}..."
    curl -L -O ${URL}
    ACTUAL_HASH=`/usr/bin/shasum -a 256 ${SRC_ARCHIVE}  | cut -f 1 -d' '`
    if [[ ${ACTUAL_HASH} != ${HASH} ]]; then
	echo Invalid hash value for ${SRC_ARCHIVE}
	exit 1
    fi
fi

if ! [ -d ${SRC_DIR} ]; then
    tar xfz ${SRC_ARCHIVE}
    pushd ${SRC_DIR}
    popd
fi

cd ${SRC_DIR}
if [ -e Makefile ]; then
    make clean
fi

echo "Building zstd ..."
make CFLAGS="-mmacosx-version-min=10.13" -j8
make install PREFIX=${INSTALL_PREFIX}
