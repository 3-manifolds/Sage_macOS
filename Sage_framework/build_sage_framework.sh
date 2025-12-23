BASE_DIR=`pwd`
VERSION=`../bin/get_sage_version`
SAGE_SYMLINK="/var/tmp/sage-${VERSION}-current"
PYTHON_LONG_VERSION=`repo/sage/local/bin/python3 --version | cut -f2 -d '-' | sed 's/Python //'`
PYTHON_VERSION=`echo ${PYTHON_LONG_VERSION} | cut -f 1,2 -d'.'`
PY_VRSN=`echo ${PYTHON_VERSION} | sed 's/\\.//g'`
##TKINTER_LIB=_tkinter.cpython-${PY_VRSN}-darwin.so
REPO="${BASE_DIR}/repo/sage"
FILES="${BASE_DIR}/files"
BUILD="${BASE_DIR}/build"
VERSION_DIR="${BUILD}/Sage.framework/Versions/${VERSION}"
CURRENT_DIR="${BUILD}/Sage.framework/Versions/Current"
RESOURCE_DIR="${VERSION_DIR}/Resources"
PYLIB="local/lib/python${PYTHON_VERSION}"
SITE_PACKAGES="${VERSION_DIR}/${PYLIB}/site-packages"
KERNEL_DIR="${VERSION_DIR}/local/share/jupyter/kernels"
INPUT_HOOKS="${VERSION_DIR}/${PYLIB}/site-packages/IPython/terminal/pt_inputhooks"
SAGE_SRC="${REPO}/src"

echo Building framework for SageMath ${VERSION} using Python ${PYTHON_LONG_VERSION}

# This allows Sage.framework to be a symlink to the framework inside the application.
if ! [ -d "${BUILD}/Sage.framework" ]; then
    mkdir -p "${BUILD}"/Sage.framework
fi

