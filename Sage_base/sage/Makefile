# This makefile installs several software packages in a prefix directory named
# local, which will be copied into the Sage directory tree before building
# Sage.  These are intended to be recognized as "system packages" by the Sage
# build system and used as is.  (For some packages which are provided as part
# of macOS, such as zlib, a pkgconfig .pc file must be created in order to
# make Sage recognize the package as a usable "system package".)
#
# The make program is not really designed to handle a situation where recipes
# produce multiple files, some of which may be prerequisites for other
# targets.  Here we borrow Sage's scheme for working around this.  Each make
# target is an empty file in the directory ${IST} which gets created when the
# corresponding package is installed.  The existence of the file is meant to
# indicate that all components of the package are installed and up-to-date as
# of the timestamp date on the empty file.  If a package X requires any component
# of another package Y then ${IST}/Y should be a prerequisite for ${IST}/X.
# This forces the packages to be installed in an appropriate sequence.

# For the macOS SageMath-X.Y app, the build directory should be moved to
# /var/tmp/sage-X.Y-current in order to be consistent with how the sage build
# is done.  Note that dylib ids and shebangs built here will use the
# INSTALL_DIR path.

INSTALL_DIR := $(shell pwd)/local/lib
GCC_LIB := /usr/local/gcc14/lib
IST := install_stamps

all: ${IST} ${IST}/gmp ${IST}/mpfr ${IST}/mpc ${IST}/openblas ${IST}/openssl ${IST}/tcltk ${IST}/python

.PHONY: setup tarball

${IST}: notabot.cfg entitlements.plist
	mkdir -p local/lib
	mkdir -p ${IST}
	cp -a gfortran/* local/lib

${IST}/openblas: ${IST}
	bash openblas/build_openblas.sh
	python -m notabot.sign local/lib/libopenblas.dylib
	touch ${IST}/openblas

${IST}/gmp: ${IST}
	bash gmp/build_gmp.sh
	python -m notabot.sign local/lib/libgmp.dylib
	touch ${IST}/gmp

${IST}/mpfr: ${IST}/gmp
	bash mpfr/build_mpfr.sh
	macher edit_libpath ${INSTALL_DIR}/libgmp.10.dylib @loader_path/libgmp.10.dylib local/lib/libmpfr.6.dylib
	python -m notabot.sign local/lib/libmpfr.dylib
	touch ${IST}/mpfr

${IST}/mpc: ${IST}/mpfr ${IST}/gmp
	bash mpc/build_mpc.sh
	install_name_tool -change ${INSTALL_DIR}/libmpfr.6.dylib @loader_path/libmpfr.6.dylib local/lib//libmpc.dylib 
	install_name_tool -change ${INSTALL_DIR}/libgmp.10.dylib @loader_path/libgmp.10.dylib local/lib//libmpc.dylib
	python -m notabot.sign local/lib/libmpc.dylib
	touch ${IST}/mpc

${IST}/openssl: ${IST}
	bash openssl/build_openssl.sh
	install_name_tool -change ${INSTALL_DIR}/libcrypto.3.dylib @loader_path/libcrypto.3.dylib local/lib/libssl.dylib 
	python -m notabot.sign local/lib/libssl.dylib
	python -m notabot.sign local/lib/libcrypto.dylib
	python -m notabot.sign local/bin/openssl
	python -m notabot.sign local/bin/c_rehash
	touch ${IST}/openssl

${IST}/tcltk: ${IST}
	bash tcltk/build_tcltk.sh
	python -m notabot.sign local/lib/libtcl9.0.dylib
	python -m notabot.sign local/lib/libtcl9tk9.0.dylib
	python -m notabot.sign local/bin/tclsh9.0
	python -m notabot.sign local/bin/wish9.0
	touch ${IST}/tcltk

${IST}/python: ${IST}/openssl ${IST}/tcltk
	bash python/build_python.sh
	install_name_tool -change ${INSTALL_DIR}/libcrypto.3.dylib @loader_path/../../libcrypto.3.dylib local/lib/python3.13/lib-dynload/_hashlib.cpython-313-darwin.so
	install_name_tool -change ${INSTALL_DIR}/libcrypto.3.dylib @loader_path/../../libcrypto.3.dylib local/lib/python3.13/lib-dynload/_ssl.cpython-313-darwin.so
	install_name_tool -change ${INSTALL_DIR}/libssl.3.dylib @loader_path/../../libssl.3.dylib local/lib/python3.13/lib-dynload/_ssl.cpython-313-darwin.so
	install_name_tool -change ${INSTALL_DIR}/libtcl9.0.dylib @loader_path/../../libtcl9.0.dylib local/lib/python3.13/lib-dynload/_tkinter.cpython-313-darwin.so
	install_name_tool -change ${INSTALL_DIR}/libtcl9tk9.0.dylib @loader_path/../../libtcl9tk9.0.dylib local/lib/python3.13/lib-dynload/_tkinter.cpython-313-darwin.so
	find local/lib/python3.13 -name '*.so' -exec python3 -m notabot.sign {} \;
	find local/lib/python3.13/lib-dynload -name '*.dylib' -exec python3 -m notabot.sign {} \;
	python -m notabot.sign local/bin/python3.13
	touch ${IST}/python

tarball:
	tar cfz sagebase.tgz local
	shasum sagebase.tgz > sagebase.sha1
