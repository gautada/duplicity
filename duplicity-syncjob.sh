#!/bin/sh

# This script synchronizes the source to target directories 
# to provide a copy for the duplicity script to run to encrypt the backup 
# and push to the backup to destination and offsite.

USER="$(awk -F':' -v uid=1001 '${3} == uid { print "${1}" }' /etc/passwd)"
/bin/su "${USER}" -c "/usr/bin/duplicity-backup"
