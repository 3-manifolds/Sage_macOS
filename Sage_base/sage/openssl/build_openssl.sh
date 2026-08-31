# Openssl 3.5 is a long term support version.
VERSION=3.5.8
SRC_DIR=openssl-${VERSION}
SRC_ARCHIVE=openssl-${VERSION}.tar.gz
URL=https://github.com/openssl/openssl/releases/download/${SRC_DIR}/${SRC_ARCHIVE}
HASH=a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2
INSTALL_PREFIX=`pwd`/local
ARCH=`/usr/bin/arch`

set -e
cd openssl

if ! [ -e ${SRC_ARCHIVE} ]; then
    echo "Downloading source archive ${SRC_ARCHIVE}..."
    curl -L -O ${URL}
    ACTUAL_HASH=`/usr/bin/shasum -a 256${SRC_ARCHIVE}  | cut -f 1 -d' '`
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
  export MACOSX_DEPLOYMENT_TARGET=11.0
  ./config --prefix=${INSTALL_PREFIX} CFLAGS="-mmacosx-version-min=11.0" \
	   no-asm
else
  export MACOSX_DEPLOYMENT_TARGET=10.13
  ./config --prefix=${INSTALL_PREFIX} CFLAGS="-mmacosx-version-min=10.13" \
	   no-asm
fi

make -j8
make install_runtime
make install_programs
make install_ssldirs
make install_dev
