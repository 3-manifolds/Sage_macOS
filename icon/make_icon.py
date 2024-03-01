#!/usr/bin/env python3
from subprocess import run

for res in (512, 256, 128, 32, 16):
    run(['sips', '-z', str(res), str(res),  'sage_icon_1024.png',
	 '--out', 'Sage.iconset/icon_%sx%s.png'%(res, res)])
    run(['sips', '-z', str(2*res), str(2*res),  'sage_icon_1024.png',
	 '--out', 'Sage.iconset/icon_%sx%s@2x.png'%(res, res)])
run(['iconutil', '-c', 'icns', 'Sage.iconset'])
	   
	   
