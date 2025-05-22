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
KERNEL_DIR="${VERSION_DIR}/local/share/jupyter/kernels"
INPUT_HOOKS="${VERSION_DIR}/${PYLIB}/site-packages/IPython/terminal/pt_inputhooks"

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
rm -rf "${VERSION_DIR}"/local/share/jupyter/kernels/sagemath
# See sage/repl/ipython_kernel/install.py
mkdir -p ${KERNEL_DIR}/sagemath
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${KERNEL_DIR}/sagemath/kernel.json
cp ${FILES}/osx.py ${INPUT_HOOKS}
cp -p ${FILES}/BuildPackages.sh "${VERSION_DIR}"/local/lib/gap/bin
cp ${FILES}/sage-notebook "${VERSION_DIR}"/local/bin
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/sage-notebook > "${VERSION_DIR}"/local/bin/sage-notebook
cp ${FILES}/sage "${VERSION_DIR}"/local/bin
cp ${FILES}/sage-env "${VERSION_DIR}"/local/bin
cp ${FILES}/sagedoc.py "${VERSION_DIR}"/${PYLIB}/site-packages/sage/misc/
cp ${FILES}/ipython_kernel/* "${VERSION_DIR}"/${PYLIB}/site-packages/sage/repl/ipython_kernel

# Make sure that the venv symlink exists -- just in case ...
if ! [ -e "${VERSION_DIR}/venv" ]; then
    ln -s local "${VERSION_DIR}/venv"
fi

# Update Sage's jupyter kernel directory.
rm -rf  "${VERSION_DIR}"/local/share/jupyter/kernels
cp -R ../package/local_share/jupyter/kernels "${VERSION_DIR}"/local/share/jupyter

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
echo "Installing notebook"
PIP_ARGS="install --upgrade --no-user"
local/bin/python3 -m pip $PIP_ARGS notebook
echo "Renstalling pillow"
local/bin/python3 -m pip $PIP_ARGS pillow
echo "Installing cocoserver"
PIP_ARGS="install --upgrade --no-user --no-deps"
local/bin/python3 -m pip $PIP_ARGS cocoserver
popd

# Fix up rpaths and shebangs 
echo "Rewriting load paths ..."
source ../IDs.sh
mv files_to_sign files_to_sign.bak
python3 fix_paths.py repo "${VERSION_DIR}"/local/bin >> files_to_sign
python3 fix_paths.py repo "${VERSION_DIR}"/local/lib >> files_to_sign
python3 fix_paths.py repo "${VERSION_DIR}"/local/libexec >> files_to_sign
python3 fix_scripts.py "${VERSION_DIR}"/local/bin

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
# Sign the framework.
echo "Signing files ..."
python3 sign_sage.py

echo "Starting Sage to create byte code files ..."
"${SAGE_SYMLINK}"/local/bin/sage -c "print(2 + 2) ; exit"
echo "We need to sign the framework again:"
rm "${SAGE_SYMLINK}"
python3 sign_sage.py framework
