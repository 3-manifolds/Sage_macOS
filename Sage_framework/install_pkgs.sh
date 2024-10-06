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
if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
    exit 1
fi
mv repo/sage ${SAGE_SYMLINK}
pushd ${SAGE_SYMLINK}
# Re-install pillow jupyterlab and notebook.
PIP_ARGS="install --no-user --force-reinstall --upgrade-strategy eager"
venv/bin/python3 -m pip $PIP_ARGS pillow jupyterlab notebook
# Install cocoserver
PIP_ARGS="install --no-user --upgrade --no-deps"
venv/bin/python3 -m pip $PIP_ARGS cocoserver
# Move the repo back where it belongs.
popd
mv /var/tmp/sage-$VERSION-current repo/sage
