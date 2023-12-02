BASE_DIR=`pwd`
VERSION=`../bin/get_sage_version`
PYTHON_LONG_VERSION=`readlink repo/sage/venv | cut -f2 -d '-' | sed s/python//`
PYTHON_VERSION=`echo ${PYTHON_LONG_VERSION} | cut -f 1,2 -d'.'`
echo Building framework for SageMath ${VERSION} using Python ${PYTHON_LONG_VERSION}
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
NOTEBOOK_VENV=${VERSION_DIR}/notebook_venv

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
mkdir -p ${VERSION_DIR}/${VENV_DIR}
cp -R "${REPO}"/local/var/lib/sage/installed/ ${VERSION_DIR}/local/var/lib/sage/installed
cp -R "${REPO}"/local/var/lib/sage/scripts/ ${VERSION_DIR}/local/var/lib/sage/scripts
cp -R "${REPO}"/${VENV_DIR}/{bin,lib,include,share} ${VERSION_DIR}/${VENV_DIR}
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
if [ $(uname -m) == "arm64" ]; then
    TKINTER=_tkinter.cpython-311-darwin-arm64.so
else
    TKINTER=_tkinter.cpython-311-darwin-x86_64.so
fi
TKINTER_TARGET=_tkinter.cpython-311-darwin.so
# Install jupyter kernels, etc.
cp -p ${FILES}/page.html ${VERSION_DIR}/${VENV_PYLIB}/site-packages/notebook/templates/page.html
rm -rf ${VERSION_DIR}/${VENV_DIR}/share/jupyter/kernels/sagemath
# See sage/repl/ipython_kernel/install.py
mkdir -p ${VENV_KERNEL_DIR}/sagemath
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${VENV_KERNEL_DIR}/sagemath/kernel.json
cp -p ${FILES}/${TKINTER} ${VERSION_DIR}/${VENV_PYLIB}/lib-dynload/${TKINTER_TARGET}
cp -p ${FILES}/tkinter/__init__.py ${VERSION_DIR}/${VENV_PYLIB}/tkinter/__init__.py
cp ${FILES}/osx.py ${INPUT_HOOKS}
cp -p ${FILES}/BuildPackages.sh ${VERSION_DIR}/local/lib/gap/bin
cp ${FILES}/sage-notebook ${VERSION_DIR}/${VENV_DIR}/bin

# Fix illegal symlinks that point outside of the bundle
# rm ${VERSION_DIR}/local/share/gap/{gac,gap}
# ln -s ../../bin/gac ${VERSION_DIR}/local/share/gap/gac
# ln -s ../../bin/gap ${VERSION_DIR}/local/share/gap/gap
rm -rf ${VERSION_DIR}/local/share/jupyter/kernels/sagemath/doc
rm -f ${VERSION_DIR}/local/share/threejs-sage/threejs-sage
rm -rf ${THREEJS_SAGE}
ln -s ../../../../../../../share/threejs-sage ${THREEJS_SAGE}

# Make @interact work
mkdir -p ${NBEXTENSIONS}/widgets/notebook
ln -s ../../jupyter-js-widgets ${NBEXTENSIONS}/widgets/notebook/js

# Remove useless stuff
rm -rf ${VERSION_DIR}/local/lib/saclib
rm -rf ${VERSION_DIR}/local/share/man

# Build a separate venv for notebooks, using sage packages when
# they meet the requirements of the notebook package.
echo "Building notebook venv ..."
${VERSION_DIR}/venv/bin/sage -python -m venv --system-site-packages ${NOTEBOOK_VENV}
${NOTEBOOK_VENV}/bin/pip install --no-user --upgrade jupyterlab
${NOTEBOOK_VENV}/bin/pip install --no-user --upgrade jupyterlabwidgets
${NOTEBOOK_VENV}/bin/pip install --no-user --upgrade notebook
${NOTEBOOK_VENV}/bin/pip install --no-user --ignore-installed ipywidgets
# Clean up the venv
rm -rf ${NOTEBOOK_VENV}/lib/python3.11/site-packages/setuptools*
rm -rf ${NOTEBOOK_VENV}/lib/python3.11/site-packages/pip*
rm -rf ${NOTEBOOK_VENV}/bin/pip*
rm -rf ${NOTEBOOK_VENV}/bin/activate*
rm ${NOTEBOOK_VENV}/bin/Activate.ps1
# Fix the executable symlink so that it points to the Sage python
rm ${NOTEBOOK_VENV}/bin/python3
ln -s ../../venv/bin/python3 ${NOTEBOOK_VENV}/bin/python3
# The pyvenv.cfg file is what makes a venv into a venv.  A minimal
# venv contains a python executable, a site-packages directory, and a
# pyvenv.cfg file.  The pyvenv.cfg file must either go in the same
# directory as the python executable for the venv, or one level up.
# (The executable is allowed to be a symlink, which will not be
# dereferenced when determining its location.)  The top level of a
# framework version directory can only contain directories, symlinks
# or signed code files.  So we place the pyvenv.cfg in the bin
# directory.  We customize it so it shows the venv home as being
# the bin directory in the sage venv, relative to our /var/tmp symlink.
cp ../jinja/output/pyvenv.cfg ${NOTEBOOK_VENV}/pyvenv.cfg
NOTEBOOK_KERNELS=${NOTEBOOK_VENV}/share/jupyter/kernels
mkdir -p ${NOTEBOOK_KERNELS}/sagemath
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${NOTEBOOK_KERNELS}/sagemath/kernel.json

# Fix up rpaths and shebangs 
echo "Patching files ..."
source ../IDs.sh
mv files_to_sign files_to_sign.bak
python3 fix_paths.py repo ${VERSION_DIR}/local/bin >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/local/lib >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/local/libexec >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/${VENV_DIR}/bin >> files_to_sign
python3 fix_paths.py repo ${VERSION_DIR}/${VENV_DIR}/lib >> files_to_sign
find ${NOTEBOOK_VENV} -name '*.so' >> files_to_sign
python3 fix_scripts.py ${NOTEBOOK_VENV}/bin

# Replace Sage's Pillow with the binary package from pypi, so libjpeg will work.
# Do this after running fix_paths, since the rpaths are set by delocate
PIP_TARGET=${VERSION_DIR}/${VENV_PYLIB}/site-packages
PIP_ARGS="install --upgrade --no-user --force --only-binary :all:"
echo Re-installing Pillow
${VERSION_DIR}/venv/bin/python3 -m pip ${PIP_ARGS} --target ${PIP_TARGET} Pillow
find ${PIP_TARGET}/PIL/ -name '*.dylib' >> files_to_sign
find ${PIP_TARGET}/PIL/ -name '*.so' >> files_to_sign

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
# Start sage to create a minimal set of bytecode files.
echo "Starting Sage to create byte code files ..."
${VERSION_DIR}/venv/bin/sage -c "print(2+2) ; exit"
echo "Signing the framework again:"
python3 sign_sage.py framework
