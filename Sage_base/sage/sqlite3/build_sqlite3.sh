TCL_FRAMEWORK=/Library/Frameworks/Tcl.framework
TCL_VERSION=`readlink ${TCL_FRAMEWORK}/Versions/Current`
TCLSH=${TCL_FRAMEWORK}/Versions/Current/tclsh${TCL_VERSION}
SQLITE_VERSION="3.53.04"
SRC_DIR="sqlite-src-3530400"
SRC_ARCHIVE=${SRC_DIR}.zip
URL=https://sqlite.org/2026/${SRC_ARCHIVE}
HASH="d18fa15aec74d8c17e1463f861095adc01b5ad190256acb4f91d22f0368d232b"
ARCH=`/usr/bin/arch`
if [ $ARCH == "arm64" ]; then
    SQLITE_CFLAGS="-mmacosx-version-min=11.0"
else
    SQLITE_CFLAGS="-mmacosx-version-min=11.0"
fi
INSTALL_PREFIX=`pwd`/local

if ! [ -e ${SRC_ARCHIVE} ]; then
    echo "Downloading source archive ${SRC_ARCHIVE}..."
    curl -L -O ${URL}
fi

ACTUAL_HASH=`/usr/bin/shasum -a256 ${SRC_ARCHIVE}  | cut -f 1 -d' '`
if [[ ${ACTUAL_HASH} != ${HASH} ]]; then
    echo Invalid hash value for ${SRC_ARCHIVE}
    exit 1
fi

if ! [ -d ${SRC_DIR} ]; then
    unzip ${SRC_ARCHIVE}
fi

cd ${SRC_DIR}

if [ -e Makefile ]; then
    make distclean
fi

./configure --all \
	    --prefix=${INSTALL_PREFIX} \
	    --with-tcl="${TCL_FRAMEWORK}" \
	    -with-tclsh="${TCLSH}" \
	    CFLAGS="${SQLITE_CFLAGS}" \
	    TCLLIBDIR=${INSTALL_PREFIX}

make -j8
make install
