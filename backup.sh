#!/bin/sh
#  PASSPHRASE="$DUPLICITY_ENCRYPTER_PASSWORD" SIGN_PASSPHRASE="$DUPLICITY_SIGNER_PASSWORD" /usr/bin/duplicity full --archive-dir "$HOME"/cache --encrypt-key "$DUPLICITY_ENCRYPTER_FINGERPRINT" --sign-key "$DUPLICITY_SIGNER_FINGERPRINT" --verbosity d "$HOME"/local "$DUPLICITY_TARGET_URL"

ARCHIVE_DIR="${HOME}/duplicity-cache"
mkdir -p "${ARCHIVE_DIR}"
SOURCE_DIR="/mnt/volumes/backup"
TARGET_URL="file:///mnt/volumes/data/"
SIGN_PASSPHRASE="${DUPLICITY_SIGNER_PASSWORD}" \
  /usr/bin/duplicity full \
    --archive-dir "${ARCHIVE_DIR}" \
    --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
    --sign-key "${SIGNER_FINGERPRINT}" \
    --verbosity d \
    "${SOURCE_DIR}" "${TARGET_URL}"
