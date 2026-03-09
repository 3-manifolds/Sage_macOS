TCL_FRAMEWORK=/Library/Frameworks/Tcl.framework
TCL_VERSION=`readlink ${TCL_FRAMEWORK}/Versions/Current`
TCLSH=${TCL_FRAMEWORK}/Versions/Current/tclsh${TCL_VERSION}
SQLITE_VERSION="3.52.0"
SRC_DIR="sqlite-src-3520000"
SRC_ARCHIVE=${SRC_DIR}.zip
URL=https://sqlite.org/2026/${SRC_ARCHIVE}
HASH="652a98ca833ed638809a52bec225a7f37799f71a995778f9ccb68ad03bd1fc11"
#Reported hash ????
#HASH="a2f0a14b6530138b0c8c096f4b5e5c9d3c1b8a5effa565c91f983e1235f9e26a"
SQLITE_CFLAGS="-mmacosx-version-min=10.13"
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
