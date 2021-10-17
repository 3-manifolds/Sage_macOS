"""
Walk through the directory passed as argv[1] and convert each absolute
symlink into a relative symlink.  Exits with status 1 and prints a warning
if any symlink is broken or points outside of the top level directory.

This needs to be run on the sage directory to remove absolute
symlinks created when installing packages (mainly GAP packages.)
"""

import os
import sys

def fix_symlinks(root_dir, check_only=False):
    for dirpath, dirnames, filenames in os.walk(root_dir):
        for filename in filenames + dirnames:
            link_path = os.path.join(dirpath, filename)
            if not os.path.islink(link_path):
                continue
            target = os.readlink(link_path)
            if os.path.isabs(target):
                if not os.path.exists(target):
                    print('%s is a broken symlink'%link_path)
                    if not check_only:
                        sys.exit(1)
                    continue
                if not target.startswith(root_dir):
                    print('%s has a forbidden target'%link_path)
                    if not check_only:
                        sys.exit(1)
                target_dir, target_base = os.path.split(target)
                relative_path = os.path.relpath(dirpath, target_dir)
                new_target = os.path.normpath(
                    os.path.join(relative_path, target_base))
                if check_only:
                    print('Absolute link: %s -> %s\n'%(link_path, target))
                else:
                    print('Fixed: %s -> %s'%(link_path, new_target))
                    os.remove(link_path)
                    os.symlink(new_target, link_path)
            else:
                full_target = os.path.join(dirpath, target)
                if not os.path.exists(full_target):
                    print('%s is a broken symlink'%link_path)
                    if not check_only:
                        sys.exit(1)

def main():
    try:
        root_dir = os.path.abspath(sys.argv[1])
    except IndexError:
        print('Usage: relativize_links dir')
        sys.exit(1)
    if not os.path.isdir(root_dir):
        print('%s is not a directory'%root_dir)
        sys.exit(1)
    fix_symlinks(root_dir, check_only=False)

if __name__ == '__main__':
    main()
