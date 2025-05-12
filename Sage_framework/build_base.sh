if ! [ -e base/sage ]; then
    echo "The base distribution is not where we expect to find it."
    echo "This script must be run from the Sage_framework directory."
    exit 1
fi

VERSION=`../bin/get_sage_version`
SAGE_SYMLINK="/var/tmp/sage-$VERSION-current"

# By default, a sage build cannot be relocated.  Sage_macOS is
# relocatable.  This is done by using a symlink in /var/tmp which
# points to the current location of the sage root.
#
# To make this work, we relocate the sage source tree to the location
# where the sage symlink will be when sage is actually being run. This
# tricks the sage build system into generating appropriate shebangs
# for installed scripts and deals with any other random places where
# sage may use a hardwired path to the sage root.
#

if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
    exit 1
fi
mv base/sage ${SAGE_SYMLINK}
pushd ${SAGE_SYMLINK}

# Do the main build with 8 CPUs using gmake
gmake -j8

# Move the repo back where it came from.
popd
mv /var/tmp/sage-$VERSION-current base/sage
