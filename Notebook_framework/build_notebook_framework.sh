#!/bin/bash
set -e
BASE_DIR=`pwd`
BUILD=${BASE_DIR}/build
VERSION=`../bin/get_sage_version`
SAGE="/var/tmp/sage-${VERSION}-current/venv/bin/sage"
SAGE_PYTHON="/var/tmp/sage-${VERSION}-current/venv/bin/python3"
PYTHON_VERSION=`${SAGE_PYTHON} --version`
echo Building Notebook framework for SageMath ${VERSION} using ${PYTHON_VERSION}
VERSION_DIR=${BUILD}/Notebook.framework/Versions/${VERSION}
CURRENT_DIR=${BUILD}/Notebook.framework/Versions/Current
RESOURCE_DIR=${VERSION_DIR}/Resources
# Clean out everything.
echo Removing old framework ...
rm -rf "${BUILD}"/Notebook.framework/*

echo Creating bundle structure ...
# Create the bundle directories
mkdir -p "${RESOURCE_DIR}"
ln -s ${VERSION} "${CURRENT_DIR}"
ln -s Versions/Current/Resources "${BUILD}"/Notebook.framework/Resources

# Create the resource files
sed "s/__VERSION__/${VERSION}/g" Info.plist > "${RESOURCE_DIR}"/Info.plist

# Construct a venv as a Version directory
sage -python -m venv  --system-site-packages $VERSION_DIR

echo Installing packages ...
# Install jupyterlab and notebook v7 using the pip from the venv
${VERSION_DIR}/bin/python -m pip install --no-user jupyterlab 
${VERSION_DIR}/bin/python -m pip install --no-user notebook==7.0.0.rc0 

# That done, we can remove stuff we don't need and don't want used.
# This includes setuptools and pip.
rm -rf ${VERSION_DIR}/lib/python3.11/site-packages/setuptools*
rm -rf ${VERSION_DIR}/lib/python3.11/site-packages/pip*
rm -rf ${VERSION_DIR}/bin/pip*
rm -rf ${VERSION_DIR}/bin/activate*
rm ${VERSION_DIR}/bin/Activate.ps1
# The pyvenv.cfg file is what makes a venv into a venv.  A minimal
# venv contains a python executable, a site-packages directory, and a
# pyvenv.cfg file.  The pyvenv.cfg file must either go in the same
# directory as the python executable for the venv, or one level up.
# (The executable is allowed to be a symlink, which will not be
# dereferenced when determining its location.)  The top level of a
# framework version directory can only contain directories, symlinks
# or signed code files.  So we place the pyvenv.cfg in the bin
# directory.  We also customize it so it reflects our /var/tmp symlink.
rm ${VERSION_DIR}/pyvenv.cfg
cp ../jinja/output/pyvenv.cfg ${VERSION_DIR}/bin/pyvenv.cfg
echo Signing framework ...
source ../IDs.sh
OPTIONS="-v --timestamp --options runtime --force"
codesign -s $DEV_ID $OPTIONS `find build -name '*.so'`
codesign -s $DEV_ID $OPTIONS build/Notebook.framework
