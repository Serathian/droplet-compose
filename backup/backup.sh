#!/bin/sh
set -eu

if [ -f /run/backup.env ]; then
  . /run/backup.env
fi

if [ -z "${BACKUP_S3_BUCKET:-}" ]; then
  echo "[backup] BACKUP_S3_BUCKET is not set; skipping backup."
  exit 0
fi

if [ -z "${BACKUP_S3_ACCESS_KEY_ID:-}" ] || [ -z "${BACKUP_S3_SECRET_ACCESS_KEY:-}" ]; then
  echo "[backup] ERROR: BACKUP_S3_ACCESS_KEY_ID or BACKUP_S3_SECRET_ACCESS_KEY is missing." >&2
  exit 1
fi

export AWS_ACCESS_KEY_ID="$BACKUP_S3_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$BACKUP_S3_SECRET_ACCESS_KEY"
export AWS_DEFAULT_REGION="${BACKUP_S3_REGION:-us-east-1}"
export PGPASSWORD="${POSTGRES_PASSWORD:-}"

TIMESTAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
PREFIX="${BACKUP_S3_PREFIX:-basecamp-backups}"
PREFIX="${PREFIX#/}"
PREFIX="${PREFIX%/}"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

aws_s3() {
  if [ -n "${BACKUP_S3_ENDPOINT:-}" ]; then
    aws --endpoint-url "$BACKUP_S3_ENDPOINT" "$@"
  else
    aws "$@"
  fi
}

upload_file() {
  src="$1"
  dest="$2"
  if [ -n "${BACKUP_S3_STORAGE_CLASS:-}" ]; then
    aws_s3 s3 cp "$src" "$dest" --storage-class "$BACKUP_S3_STORAGE_CLASS" --only-show-errors
  else
    aws_s3 s3 cp "$src" "$dest" --only-show-errors
  fi
}

echo "[backup] Waiting for postgres..."
pg_isready -h postgres -U "${POSTGRES_USER:-payload}" -d "${POSTGRES_DB:-payload}" >/dev/null

DB_DUMP_PATH="${TMP_DIR}/basecamp-${TIMESTAMP}.dump"
echo "[backup] Dumping database ${POSTGRES_DB:-payload}..."
pg_dump -h postgres -U "${POSTGRES_USER:-payload}" -d "${POSTGRES_DB:-payload}" -Fc -f "$DB_DUMP_PATH"

if [ ! -s "$DB_DUMP_PATH" ]; then
  echo "[backup] ERROR: Generated database dump is empty." >&2
  exit 1
fi

DB_DEST="s3://${BACKUP_S3_BUCKET}/${PREFIX}/postgres/basecamp-${TIMESTAMP}.dump"
upload_file "$DB_DUMP_PATH" "$DB_DEST"
echo "[backup] Uploaded database dump to ${DB_DEST}"

if [ -s /traefik/acme.json ]; then
  ACME_PATH="${TMP_DIR}/acme-${TIMESTAMP}.json.gz"
  gzip -c /traefik/acme.json > "$ACME_PATH"
  ACME_DEST="s3://${BACKUP_S3_BUCKET}/${PREFIX}/traefik/acme-${TIMESTAMP}.json.gz"
  upload_file "$ACME_PATH" "$ACME_DEST"
  echo "[backup] Uploaded Traefik ACME backup to ${ACME_DEST}"
fi

RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
if [ "$RETENTION_DAYS" -gt 0 ] 2>/dev/null; then
  for subprefix in "${PREFIX}/postgres/" "${PREFIX}/traefik/"; do
    EXPIRED_KEYS="$(
      aws_s3 s3api list-objects-v2 \
        --bucket "$BACKUP_S3_BUCKET" \
        --prefix "$subprefix" \
        --output json | \
      python3 -c '
import datetime, json, sys
days = int(sys.argv[1])
cutoff = datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(days=days)
data = json.load(sys.stdin)
for obj in data.get("Contents", []):
    lm = datetime.datetime.fromisoformat(obj["LastModified"].replace("Z", "+00:00"))
    if lm < cutoff:
        print(obj["Key"])
' "$RETENTION_DAYS"
    )"
    if [ -n "$EXPIRED_KEYS" ]; then
      printf '%s\n' "$EXPIRED_KEYS" | while IFS= read -r key; do
        [ -n "$key" ] && aws_s3 s3 rm "s3://${BACKUP_S3_BUCKET}/${key}" --only-show-errors && echo "[backup] Pruned expired backup ${key}"
      done
    fi
  done
fi

echo "[backup] Backup complete at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
