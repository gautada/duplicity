#!/bin/sh

# Load shared environment validation and TARGET_URL construction.
# shellcheck source=duplicity-common.sh
# shellcheck disable=SC1091
. /usr/bin/duplicity-common

# Backup additionally requires the signer passphrase.
require SIGNER_PASSPHRASE

SOURCE_DIR="/mnt/volumes/backup"
#to-do: Check to make sure the backup dir exists and log and fail if no

ARCHIVE_DIR="${HOME}/duplicity-cache"
mkdir -p "${ARCHIVE_DIR}"

# Always clean-up the target
/usr/bin/duplicity remove-older-than 3m --force "$TARGET_URL"

# Run a FULL backup on Sundays (date +%u: 1=Mon .. 7=Sun), incremental otherwise.
SUNDAY="7"
DAY_OF_WEEK="$(/bin/date +%u)"
if [ "$DAY_OF_WEEK" = "$SUNDAY" ] ; then
  set -- full
else
  set --
fi

SIGN_PASSPHRASE="${SIGNER_PASSPHRASE}" \
/usr/bin/duplicity "$@" \
  --archive-dir "${ARCHIVE_DIR}" \
  --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
  --sign-key "${SIGNER_FINGERPRINT}" \
  --verbosity d \
  "${SOURCE_DIR}" "${TARGET_URL}"
