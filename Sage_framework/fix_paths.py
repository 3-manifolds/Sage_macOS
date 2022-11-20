import sys
import os
import subprocess
import re
LOCAL_LIB = '/private/var/tmp/sage-X.X-current/local/lib'
get_info = re.compile(b'Filetype: (?P<filetype>.*)| *LC_LOAD_DYLIB: (?P<dylib>.*)| *LC_RPATH: (?P<rpath>.*)')
get_version = re.compile('SageMath version ([0-9]\.[0-9]*)')

# Bigendian encoding of the magic numbers for mach-O binaries
feedface_big = b'\xfe\xed\xfa\xce'
cafebabe_big = b'\xca\xfe\xba\xbe'
feedfacf_big = b'\xfe\xed\xfa\xcf'
cafebabf_big = b'\xca\xfe\xba\xbf'
# Smallendian encodings of the magic number for mach-O binaries
feedface = b'\xce\xfa\xed\xfe'
cafebabe = b'\xbe\xba\xfe\xca'
feedfacf = b'\xcf\xfa\xed\xfe'
cafebabf = b'\xbf\xba\xfe\xca'

magics = (cafebabf, feedfacf,  cafebabe_big, feedface_big, cafebabe, feedface, cafebabf_big, feedfacf_big)

def unique(some_list):
    return list(dict((x, None) for x in some_list).keys())

class MachFile:
    def __init__(self, path):
        self.path = path
        nodes = self.path.split(os.path.sep)
        self.nodes = nodes[nodes.index('local'):]
        self.local_path = os.path.join(*nodes)
        self.depth = len(nodes)
        info = subprocess.run(['macher', 'info', path], capture_output=True).stdout
        self.filetype = None
        self.dylibs = []
        self.rpaths = []
        for line in info.split(b'\n'):
            m = get_info.match(line)
            if m is None:
                continue
            filetype = m['filetype']
            if filetype:
                self.filetype = filetype.decode('ascii')
                continue
            dylib = m['dylib']
            if dylib:
                if (not dylib.startswith(b'/usr') and
                    not dylib.startswith(b'/lib') and
                    not dylib.startswith(b'/System')):
                    self.dylibs.append(dylib.decode('ascii'))
                continue
            rpath = m['rpath']
            if rpath:
                self.rpaths.append(rpath.decode('ascii'))

    def relative_path(self, path):
        """
        Return a relative path from the directory containing this file to
        the directory containing the file wiht the give path.
        """
        nodes = path.split(os.path.sep)
        try:
            local_nodes = nodes[nodes.index('local'):]
        except ValueError:
            return
        prefix = []
        index = 0
        for local_node, node in zip(local_nodes, self.nodes):
            if local_node == node:
                index += 1
        steps = len(self.nodes) - index - 1
        try:
            return os.path.join(*(['..']*steps + local_nodes[index:-1]))
        except TypeError:
            return ''

    def fixed_rpaths(self):
        """
        Return the list of rpaths to be installed in this file.  These
        should all be relative paths, prefixed with @loader_path or
        @executable_path, depending on the file type.
        """
        rpaths = unique(self.rpaths)
        relpaths = []
        def build_rpath(relpath):
            if self.filetype == "MH_EXECUTE":
                prefix = '@executable_path'
            elif self.filetype in ("MH_DYLIB", "MH_BUNDLE"):
                prefix = '@loader_path'
            else:
                prefix = ''
            if relpath:
                return os.path.join(prefix, relpath)
            else:
                return prefix
        for dylib in self.dylibs:
            if dylib.startswith('/opt'):
                # Special case for libgfortan on arm64.  Simulate the library being
                # installed in our bundle.
                installed_path = os.path.join(LOCAL_LIB, os.path.basename(dylib))
                relpaths.append(self.relative_path(installed_path))
            elif dylib.startswith('/'):
                 relpaths.append(self.relative_path(dylib))
            elif dylib.startswith('@rpath'):
                for rpath in rpaths:
                    if rpath.startswith('@loader_path'):
                        # Already fixed, e.g. _tkinter
                        continue
                    expanded_dylib = dylib.replace('@rpath', rpath)
                    relpaths.append(self.relative_path(expanded_dylib))
            elif dylib.startswith('@'):
                continue
            else:
                raise RuntimeError('Unrecognized load path %s'%dylib)
        fixed = [rpath for rpath in self.rpaths if rpath.startswith('@loader_path')]
        return fixed + unique([build_rpath(relpath) for relpath in relpaths])

    def fix(self):
        rpaths = self.fixed_rpaths()
        subprocess.run(['macher', 'clear_rpaths', self.path], capture_output=True)
        for rpath in rpaths:
            subprocess.run(['macher', 'add_rpath', rpath, self.path], capture_output=True)
        for dylib in self.dylibs:
            if (dylib.startswith('/usr') or dylib.startswith('/lib') or
                    dylib.startswith('@rpath')):
                continue
            new_dylib = os.path.join('@rpath', os.path.basename(dylib))
            subprocess.run(['macher', 'edit_libpath', dylib, new_dylib, self.path])
        # Stripping more than this breaks the gcc stub library, but probably most executables
        # and libraries could be stripped to -u -r without causing problems.
        subprocess.run(['strip', '-x', self.path], capture_output=True)
        print(self.path)

