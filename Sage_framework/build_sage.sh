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

# Install micromamba
MICROMAMBA_VERSION="1.5.10-0"
if [[ "$(uname -m)" == "arm64" ]]; then
  osx_arch="osx-arm64"
else
  osx_arch="osx-64"
fi
MICROMAMBA_URL="https://github.com/mamba-org/micromamba-releases/releases/download/${MICROMAMBA_VERSION}/micromamba-${osx_arch}"
MICROMAMBA_DIR="${PWD}/micromamba"
MICROMAMBA_EXE="${MICROMAMBA_DIR}/micromamba"
if [[ ! -f ${MICROMAMBA_EXE} ]]; then
  mkdir -p ${MICROMAMBA_DIR}
  curl -L -o "${MICROMAMBA_EXE}" "${MICROMAMBA_URL}"
  chmod +x "${MICROMAMBA_EXE}"
fi
eval "$(${MICROMAMBA_EXE} shell hook --shell bash)"

# Set environment variables for the build.
if [ $(uname -m) == "arm64" ]; then
    export CFLAGS="-O2 -mmacosx-version-min=11.0"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    export LDFLAGS="-Wl,-platform_version,macos,11.0,11.1 -L/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib"
    export MACOSX_DEPLOYMENT_TARGET="11.0"
    export CONDA_OVERRIDE_OSX=11.0
else
    export GMP_CONFIGURE="--enable-fat"
    export SAGE_FAT_BINARY="yes"
    export CFLAGS="-O2 -mmacosx-version-min=10.12 -mno-avx2 -mno-bmi2"
    export CXXFLAGS="$CFLAGS -stdlib=libc++"
    if [ `/usr/bin/ld -ld_classic 2> >(grep -c warning)` != "0" ] ; then
	export LDFLAGS="-ld_classic -Wl,-platform_version,macos,10.12,11.3"
    else
	export LDFLAGS="-Wl,-platform_version,macos,10.12,11.3"
    fi
    export MACOSX_DEPLOYMENT_TARGET="10.12"
    export CONDA_OVERRIDE_OSX=10.13
fi

OPTIONAL_PKGS=" \
isl \
4ti2 \
benzene \
bliss \
gap_packages \
latte_int \
bliss \
buckygen \
cbc \
coxeter3 \
sagemath_coxeter3 \
csdp \
e_antic \
frobby \
igraph \
kenzo \
libnauty \
libsemigroups \
lrslib \
meataxe \
sagemath_meataxe \
mcqd \
mpfrcx \
normaliz \
p_group_cohomology \
pari_elldata \
pari_galpol \
pari_nftables \
plantri \
sagemath-bliss \
sage_numerical_backends_coin \
pynormaliz \
pycosat \
pysingular \
qepcad \
sirocco \
sagemath_sirocco \
symengine \
symengine_py \
tdlib \
tides "

# Disable some conda packages. This is strictly not necessary
# as they get overriden by the SPKGS, but good to keep track

# These packages don't have osx-arm64 packages
DISABLE_CONDA="4ti2 latte_int lrslib pynormaliz pysingular"
# These depend on sagelib
DISABLE_CONDA="$DISABLE_CONDA sagemath_sirocco"
# No spkg-configure.m4
DISABLE_CONDA="$DISABLE_CONDA e_antic elliptic_curves"
# lrsnash missing
DISABLE_CONDA="$DISABLE_CONDA lrslib"
# spkg-configure.m4 insufficient
DISABLE_CONDA="$DISABLE_CONDA mathjax threejs"
# not sure what's going on here
DISABLE_CONDA="$DISABLE_CONDA pythran symengine"

CONDA_PKGS="autoconf automake libtool pkg-config python=3.13"
for pkg_path in ${SAGE_SYMLINK}/build/pkgs/*; do
  pkg=$(basename $pkg_path)
  if [[ " ${DISABLE_CONDA} " != *" ${pkg} "* && -f "${pkg_path}/type" && -f "${pkg_path}/distros/conda.txt" ]]; then
    pkg_type=$(cat ${pkg_path}/type)
    if [[ "${pkg_type}" == "standard" || "${OPTIONAL_PKGS}" == *" ${pkg} "* ]]; then
      conda_txt=$(cat ${pkg_path}/distros/conda.txt | sed '/#/d')
      CONDA_PKGS="${CONDA_PKGS} ${conda_txt}"
    fi
  fi
done

echo ${CONDA_PKGS}

# Use micromamba to install a binary
micromamba create --yes \
  --root-prefix "${MICROMAMBA_DIR}" \
  --prefix "${PWD}/local" \
  -c conda-forge \
  ${CONDA_PKGS}

micromamba activate -p "${PWD}/local"
# some optional packages don't understand arm64-apple-darwin
unset build_alias
unset host_alias
# workaround for https://github.com/conda-forge/cvxopt-feedstock/pull/74
cvxopt_file="${PWD}/local/lib/python3.12/site-packages/cvxopt-0.0.0-py3.12.egg-info/PKG-INFO"
if [[ -f ${cvxopt_file} ]]; then
  sed -i.bak "s/0.0.0/1.3.2/g" ${cvxopt_file}
  rm ${cvxopt_file}.bak
fi

# Make sure that runpath.sh exists, is correct, and is executable.
# The sage bash script requires this.
mkdir -p local/var/lib/sage
echo SAGE_SYMLINK=${SAGE_SYMLINK} > local/var/lib/sage/runpath.sh
chmod +x local/var/lib/sage/runpath.sh

# Run bootstrap and configure.
CONFIG_OPTIONS="--with-python=$(which python3) \
--enable-system-site-packages \
--disable-notebook \
--disable-editable \
--disable-gp2c \
"

for pkg in ${OPTIONAL_PKGS}; do
  CONFIG_OPTIONS="$CONFIG_OPTIONS --enable-${pkg}"
done

./bootstrap
./configure $CONFIG_OPTIONS > /tmp/configure.out

# Do the main build with 8 CPUs
export MAKE="make -j8"
make build

# rm -rf ${MICROMAMBA_DIR}

# Move the repo back where it came from.
popd
mv /var/tmp/sage-$VERSION-current repo/sage
