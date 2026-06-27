#!/bin/sh

# Load shared environment validation and TARGET_URL construction.
# shellcheck source=duplicity-common.sh
# shellcheck disable=SC1091
. /usr/bin/duplicity-common

require SIGNER_FINGERPRINT
require ENCRYPTER_FINGERPRINT

# Setup gpg for use with duplicity. Only import when the keys are not already
# present in the keyring, so re-running setup is idempotent (and does not fail
# when the .asc secret files are no longer mounted).
if /usr/bin/gpg --list-keys "${ENCRYPTER_FINGERPRINT}" >/dev/null 2>&1 \
  && /usr/bin/gpg --list-secret-keys "${SIGNER_FINGERPRINT}" >/dev/null 2>&1; then
  echo "GPG keys already present in keyring; skipping import."
else
  /usr/bin/gpg --batch --yes --import "/mnt/volumes/secrets/${ENCRYPTER_FINGERPRINT}.asc"
  /usr/bin/gpg --batch --yes --import "/mnt/volumes/secrets/${SIGNER_FINGERPRINT}.asc"
  /usr/bin/gpg --list-keys --fingerprint "${ENCRYPTER_FINGERPRINT}"
  /usr/bin/gpg --list-secret-keys --fingerprint "${SIGNER_FINGERPRINT}"
  echo "$ENCRYPTER_FINGERPRINT:6:" | gpg --import-ownertrust
  echo "$SIGNER_FINGERPRINT:6:" | gpg --import-ownertrust
fi

# mkdir -p "${ARCHIVE_DIR}"

# PASSPHRASE="" SIGN_PASSPHRASE="${SIGNER_PASSPHRASE}" /usr/bin/duplicity \
#   cleanup --force "${TARGET_URL}"
