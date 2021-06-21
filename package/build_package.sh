#!/bin/bash
source IDs.sh

pkgbuild --root local_bin --scripts local_bin/scripts --identifier org.computop.SageMath.bin --version 9.3 --install-location /usr/local/bin bin.pkg
productsign --sign $DEV_ID bin.pkg packages/SageMath_bin.pkg

pkgbuild --root local_share --identifier org.computop.SageMath.share --version 9.3 --install-location /usr/local/share share.pkg
productsign --sign $DEV_ID share.pkg packages/SageMath_share.pkg

productbuild --distribution Distribution --package-path packages --resources resources recommended.pkg

productsign --sign $DEV_ID recommended.pkg Recommended.pkg

xcrun altool --notarize-app --primary-bundle-id "SageMath-9.3" --username "marc.culler@gmail.com" --password $ONE_TIME_PASS --file Recommended.pkg

echo Waiting one minute ...
sleep 60

xcrun stapler staple Recommended.pkg
