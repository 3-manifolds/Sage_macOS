BASE=`pwd`
# The CFLAGS depend on the architecture
#export CFLAGS="-O2 -mmacosx-version-min=10.9 -mno-avx -mno-avx2 -mno-bmi2"
export CFLAGS="-O2 -mmacosx-version-min=10.9"
mkdir -p ${BASE}/dist
make -C Tcl/macosx
make -C Tk/macosx
#make -j6 -C Tcl/macosx install-embedded SUBFRAMEWORK=1 DESTDIR=${BASE}/dist \
#     DYLIB_INSTALL_DIR=@rpath/Tcl
#make -j6 -C Tk/macosx install-embedded SUBFRAMEWORK=1 DESTDIR=${BASE}/dist \
#     DYLIB_INSTALL_DIR=@rpath/Tk
