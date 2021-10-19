VERSION=9.4
cd build/Sage.framework/Versions/${VERSION}/local/share/gap/pkg
for pkg in `ls` ; do
  if [[ -L $pkg/bin ]]; then
    rm $pkg/bin ;
    ln -s ../../../../lib/gap/pkg/$pkg/bin $pkg/bin ; 
fi
done
