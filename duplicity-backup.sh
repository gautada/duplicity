#!/bin/sh

# Load shared environment validation and TARGET_URL construction.
# shellcheck source=duplicity-common.sh
# shellcheck disable=SC1091
. /usr/bin/duplicity-common

# Backup additionally requires the signer passphrase.
require SIGNER_PASSPHRASE

# SOURCE_DIR="${SOURCE_DIR:-/mnt/volumes/backup}"
# #to-do: Check to make sure the backup dir exists and log and fail if no

# ARCHIVE_DIR="${HOME}/duplicity-cache"
# mkdir -p "${ARCHIVE_DIR}"

# Always clean-up the target
/usr/bin/duplicity remove-older-than 3m --force "$TARGET_URL"

# Determine whether to run a FULL or incremental backup.
#
# A FULL backup is forced when this script is invoked as `duplicity-full-backup`
# (e.g. via a symlink to `duplicity-backup`). Otherwise a FULL backup runs on
# Sundays (date +%u: 1=Mon .. 7=Sun) and incremental on all other days.
SUNDAY="7"
DAY_OF_WEEK="$(/bin/date +%u)"
# case "${0##*/}" in
#   duplicity-full-backup)
#     set -- full
#     ;;
#   *)
if [ "$DAY_OF_WEEK" = "$SUNDAY" ] ; then
  set -- full
else
  set --
fi
#     ;;
# esac

PASSPHRASE="" SIGN_PASSPHRASE="${SIGNER_PASSPHRASE}" \
/usr/bin/duplicity "$@" \
  --archive-dir "${ARCHIVE_DIR}" \
  --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
  --sign-key "${SIGNER_FINGERPRINT}" \
  --verbosity info \
  "${SOURCE_DIR}" "${TARGET_URL}"
