#!/bin/bash
source IDs.sh
PKG_ID=9_7
VERSION=1.0

mkdir -p packages

pkgbuild --root local_bin --scripts local_bin/sage_install/scripts --identifier org.computop.SageMath.$PKG_ID.bin --version $VERSION --install-location /usr/local/bin bin.pkg
REPO_SAGETEX="../Sage_framework/repo/sage/venv/share/texmf/tex/latex/sagetex/sagetex.sty"
PKG_SAGETEX="local_texlive/texmf-local/tex/latex/local/sagetex.sty"
if [ `cmp $REPO_SAGETEX $PKG_SAGETEX` ]; then
    echo Updating sagetex.sty
    cp $REPO_SAGETEX $PKG_SAGETEX
fi
cp $REPO_SAGETEX $PKG_SAGETEX

productsign --sign $DEV_ID bin.pkg packages/SageMath_bin.pkg

pkgbuild --root local_share --identifier org.computop.SageMath.$PKG_ID.share --version $VERSION --install-location /usr/local/share share.pkg
productsign --sign $DEV_ID share.pkg packages/SageMath_share.pkg

pkgbuild --root local_texlive --identifier org.computop.SageMath.$PKG_ID.texlive --version $VERSION --install-location /usr/local/texlive texlive.pkg
productsign --sign $DEV_ID texlive.pkg packages/SageMath_texlive.pkg

productbuild --distribution Distribution --package-path packages --resources resources recommended.pkg

productsign --sign $DEV_ID recommended.pkg Recommended_$PKG_ID.pkg

xcrun notarytool submit Recommended_$PKG_ID.pkg --keychain-profile culler --wait
#xcrun altool --notarize-app --primary-bundle-id "SageMath-$VERSION" --username "marc.culler@gmail.com" --password $ONE_TIME_PASS --file Recommended_$PKG_ID.pkg

xcrun stapler staple Recommended_$PKG_ID.pkg
