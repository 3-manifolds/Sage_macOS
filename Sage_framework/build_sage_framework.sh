BASE_DIR=`pwd`
VERSION=`../bin/get_sage_version`
SAGE_SYMLINK="/var/tmp/sage-$VERSION-current"
PYTHON_LONG_VERSION=`readlink repo/sage/venv | cut -f2 -d '-' | sed s/python//`
PYTHON_VERSION=`echo ${PYTHON_LONG_VERSION} | cut -f 1,2 -d'.'`
PY_VRSN=`echo ${PYTHON_VERSION} | sed 's/\\.//g'`
echo Building framework for SageMath ${VERSION} using Python ${PYTHON_LONG_VERSION}
TKINTER_LIB=_tkinter.cpython-${PY_VRSN}-darwin.so
REPO=${BASE_DIR}/repo/sage
FILES=${BASE_DIR}/files
BUILD=${BASE_DIR}/build
VERSION_DIR=${BUILD}/Sage.framework/Versions/${VERSION}
CURRENT_DIR=${BUILD}/Sage.framework/Versions/Current
RESOURCE_DIR=${VERSION_DIR}/Resources
VENV_DIR="local/var/lib/sage/venv-python${PYTHON_LONG_VERSION}"
VENV_PYLIB="${VENV_DIR}/lib/python${PYTHON_VERSION}"
VENV_KERNEL_DIR=${VERSION_DIR}/"${VENV_DIR}/share/jupyter/kernels"
NBEXTENSIONS="${VERSION_DIR}/${VENV_DIR}/share/jupyter/nbextensions"
THREEJS_SAGE="${NBEXTENSIONS}/threejs-sage"
INPUT_HOOKS=${VERSION_DIR}/${VENV_PYLIB}/site-packages/IPython/terminal/pt_inputhooks

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
ln -s ${VENV_DIR} ${VERSION_DIR}/venv

# Create the resource files
cp "${REPO}"/{COPYING.txt,README.md,VERSION.txt} "${RESOURCE_DIR}"
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/Info.plist > "${RESOURCE_DIR}"/Info.plist
cp ${FILES}/pip.conf ${RESOURCE_DIR}
mkdir -p ${VERSION_DIR}/local/{bin,include,lib,etc,libexec}
echo "Copying files ..."
cp -R "${REPO}"/local/bin/ ${VERSION_DIR}/local/bin
cp -R "${REPO}"/local/include/ ${VERSION_DIR}/local/include
cp -R "${REPO}"/local/lib/ ${VERSION_DIR}/local/lib
cp -R "${REPO}"/local/etc/ ${VERSION_DIR}/local/etc
cp -R "${REPO}"/local/libexec/ ${VERSION_DIR}/local/libexec
ln -s lib "${VERSION_DIR}"/local/lib64
mkdir -p ${VERSION_DIR}/local/var/lib/sage/{installed,scripts}
mkdir -p ${VERSION_DIR}/${VENV_DIR}/etc
cp -R "${REPO}"/local/var/lib/sage/installed/ ${VERSION_DIR}/local/var/lib/sage/installed
cp -R "${REPO}"/local/var/lib/sage/scripts/ ${VERSION_DIR}/local/var/lib/sage/scripts
cp -R "${REPO}"/${VENV_DIR}/{bin,lib,include,share} ${VERSION_DIR}/${VENV_DIR}
cp -R "${REPO}"/${VENV_DIR}/etc/jupyter ${VERSION_DIR}/${VENV_DIR}/etc

# Copy the useful parts of local/share
rm -rf ${VERSION_DIR}/${VENV_DIR}/share/{doc,man}
mkdir -p ${VERSION_DIR}/local/share
for share_dir in `ls "${REPO}"/local/share`; do
    if [ $share_dir != "doc" ]; then
	cp -R "${REPO}"/local/share/$share_dir ${VERSION_DIR}/local/share/$share_dir
    fi
done

# Create the runpath.sh script
echo SAGE_SYMLINK=/var/tmp/sage-${VERSION}-current > ${VERSION_DIR}/local/var/lib/sage/runpath.sh
chmod 755 ${VERSION_DIR}/local/var/lib/sage/runpath.sh

