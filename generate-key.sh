#!/usr/bin/env sh
set -euo pipefail

generate_key() {
  EMAIL="${1:-generic@email.com}"
  EMAIL="$(printf '%s' "${EMAIL}" | tr '[:upper:]' '[:lower:]')"
  TYPE="${EMAIL%@*}"
  FIRST="$(printf '%s' "${TYPE}" | cut -c 1 | tr '[:lower:]' '[:upper:]')"
  REST="$(printf '%s' "${TYPE}" | cut -c 2-)"
  NAME="${FIRST}${REST}"
  REALNAME="${2:-Duplicity Backup ${NAME}}"
  EMAIL="${2:-duplicity-${EMAIL}}"
  EXPIRE="10y"

  printf '%s' "Enter GPG(${EMAIL}) passphrase: " >&2
  stty -echo
  IFS= read -r PASSPHRASE
  stty echo
  printf '\n' >&2

  printf '%s' "Confirm: " >&2
  stty -echo
  IFS= read -r PASSPHRASE_CONFIRM
  stty echo
  printf '\n' >&2
  
  if [ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]; then
    echo "ERROR: Passphrases do not match." >&2
    exit 1
  fi

  KEY_PARAMS="$(mktemp)"
  chmod 600 "$KEY_PARAMS"

  trap 'rm -f "$KEY_PARAMS"' EXIT

  cat > "$KEY_PARAMS" <<EOF
Key-Type: RSA
Key-Length: 4096
Key-Usage: cert,sign
Subkey-Type: RSA
Subkey-Length: 4096
Subkey-Usage: encrypt
Name-Real: $REALNAME
Name-Email: $EMAIL
Expire-Date: $EXPIRE
Passphrase: $PASSPHRASE
%commit
EOF

  echo
  echo "Generating key..."

  gpg --batch \
      --pinentry-mode loopback \
      --generate-key "$KEY_PARAMS"

  # unset PASSPHRASE
  unset PASSPHRASE_CONFIRM

  echo
  echo "Key generated successfully."
  echo

  FINGERPRINT="$(
    gpg --with-colons --fingerprint "$EMAIL" \
      | awk -F: '/^fpr:/ {print $10; exit}'
  )"

  echo "Fingerprint:"
  echo "$FINGERPRINT"
  echo

  TMP_KEY_FILE="$(mktemp)"
  gpg --armor --export "${FINGERPRINT}" > "${TMP_KEY_FILE}"
  gpg --batch --yes \
      --pinentry-mode loopback \
      --passphrase "${PASSPHRASE}" \
      --armor \
      --export-secret-keys "${FINGERPRINT}" >> "${TMP_KEY_FILE}"
  mv "${TMP_KEY_FILE}" "${FINGERPRINT}.${TYPE}-bundle.asc"

  if [ "${TYPE}" = "encyptor" ] ; then
    gpg --batch --yes --pinentry-mode loopback --armor --delete-secret-key "${FINGERPRINT}"
  else
    gpg --batch --yes --pinentry-mode loopback --armor --delete-key "${FINGERPRINT}"
  fi
  unset PASSPHRASE
}

generate_key "${1:-test@example.com}"

