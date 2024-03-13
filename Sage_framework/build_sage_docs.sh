VERSION=`../bin/get_sage_version`
SAGE_SYMLINK=/var/tmp/sage-$VERSION-current
if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
fi
# Build the documentatation.
# The doc build does not seem to work when done in parallel, so no -j4.
mv repo/sage ${SAGE_SYMLINK}
pushd ${SAGE_SYMLINK}
# Make sure that runpath.sh exists, is correct, and is executable.
# The sage bash script requires this.
mkdir -p local/var/lib/sage
echo SAGE_SYMLINK=${SAGE_SYMLINK} > local/var/lib/sage/runpath.sh
chmod +x local/var/lib/sage/runpath.sh
make doc-clean doc-uninstall
pushd src/doc
export PATH=${SAGE_SYMLINK}/venv/bin:$PATH
export SAGE_ROOT=${SAGE_SYMLINK}
make doc-html--all
popd
popd
mv ${SAGE_SYMLINK} repo/sage
# Copy and compress the documentation
if [ -e repo/documentation ]; then
    rm -rf repo/documentation.old
    mv repo/documentation repo/documentation.old
fi
cp -R repo/sage/local/share/doc/sage/html/en repo/documentation
../bin/compress_site.py repo/documentation
