#!/bin/bash
for res in 512 256 128 32 16 ; do
    sips -z $res $res sage_icon_1024.png --out Sage.iconset/icon_$resx$res.png
    sips -z $res $res sage_icon_@2x1024.png --out Sage.iconset/icon_@2x$resx$res.png
done
iconutil -c icns Sage.iconset
	   
	   
