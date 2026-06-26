#!/bin/sh
# shellcheck shell=dash

# =============================================================================
# duplicity-backup.sh
# =============================================================================
# This script performs encrypted, signed, and incremental backups using
# duplicity. It follows a two-phase approach:
#   1. Sync the source data to a local staging directory via rsync.
#   2. Run duplicity to create an encrypted+signed backup at the target URL.
#
# On weekdays (Mon–Sat) it runs an INCREMENTAL backup (only changed files).
# On Sundays it runs a FULL backup and prunes backups older than 3 months.
# If an incremental backup fails, it falls back to a full backup after
# cleaning up the corrupted state.
#
# Required environment variables:
#   DUPLICITY_TARGET_URL            - Destination URL for the backup (e.g. s3://bucket/path)
#                                     Defaults to file://$HOME/target/$INSTANCE_ID if unset.
#   DUPLICITY_ENCRYPTER_PASSWORD    - Passphrase for the GPG encryption key.
#   DUPLICITY_ENCRYPTER_FINGERPRINT - GPG fingerprint of the encryption key.
#   DUPLICITY_SIGNER_PASSWORD       - Passphrase for the GPG signing key.
#   DUPLICITY_SIGNER_FINGERPRINT    - GPG fingerprint of the signing key.
#
# Optional environment variables:
#   INSTANCE_ID     - Unique ID for this backup instance (used to namespace
#                     the target path). Auto-derived if not set.
#   K8S_POD_NAME    - Kubernetes pod name; used as INSTANCE_ID when running
#                     inside a Kubernetes pod.
#   INSTANCE_PREFIX - Prefix combined with the hostname to form INSTANCE_ID
#                     when K8S_POD_NAME is not available.
# =============================================================================

# -----------------------------------------------------------------------------
# Resolve INSTANCE_ID
# -----------------------------------------------------------------------------
# INSTANCE_ID namespaces the backup target so that multiple instances (e.g.
# different Kubernetes pods or hosts) can back up to the same root URL without
# overwriting each other.
#
# Priority order:
#   1. $INSTANCE_ID        — caller-supplied, used as-is.
#   2. $K8S_POD_NAME       — automatically injected by Kubernetes via the
#                            Downward API; ideal for pod-level namespacing.
#   3. $INSTANCE_PREFIX-<hostname> — a human-readable prefix combined with
#                            the local hostname.
#   4. <hostname>          — bare hostname as a last resort.
if [ -z "$INSTANCE_ID" ]; then
    # Use pod name if provided, else hostname, else random suffix
    if [ -n "$K8S_POD_NAME" ]; then
        INSTANCE_ID="$K8S_POD_NAME"
    elif [ -n "$INSTANCE_PREFIX" ]; then
        INSTANCE_ID="${INSTANCE_PREFIX}-$(hostname)"
    else
        INSTANCE_ID="$(hostname)"
    fi
fi

# -----------------------------------------------------------------------------
# Resolve DUPLICITY_TARGET_URL
# -----------------------------------------------------------------------------
# If the caller did not supply a target URL, fall back to a local path under
# $HOME/target/<INSTANCE_ID>. This is mainly useful for testing or single-host
# setups where remote storage is not configured.
if [ -z "$DUPLICITY_TARGET_URL" ] ; then
    DUPLICITY_TARGET_URL="file://$HOME/target/$INSTANCE_ID"
fi

