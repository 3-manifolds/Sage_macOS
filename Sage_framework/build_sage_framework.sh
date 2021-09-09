BASE_DIR=`pwd`
VERSION=`./get_sage_version`
echo Sage Version is ${VERSION}.
REPO=${BASE_DIR}/repo/sage
FILES=${BASE_DIR}/files
BUILD=${BASE_DIR}/build
VERSION_DIR=${BUILD}/Sage.framework/Versions/$VERSION
CURRENT_DIR=${BUILD}/Sage.framework/Versions/Current
RESOURCE_DIR=${VERSION_DIR}/Resources
KERNEL_DIR="${VERSION_DIR}/Resources/jupyter/kernels/SageMath-${VERSION}"
# This allows Sage.framework to be a symlink to the framework inside the application.
if ! [ -d "${BUILD}/Sage.framework" ]; then
    mkdir -p "${BUILD}"/Sage.framework
fi

# Clean out everything.
rm -rf "${BUILD}"/Sage.framework/*

# Create the bundle directories
mkdir -p "${RESOURCE_DIR}"
ln -s ${VERSION} "${CURRENT_DIR}"
ln -s Versions/Current/Resources "${BUILD}"/Sage.framework/Resources

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
cp -R "${REPO}"/local/var/lib/sage/installed/ ${VERSION_DIR}/local/var/lib/sage/installed
cp -R "${REPO}"/local/var/lib/sage/scripts/ ${VERSION_DIR}/local/var/lib/sage/scripts
mkdir -p ${VERSION_DIR}/local/share
for share_dir in `ls "${REPO}"/local/share`; do
    if [ $share_dir != "doc" ]; then
	cp -R "${REPO}"/local/share/$share_dir ${VERSION_DIR}/local/share/$share_dir
    fi
done
# Create the runpath.sh script
echo SAGE_SYMLINK=/var/tmp/sage-${VERSION}-current > ${VERSION_DIR}/local/var/lib/sage/runpath.sh
chmod 755 ${VERSION_DIR}/local/var/lib/sage/runpath.sh

# create the local/bin/SageMath symlink
ln -s python3.9 ${VERSION_DIR}/local/bin/SageMath

# Copy our modified files into the bundle
cp -p ${FILES}/_tkinter.cpython-39-darwin.so ${VERSION_DIR}/local/lib/python3.9/lib-dynload
cp -p ${FILES}/page.html ${VERSION_DIR}/local/lib/python3.9/site-packages/notebook/templates/page.html
cp -p ${FILES}/{sage,sage-env} ${VERSION_DIR}/local/bin
cp -p ${FILES}/kernel.py ${VERSION_DIR}/local/lib/python3.9/site-packages/sage/repl/ipython_kernel/kernel.py
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/sage-env-config > "${VERSION_DIR}"/local/bin/sage-env-config
rm -rf ${VERSION_DIR}/local/share/jupyter/kernels/sagemath
mkdir -p ${KERNEL_DIR}
sed "s/__VERSION__/${VERSION}/g" "${FILES}"/kernel.json > ${KERNEL_DIR}/kernel.json
cp ${FILES}/_tkinter.cpython-39-darwin.so "${VERSION_DIR}"/local/lib/python3.9/lib-dynload
cp ${FILES}/sagedoc.py ${VERSION_DIR}/local/lib/python3.9/site-packages/sage/misc/sagedoc.py

# Fix illegal symlinks that point outside of the bundle
rm ${VERSION_DIR}/local/share/gap/{gac,gap}
ln -s ../../bin/gac ${VERSION_DIR}/local/share/gap/gac
ln -s ../../bin/gap ${VERSION_DIR}/local/share/gap/gap
rm -rf ${VERSION_DIR}/local/share/jupyter/kernels/sagemath/doc
rm -f ${VERSION_DIR}/local/share/jupyter/nbextensions/threejs-sage
ln -s ../../threejs-sage ${VERSION_DIR}/local/share/jupyter/nbextensions/threejs-sage

# Fix up rpaths and shebangs 
echo "Patching files ..."
mv files_to_sign files_to_sign.bak
python3 fix_paths.py ${VERSION_DIR}/local/bin > files_to_sign
python3 fix_paths.py ${VERSION_DIR}/local/lib >> files_to_sign
python3 fix_paths.py ${VERSION_DIR}/local/libexec >> files_to_sign

# Remove xattrs
xattr -rc ${BUILD}/Sage.framework

# Start sage to create byte code files that should be included
echo "Starting Sage to create byte code files ..."
${VERSION_DIR}/local/bin/sage

# Sign the framework.
echo "Signing files ..."
#local/share/cmake-3.21/Modules/Internal/CPack/CPack.OSXScriptLauncher.in
python3 sign_sage.py

