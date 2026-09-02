#!/bin/sh
# Nightly Postgres dump. Install on the host with:
#   crontab -e  ->  15 3 * * * /opt/cal/deploy/hetzner/backup.sh >> /opt/cal/backups/backup.log 2>&1
set -eu
cd "$(dirname "$0")"
. ./.env
mkdir -p ../../backups
FILE="../../backups/cal-$(date -u +%F).sql.gz"
docker compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" | gzip > "$FILE"
find ../../backups -name 'cal-*.sql.gz' -mtime +14 -delete
echo "$(date -u +%FT%TZ) wrote $FILE"
