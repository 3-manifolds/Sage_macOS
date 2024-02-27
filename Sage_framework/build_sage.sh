VERSION=`../bin/get_sage_version`
if [ -L /var/tmp/sage-$VERSION-current ]; then
    rm /var/tmp/sage-$VERSION-current
elif [ -e /var/tmp/sage-$VERSION-current ]; then
    echo /var/tmp/sage-$VERSION-current is not a symlink !!!
    exit 1
fi

# For the build, we relocate the sage root to the location where the
# sage symlink will be when sage is actually being run. This tricks the
# build system into generating appropriate shebangs for installed scripts
# and deals with any other random places where sage may use a hardwired
# path to the sage root.  By default a sage build cannot be relocated.

SAGE_SYMLINK="/var/tmp/sage-$VERSION-current"
mv repo/sage ${SAGE_SYMLINK}
pushd ${SAGE_SYMLINK}
# Make sure that runpath.sh exists, is correct, and is executable.
# The sage bash script requires this.
mkdir -p local/var/lib/sage
echo SAGE_SYMLINK=${SAGE_SYMLINK} > local/var/lib/sage/runpath.sh
chmod +x local/var/lib/sage/runpath.sh

if [ $(uname -m) == "arm64" ]; then
    export CFLAGS="-O2 -mmacosx-version-min=11.0"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    export LDFLAGS="-Wl,-platform_version,macos,11.0,11.1 -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
    export MACOSX_DEPLOYMENT_TARGET="11.0"
#    export CC=/usr/bin/gcc
#    export CXX=/usr/bin/clang++
#    export FC=/opt/homebrew/bin/gfortran-11
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
CONFIG_OPTIONS="--with-system-python3=no \
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
--enable-cryptominisat \
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
make configure
./configure $CONFIG_OPTIONS > /tmp/configure.out
# Do the main build with 4 CPUs
make -j4 build
# Install cocoserver "by hand" - this is simpler than making an spkg.
SITE_PACKAGES=`venv/bin/python3 -c "import site; print(site.getsitepackages()[0])"`
PIP_ARGS="install --upgrade --no-user --no-deps --target ${SITE_PACKAGES}"
venv/bin/python3 -m pip ${PIP_ARGS} cocoserver
# Build the documentatation.
# The doc build does not seem to work when done in parallel, so no -j4.
pushd src/doc
make PATH=$SAGE_SYMLINK/venv/bin:$PATH SAGE_ROOT=$SAGE_SYMLINK doc-html--all
popd
# Move the repo back where it belongs.
popd
mv /var/tmp/sage-$VERSION-current repo/sage
# Fix the broken p_group_cohomology spkg
cp -R repo/p_group_cohomology-3.3.2/gap_helper repo/sage/local/share/gap/pkg/p_group_cohomology_helper
cp repo/p_group_cohomology-3.3.2/singular_helper/dickson.lib repo/sage/local/share/singular/LIB
# Copy and compress the documentation
if [ -e repo/documentation ]; then
    rm -rf repo/documentation.old
    mv repo/documentation repo/documentation.old
fi
cp -R repo/sage/local/share/doc/sage/html/en repo/documentation
../bin/compress_site.py repo/documentation
