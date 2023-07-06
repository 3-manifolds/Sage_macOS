VERSION=`../bin/get_sage_version`
PYTHON="repo/sage/venv/bin/python3"
PY_VERSION=`${PYTHON} -V | cut -d' ' -f2 | cut -d. -f1,2`
SITE_PACKAGES="venv/lib/python${PY_VERSION}/site-packages"
PIP_INSTALL="venv/bin/sage -pip install"
PIP_OPTS="--upgrade --no-user --no-deps --target ${SITE_PACKAGES}"
if [ -L /var/tmp/sage-$VERSION-current ]; then
    rm /var/tmp/sage-$VERSION-current
elif [ -e /var/tmp/sage-$VERSION-current ]; then
    echo /var/tmp/sage-$VERSION-current is not a symlink !!!
fi
mv repo/sage /var/tmp/sage-$VERSION-current
pushd /var/tmp/sage-$VERSION-current
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
    export LDFLAGS="-Wl,-platform_version,macos,10.9,11.3"
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
make -j4 build
make
# Install some extra pip packages
${PIP_INSTALL} ${PIP_OPTS} cocoserver
popd
mv /var/tmp/sage-$VERSION-current repo/sage
# Fix the broken p_group_cohomology spkg
cp -R repo/p_group_cohomology-3.3.2/gap_helper repo/sage/local/share/gap/pkg/p_group_cohomology_helper
cp repo/p_group_cohomology-3.3.2/singular_helper/dickson.lib repo/sage/local/share/singular/LIB
# Copy and compress the documentation
rm -rf repo/documentation.old
mv repo/documentation repo/documentation.old
cp -R repo/sage/local/share/doc/sage/html/en repo/documentation
../bin/compress_site.py repo/documentation