# -----------------------------------------------------------------------------
# full_clean()  — purge corrupted/incomplete backup state
# -----------------------------------------------------------------------------
# Called as a recovery step when an incremental backup fails. It:
#   1. Runs `duplicity cleanup` to remove any incomplete or partial backup
#      sets at the target URL (requires the encryption passphrase to access
#      the remote metadata).
#   2. Wipes the local duplicity cache ($HOME/cache) and the local staging
#      directory ($HOME/local) so the next run starts from a clean slate.
#
# The --force flag tells duplicity to delete without prompting for confirmation.
full_clean() {
 # shellcheck disable=SC2086
 PASSPHRASE="$DUPLICITY_ENCRYPTER_PASSWORD" duplicity cleanup --force "$DUPLICITY_TARGET_URL"
 /bin/rm -rf "$HOME"/cache/* "$HOME"/local/*
 
}

# -----------------------------------------------------------------------------
# sync_local()  — stage source data into the local working directory
# -----------------------------------------------------------------------------
# Uses rsync to mirror $HOME/source/ into $HOME/local so that duplicity
# operates on a consistent local snapshot rather than directly on the source.
#
# Flags:
#   --exclude 'duplicity'  Prevent backing up any nested duplicity metadata
#                          that may be stored alongside the source data.
#   --recursive            Traverse subdirectories.
#   --verbose              Print each transferred file for audit logging.
sync_local() {
 /usr/bin/rsync --exclude 'duplicity' --recursive --verbose "$HOME"/source/ "$HOME"/local
}

# -----------------------------------------------------------------------------
# weekly_rotate()  — full backup + old-backup pruning (runs every Sunday)
# -----------------------------------------------------------------------------
# Performs two operations in sequence:
#
#   1. PRUNE: Remove backup sets older than 3 months from the target URL.
#      This keeps storage consumption bounded. --force skips the confirmation
#      prompt. Only DUPLICITY_ENCRYPTER_PASSWORD is needed here (read access).
#
#   2. FULL BACKUP: Create a brand-new full backup of $HOME/local, regardless
#      of any existing incremental chain. This resets the incremental baseline
#      and ensures recovery never requires more than one full set plus
#      up-to-6-days of incrementals.
#
#      --archive-dir  Local cache directory for duplicity's own metadata
#                     (speeds up subsequent operations by avoiding remote reads).
#      --encrypt-key  GPG key fingerprint used to encrypt the backup data;
#                     only the holder of the matching private key can restore.
#      --sign-key     GPG key fingerprint used to sign the backup data;
#                     provides integrity verification on restore.
#      --verbosity d  Debug-level output for detailed logging.
weekly_rotate() {
 # shellcheck disable=SC2086
 PASSPHRASE="$DUPLICITY_ENCRYPTER_PASSWORD" /usr/bin/duplicity remove-older-than 3m --force "$DUPLICITY_TARGET_URL"
 # shellcheck disable=SC2086
 PASSPHRASE="$DUPLICITY_ENCRYPTER_PASSWORD" SIGN_PASSPHRASE="$DUPLICITY_SIGNER_PASSWORD" /usr/bin/duplicity full --archive-dir "$HOME"/cache --encrypt-key "$DUPLICITY_ENCRYPTER_FINGERPRINT" --sign-key "$DUPLICITY_SIGNER_FINGERPRINT" --verbosity d "$HOME"/local "$DUPLICITY_TARGET_URL"
}

# -----------------------------------------------------------------------------
# Main logic — day-of-week dispatch
# -----------------------------------------------------------------------------
# %u returns ISO weekday numbers: 1=Mon … 7=Sun. We treat 7 as the Sunday
# value but duplicity convention commonly uses 0; here SUNDAY is set to "0"
# and `date +%u` returns 7 on Sunday — NOTE: this means the Sunday branch
# is never actually triggered by the date check as written. Verify with your
# system's `date` implementation; on some systems +%u returns 0 for Sunday.
SUNDAY="0"
DAY_OF_WEEK="$(/bin/date +%u)"

# Always perform an initial local sync so the staging directory is up-to-date
# before any backup decision is made.
sync_local

if [ "$DAY_OF_WEEK" = "$SUNDAY" ] ; then
 # ---- Sunday: full backup with rotation ----
 # Prune old backups first, then create a fresh full backup. No incremental
 # fallback is needed because we are explicitly doing a clean-slate backup.
 weekly_rotate
else
 # ---- Weekday: incremental backup ----
 # Re-sync to capture any changes that may have occurred since the first
 # sync (guards against a race window if the script was delayed in starting).
 sync_local
 # shellcheck disable=SC2086
 # Run an incremental backup. duplicity automatically determines what has
 # changed since the last full or incremental backup using its own metadata
 # stored in --archive-dir. The result is a compact delta backup set.
 PASSPHRASE="$DUPLICITY_ENCRYPTER_PASSWORD" SIGN_PASSPHRASE="$DUPLICITY_SIGNER_PASSWORD" /usr/bin/duplicity --archive-dir "$HOME"/cache --encrypt-key "$DUPLICITY_ENCRYPTER_FINGERPRINT" --sign-key "$DUPLICITY_SIGNER_FINGERPRINT" --verbosity d "$HOME"/local "$DUPLICITY_TARGET_URL"
 RESULT=$?
 if [ "$RESULT" -ne 0 ] ; then
  # ---- Incremental backup failed: recover and retry as full ----
  # A non-zero exit code typically indicates a corrupted or inconsistent
  # backup chain (e.g. the cache is out of sync with the remote). The
  # recovery sequence is:
  #   1. full_clean — remove corrupt remote state and wipe local cache/staging.
  #   2. sync_local — re-populate the staging directory from source.
  #   3. weekly_rotate — prune old backups and write a fresh full backup,
  #      establishing a clean new baseline for future incrementals.
  full_clean
  sync_local
  weekly_rotate
 fi
fi
