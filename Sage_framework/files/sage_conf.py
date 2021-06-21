# build/pkgs/sage_conf/src/sage_conf.py.  Generated from sage_conf.py.in by configure.

VERSION = "9.3"

MAXIMA = "/var/tmp/sage-9.3-current/local/bin/maxima"

ARB_LIBRARY = "arb"

NTL_INCDIR = ""
NTL_LIBDIR = ""

# Path to the ecl-config script
# TODO: At the moment this is hard-coded, needs to be set during the configure phase if we want to support system-installed ecl.
ECL_CONFIG = "/var/tmp/sage-9.3-current/local/bin/ecl-config"

SAGE_NAUTY_BINS_PREFIX = ""

# Colon-separated list of pkg-config modules to search for cblas functionality.
# We hard-code it here as cblas because configure (build/pkgs/openblas/spkg-configure.m4)
# always provides cblas.pc, if necessary by creating a facade pc file for a system BLAS.
CBLAS_PC_MODULES = "cblas"

# Used in sage.repl.ipython_kernel.install
MATHJAX_DIR = "/var/tmp/sage-9.3-current/local/share/mathjax"
THREEJS_DIR = "/var/tmp/sage-9.3-current/local/share/threejs"

# The following must not be used during build to determine source or installation
# location of sagelib.  See comments in SAGE_ROOT/src/Makefile.in
SAGE_LOCAL = "/var/tmp/sage-9.3-current/local"
SAGE_ROOT = "/var/tmp/sage-9.3-current"

# Entry point 'sage-config'.  It does not depend on any packages.

def _main():
    from argparse import ArgumentParser
    from sys import exit, stdout
    parser = ArgumentParser()
    parser.add_argument('--version', help="show version", action="version",
                       version='%(prog)s ' + VERSION)
    parser.add_argument("VARIABLE", nargs='?', help="output the value of VARIABLE")
    args = parser.parse_args()
    d = globals()
    if args.VARIABLE:
        stdout.write('{}\n'.format(d[args.VARIABLE]))
    else:
        for k, v in d.items():
            if not k.startswith('_'):
                stdout.write('{}={}\n'.format(k, v))

if __name__ == "__main__":
    _main()
