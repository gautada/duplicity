#!/bin/sh

# Ensure required GPG fingerprints and passphrase are defined; abort otherwise.
if [ -z "${ENCRYPTER_FINGERPRINT}" ]; then
  echo "ERROR: ENCRYPTER_FINGERPRINT is not defined" >&2
  exit 1
fi
if [ -z "${SIGNER_FINGERPRINT}" ]; then
  echo "ERROR: SIGNER_FINGERPRINT is not defined" >&2
  exit 1
fi
if [ -z "${SIGNER_PASSPHRASE}" ]; then
  echo "ERROR: SIGNER_PASSPHRASE is not defined" >&2
  exit 1
fi

if [ -z "${TARGET_PROTO}" ] ; then
  echo "ERROR: TARGET_PROTO is not defined" >&2
  exit 1
fi

if [ -z "${TARGET_DIR}" ] ; then
  echo "ERROR: TARGET_DIR is not defined" >&2
  exit 1
fi

ARCHIVE_DIR="${HOME}/duplicity-cache"
mkdir -p "${ARCHIVE_DIR}"
SOURCE_DIR="/mnt/volumes/backup"
# TARGET_DIR="/mnt/volumes/data/duplicity-backup"
if [ "file://" = "${TARGET_PROTO}" ] ; then
  mkdir -p "${TARGET_DIR}"
fi
TARGET_URL="${TARGET_PROTO}${TARGET_DIR}"


# duplicity collection-status \
#   --encrypt-key "$ENCRYPTER_FINGERPRINT" \
#   --sign-key "$SIGNER_FINGERPRINT" \
#   file:///mnt/volumes/data/duplicity-test

WEEK_OF_YEAR="$(/bin/date +%U)"
TARGET_URL="${TARGET_URL}/${WEEK_OF_YEAR}"
SUNDAY="0"
DAY_OF_WEEK="$(/bin/date +%u)"

if [ "$DAY_OF_WEEK" = "$SUNDAY" ] ; then
  SIGN_PASSPHRASE="${SIGNER_PASSPHRASE}" \
  /usr/bin/duplicity full \
    --archive-dir "${ARCHIVE_DIR}" \
    --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
    --sign-key "${SIGNER_FINGERPRINT}" \
    --verbosity d \
    "${SOURCE_DIR}" "${TARGET_URL}" 
else
  SIGN_PASSPHRASE="${SIGNER_PASSPHRASE}" \
  /usr/bin/duplicity \
    --archive-dir "${ARCHIVE_DIR}" \
    --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
    --sign-key "${SIGNER_FINGERPRINT}" \
    --verbosity d \
    "${SOURCE_DIR}" "${TARGET_URL}" 
fi


