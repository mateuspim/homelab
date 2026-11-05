#!/usr/bin/env bash
# Apply download-first queue settings to the current public-tracker setup.
# Private trackers need their own ratio/seeding-time overrides before use.
set -euo pipefail
qb() { docker exec qbittorrent curl -fsS "http://localhost:8080/api/v2/$1" "${@:2}"; }
settings='{"queueing_enabled":true,"max_active_downloads":20,"max_active_uploads":3,"max_active_torrents":23,"dont_count_slow_torrents":true,"slow_torrent_dl_rate_threshold":10,"slow_torrent_ul_rate_threshold":10,"slow_torrent_inactive_timer":120,"dl_limit":0,"scheduler_enabled":false,"max_ratio":1,"max_seeding_time":1440,"max_inactive_seeding_time":-1,"share_limits_mode":"MatchAny","max_ratio_act":0}'
# Store only the preferences being changed; never back up auth credentials here.
backup_dir=/opt/appdata/qbittorrent/tuning-backups
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"
umask 077
qb app/preferences | jq --argjson s "$settings" 'with_entries(select(.key as $k | $s | has($k)))' > "$backup_dir/$(date +%Y%m%dT%H%M%S%N).json"
qb app/setPreferences --data-urlencode "json=$settings"
if [[ $(qb transfer/speedLimitsMode) == 1 ]]; then
  qb transfer/toggleSpeedLimitsMode -X POST
fi
qb app/preferences | jq -e --argjson s "$settings" '. as $p | all($s | to_entries[]; $p[.key] == .value)' >/dev/null
echo 'qBittorrent: 20 downloads, 3 seeds, slow torrents skip queue limits; seed to ratio 1 or 24h, then stop.'
