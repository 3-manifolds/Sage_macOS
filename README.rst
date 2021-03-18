Sage_MacOS
==========

The Sage_MacOS project aims to provide a simple, streamlined macOS application which
runs SageMath and can be installed by the usual process of dragging the application
bundle to the /Applications directory.  There is currently a functioning, signed
and notarized beta release of such an app available from the Releases section.

The structure of the application bundle is that the main executable is a python
script (run by exec in bash) which runs a small tkinter application.  The
application has a single window which can launch Sage, either as a command line
program or as a Jupyter notebook.  The command line interface can run either in
Terminal.app or, if it is installed, in iTerm.app.  For the notebook interface,
it is possible to either create a new Jupyter server or to connect to a Jupyter
server which is already running.

Once Sage is launched, the window is withdrawn.  Activating the app by clicking
its dock icon causes the window to reappear and allow another instance of Sage
to be launched.

There is a backwards incompatibility with the former Sage app distributed by
sagemath.org which is slated for removal from 9.3.  That app had a bash script
at the top level of the bundle (e.g. /Applications/SageMath.app/sage).  But
placing a script in that location prevents signing the bundle, since it violates
Apple's specifications for the structure of a applicaton bundle.  Instead, this
app provides a separate installer package which creates a tiny bash script
named /usr/local/bin/sage which can be used to run sage from a shell or script.

Eventually this project will include all of the tools that are used to build
the application starting from a macOS binary distribution of SageMath.
Currently the project is missing some of those tools, however.
