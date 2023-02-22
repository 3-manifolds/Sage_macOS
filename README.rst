Sage_MacOS
==========

The Sage_MacOS project aims to provide a simple, streamlined macOS application which
runs SageMath and can be installed by the usual process of dragging the application
bundle to the /Applications directory.  There is currently a signed and notarized
release of such an app for SageMath 9.6 available in the Releases section, which
is accessable from the right hand side of this page.

The structure of the application bundle is that the main executable is a small C
program which execs the sage python interpreter to run a small tkinter application.
The Frameworks section of the bundle contains frameworks for Tcl, Tk and Sage.  The
Sage framework contains the result of a standard build of Sage with inessential
components removed.  Executables and libraries in the framework have modified load
paths and rpaths designed to make the framework fully relocatable and self-contained
to allow for signing and notarization.

The application opens a small window which can launch Sage, either as a command line
program or as a Jupyter notebook.  The command line interface can run either in
Terminal.app or, if it is installed, in iTerm.app. Once Sage is launched, the app
exits.  This behavior is similar to that of Apple's Launchpad.app.  The application
icon can be placed in the dock to make it easy to launch Sage at any time. 

The distrubution includes an Installer package which creates an executable bash script
named /usr/local/bin/sage that can be used to run sage from a shell or script.  It
also installs Jupyter kernel descriptions in a standard location in /usr/local to
enable Jupyter applications to run Sage.

*  .. image:: https://img.shields.io/github/downloads/3-manifolds/Sage_macOS/v1.6.0/total.svg
