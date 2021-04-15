#!/bin/bash
# This script assumes that ../repo/sage is a clone of the Sage git repository
# and that a successful build of some branch is in place there.  It will be
# used as is, copying what we need into the framework.
SAGE_REPO=repo/sage
FRAMEWORK=build/Sage.framework
PYTHON=python3.9
source $SAGE_REPO/src/bin/sage-version.sh
CURRENT=$FRAMEWORK/Versions/Current
mkdir -p $FRAMEWORK/Versions/$SAGE_VERSION
ln -s $SAGE_VERSION $CURRENT
mkdir -p $CURRENT/Resources
ln -s Versions/Current/Resources $FRAMEWORK/Resources
cp $SAGE_REPO/{VERSION.txt,README.md,COPYING.txt} $FRAMEWORK/Resources
sed -e s/XXXX/$SAGE_VERSION/g resources/Info.plist > $FRAMEWORK/Resources/Info.plist
cp resources/pip.conf $FRAMEWORK/Resources
mkdir -p $CURRENT/local/var
cp -R $SAGE_REPO/local/var/lib $CURRENT/local/var
cp -R $SAGE_REPO/local/{bin,etc,include,lib,lib64,libexec} $CURRENT/local
mkdir -p $CURRENT/local/share
for dir in `ls $SAGE_REPO/local/share`
do
   if [ $dir != doc ] && [ $dir != man ]; then
       cp -R $SAGE_REPO/local/share/$dir $CURRENT/local/share
   fi
done
LOCAL=$CURRENT/local
# Remove static libraries
find $LOCAL -name '*.a' -delete
find $LOCAL -name '*.la' -delete
# Fix symlinks 
rm $LOCAL/share/gap/{gac,gap}
ln -s ../../bin/gap $CURRENT/local/share/gap/gap
ln -s ../../bin/gac $CURRENT/local/share/gap/gac
rm $LOCAL/share/jupyter/kernels/sagemath/doc
rm $LOCAL/share/jupyter/kernels/sagemath/logo*
cp $SAGE_REPO/build/pkgs/sagelib/src/sage/ext_data/notebook-ipython/logo* $LOCAL/share/jupyter/kernels/sagemath
rm $LOCAL/share/jupyter/nbextensions/threejs
ln -s ../../threejs $LOCAL/share/jupyter/nbextensions/threejs
# Remove saved wheels (which contain unsigned binaries)
rm -rf $LOCAL/var/lib/sage/wheels
# Remove .pyc files
find $LOCAL -name '*.pyc' -delete
# Fix up hardwired paths and rpaths
python3 fix_paths.py
# Recompile byte code with a relative prefix (used in tracebacks)
python3 -m compileall -d local/lib/$PYTHON $LOCAL/lib/$PYTHON
python3 -m compileall -d local/bin $LOCAL/bin
python3 -m compileall -d local/share/cysignals $CURRENT/local/share/cysignals
python3 -m compileall -d local/share/texmf/tex/latex/sagetex $CURRENT/local/share/texmf/tex/latex/sagetex
# Replace a few files with our own versions and add runpath.sh
cp files/sage files/sage-env $LOCAL/bin
cp files/page.html $LOCAL/lib/python3.9/site-packages/notebook/templates/
echo SAGE_SYMLINK=$SAGE_SYMLINK > $LOCAL/var/lib/sage/runpath.sh
chmod +x $LOCAL/var/lib/sage/runpath.sh
TCL_RPATH=@loader_path/../../../../../../../Tcl.framework/Versions/Current
TK_RPATH=@loader_path/../../../../../../../Tk.framework/Versions/Current
/usr/local/bin/macher clear_rpaths $LOCAL/lib/$PYTHON/lib-dynload/_tkinter.cpython-*.so
/usr/local/bin/macher add_rpath $TCL_RPATH $LOCAL/lib/$PYTHON/lib-dynload/_tkinter.cpython-*.so
/usr/local/bin/macher add_rpath $TK_RPATH $LOCAL/lib/$PYTHON/lib-dynload/_tkinter.cpython-*.so
ln -s $PYTHON $LOCAL/bin/SageMath
python3 sign_sage.py
