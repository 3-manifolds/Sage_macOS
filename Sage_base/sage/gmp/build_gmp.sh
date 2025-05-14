#!/bin/bash
VERSION=6.3.0
SRC_ARCHIVE=gmp-${VERSION}.tar.xz
SRC_DIR=gmp-${VERSION}
URL=https://ftp.gnu.org/gnu/gmp/gmp-6.3.0.tar.xz
HASH=b4043dd2964ab1a858109da85c44de224384f352
INSTALL_PREFIX=`pwd`/local
ARCH=`/usr/bin/arch`

set -e
cd gmp

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
export
if [ $ARCH == "arm64" ]; then
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    --enable-cxx \
    CFLAGS="-mmacosx-version-min=11" \
    LDFLAGS="-Wl,-ld_classic"
else
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    --enable-cxx \
    CFLAGS="-mmacosx-version-min=10.13 -mno-avx2 -mno-bmi2" \
    LDFLAGS="-Wl,-ld_classic"
fi
make -j8
make check
make install
