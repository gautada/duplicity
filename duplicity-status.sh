#!/bin/sh
duplicity collection-status \
   --encrypt-key "$ENCRYPTER_FINGERPRINT" \
   --sign-key "$SIGNER_FINGERPRINT" \
   file:///mnt/volumes/data/25
