#!/bin/sh
set -eu

if [ -f /run/backup.env ]; then
  . /run/backup.env
fi

if [ -z "${BACKUP_S3_BUCKET:-}" ]; then
  echo "[restore] ERROR: BACKUP_S3_BUCKET is not set." >&2
  exit 1
fi

if [ -z "${BACKUP_S3_ACCESS_KEY_ID:-}" ] || [ -z "${BACKUP_S3_SECRET_ACCESS_KEY:-}" ]; then
  echo "[restore] ERROR: BACKUP_S3_ACCESS_KEY_ID or BACKUP_S3_SECRET_ACCESS_KEY is missing." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$BACKUP_S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BACKUP_S3_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${BACKUP_S3_REGION:-us-east-1}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

PREFIX="${BACKUP_S3_PREFIX:-basecamp-backups}"
PREFIX="${PREFIX#/}"
PREFIX="${PREFIX%/}"
TARGET="${1:-latest}"

aws_s3() {
  if [ -n "${BACKUP_S3_ENDPOINT:-}" ]; then
    aws --endpoint-url "$BACKUP_S3_ENDPOINT" "$@"
  else
    aws "$@"
  fi
}

if [ "$TARGET" = "latest" ]; then
  TARGET="$(
    aws_s3 s3api list-objects-v2 \
      --bucket "$BACKUP_S3_BUCKET" \
      --prefix "${PREFIX}/postgres/" \
      --output json | \
    python3 -c '
import json, sys
items = json.load(sys.stdin).get("Contents", [])
items = [o for o in items if o["Key"].endswith(".dump")]
if not items:
    sys.exit(1)
latest = max(items, key=lambda o: o["LastModified"])
print(latest["Key"])
'
  )"
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

DUMP_FILE="${TMP_DIR}/restore.dump"
echo "[restore] Downloading s3://${BACKUP_S3_BUCKET}/${TARGET}..."
aws_s3 s3 cp "s3://${BACKUP_S3_BUCKET}/${TARGET}" "$DUMP_FILE" --only-show-errors

echo "[restore] Ensuring PostGIS extension and restoring ${POSTGRES_DB:-payload}..."
psql -h postgres -U "${POSTGRES_USER:-payload}" -d "${POSTGRES_DB:-payload}" -c "CREATE EXTENSION IF NOT EXISTS postgis;"
pg_restore --clean --if-exists --no-owner --no-privileges -h postgres -U "${POSTGRES_USER:-payload}" -d "${POSTGRES_DB:-payload}" "$DUMP_FILE"

echo "[restore] Database restore complete."