# Clean out everything.
echo Removing old framework ...
rm -rf "${BUILD}"/Sage.framework/*

# Create the bundle directories
mkdir -p "${RESOURCE_DIR}"
ln -s ${VERSION} "${CURRENT_DIR}"
ln -s Versions/Current/Resources "${BUILD}"/Sage.framework/Resources

# Create the resource files
cp "${REPO}"/{COPYING.txt,README.md,VERSION.txt} "${RESOURCE_DIR}"
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/Info.plist > "${RESOURCE_DIR}"/Info.plist
cp "${FILES}"/pip.conf "${RESOURCE_DIR}"
mkdir -p "${VERSION_DIR}"/local/{bin,include,lib,etc,libexec}

# Copy parts of local
echo "Copying files ..."
cp -a "${REPO}"/local/bin/ "${VERSION_DIR}"/local/bin
cp -a "${REPO}"/local/include/ "${VERSION_DIR}"/local/include
cp -a "${REPO}"/local/lib/ "${VERSION_DIR}"/local/lib
cp -a "${REPO}"/local/etc/ "${VERSION_DIR}"/local/etc
cp -a "${REPO}"/local/libexec/ "${VERSION_DIR}"/local/libexec
ln -s lib "${VERSION_DIR}"/local/lib64
mkdir -p "${VERSION_DIR}"/local/var/lib/sage/{installed,scripts}
mkdir -p "${VERSION_DIR}"/local/etc
cp -a "${REPO}"/local/var/lib/sage/installed/ "${VERSION_DIR}"/local/var/lib/sage/installed
cp -a "${REPO}"/local/var/lib/sage/scripts/ "${VERSION_DIR}"/local/var/lib/sage/scripts
cp -a "${REPO}"/local/{bin,lib,include,share} "${VERSION_DIR}"/local
cp -a "${REPO}"/local/etc/jupyter "${VERSION_DIR}"/local/etc

# Remove parts of local/share that we won't use.
rm -rf "${VERSION_DIR}"/local/lib/pkgconfig
rm -rf "${VERSION_DIR}"/local/share/{doc,man}
rm -rf "${VERSION_DIR}"/local/lib/saclib

# Create the runpath.sh script
echo SAGE_SYMLINK=/var/tmp/sage-${VERSION}-current > "${VERSION_DIR}"/local/var/lib/sage/runpath.sh
chmod 755 "${VERSION_DIR}"/local/var/lib/sage/runpath.sh

# Copy our modified files into the bundle
# Install jupyter kernels, etc.
rm -rf "${KERNEL_DIR}"
# See sage/repl/ipython_kernel/install.py
mkdir -p ${KERNEL_DIR}/SageMath-${VERSION}
mkdir -p ${KERNEL_DIR}/python3
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${KERNEL_DIR}/SageMath-${VERSION}/kernel.json
cp ${FILES}/kernel_logos/* ${KERNEL_DIR}/SageMath-${VERSION}
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/python_kernel.json > ${KERNEL_DIR}/python3/kernel.json
cp ${FILES}/osx.py ${INPUT_HOOKS}
cp -p ${FILES}/BuildPackages.sh "${VERSION_DIR}"/local/lib/gap/bin
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/sage-notebook > "${VERSION_DIR}"/local/bin/sage-notebook
chmod +x "${VERSION_DIR}"/local/bin/sage-notebook
# This overwrites the entrypoint for the new sage extension module,
# which is useless for actually running Sage.
cp ${FILES}/sage "${VERSION_DIR}"/local/bin
cp ${FILES}/sagedoc.py "${VERSION_DIR}"/${PYLIB}/site-packages/sage/misc/
cp ${FILES}/ipython_kernel/* "${VERSION_DIR}"/${PYLIB}/site-packages/sage/repl/ipython_kernel
cp ${SAGE_SRC}/bin/sage-eval "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-env "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-ipython "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-notebook "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-run "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-preparse "${VERSION_DIR}"/local/bin
cp ${SAGE_SRC}/bin/sage-version.sh "${VERSION_DIR}"/local/bin

# Make sure that the venv symlink exists -- just in case ...
if ! [ -e "${VERSION_DIR}/venv" ]; then
    ln -s local "${VERSION_DIR}/venv"
fi

# # Install current versions of pip packages over the ones built by Sage

if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
    exit 1
fi
ln -s "${VERSION_DIR}" "${SAGE_SYMLINK}"
pushd "${SAGE_SYMLINK}"

PIP_ARGS="install --upgrade --no-user --force-reinstall --upgrade-strategy eager"
echo "Reinstalling jupyterlab"
local/bin/python3 -m pip $PIP_ARGS jupyterlab
echo "Reinstalling notebook"
PIP_ARGS="install --upgrade --no-user"
local/bin/python3 -m pip $PIP_ARGS notebook
local/bin/python3 -m pip $PIP_ARGS ipympl
echo "Reinstalling pillow"
local/bin/python3 -m pip $PIP_ARGS pillow
echo "Installing cocoserver"
PIP_ARGS="install --upgrade --no-user --no-deps"
local/bin/python3 -m pip $PIP_ARGS cocoserver
popd

# Fix up rpaths and shebangs 
echo "Rewriting load paths ..."
source ../IDs.sh
python3 fix_paths.py repo "${VERSION_DIR}"/local/bin 2> /dev/null
python3 fix_paths.py repo "${VERSION_DIR}"/local/lib 2> /dev/null
python3 fix_paths.py repo "${VERSION_DIR}"/local/libexec 2> /dev/null
python3 fix_scripts.py "${VERSION_DIR}"/local/bin

# Some sagelib extension modules have bad rpaths
ECL_SO="${SITE_PACKAGES}/sage/libs/ecl.cpython-${PY_VRSN}-darwin.so"
macher clear_rpaths ${ECL_SO}
macher add_rpath @loader_path/../../../../ ${ECL_SO}

BLISS_SO="${SITE_PACKAGES}/sage/graphs/bliss.cpython-${PY_VRSN}-darwin.so"
macher add_rpath @loader_path/../../../.. $BLISS_SO

# Fix the absolute symlinks for the GAP packages
pushd "${VERSION_DIR}"/local/share/gap/pkg > /dev/null
for pkg in `ls` ; do
  if [[ -L $pkg/bin ]]; then
    rm $pkg/bin ;
    ln -s ../../../../lib/gap/pkg/$pkg/bin $pkg/bin ; 
  fi
done
popd > /dev/null

# Remove xattrs (must be done before signing!)
xattr -rc ${BUILD}/Sage.framework

# Remove byte code
find ${BUILD}/Sage.framework -name '*.pyc' -delete

# Fix up load paths
python3 fix_paths.py repo/sage Frameworks/Sage.framework

echo "Starting Sage to create byte code files ..."
"${SAGE_SYMLINK}"/local/bin/sage -c "print(2 + 2) ; exit"

# Sign the framework.
echo "Signing files ..."
python3 -m notabot.sign ${BUILD}/Sage.framework

# Remove the symlink
rm "${SAGE_SYMLINK}"
