#!/bin/sh
# Nightly Postgres dump for Cal. Install on the Swarm manager:  crontab -e
#   15 3 * * * /opt/stacks/cal/backup.sh >> /opt/backups/cal/backup.log 2>&1
set -eu
OUT=/opt/backups/cal
mkdir -p "$OUT"
DATE=$(date -u +%F)
DB=$(docker ps -q -f name=cal_db | head -1)
[ -n "$DB" ] || { echo "cal db container not running"; exit 1; }
docker exec "$DB" sh -c 'pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB"' | gzip > "$OUT/cal-$DATE.sql.gz"
chmod 600 "$OUT/cal-$DATE.sql.gz"
find "$OUT" -name 'cal-*.sql.gz' -mtime +14 -delete
echo "$(date -u +%FT%TZ) backup written to $OUT/cal-$DATE.sql.gz"
