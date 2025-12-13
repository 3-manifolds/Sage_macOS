#!/bin/bash
if ! [ -e repo/sage ]; then
    echo "The sage distribution is not where we expect to find it."
    echo "This script must be run from the Sage_framework directory."
    exit 1
fi

VERSION=`../bin/get_sage_version`
SAGE_SYMLINK="/var/tmp/sage-$VERSION-current"

# By default, a sage build cannot be relocated.  This build is
# relocatable.  This is done by using a symlink in /var/tmp which
# points to the current location of the sage root.
#
# To make this work, we relocate the sage source tree to the location
# where the sage symlink will be when sage is actually being run. This
# tricks the sage build system into generating appropriate shebangs
# for installed scripts and deals with any other random places where
# sage may use a hardwired path to the sage root.
#
# To build a framework that can be used in a macOS app we also need
# to edit all loader paths and rpaths, making them relative by using
# @loader_path.  This is done in a separate pass.

if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
    exit 1
fi
mv repo/sage ${SAGE_SYMLINK}
pushd ${SAGE_SYMLINK}

# Make sure that runpath.sh exists, is correct, and is executable.
# The sage bash script requires this.
mkdir -p local/var/lib/sage
echo SAGE_SYMLINK=${SAGE_SYMLINK} > local/var/lib/sage/runpath.sh
chmod +x local/var/lib/sage/runpath.sh

SAGE_INC="`pwd`/local/include"
SAGE_LIB="`pwd`/local/lib"

# Set environment variables for the build.
# CPPFLAGS are needed for the autoconf macro to find the absolute path to gmp.h
if [ $(uname -m) == "arm64" ]; then
    export CFLAGS="-O2 -mmacosx-version-min=11.0 -I$SAGE_INC"
    export CPPFLAGS="-I$SAGE_INC"
    export CXXFLAGS="$CFLAGS"
    #export CXX="/usr/bin/g++ -std=gnu++11 -std=gnu++17 $CFLAGS"
    export LDFLAGS="-Wl,-platform_version,macos,11.0,11.3  -L$SAGE_LIB"
    export MACOSX_DEPLOYMENT_TARGET="11.0"
else
    export GMP_CONFIGURE="--enable-fat"
    export SAGE_FAT_BINARY="yes"
    export CFLAGS="-O2 -mmacosx-version-min=10.13 -mno-avx2 -mno-bmi2 -I$SAGE_INC"
    export CPPFLAGS="-I$SAGE_INC"
    export CXXFLAGS="$CFLAGS"
    #export CXX="/usr/bin/g++ -std=gnu++11 -std=gnu++17 $CFLAGS"
    # if [ `/usr/bin/ld -ld_classic 2> >(grep -c warning)` != "0" ] ; then
    # 	export LDFLAGS="-ld_classic -Wl,-platform_version,macos,10.13,11.0 -L$SAGE_LIB"
    # else
    # 	export LDFLAGS="-Wl,-platform_version,macos,10.13,11.0 -L$SAGE_LIB"
    # fi
    export LDFLAGS="-Wl,-platform_version,macos,10.13,10.13 -L$SAGE_LIB"
    export MACOSX_DEPLOYMENT_TARGET="10.13"
fi
export SSL_CERT_FILE=`python3 -c "import ssl; print(ssl.get_default_verify_paths().cafile)"`
#export PKG_CONFIG_PATH=`pwd`/local/lib/pkgconfig
       
# Run bootstrap and configure.
CONFIG_OPTIONS=" \
PKG_CONFIG_PATH=`pwd`/local/lib/pkgconfig \
--with-sage-venv=no \
--with-python=`pwd`/local/bin/python3 \
--with-system-scipy=yes \
--disable-editable \
--enable-isl \
--enable-4ti2 \
--enable-benzene \
--enable-gap_packages \
--enable-latte_int \
--enable-bliss \
--enable-buckygen \
--enable-cbc \
--enable-coxeter3 \
--enable-csdp \
--enable-e_antic \
--enable-frobby \
--enable-gp2c \
--enable-igraph \
--enable-kenzo \
--enable-libnauty \
--enable-libsemigroups \
--enable-lrslib \
--enable-meataxe \
--enable-mcqd \
--enable-mpfrcx \
--enable-normaliz \
--enable-p_group_cohomology \
--enable-pari_elldata \
--enable-pari_galpol \
--enable-pari_nftables \
--enable-plantri \
--enable-sage_numerical_backends_coin \
--enable-pynormaliz \
--enable-pycosat \
--enable-pysingular \
--enable-qepcad \
--enable-sirocco \
--enable-symengine \
--enable-symengine_py \
--enable-tdlib \
--enable-tides"

./bootstrap
./configure $CONFIG_OPTIONS > /tmp/configure.out

# Do the main build with 8 CPUs
export MAKE="make -j8"
make build

# Move the repo back where it came from.
popd
mv /var/tmp/sage-$VERSION-current repo/sage
