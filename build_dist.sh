#!/bin/bash
# Construct the SageMath distribution form the current state
# of the repo.
set -e
SAGE_VERSION=`bin/get_sage_version`
PYTHON_VERSION=`bin/get_python_version`
SAGE_DASH_VERSION=$(echo $SAGE_VERSION | sed s/\\\./\\\-/g)
SAGE_SCORE_VERSION=$(echo $SAGE_VERSION | sed s/\\\./\\\_/g)
DIST=SageMath-$SAGE_VERSION
APP=$DIST/SageMath-$SAGE_DASH_VERSION.app
PKG=Recommended_$SAGE_SCORE_VERSION.pkg
PYTHON3=../Frameworks/Sage.framework/Versions/Current/venv/python3
mkdir $DIST
# Render templates and nstall the package
cd package
. build_package.sh
cd ..
mv package/$PKG $DIST
# Build the app bundle directory structure
mkdir -p $APP/Contents/{MacOS,Frameworks,Resources}
cp jinja/output/Info.plist $APP/Contents/MacOS
# Install the main executable and the Python link
cd main_ex
make
cd ..
# Populate MacOS
mv main_ex/SageMath $APP/Contents/MacOS
ln -s $PYTHON3 $APP/Contents/MacOS/Python
# Populate Resources
cp icon/{Sage.icns,sage_icon_1024.png} $APP/Contents/Resources
cp logos/{sage_logo_512.png,sage_logo_256.png} $APP/Contents/Resources
cp main.py $APP/Contents/Resources
