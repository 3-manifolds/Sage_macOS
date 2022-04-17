#!/bin/bash
source IDs.sh
PKG_ID=9_6
VERSION=1.0

mkdir -p packages

pkgbuild --root local_bin --scripts local_bin/sage_install/scripts --identifier org.computop.SageMath.$PKG_ID.bin --version $VERSION --install-location /usr/local/bin bin.pkg
productsign --sign $DEV_ID bin.pkg packages/SageMath_bin.pkg

pkgbuild --root local_share --identifier org.computop.SageMath.$PKG_ID.share --version $VERSION --install-location /usr/local/share share.pkg
productsign --sign $DEV_ID share.pkg packages/SageMath_share.pkg

pkgbuild --root local_texlive --identifier org.computop.SageMath.$PKG_ID.texlive --version $VERSION --install-location /usr/local/texlive texlive.pkg
productsign --sign $DEV_ID texlive.pkg packages/SageMath_texlive.pkg

productbuild --distribution Distribution --package-path packages --resources resources recommended.pkg

productsign --sign $DEV_ID recommended.pkg Recommended_$PKG_ID.pkg

xcrun altool --notarize-app --primary-bundle-id "SageMath-$VERSION" --username "marc.culler@gmail.com" --password $ONE_TIME_PASS --file Recommended_$PKG_ID.pkg

echo Waiting 90 seconds ...
sleep 90

xcrun stapler staple Recommended_$PKG_ID.pkg