class ScriptFile:
    def __init__(self, repo, symlink, path):
        self.path = path
        nodes = self.path.split(os.path.sep)
        self.sage_dir = os.path.join(repo, 'sage').encode('utf-8')
        self.symlink = symlink

    def fix(self):
        try:
            with open(self.path, 'rb') as infile:
                shebang = infile.readline()
                rest = infile.read()
                tail = shebang.split(b'/local/')[1]
                new_shebang = b'#!' + os.path.join(self.symlink, b'local', tail)
        except:
            new_shebang = shebang
        with open(self.path, 'wb') as outfile:
            outfile.write(new_shebang + b'\n')
            outfile.write(rest.replace(self.sage_dir, self.symlink))

class ConfigFile:
    def __init__(self, repo, symlink, path):
        self.path = path
        nodes = self.path.split(os.path.sep)
        self.sage_dir = os.path.join(repo, 'sage').encode('utf-8')
        self.symlink = symlink

    def fix(self):
        with open(self.path, 'rb') as infile:
            contents = infile.read()
        with open(self.path, 'wb') as outfile:
            outfile.write(contents.replace(self.sage_dir, self.symlink))

def mach_check(path):
    if os.path.islink(path):
        return False
    with open(path, 'rb') as inputfile:
        magic = inputfile.read(4)
    return magic in magics

def shebang_check(path):
    if os.path.islink(path):
        return False
    with open(path, 'rb') as inputfile:
        first = inputfile.read(2)
    return first == b'#!'

# These files need to be fixed as ConfigFiles as well.
MAKEFILE = 'python3.9/config-3.9-darwin/Makefile'
DARWIN_DATA = 'python3.9/_sysconfigdata__darwin_darwin.py'
SAGE_CONFIG = 'python3.9/site-packages/sage_conf.py'

#def fix_files(repo, symlink, directory):
def fix_files(repo, directory):
    for dirpath, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            fullpath = os.path.join(dirpath, filename)
            if mach_check(fullpath):
                MF = MachFile(fullpath)
                MF.fix()
                #if MF.filetype == "MH_DYLIB":
                #    id_path = os.path.join("@rpath", os.path.split(fullpath)[1])
                #    subprocess.run(['macher', 'set_id', id_path, fullpath])
            # elif shebang_check(fullpath):
            #     ScriptFile(repo, symlink, fullpath).fix()
            # elif (fullpath.endswith('.pc') or
            #         fullpath.endswith(MAKEFILE) or
            #         fullpath.endswith(DARWIN_DATA) or
            #         fullpath.endswith(SAGE_CONFIG)):
            #     ConfigFile(repo, symlink, fullpath).fix()

# def fix_config_files(directory):
#     for dirpath, dirnames, filenames in os.walk(directory):
#         for filename in filenames:
#             fullpath = os.path.join(dirpath, filename)
#             ConfigFile(fullpath).fix()

# def fix_scripts(directory):
#     for dirpath, dirnames, filenames in os.walk(directory):
#         for filename in filenames:
#             fullpath = os.path.join(dirpath, filename)
#             if shebang_check(fullpath):
#                 ScriptFile(fullpath).fix()

if __name__ == '__main__':
    try:
        repo, directory = sys.argv[1], sys.argv[2]
    except IndexError:
        print('Usage python3 fixpaths.py repo <directory>')
    with open(os.path.join(repo, 'sage', 'VERSION.txt')) as input_file:
        m = get_version.match(input_file.readline())
    sage_version = m.groups()[0]
    LOCAL_LIB = LOCAL_LIB.replace('X.X', sage_version)
    repo = os.path.abspath(repo)
    fix_files(repo, directory)