# Copy our modified files into the bundle
# Install jupyter kernels, etc.
rm -rf ${VERSION_DIR}/${VENV_DIR}/share/jupyter/kernels/sagemath
# See sage/repl/ipython_kernel/install.py
mkdir -p ${VENV_KERNEL_DIR}/sagemath
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${VENV_KERNEL_DIR}/sagemath/kernel.json
#cp -p ${FILES}/${TKINTER} ${VERSION_DIR}/${VENV_PYLIB}/lib-dynload/
cp -p ${FILES}/tkinter/__init__.py ${VERSION_DIR}/${VENV_PYLIB}/tkinter/__init__.py
cp ${FILES}/osx.py ${INPUT_HOOKS}
cp -p ${FILES}/BuildPackages.sh ${VERSION_DIR}/local/lib/gap/bin
cp ${FILES}/sage-notebook ${VERSION_DIR}/${VENV_DIR}/bin
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/sage-notebook > ${VERSION_DIR}/${VENV_DIR}/bin/sage-notebook
cp ${FILES}/sage ${VERSION_DIR}/${VENV_DIR}/bin
cp ${FILES}/sage-env ${VERSION_DIR}/${VENV_DIR}/bin
cp ${FILES}/sagedoc.py ${VERSION_DIR}/${VENV_PYLIB}/site-packages/sage/misc/
cp ${FILES}/ipython_kernel/* ${VERSION_DIR}/${VENV_PYLIB}/site-packages/sage/repl/ipython_kernel
# Fix illegal symlinks that point outside of the bundle
rm -rf ${VERSION_DIR}/local/share/jupyter/kernels/sagemath/doc
rm -f ${VERSION_DIR}/local/share/threejs-sage/threejs-sage
rm -rf ${THREEJS_SAGE}
ln -s ../../../../../../../share/threejs-sage ${THREEJS_SAGE}

# Make @interact work
mkdir -p ${NBEXTENSIONS}/widgets/notebook
ln -s ../../jupyter-js-widgets ${NBEXTENSIONS}/widgets/notebook/js

# Remove some useless stuff
rm -rf ${VERSION_DIR}/local/lib/saclib
rm -rf ${VERSION_DIR}/local/share/man

# Update Sage's jupyter kernel directory.
rm -rf  ${VERSION_DIR}/venv/share/jupyter/kernels
cp -R ../package/local_share/jupyter/kernels ${VERSION_DIR}/venv/share/jupyter

# # Install current versions of pip packages over the ones built by Sage

if [ -L ${SAGE_SYMLINK} ]; then
    rm ${SAGE_SYMLINK}
elif [ -e ${SAGE_SYMLINK} ]; then
    echo ${SAGE_SYMLINK} is not a symlink !!!
    exit 1
fi
mv $VERSION_DIR $SAGE_SYMLINK
pushd ${SAGE_SYMLINK}

PIP_ARGS="install --upgrade --no-user --force-reinstall --upgrade-strategy eager"
venv/bin/python3 -m pip $PIP_ARGS jupyterlab
venv/bin/python3 -m pip $PIP_ARGS notebook
venv/bin/python3 -m pip $PIP_ARGS pillow

# Install cocoserver
PIP_ARGS="install --no-user --upgrade --no-deps"
venv/bin/python3 -m pip $PIP_ARGS cocoserver

popd
mv $SAGE_SYMLINK $VERSION_DIR

# Fix up rpaths and shebangs 
echo "Patching files ..."
source ../IDs.sh
mv files_to_sign files_to_sign.bak
python3 fix_paths.py repo ${VERSION_DIR}/local/bin >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/local/lib >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/local/libexec >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/${VENV_DIR}/bin >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/${VENV_DIR}/lib >> files_to_sign
python3 fix_scripts.py ${VERSION_DIR}/$VENV_DIR}/bin

# Fix the absolute symlinks for the GAP packages
pushd ${VERSION_DIR}/local/share/gap/pkg > /dev/null
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
# Overwrite the _tkinter extension with our signed version
cp -p ${FILES}/${TKINTER_LIB} ${VERSION_DIR}/${VENV_PYLIB}/lib-dynload/
# Start sage to create a minimal set of bytecode files.
echo "Starting Sage to create byte code files ..."
${VERSION_DIR}/venv/bin/sage -c "print(2+2) ; exit"
echo "We need to sign the framework again:"
python3 sign_sage.py framework
