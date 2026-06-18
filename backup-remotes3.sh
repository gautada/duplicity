#!/bin/sh
export PASSPHRASE="${DUPLICITY_ENCRYPTER_PASSWORD}"
export SIGN_PASSPHRASE="${DUPLICITY_SIGNER_PASSWORD}"

MONTH_NUM="$(/bin/date +%m)"
MONTH_NAME="$(date +%b)"
# DAY="$(/bin/date +%d)"

DESTINATION="s3://duplicity.gautier.org/${MONTH_NUM}-${MONTH_NAME}/"
echo "${DESTINATION}"

# is_running=$(ps -ef | grep duplicity  | grep python | wc -l)

python /usr/bin/backup-cleanup
# OLDER_THAN="1h"
# /usr/bin/duplicity remove-older-than ${OLDER_THAN} ${DESTINATION}

/usr/bin/duplicity \
 --archive-dir /mnt/volumes/container \
 --encrypt-key "${DUPLICITY_ENCRYPTER_FINGERPRINT}" \
 --sign-key "${DUPLICITY_SIGNER_FINGERPRINT}" \
 --verbosity d /mnt/volumes/source "${DESTINATION}"
