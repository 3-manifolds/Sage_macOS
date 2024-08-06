Sage_MacOS
==========

The Sage_MacOS project provides a macOS application which allows
starting a Sage session running either in a command line or in a
Jupyter or JupyterLab notebook. It is distributed as a single file
disk image which can be installed by the familiar process of
dragging the application icon to the Applications folder.  The
application and the disk image are signed and notarized, so no
special set up is required to run the app.

When the app is started by clicking its icon it opens a small window
which allows selecting a user interface.  Clicking the "Launch" button
starts Sage running with the chosen command line or notebook
interface and closes the window.  If a notebook interface was
requested, a Jupyter server will be started. The window will
reopen if the icon is clicked again, allowing starting a new session.

As with a typical macOS application, SageMath continues to run
until it is stopped by selecting Quit from the File menu, or
typing Command-Q, or selecting Quit from the contextual menu
on the Dock icon.  When the app quits it will terminate the Jupyter
server process, if one was started.  (This is a change starting
with version 10.3, meant to prevent having unused server processes
running on the system.)

The disk image includes an Installer package which creates an
executable script ``/usr/local/bin/sage`` that can be used
to start sage from a shell or script.  It also installs Jupyter
kernel specifications in a standard location in /usr/local to
enable other Jupyter applications to use the Sage kernel.

The sage script does not support the -i option, because installing
new packages inside of a notarized application bundle causes the
signature to become invalid and the application to be unusable.
However, the application already includes as many optional
packages as possible.  In addition, the Sage %pip command can
be used to install PyPI packages in the user's .sage directory,
allowing them to be accessed during a Sage session.

*  .. image:: https://img.shields.io/github/downloads/3-manifolds/Sage_macOS/v2.4.0/total.svg
