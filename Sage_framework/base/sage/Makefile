SYMLINK := /var/tmp/sage-10.7-current
INSTALL_DIR := ${SYMLINK}/local/lib
GCC_LIB := /usr/local/gcc14/lib
LOCAL_LIB := $(shell realpath local/lib)
LIB_DYNLOAD := ${LOCAL_LIB}/python3.13/lib-dynload

all: setup openblas gmp mpfr mpc openssl tcltk python

.PHONY: setup openblas gmp mpfr mpc tarball 

setup:  notabot.cfg entitlements.plist
	mkdir -p local/lib
	cp -a ${GCC_LIB}/libgcc_s*.dylib local/lib
	macher set_id ${INSTALL_DIR}/libgcc_s.1.1.dylib local/lib/libgcc_s.1.1.dylib 
	python -m notabot.sign local/lib/libgcc_s.1.1.dylib
	cp -a ${GCC_LIB}/libgfortran*.dylib local/lib
	macher set_id ${INSTALL_DIR}/libgfortran.5.dylib local/lib/libgfortran.dylib
	python -m notabot.sign local/lib/libgfortran.dylib
	cp -a ${GCC_LIB}/libquadmath*.dylib local/lib
	macher set_id ${INSTALL_DIR}/libquadmath.0.dylib local/lib/libquadmath.dylib
	python -m notabot.sign local/lib/libquadmath.dylib

local/lib/libopenblas.dylib: 
	bash openblas/build_openblas.sh

openblas: local/lib/libopenblas.dylib
	macher set_id ${INSTALL_DIR}/libopenblasp-r0.3.29.dylib $<
	macher clear_rpaths $<
	macher add_rpath @loader_path $<
	python -m notabot.sign local/lib/libopenblas.dylib

local/lib/libgmp.dylib:
	bash gmp/build_gmp.sh

gmp: local/lib/libgmp.dylib
	macher set_id ${INSTALL_DIR}/libgmp.10.dylib $<
	python -m notabot.sign local/lib/libgmp.dylib

local/lib/libmpfr.dylib:
	bash mpfr/build_mpfr.sh

mpfr: local/lib/libmpfr.dylib
	macher set_id ${INSTALL_DIR}/libmpfr.6.dylib $<
	macher edit_libpath ${INSTALL_DIR}/libgmp.10.dylib @loader_path/libgmp.10.dylib $<
	python -m notabot.sign local/lib/libmpfr.dylib

local/lib/libmpc.dylib:
	bash mpc/build_mpc.sh

mpc: local/lib/libmpc.dylib
	macher set_id ${INSTALL_DIR}/libmpc.dylib $<
	macher edit_libpath ${INSTALL_DIR}/libmpfr.6.dylib @loader_path/libmpfr.6.dylib $<
	macher edit_libpath ${INSTALL_DIR}/libgmp.10.dylib @loader_path/libgmp.10.dylib $<
	python -m notabot.sign local/lib/libmpc.dylib

local/lib/libssl.3.dylib:
	bash openssl/build_openssl.sh

openssl: local/lib/libssl.3.dylib
	macher set_id ${INSTALL_DIR}/libssl.3.dylib $<
	macher set_id ${INSTALL_DIR}/libcrypto.3.dylib local/lib/libcrypto.3.dylib
	macher edit_libpath ${LOCAL_LIB}/libcrypto.3.dylib @loader_path/libcrypto.3.dylib $<
	python -m notabot.sign local/lib/libssl.dylib
	python -m notabot.sign local/lib/libcrypto.dylib
	python -m notabot.sign local/bin/openssl
	python -m notabot.sign local/bin/c_rehash

local/lib/libtcl9.0.dylib:
	bash tcltk/build_tcltk.sh

local/lib/libtcl9tk9.0.dylib:
	bash tcltk/build_tcltk.sh

tcltk: local/lib/libtcl9.0.dylib local/lib/libtcl9tk9.0.dylib
	lipo -thin x86_64 local/lib/libtcl9.0.dylib -output local/lib/libtcl9.0.dylib
	install_name_tool -id ${INSTALL_DIR}/libtcl9.0.dylib local/lib/libtcl9.0.dylib
	install_name_tool -id ${INSTALL_DIR}/libtcl9tk9.0.dylib local/lib/libtcl9tk9.0.dylib
	python -m notabot.sign local/lib/libtcl9.0.dylib
	python -m notabot.sign local/lib/libtcl9tk9.0.dylib
	python -m notabot.sign local/bin/tclsh9.0
	python -m notabot.sign local/bin/wish9.0

local/lib/python3.13:
	bash python/build_python.sh

python: local/lib/python3.13
	macher edit_libpath ${INSTALL_DIR}/libcrypto.3.dylib @loader_path/../../libcrypto.3.dylib local/lib/python3.13/lib-dynload/_hashlib.cpython-313-darwin.so
	macher edit_libpath ${INSTALL_DIR}/libcrypto.3.dylib @loader_path/../../libcrypto.3.dylib local/lib/python3.13/lib-dynload/_ssl.cpython-313-darwin.so
	macher edit_libpath ${INSTALL_DIR}/libssl.3.dylib @loader_path/../../libssl.3.dylib local/lib/python3.13/lib-dynload/_ssl.cpython-313-darwin.so
	macher edit_libpath ${INSTALL_DIR}/libtcl9.0.dylib @loader_path/../../libtcl9.0.dylib local/lib/python3.13/lib-dynload/_tkinter.cpython-313-darwin.so
	macher edit_libpath ${INSTALL_DIR}/libtcl9tk9.0.dylib @loader_path/../../libtcl9tk9.0.dylib local/lib/python3.13/lib-dynload/_tkinter.cpython-313-darwin.so
	find local/lib/python3.13/lib-dynload -name '*.so' -exec python3 -m notabot.sign {} \;

tarball:
	tar cfz sagebase.tgz local
	shasum sagebase.tgz > sagebase.sha1
