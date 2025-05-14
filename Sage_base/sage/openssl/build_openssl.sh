VERSION=3.4.0
SRC_DIR=openssl-${VERSION}
SRC_ARCHIVE=openssl-${VERSION}.tar.gz
URL=https://github.com/openssl/openssl/releases/download/${SRC_DIR}/${SRC_ARCHIVE}
HASH=5c2f33c3f3601676f225109231142cdc30d44127
INSTALL_PREFIX=`pwd`/local

set -e
cd openssl

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

./config --prefix=${INSTALL_PREFIX} no-asm
make -j8
make install_runtime
make install_programs
make install_ssldirs
make install_dev
