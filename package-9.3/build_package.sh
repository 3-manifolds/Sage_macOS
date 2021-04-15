#!/bin/bash
source IDs.sh

pkgbuild --root local_bin --scripts local_bin/scripts --identifier org.computop.SageMath-9-3.bin --version 1.0 --install-location /usr/local/bin bin.pkg
productsign --sign $DEV_ID bin.pkg packages/SageMath_9_3bin.pkg

pkgbuild --root kernel --identifier org.computop.SageMath-9-3.kernel --version 1.0 --install-location /usr/local/share/jupyter/kernels/sagemath_9_3_all kernel.pkg
productsign --sign $DEV_ID kernel.pkg packages/SageMath_9_3_kernel.pkg

productbuild --distribution Distribution --package-path packages --resources resources recommended.pkg

productsign --sign $DEV_ID recommended.pkg Recommended_9_3.pkg

xcrun altool --notarize-app --primary-bundle-id "SageMath-9.3" --username "$EMAIL" --password $ONE_TIME_PASS --file Recommended_9_3.pkg

#xcrun stapler staple Recommended_9_3.pkg
