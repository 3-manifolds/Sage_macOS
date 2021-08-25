export GMP_CONFIGURE="--enable-fat"
export SAGE_FAT_BINARY="yes"
export CFLAGS="-mmacosx-version-min=10.9 -mno-avx -mno-avx2 -mno-bmi2"
export LDFLAGS="-Wl,-platform_version,macos,10.9,11.3"
export MACOSX_DEPLOYMENT_TARGET="10.9"
export MAKE="make -j4"
cd repo/sage
./configure --without-system-python3
make build
cd ../..

