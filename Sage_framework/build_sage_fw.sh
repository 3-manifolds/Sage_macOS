BASE_DIR=`pwd`
VERSION=9.2
SRC_DIR=SageMath
SRC_ARCHIVE=sage-9.2-OSX_10.15.7-x86_64.tar.bz2
TRIMMED_ARCHIVE=trimmed.tgz
URL=https://mirror.csclub.uwaterloo.ca/sage/osx/intel/sage-9.2-OSX_10.15.7-x86_64.tar.bz2
HASH=7edc4838ca3485d529a4145d93781c1d
FRAMEWORKS=${BASE_DIR}/../Frameworks

if ! [ -e ${SRC_ARCHIVE} ]; then
    curl -O ${URL}
fi
ACTUAL_HASH=`md5 -q ${SRC_ARCHIVE}`
if [[ ${ACTUAL_HASH} != ${HASH} ]]; then
    echo Invalid hash value for ${SRC_ARCHIVE}
    exit 1
fi
if ! [ -e ${TRIMMED_ARCHIVE} ]; then
    echo Building a trimmed archive ...
    rm -rf ${SRC_DIR}
    echo Unpacking the full archive ...
    tar xfj ${SRC_ARCHIVE}
    echo Removing xattrs ...
    xattr -r -c ${SRC_DIR}
    UUID=`python3 get_sage_id.py`
    DESTINATION="/var/tmp/sage-$UUID"
    echo Rewriting paths with $DESTINATION ...
    mkdir -p files
    echo SAGE_SYMLINK=$DESTINATION > files/runpath.sh
    SageMath/relocate-once.py -d$DESTINATION
    echo Trimming Sage to a reasonable size ...
    rm -rf ${SRC_DIR}/.*
    rm -rf ${SRC_DIR}/{Makefile,bootstrap,build,docker,upstream,logs,m4}
    rm -rf ${SRC_DIR}/config*
    rm -rf ${SRC_DIR}/tox*
    rm -rf ${SRC_DIR}/*.yml
    rm -rf ${SRC_DIR}/src/.*
    rm -rf ${SRC_DIR}/src/doc
    rm -rf ${SRC_DIR}/src/mac-app
    rm -rf ${SRC_DIR}/local/var/tmp
    rm -rf ${SRC_DIR}/local/var/lib/sage/wheels
    rm -rf ${SRC_DIR}/local/lib/pkgconfig
    rm -rf ${SRC_DIR}/local/lib/cmake
    rm -rf ${SRC_DIR}/local/lib/libgcc_ext*
    rm -rf ${SRC_DIR}/local/share/jupyter/kernels/sagemath/doc
    rm -rf ${SRC_DIR}/local/share/doc    
    find SageMath/local/lib -name '*.a' -delete
    find SageMath/local/lib -name '*.la' -delete
    echo Archiving the trimmed Sage ...
    tar cfz ${TRIMMED_ARCHIVE} ${SRC_DIR}
    ####  Maybe we need to run sage to create byte code needed for startup ???
    echo Please rerun the script to process the trimmed archive.
else
    echo Removing SageMath ...
    rm -rf ${SRC_DIR}
    echo Unpacking the trimmed archive ...
    tar xfz ${TRIMMED_ARCHIVE}
    echo Fixing up rpaths and load paths ...
    rm -f files_to_sign
    python3 fix_paths.py ${SRC_DIR}/local/lib > files_to_sign
    python3 fix_paths.py ${SRC_DIR}/local/bin >> files_to_sign
    python3 fix_paths.py ${SRC_DIR}/local/libexec >> files_to_sign
    cp files/sage ${SRC_DIR}/local/bin/sage
    chmod 755 ${SRC_DIR}/local/bin/sage
    cp files/runpath.sh ${SRC_DIR}/local/var/lib/sage/runpath.sh
    chmod 755 ${SRC_DIR}/local/var/lib/sage/runpath.sh
    cp files/sage-env ${SRC_DIR}/local/bin/sage-env
    chmod 755 ${SRC_DIR}/local/bin/sage-env
    cp files/_ssl.cpython-38-darwin.so ${SRC_DIR}/local/lib/python3.8/lib-dynload
    chmod 755 ${SRC_DIR}/local/lib/python3.8/lib-dynload/_ssl.cpython-38-darwin.so 
    cp files/_tkinter.cpython-38-darwin.so ${SRC_DIR}/local/lib/python3.8/lib-dynload
    chmod 755 ${SRC_DIR}/local/lib/python3.8/lib-dynload/_tkinter.cpython-38-darwin.so 
fi
