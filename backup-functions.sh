#!/bin/sh

gpg_passphrase() {
 FINGERPRINT="${1}"
 PASSPHRASE="$(/usr/bin/env | /bin/grep _"${FINGERPRINT}" | /usr/bin/awk -F '=' '{print $2}')"
 if [ -z "${PASSPHRASE}" ] ; then
  if [ -f "/mnt/volumes/secrets/${FINGERPRINT}" ] ; then
   PASSPHRASE="$(/bin/cat /mnt/volumes/secrets/"${FINGERPRINT}")"
  else
   if [ -f "/etc/container/${FINGERPRINT}" ] ; then
    PASSPHRASE="$(/bin/cat /etc/container/"${FINGERPRINT}")"
   else
    if [ -f "/mnt/volumes/container/${FINGERPRINT}" ] ; then
     PASSPHRASE="$(/bin/cat /mnt/volumes/container/"${FINGERPRINT}")"
    fi
   fi
  fi
 fi
 echo "${PASSPHRASE}"
}

load_gpg_key() {
 KEY_FILE="/etc/container/${1}"
 if [ ! -f "${KEY_FILE}" ] ; then
  echo "[ERROR] Unable to find the backup certificate(${KEY_FILE})"
  return 1
 fi
 FINGERPRINT="$(/usr/bin/gpg --show-keys "${KEY_FILE}" | sed -n '2p' | xargs)"
 PUSH="$(gpg_passphrase "${FINGERPRINT}")"
 echo "${PUSH}" | /usr/bin/gpg --quiet --passphrase-fd 0 --batch --trusted-key "${FINGERPRINT}" --import "${KEY_FILE}"
 echo "${FINGERPRINT}"
 return 0
}

generate_hashmap() {
 hashmap="$(/usr/bin/find "${1}" -type f -exec /usr/bin/sha256sum {} \; | /usr/bin/sort | /usr/bin/sha256sum |  awk '{print ${1}}')"
 echo "${hashmap}"
}

# container_backup() {
#  echo "[ INFO] Current directory($(/bin/pwd))"
#  echo "[ WARN] Default container backup function not customized for container"
#  /bin/cp -rv /mnt/volumes/container/* /tmp/backup
#  return $?
# }
 
if [ -f "/etc/container/backup" ] ; then
  # shellcheck disable=SC1091
  . /etc/container/backup
fi

create_backup_source() {
 SOURCE="${1}"
 # Collect backup material
 /bin/mkdir -p "${SOURCE}"
 cd "${SOURCE}" || exit # Not sure this is the correct solution
 # if [ -f /etc/container/backup ] ; then
 #   if /usr/bin/id -u 1001 > /dev/null 2>&1; then
 #    USRNAME=$(/usr/bin/id -un 1001)
 #    /bin/su $USERNAME -c /etc/container/backup
 #   else
 #    echo "No downstream user found."
 #    exec /etc/container/backup
 #   fi
 # else
 #  default_container_backup # Call default backup function
 # fi
 if /usr/bin/id -u 1001 > /dev/null 2>&1; then
  USERNAME=$(/usr/bin/id -un 1001)
  /bin/su "${USERNAME}" -c container_backup
 else
  container_backup
 fi
 RTN="${?}"
 if [ "${RTN}" -ne 0 ] ; then
  echo "[ERROR]: Function(${RTN}) did not work"
  return "${RTN}"
 fi
 HASHMAP="$(generate_hashmap "${SOURCE}")"
 echo "${HASHMAP}" >> "${SOURCE}/.hashmap"
 cd /
}

clean_backup_source() {
 SOURCE="${1}"
 echo "[ INFO]: Clean source folder ${SOURCE}"
 # /bin/rm -frv "${SOURCE}/*"
 /bin/rm -frv "${SOURCE:?}/"*
}
 
duplicity_clean() {
 SOURCE="${1}"
 CACHE="${2}"
 TARGET="${3}"
 # INFO="$(/usr/bin/duplicity remove-all-but-n-full 1 --force file:/"${TARGET}")"
 if [ -f "${TARGET}/duplicity-full*.manifest.gpg" ] ; then
  # MANIFEST="${CACHE}/$(ls "${TARGET}"/duplicity-full*.manifest.gpg | awk -F '/' '{print $5}' | sed 's/.\{4\}$//')"
  MANIFEST="${CACHE}/$(find "${TARGET}" -maxdepth 1 -type f -name 'duplicity-full*.manifest.gpg' -exec basename {} .gpg \; | head -n 1)"
  echo "${MANIFEST}"
 else
  echo "${CACHE}/duplicity-full*.manifest"
 fi
}

duplicity_backup() {
 TYPE="$(echo "${1}" | /usr/bin/tr '[:upper:]' '[:lower:]')"
 FULL="full"
 NAME="${2}"
 SOURCE="${3}"
 ARCHIVE="${4}"
 TARGET="${5}"
 
 echo "[ INFO]: ***** BACKUP(${TYPE}) *****"
 SIGNER_FINGERPRINT="$(load_gpg_key signer.key)"
 echo "[ INFO]: Signer=${SIGNER_FINGERPRINT}"
 ENCRYPTER_FINGERPRINT="$(load_gpg_key encrypter.key)"
 echo "[ INFO]: Encrypter: ${ENCRYPTER_FINGERPRINT}"
 if [ "${TYPE}" = "${FULL}" ] ; then
  echo "[ INFO]: Clean backup cache(${CACHE})"
  /bin/rm -frv "${CACHE}"
  echo "[ INFO]: Clean backup target(${TARGET})"
  /bin/rm -frv "${TARGET}/duplicity*"
 fi
 # env SIGN_PASSPHRASE="$(gpg_passphrase $SIGNER_FINGERPRINT)" /usr/bin/duplicity $TYPE --encrypt-key $ENCRYPTER_FINGERPRINT --sign-key $SIGNER_FINGERPRINT --name $NAME --archive-dir $ARCHIVE $SOURCE "file:/$TARGET"
 /usr/bin/duplicity "${TYPE}" --encrypt-key "${ENCRYPTER_FINGERPRINT}" \
                          --sign-key "${SIGNER_FINGERPRINT}" \
                          --name "${NAME}" \
                           --archive-dir "${ARCHIVE}" "${SOURCE}" "file:/${TARGET}"
}

