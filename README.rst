Sage_MacOS
==========

The Sage_MacOS project aims to provide a simple, streamlined macOS application which
runs SageMath and can be installed by the usual process of dragging the application
bundle to the /Applications directory.

Sage_MacOS leverages Apple's Terminal application.  The structure of the application
bundle is that the main executable is a short python script which launches a Terminal
window running the sage startup shell script as its "command".  In addition the
Frameworks directory in the bundle contains four frameworks: Sage.framework, which
embeds a stripped down, but complete, version of the standard Sage binary distribution,
and OpenSSL.framework, Tcl.framework and Tk.framework.  The last three frameworks
are used to provide working ssl and tkinter modules within Sage.  (The standard macOS
binary distribution of SageMath does not include working versions of these modules.)

Eventually this project will include scripts that can be used to build the application
from a macOS binary distribution of SageMath.  Currently the project is empty, except
for this README file, but it does have a prelease version of the macOS Application
that can be downloaded for testing.
