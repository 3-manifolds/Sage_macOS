import sys
import os

class ScriptFile:
    def __init__(self, fullpath):
        self.fullpath = fullpath

    def fix_shebang(self, shebang):
        nodes = shebang.split(os.path.sep)
        m = nodes.index('Versions')
        sage_version = nodes[m+1]
        tail = os.path.join(*nodes[m+2:])
        return '#!/var/tmp/sage-%s-current/'%sage_version + tail
        
    def fix(self):
        with open(self.fullpath, 'r') as infile:
            shebang = infile.readline()
            rest = infile.read()
        new_shebang = self.fix_shebang(shebang)
        with open(self.fullpath, 'w') as outfile:
            outfile.write(new_shebang + '\n')
            outfile.write(rest)

def shebang_check(path):
    if os.path.islink(path):
        return False
    with open(path, 'rb') as inputfile:
        first = inputfile.read(2)
    return first == b'#!'

def fix_scripts(directory):
    for dirpath, dirnames, filenames in os.walk(directory):
        for filename in filenames:
            fullpath = os.path.join(dirpath, filename)
            if shebang_check(fullpath):
                ScriptFile(fullpath).fix()

if __name__ == '__main__':
    try:
        directory = sys.argv[1]
    except IndexError:
        print('Usage python3 fixscripts.py <directory>')
    fix_scripts(directory)
