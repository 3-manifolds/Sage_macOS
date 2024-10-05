# This script replaces sage's pillow and notebook packages and their
# dependencies with current versions installed from binary wheels.  It
# also installs cocoserver, for viewing the documentation.

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

# Set environment variables for the build.
if [ $(uname -m) == "arm64" ]; then
    export CFLAGS="-O2 -mmacosx-version-min=11.0"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    export LDFLAGS="-Wl,-platform_version,macos,11.0,11.1 -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
    export MACOSX_DEPLOYMENT_TARGET="11.0"
else
    export GMP_CONFIGURE="--enable-fat"
    export SAGE_FAT_BINARY="yes"
    export CFLAGS="-O2 -mmacosx-version-min=10.9 -mno-avx -mno-avx2 -mno-bmi2"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    if [ `/usr/bin/ld -ld_classic 2> >(grep -c warning)` != "0" ] ; then
	export LDFLAGS="-ld_classic -Wl,-platform_version,macos,10.9,11.3"
    else
	export LDFLAGS="-Wl,-platform_version,macos,10.9,11.3"
    fi
    export MACOSX_DEPLOYMENT_TARGET="10.9"
fi
# Run bootstrap and configure.
CONFIG_OPTIONS="--with-system-python3=no \
--disable-notebook \
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

# Force xz to be built first.  Otherwise it gets built after gmp even
# though gmp lists xz as a dependency.  This causes gmp and the
# many packages that depend on it to get rebuilt in every incremental
# build.  That is very frustrating.
make xz

# Do the main build with 8 CPUs
export MAKE="make -j8"
make -j8 build

# Re-install pillow jupyterlab and notebook.
PIP_ARGS="install --no-user --force-reinstall --upgrade-strategy eager"
venv/bin/python3 -m pip $PIP_ARGS pillow jupyterlab notebook
# Install cocoserver
PIP_ARGS="install --no-user --upgrade --no-deps"
venv/bin/python3 -m pip $PIP_ARGS cocoserver
# Move the repo back where it belongs.
popd
mv /var/tmp/sage-$VERSION-current repo/sage
