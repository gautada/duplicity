#!/bin/sh

# duplicity-common.sh
# Shared setup sourced by duplicity-backup and duplicity-status.
# Validates the required environment and builds TARGET_URL.
# NOTE: a failed check calls `exit`, which aborts the sourcing script
# (and its shell) as intended.

# require VAR [VAR...] -- abort if any named variable is unset/empty.
require() {
  for _var in "$@"; do
    eval "_val=\$$_var"
    if [ -z "$_val" ]; then
      echo "ERROR: $_var is not defined" >&2
      exit 1
    fi
  done
}

# Required by both backup and status.
require ENCRYPTER_FINGERPRINT SIGNER_FINGERPRINT TARGET_PROTO TARGET_DIR

# For local file targets, ensure the destination directory exists.
# if [ "file://" = "${TARGET_PROTO}" ] ; then
#   mkdir -p "${TARGET_DIR}"
# fi

SOURCE_DIR="${DUPLICITY_SOURCE:-/mnt/volumes/backup}"
#to-do: Check to make sure the backup dir exists and log and fail if no
echo "Source: ${SOURCE_DIR}"
mkdir -p "{$SOURCE_DIR}"

# shellcheck disable=SC2034
# ARCHIVE_DIR="${HOME}/duplicity-cache"
ARCHIVE_DIR="${DUPLICITY_ARCHIVE:-/mnt/volumes/data/archive}"
echo "Archive: ${ARCHIVE_DIR}"
mkdir -p "{$ARCHIVE_DIR}"

TARGET_DIR="${DUPLICITY_TARGET:-/mnt/volumes/data/target}"
echo "Target: ${TARGET_DIR}"
mkdir -p "{$TARGET_DIR}"

# Backups are bucketed by week-of-year (00-53) under the target.
WEEK_OF_YEAR="$(/bin/date +%U)"
# TARGET_URL is consumed by the scripts that source this file.
# shellcheck disable=SC2034
TARGET_URL="${TARGET_PROTO}${TARGET_DIR}/${WEEK_OF_YEAR}"
