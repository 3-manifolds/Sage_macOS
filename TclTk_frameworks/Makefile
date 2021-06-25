MACHER=/usr/local/bin/macher
TCL_RPATH=@loader_path/../../../../../../Tcl.framework/Versions/Current
TK_RPATH=@loader_path/../../../../../../Tk.framework/Versions/Current
TCL_FRAMEWORK=Frameworks/Tcl.framework
TCL_VERSION_DIR=${TCL_FRAMEWORK}/Versions/Current
TCL_LIB=${TCL_VERSION_DIR}/Tcl
TK_FRAMEWORK=Frameworks/Tk.framework
TK_VERSION_DIR=${TK_FRAMEWORK}/Versions/Current
TK_LIB=${TK_VERSION_DIR}/Tk
WISH=${TK_VERSION_DIR}/Resources/Wish.app
DEV_ID := $(shell cat DEV_ID.txt)
CS_OPTS=-v -s ${DEV_ID} --timestamp --options runtime --entitlements entitlement.plist --force
PY_CS_OPTS=-v -s ${DEV_ID} --timestamp --options runtime --force

all: Setup TclTk Sign

.PHONY: Setup TclTk Sign

Setup:
	mkdir -p Frameworks

TclTk:
	rm -rf dist ; \
	bash build_tcltk.sh ; \
	find dist/Frameworks/Tcl.framework -name '*.a' -delete ; \
	find dist/Frameworks/Tk.framework -name '*.a' -delete ; \
	rm -rf ${TCL_FRAMEWORK}
	rm -rf ${TK_FRAMEWORK}
	mv dist/Frameworks/Tcl.framework Frameworks
	mv dist/Frameworks/Tk.framework Frameworks
	chmod +w ${TCL_LIB} ${TK_LIB}
	${MACHER} set_id @rpath/Tcl ${TCL_LIB}
	${MACHER} set_id @rpath/Tk ${TK_LIB}
	rm -rf ${WISH}
	rm ${TCL_FRAMEWORK}/{PrivateHeaders,Tcl,tclConfig.sh}
	mv ${TCL_VERSION_DIR}/{tclConfig.sh,tclooConfig.sh} ${TCL_VERSION_DIR}/Resources
	rm ${TK_FRAMEWORK}/{PrivateHeaders,Tk,tkConfig.sh}
	mv ${TK_VERSION_DIR}/tkConfig.sh ${TK_VERSION_DIR}/Resources

Sign:
	codesign ${CS_OPTS} ${TCL_LIB}
	codesign ${CS_OPTS} ${TCL_FRAMEWORK}
	codesign ${CS_OPTS} ${TK_LIB}
	codesign ${CS_OPTS} ${TK_FRAMEWORK}

