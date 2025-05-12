#!/usr/bin/bash
VERSION=9.0.1
TCL_SRC_ARCHIVE=tcl-core${VERSION}-src.tar.gz
TK_SRC_ARCHIVE=tk${VERSION}-src.tar.gz
TCL_HASH=c7d13eb75922a6abce02b4cadabbc18f1b4ec7bf
TK_HASH=6715d2b003e050dbc3caceb6240431cd2d736711
INSTALL_PREFIX=`pwd`/local

set -e
cd tcltk

if ! [ -e ${TCL_SRC_ARCHIVE} ] ; then
    curl -L -O https://prdownloads.sourceforge.net/tcl/${TCL_SRC_ARCHIVE}
    ACTUAL_HASH=`/usr/bin/shasum ${TCL_SRC_ARCHIVE}  | cut -f 1 -d' '`
    if [[ ${ACTUAL_HASH} != ${TCL_HASH} ]]; then
	echo Invalid hash value for ${TCL_SRC_ARCHIVE}
	exit 1
    fi
fi
rm -rf Tcl
mkdir -p Tcl
tar xf ${TCL_SRC_ARCHIVE} --directory=Tcl --strip-components=1

if ! [ -e ${TK_SRC_ARCHIVE} ] ; then
    curl -L -O https://prdownloads.sourceforge.net/tcl/${TK_SRC_ARCHIVE}
    ACTUAL_HASH=`/usr/bin/shasum ${TK_SRC_ARCHIVE}  | cut -f 1 -d' '`
    if [[ ${ACTUAL_HASH} != ${TK_HASH} ]]; then
	echo Invalid hash value for ${TK_SRC_ARCHIVE}
	exit 1
    fi
fi
rm -rf Tk
mkdir -p Tk
tar xf ${TK_SRC_ARCHIVE} --directory=Tk --strip-components=1

pushd Tcl/unix
./configure \
    CFLAGS=-mmacosx-version-min=10.13 \
    --prefix ${INSTALL_PREFIX}
make -j8 install-binaries install-libraries install-headers
popd

pushd Tk/unix
./configure \
    CFLAGS=-mmacosx-version-min=10.13 \
    MACHER_PROG=/usr/bin/true \
    --enable-aqua \
    --disable-zipfs \
    --prefix ${INSTALL_PREFIX}
make -j8 install-binaries install-libraries install-headers
popd

# ????????
chmod u+w ${INSTALL_PREFIX}/lib/libtcl*
