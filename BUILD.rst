Prerequisites
=============

Several things need to be in place before you can run the scripts which build
the SageMath frameworks and app.  You may need to install XCode in order to
have the xcrun notarize-app and xcrun staple commands available.

Macher
------

Download and install macher from:
https://github.com/culler/macher/releases/download/v1.3/macher

This is a single file executable which can go anywhere in your path.
It is used by the fix_paths.py script in Sage_framework.

Tcl and Tk source code
----------------------

The TclTk_framework directory should contain subdirectories Tk and Tcl
which contain appropriate versions of the corresponding source code.
If you have fossil repositories, say named Tcl.fossil and Tk.fossil
somewhere on your system, then you can create the Tcl directories and
run, for example.

% cd Tcl
% fossil open /path/to/Tcl.fossil core-9-0-0
% cd ../Tk
% fossil open /path/to/Tk.fossil core-9-0-0

If you do not have fossil, source tarballs for Tcl and Tk can be
downloaded from:
https://www.tcl.tk/software/tcltk/download.html

Fossil can be downloaded from:
https://fossil-scm.org/home/uv/download.html

create-dmg
----------

The create-dmg script is used to build the final release dmg with the
background image and folder icons.  It is expected to be installed in
/usr/local/bin.  It can be downloaded from:
https://github.com/create-dmg/create-dmg

Credentials
-----------

Code signing requires that you have two certificates installed in the Keychain
Access app.  One is used for signing Applications with codesign and one is
used for signing Installers with productsign.  If you are a registered Apple
developer and have received the certificates from Apple then they will be
identified by your Apple developer id.  If they are self-signed then you will
choose the id.  Notarization also requires a one-time-password registered
with Apple.

Your Apple developer id and one-time-password should be assigned to
environment variables in a script named IDs.sh in this directory.  That
script will be sourced when credentials are needed.

package/IDs.sh :
export APPLE_ID=user@example.com
export ONE_TIME_PASS=abcd-efgh-ijkl-mnop
export DEV_ID=YOURCERTID

Build Steps
===========

The bin directory contains scripts which handle each step of building the
application bundle, once the Sage distribution has been built.  A valid
Apple developer id is needed to run the scripts build_dist, notarize_app,
and notarize_dmg.  However, the build_dist can be modified by commenting
out the 4 lines in the section "Render templates and install the package"
in order to allow building a signed but unnotarized copy of the app,
without the associated extras package.  This does require a self-signed
certificate, which must be listed in IDs.sh.

The steps are:
# Build Sage and the Sage documentation
cd Sage_framework
mkdir repo
git clone https://github.com/sagemath/sage.git
cd ../..
bash build_sage.sh

# If Sage builds successfully, continue ...
bash build_sage_docs.sh

# Verify that the documentation looks OK (requires cocoserver)
coco repo/documentation

# Build the App
cd ..
bin/build_dist
# This provides the app.  If you have a valid Developer ID you can now
# notarize the app and the installer ...
bin/quick_dmg
bin/notarize_app # takes 45 minutes or so
bin/fancy_dmg
bin/notarize_dmg # takes another 45 minutes or so

# You now have a working disk image named SageMath-X.Y.dmg
# To create the hash file, rename the image, depending on the
# architecture of the build system, as
  SageMath-X.Y_x86_64
# or
  SageMath-X.Y_arm64
# and then run:
bin/build_hashes
