#!/bin/bash
VERSION=4.2.2
SRC_DIR=mpfr-${VERSION}
SRC_ARCHIVE=${SRC_DIR}.tar.gz
URL=https://ftp.gnu.org/gnu/mpfr/${SRC_ARCHIVE}
HASH=03aa176cf35d1477e2b6725cde74a728b4ef1a9a
INSTALL_PREFIX=`pwd`/local
ARCH=`/usr/bin/arch`

set -e
cd mpfr

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
    echo unpacking ${SRC_ARCHIVE}
    tar xfz ${SRC_ARCHIVE}
    if ! [ -e $SRC_DIR ]; then
	echo "Tar failed?"
	ls -l
    fi
    pushd ${SRC_DIR}
    if [ -e ../patches ]; then
	for patchfile in `ls ../patches`; do
	    patch -p1 < ../patches/$patchfile
	done
    fi
fi

cd ${SRC_DIR}
if [ -e Makefile ]; then
    make distclean
fi
export 
if [ $ARCH == "arm64" ]; then
   ./configure \
    CFLAGS="-mmacosx-version-min=11 -I${INSTALL_PREFIX}/include" \
    LDFLAGS="-Wl,-ld_classic -L${INSTALL_PREFIX}/lib" \
    --prefix=${INSTALL_PREFIX} \
    --with-gmp=${INSTALL_PREFIX}	    
else
    ./configure \
    CFLAGS="-mmacosx-version-min=10.13 -mno-avx2 -mno-bmi2  -I${INSTALL_PREFIX}/include" \
    LDFLAGS="-Wl,-ld_classic -L${INSTALL_PREFIX}/lib" \
    --prefix=${INSTALL_PREFIX} \
    --with-gmp=${INSTALL_PREFIX}    
fi
echo "Building mpfr."
gmake -j8
gmake install
