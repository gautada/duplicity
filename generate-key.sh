#!/usr/bin/env sh
set -euo pipefail

generate_key() {
  DOMAIN="${1:-example.com}"
  REALNAME="Duplicity Backup Encryptor"
  EMAIL="${2:-duplicity-encryptor@${DOMAIN}}"
  EXPIRE="10y"

  echo "Generating GPG key for:"
  echo "  Real Name: $REALNAME"
  echo "  Email:     $EMAIL"
  echo "  Expires:   $EXPIRE"
  echo

  # read -rsp "Enter GPG passphrase: " PASSPHRASE
  # echo
  printf '%s' "Enter GPG passphrase: " >&2
  stty -echo
  IFS= read -r PASSPHRASE
  stty echo
  printf '\n' >&2

  # read -rsp "Confirm GPG passphrase: " PASSPHRASE_CONFIRM
  # echo
  printf '%s' "Confirm GPG passphrase: " >&2
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
  mv "${TMP_KEY_FILE}" "${FINGERPRINT}.public.asc"

  TMP_KEY_FILE="$(mktemp)"
  # gpg --armor --export-secret-key "${FINGERPRINT}" > "${FINGERPRINT}.private.asc"
  gpg --batch --yes \
  --pinentry-mode loopback \
  --passphrase "${PASSPHRASE}" \
  --armor \
  --export-secret-keys "${FINGERPRINT}" \
  > "${TMP_KEY_FILE}"
  mv "${TMP_KEY_FILE}" "${FINGERPRINT}.private.asc"
  
  unset PASSPHRASE
  gpg --batch --yes --pinentry-mode loopback --armor --delete-secret-key "${FINGERPRINT}"
  gpg --batch --yes --pinentry-mode loopback --armor --delete-key "${FINGERPRINT}"

  # TMP_KEY_FILE="$(mktemp)"
  # gpg --armor --export "${FINGERPRINT}" > "${TMP_KEY_FILE}"
  # mv "${TMP_KEY_FILE}" "${FINGERPRINT}.public.asc"
  #
  # TMP_KEY_FILE="$(mktemp)"
  # gpg --armor --export-secret-key "${FINGERPRINT}" > "${FINGERPRINT}.private.asc"
  # mv "${TMP_KEY_FILE}" "${FINGERPRINT}.private.asc"
  #
  # gpg --delete-secret-key "${FINGERPRINT}"
  # gpg --delete-key "${FINGERPRINT}"


  # gpg --export-secret-key -a \
  #   "${REALNAME}" > "${TMP_KEY_FILE}"
  # printf '\n\nKey File:\n%s\n\n\n' "${TMP_KEY_FILE}"

  # echo "Secret key:"
  gpg --list-secret-keys --keyid-format=long "$EMAIL"
}

generate_key "gautier.org"

