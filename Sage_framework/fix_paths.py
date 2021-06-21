import sys
import os
import subprocess
import re

get_info = re.compile(b'Filetype: (?P<filetype>.*)| *LC_LOAD_DYLIB: (?P<dylib>.*)| *LC_RPATH: (?P<rpath>.*)')
get_version = re.compile('SageMath version ([^,]*)')

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

with open('repo/sage/VERSION.txt') as input_file:
    m = get_version.match(input_file.readline())
sage_version = m.groups()[0]

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
        result = set(rpath for rpath in self.rpaths if rpath.startswith('@loader_path'))
        for dylib in self.dylibs:
            relpath = self.relative_path(dylib)
            if relpath is not None:
                if self.filetype == "MH_EXECUTE":
                    result.add(os.path.join('@executable_path', relpath))
                elif self.filetype == "MH_DYLIB":
                    result.add(os.path.join('@loader_path', relpath))
                elif self.filetype == "MH_BUNDLE":
                    result.add(os.path.join('@loader_path', relpath))
        return result

    def fixed_dylibs(self):
        result = []
        for dylib in self.dylibs:
            if (not dylib.startswith('/usr') and
                not dylib.startswith('/lib') and
                not dylib.startswith('/System')):
                result.append(os.path.join('@rpath', os.path.basename(dylib)))
        return result

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
    def __init__(self, path):
        self.path = path
        nodes = self.path.split(os.path.sep)
        self.repo = os.path.abspath('repo/sage').encode('utf-8')
        self.symlink = b'/var/tmp/sage-%s-current'%sage_version.encode('ascii')

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
            outfile.write(rest.replace(self.repo, self.symlink))

class ConfigFile:
    def __init__(self, path):
        self.path = path
        nodes = self.path.split(os.path.sep)
        self.repo = os.path.abspath('repo/sage').encode('utf-8')
        self.symlink = b'/var/tmp/sage-%s-current'%sage_version.encode('ascii')

    def fix(self):
        with open(self.path, 'rb') as infile:
            contents = infile.read()
        with open(self.path, 'wb') as outfile:
            outfile.write(contents.replace(self.repo, self.symlink))

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

# These two files need to be fixed as ConfigFiles as well.
MAKEFILE = 'local/lib/python3.9/config-3.9-darwin/Makefile'
DARWIN_DATA = 'local/lib/python3.9/_sysconfigdata__darwin_darwin.py'

def fix_files(directory):
    for dirpath, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            fullpath = os.path.join(dirpath, filename)
            if mach_check(fullpath):
                MF = MachFile(fullpath)
                MF.fix()
                if MF.filetype == "MH_DYLIB":
                    id_path = os.path.join("@rpath", os.path.split(fullpath)[1])
                    subprocess.run(['macher', 'set_id', id_path, fullpath])
            elif shebang_check(fullpath):
                ScriptFile(fullpath).fix()
            elif (fullpath.endswith('.pc') or
                    fullpath.endswith(MAKEFILE) or
                    fullpath.endswith(DARWIN_DATA)):
                ConfigFile(fullpath).fix()

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
    fix_files(sys.argv[1])
    

