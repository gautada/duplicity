#!/bin/sh

# Load shared environment validation and TARGET_URL construction.
# shellcheck source=duplicity-common.sh
# shellcheck disable=SC1091
. /usr/bin/duplicity-common

/usr/bin/duplicity collection-status \
   --encrypt-key "$ENCRYPTER_FINGERPRINT" \
   --sign-key "$SIGNER_FINGERPRINT" \
   "${TARGET_URL}"
