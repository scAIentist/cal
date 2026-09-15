#!/bin/sh
# Calls Cal.diy's cron endpoints on a schedule (replaces Vercel Cron).
# Needs CRON_SECRET and CRON_API_KEY from .env and CAL_INTERNAL_URL.
set -u
BASE="${CAL_INTERNAL_URL:-http://calcom:3000}"
AUTH="Authorization: Bearer ${CRON_SECRET}"

hit() {
  curl -fsS -m 120 -o /dev/null -H "$AUTH" "$BASE$1?apiKey=${CRON_API_KEY}" \
    || echo "$(date -u +%FT%TZ) cron $1 failed"
}

tick=0
echo "cron sidecar started against $BASE"
while true; do
  hit /api/tasks/cron                              # every minute: reminders, queued jobs
  if [ $((tick % 5)) -eq 0 ]; then                 # every 5 minutes
    hit /api/cron/calendar-subscriptions
    hit /api/cron/credentials
    hit /api/cron/selected-calendars
  fi
  if [ $((tick % 1440)) -eq 0 ]; then              # daily
    hit /api/tasks/cleanup
    hit /api/cron/calendar-subscriptions-cleanup
    hit /api/cron/queuedFormResponseCleanup
  fi
  tick=$((tick + 1))
  sleep 60
done
