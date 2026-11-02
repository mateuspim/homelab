#!/usr/bin/env bash
# install.sh — first-time Nextcloud install via occ, then base config. Safe to re-run (install step is skipped).
# Run on CT 225 as pym from /opt/stacks/nextcloud: bash install.sh [admin-user]
# The admin password is random and never shown; set your own afterwards:
#   docker exec -it nextcloud occ user:resetpassword <admin-user>
set -euo pipefail
cd "$(dirname "$0")"
ADMIN=${1:-pym}
occ() { docker exec nextcloud occ "$@"; }
# The linuxserver occ wrapper eats one level of backslashes, so class names are written with \\.

# Wait for the linuxserver init (it unpacks Nextcloud into /app/www/public on first start).
for i in $(seq 100); do docker logs nextcloud 2>&1 | grep -q 'ls.io-init\] done' && break; sleep 3; done

if occ status --output=json | jq -e '.installed' >/dev/null; then
  echo "already installed"
else
  set -a; . ./.env; set +a
  occ maintenance:install --database pgsql --database-host nextcloud-db --database-name nextcloud \
    --database-user nextcloud --database-pass "$DB_PASSWORD" \
    --admin-user "$ADMIN" --admin-pass "$(openssl rand -base64 33)" --data-dir /data
fi

occ config:system:set trusted_domains 1 --value=192.168.50.225
occ config:system:set default_phone_region --value=BR
occ config:system:set maintenance_window_start --type=integer --value=6   # 06:00 UTC = 03:00 BRT
occ config:system:set memcache.local --value='\\OC\\Memcache\\APCu'
occ config:system:set memcache.distributed --value='\\OC\\Memcache\\Redis'
occ config:system:set memcache.locking --value='\\OC\\Memcache\\Redis'
occ config:system:set redis host --value=nextcloud-redis
occ config:system:set redis port --type=integer --value=6379
occ background:cron
occ maintenance:repair --include-expensive >/dev/null
occ db:add-missing-indices >/dev/null
occ status
