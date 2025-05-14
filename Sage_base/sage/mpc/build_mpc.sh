#!/bin/bash
VERSION=1.3.1
SRC_DIR=mpc-${VERSION}
SRC_ARCHIVE=${SRC_DIR}.tar.gz
URL=https://ftp.gnu.org/gnu/mpc/${SRC_ARCHIVE}
HASH=03aa176cf35d1477e2b6725cde74a728b4ef1a9a
INSTALL_PREFIX=`pwd`/local
ARCH=`/usr/bin/arch`

set -e
cd mpc

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
    if [ -e ../patches ]; then
	for patchfile in `ls ../patches`; do
	    patch -p1 < ../patches/$patchfile
	done
    fi
    popd
fi

cd ${SRC_DIR}
if [ -e Makefile ]; then
    make distclean
fi
if [ $ARCH == "arm64" ]; then
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    --with-gmp=${INSTALL_PREFIX} \
    --with-mpfr=${INSTALL_PREFIX} \
    LDFLAGS="-Wl,-ld_classic" \
    CFLAGS="-mmacosx-version-min=11"
else
    ./configure \
    --prefix=${INSTALL_PREFIX} \
    --with-gmp=${INSTALL_PREFIX} \
    --with-mpfr=${INSTALL_PREFIX} \
    LDFLAGS="-Wl,-ld_classic" \
    CFLAGS="-mmacosx-version-min=10.13 -mno-avx2 -mno-bmi2"
fi
make -j8
make install
