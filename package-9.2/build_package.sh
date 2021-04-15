#!/bin/bash
source IDs.sh

pkgbuild --root local_bin --scripts local_bin/scripts --identifier org.computop.SageMath-9-2.bin --version 1.0 --install-location /usr/local/bin bin.pkg
productsign --sign $DEV_ID bin.pkg packages/SageMath_9_2_bin.pkg

pkgbuild --root kernel --identifier org.computop.SageMath-9-2.kernel --version 1.0 --install-location /usr/local/share/jupyter/kernels/sagemath_9_2_all kernel.pkg
productsign --sign $DEV_ID kernel.pkg packages/SageMath_9_2_kernel.pkg

productbuild --distribution Distribution --package-path packages --resources resources recommended.pkg

productsign --sign $DEV_ID recommended.pkg Recommended_9_2.pkg

xcrun altool --notarize-app --primary-bundle-id "SageMath-9.2" --username "$EMAIL" --password $ONE_TIME_PASS --file Recommended_9_2.pkg

#xcrun stapler staple Recommended_9_2.pkg
