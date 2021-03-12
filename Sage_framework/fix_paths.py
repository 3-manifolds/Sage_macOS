import sys
import os
import subprocess
import re

get_info = re.compile(b'Filetype: (?P<filetype>.*)| *LC_LOAD_DYLIB: (?P<dylib>.*)| *LC_RPATH: (?P<rpath>.*)')

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
            return ('.')

    def fixed_rpaths(self):
        result = set(rpath for rpath in self.rpaths if rpath.startswith('@loader_path'))
        for dylib in self.dylibs:
                relpath = self.relative_path(dylib)
                if relpath:
                    if self.filetype == "MH_EXECUTE":
                        result.add(os.path.join('@executable_path', self.relative_path(dylib)))
                    elif self.filetype == "MH_DYLIB":
                        result.add(os.path.join('@loader_path', self.relative_path(dylib)))
                    elif self.filetype == "MH_BUNDLE":
                        result.add(os.path.join('@loader_path', self.relative_path(dylib)))
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
        subprocess.run(['macher', 'clear_rpaths', self.path])
        for rpath in rpaths:
            subprocess.run(['macher', 'add_rpath', rpath, self.path])
        for dylib in self.dylibs:
            if (dylib.startswith('/usr') or dylib.startswith('/lib') or
                    dylib.startswith('@rpath')):
                continue
            new_dylib = os.path.join('@rpath', os.path.basename(dylib))
            subprocess.run(['macher', 'edit_libpath', dylib, new_dylib, self.path])
        print(self.path)

def mach_check(path):
    if os.path.islink(path):
        return False
    with open(path, 'rb') as inputfile:
        magic = inputfile.read(4)
    return magic in magics

def fix_mach_files(directory):
    for dirpath, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            fullpath = os.path.join(dirpath, filename)
            if mach_check(fullpath):
                MachFile(fullpath).fix()

if __name__ == '__main__':
    fix_mach_files(sys.argv[1])

