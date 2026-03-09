VERSION=3.14.3
TCLTK_VERSION=9.0
SRC_DIR=Python-${VERSION}
SRC_ARCHIVE=Python-${VERSION}.tgz
URL=https://www.python.org/ftp/python/${VERSION}/${SRC_ARCHIVE}
HASH=d7fe130d0501ae047ca318fa92aa642603ab6f217901015a1df6ce650d5470cd
INSTALL_PREFIX=`pwd`/local

TCLTK_HEADERS=${INSTALL_PREFIX}/include
TCL_LIB=${INSTALL_PREFIX}/lib/libtcl${TCLTK_VERSION}.dylib
TK_LIB=${INSTALL_PREFIX}/lib/libtcl9tk${TCLTK_VERSION}.dylib

set -e
cd python

if ! [ -e ${SRC_ARCHIVE} ]; then
    echo "Downloading source archive ${SRC_ARCHIVE}..."
    curl -L -O ${URL}
    ACTUAL_HASH=`/usr/bin/shasum -a256 ${SRC_ARCHIVE}  | cut -f 1 -d' '`
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

./configure \
    CFLAGS="-mmacosx-version-min=10.13" \
    MACOSX_DEPLOYMENT_TARGET=10.15 \
    LIBSQLITE3_CFLAGS="-I${INSTALL_PREFIX}/include" \
    LIBSQLITE3_LIBS="-L${INSTALL_PREFIX}/lib -lsqlite3" \
    LIBLZMA_CFLAGS="-I${INSTALL_PREFIX}/include" \
    LIBLZMA_LIBS="-L${INSTALL_PREFIX}/lib -llzma" \
    LIBZSTD_CFLAGS="-I${INSTALL_PREFIX}/include" \
    LIBZSTD_LIBS="-L${INSTALL_PREFIX}/lib -lzstd" \
    TCLTK_CFLAGS="-I${TCLTK_HEADERS}" \
    TCLTK_LIBS="${TCL_LIB} ${TK_LIB}" \
    LDFLAGS=-L${INSTALL_PREFIX}/lib \
    CPPFLAGS=-I${INSTAL_PREFIX}/include \
    --prefix=${INSTALL_PREFIX} \
    --with-openssl=${INSTALL_PREFIX}

make -j8
make install
