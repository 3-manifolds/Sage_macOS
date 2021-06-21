import subprocess
import os
from dev_id import DEV_ID
entitlement_file = 'entitlement.plist'
file_args = ['codesign', '-v', '-s', DEV_ID, '--timestamp', '--options', 'runtime', '--force',
                 '--entitlements', entitlement_file]
with open('files_to_sign') as infile:
    for path in infile.readlines():
        signee = path.strip()
        result = subprocess.run(file_args + [signee], capture_output=True)
        if result.returncode:
            print('Failed on %s'%path)
            print(result.stderr)
print('Signing framework ...')
subprocess.run(file_args + ['build/Sage.framework'])


