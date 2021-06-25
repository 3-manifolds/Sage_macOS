BASE=`pwd`
export CFLAGS="-mmacosx-version-min=10.9"
mkdir -p ${BASE}/dist
make -j6 -C Tcl/macosx install-embedded SUBFRAMEWORK=1 DESTDIR=${BASE}/dist \
     DYLIB_INSTALL_DIR=@executable_path/../Frameworks/Tcl.framework/Versions/8.6/Tcl
make -j6 -C Tk/macosx install-embedded SUBFRAMEWORK=1 DESTDIR=${BASE}/dist \
     DYLIB_INSTALL_DIR=@executable_path/../Frameworks/Tk.framework/Versions/8.6/Tk
