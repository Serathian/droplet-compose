#!/bin/sh
set -eu

SCHEDULE="${BACKUP_SCHEDULE:-0 3 * * *}"

umask 077
export -p > /run/backup.env
echo "${SCHEDULE} /usr/local/bin/backup.sh >> /proc/1/fd/1 2>> /proc/1/fd/2" > /etc/crontabs/root

echo "[backup] Scheduler active (schedule: ${SCHEDULE})"
exec crond -f -l 2
