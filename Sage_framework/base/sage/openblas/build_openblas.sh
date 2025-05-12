#!/bin/bash
VERSION=0.3.29
SRC_ARCHIVE=OpenBLAS-${VERSION}.tar.gz
SRC_DIR=OpenBLAS-${VERSION}
URL=https://github.com/OpenMathLib/OpenBLAS/releases/download/v${VERSION}/OpenBLAS-${VERSION}.tar.gz
HASH=575c33d545ad37ef1bfde677b02730591b1e7df4
INSTALL_PREFIX=`pwd`/local

set -e
cd openblas

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
fi

pushd ${SRC_DIR}

gmake clean
gmake \
CFLAGS=-mmacosx-version-min=10.8 \
FFLAGS=-mmacosx-version-min=10.8 \
LDFLAGS='-Wl,-ld_classic' \
USE_TLS=1 \
DYNAMIC_ARCH=1 \
DYNAMIC_LIST='CORE2 PENRYN NEHALEM SANDYBRIDGE HASWELL SKYLAKEX' \
MAKE_NB_JOBS=8 \

gmake PREFIX=${INSTALL_PREFIX} install

popd
