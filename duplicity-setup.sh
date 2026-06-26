#!/bin/sh
#
# Load shared environment validation and TARGET_URL construction.
# shellcheck source=duplicity-common.sh
# shellcheck disable=SC1091
. /usr/bin/duplicity-common

require SIGNER_FINGERPRINT
require SIGNER_FINGERPRINT

# This script should setup gpc for use with duplicity
/usr/bin/gpg --batch --yes --import "/mnt/volumes/secrets/${ENCRYPTER_FINGERPRINT}.asc"
/usr/bin/gpg --batch --yes --import "/mnt/volumes/secrets/${SIGNER_FINGERPRINT}.asc"
/usr/bin/gpg --list-keys --fingerprint "${ENCRYPTER_FINGERPRINT}"
/usr/bin/gpg --list-secret-keys --fingerprint "${SIGNER_FINGERPRINT}"
echo "$ENCRYPTER_FINGERPRINT:6:" | gpg --import-ownertrust
echo "$SIGNER_FINGERPRINT:6:" | gpg --import-ownertrust
