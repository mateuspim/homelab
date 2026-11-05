#!/usr/bin/env bash
# indexers.sh — public indexers, Prowlarr's own download client, and app sync routing on CT 220.
# Run after wire.sh, on CT 220 as pym: bash /opt/stacks/arr/indexers.sh   (needs curl + jq)
# Safe to re-run: existing indexers are updated in place (priority/tags), new ones are added only if their test passes.
set -euo pipefail
key() { grep -oP '(?<=<ApiKey>)[^<]+' "/opt/appdata/$1/config.xml"; }
declare -A PORT=([sonarr]=8989 [radarr]=7878 [lidarr]=8686 [prowlarr]=9696)
declare -A VER=([sonarr]=v3 [radarr]=v3 [lidarr]=v1 [prowlarr]=v1)
api() { # api <app> <GET|POST|PUT> <path> [json]
  local a=$1 m=$2 p=$3
  curl -fsS -X "$m" -H "X-Api-Key: $(key "$a")" -H 'Content-Type: application/json' \
    "http://localhost:${PORT[$a]}/api/${VER[$a]}$p" ${4:+--data "$4"}
}
try() { # try <app> <path> <json>: POST without -f, prints the error text on failure
  local out code
  out=$(curl -sS -o - -w '\n%{http_code}' -X POST -H "X-Api-Key: $(key "$1")" -H 'Content-Type: application/json' \
    "http://localhost:${PORT[$1]}/api/${VER[$1]}$2" --data "$3")
  code=${out##*$'\n'}; out=${out%$'\n'*}
  [[ $code == 2* ]] && return 0
  jq -r 'if type == "array" then map(.errorMessage) | join("; ") else (.message // .) end' <<<"$out" 2>/dev/null | head -c 300 || echo "$out" | head -c 300
  return 1
}
ok() { printf '  ok   %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; }

tagid() { # tagid <label>: id of a Prowlarr tag, created if missing
  local id; id=$(api prowlarr GET /tag | jq --arg l "$1" 'first(.[] | select(.label == $l)) | .id // empty')
  [ -n "$id" ] || id=$(api prowlarr POST /tag "{\"label\":\"$1\"}" | jq .id)
  echo "$id"
}

echo "== prowlarr app routing"
# An app with tags only receives indexers that share one of them, so anime/music-less indexers stay out of Lidarr etc.
declare -A APPTAG=([Sonarr]=tv [Radarr]=movies [Lidarr]=music)
for app in Sonarr Radarr Lidarr; do
  t=$(tagid "${APPTAG[$app]}")
  body=$(api prowlarr GET /applications | jq --arg n "$app" --argjson t "$t" 'first(.[] | select(.name == $n)) | .tags = [$t]')
  [ "$body" = null ] && { bad "prowlarr app $app missing: run wire.sh first"; exit 1; }
  api prowlarr PUT "/applications/$(jq .id <<<"$body")" "$body" >/dev/null
  ok "$app syncs indexers tagged ${APPTAG[$app]} ($(jq -c '[.fields[] | select(.name | test("SyncCategories|syncCategories")) | .value] | add' <<<"$body"))"
done

echo "== indexers"
# Trusted, moderated public sources only (user's call): no open-upload sites (TPB, LimeTorrents, KAT clones,
# TorrentDownloads) and no meta-aggregators that mirror them (Knaben, uindex). No Brazilian tracker in Prowlarr is
# public (all private/semi-private).
# 1337x: added back on the user's call (2026-11-01: Internet Archive alone finds almost no real movie releases).
# It can't be limited to VIP/trusted uploaders, so it relies on the recyclarr filters (No-RlsGroup/Obfuscated/Retags/LQ
# at -10000), qBit excluded_file_names (executables) and a 5-seeder minimum against fresh fakes.
# definition | priority (lower wins) | apps it syncs to. Cloudflare sites (definition has an info_flaresolverr note) get tag flaresolverr.
LIST="
nyaasi|10|tv,movies
SubsPlease|15|tv
eztv|20|tv
1337x|25|tv,movies,music
"
# YTS is out too: TRaSH lists YTS/YIFY as LQ, and the radarr profile scores LQ -10000, so every result would be rejected.
DROP="internetarchive yts thepiratebay limetorrents torrentdownloads Knaben uindex kickasstorrents-to kickasstorrents-ws TorrentsCSV"
# Per-definition settings: Nyaa trusted uploads only, anime category only, Sonarr-style season tags.
# Internet Archive removed: poor release coverage and trailer-only movie matches.
declare -A SET=([nyaasi]='{"filter-id":2,"cat-id":1,"sonarr_compatibility":true}'
                [1337x]='{"torrentBaseSettings.appMinimumSeeders":5}')
schema=$(api prowlarr GET /indexer/schema)
existing=$(api prowlarr GET /indexer)
cf=$(tagid flaresolverr)
for def in $DROP; do # removed sources: the next app sync removes them from sonarr/radarr/lidarr
  for id in $(jq --arg d "$def" '.[] | select(.definitionName == $d) | .id' <<<"$existing"); do
    api prowlarr DELETE "/indexer/$id" >/dev/null; ok "$def removed (excluded source)"
  done
done
while IFS='|' read -r def prio apps; do
  [ -n "$def" ] || continue
  tags=$(for a in ${apps//,/ }; do tagid "$a"; done | jq -s .)
  base=$(jq --arg d "$def" 'first(.[] | select(.definitionName == $d and .privacy == "public"))' <<<"$schema")
  [ "$base" = null ] && { bad "$def: no public definition in this Prowlarr"; continue; }
  if jq -e 'any(.fields[]; .name == "info_flaresolverr")' <<<"$base" >/dev/null; then tags=$(jq --argjson c "$cf" '. + [$c]' <<<"$tags"); fi
  cur=$(jq --arg d "$def" 'first(.[] | select(.definitionName == $d)) // empty' <<<"$existing")
  if [ -n "$cur" ]; then
    body=$(jq --argjson p "$prio" --argjson t "$tags" --argjson s "${SET[$def]:-{\}}" '.priority = $p | .tags = $t | .enable = true
      | .fields |= map(.name as $n | if $s | has($n) then .value = $s[$n] else . end)' <<<"$cur")
    api prowlarr PUT "/indexer/$(jq .id <<<"$cur")?forceSave=true" "$body" >/dev/null
    if err=$(try prowlarr /indexer/test "$body"); then ok "$def (prio $prio, tags $apps$(jq -e --argjson c "$cf" 'index($c)' <<<"$tags" >/dev/null && echo ,flaresolverr)) exists, test passed"
    else bad "$def exists but test failed now: $err (kept; rerun later)"; fi
    continue
  fi
  body=$(jq --argjson p "$prio" --argjson t "$tags" --argjson s "${SET[$def]:-{\}}" '
    .name = (.name // .definitionName) | .enable = true | .priority = $p | .tags = $t | .appProfileId = 1
    | .indexerUrls[0] as $u
    | .fields |= map(.name as $n | if $n == "baseUrl" then .value = $u elif $s | has($n) then .value = $s[$n] else . end)' <<<"$base")
  if err=$(try prowlarr /indexer/test "$body"); then
    if ! err=$(try prowlarr /indexer "$body"); then bad "$def test passed but save failed: $err"; continue; fi
    ok "$def added (prio $prio, tags $apps$(jq -e --argjson c "$cf" 'index($c)' <<<"$tags" >/dev/null && echo ,flaresolverr)), test passed"
  else
    bad "$def skipped: $err"
  fi
done <<<"$LIST"

echo "== prowlarr download client"
# Manual grabs from Prowlarr search. Same netns as qBit, so localhost; blank creds (auth bypass). Mapped to the arr categories,
# anything else lands in category "prowlarr" (-> /data/torrents/prowlarr, nothing imports it).
qb() { docker exec qbittorrent curl -fsS "http://localhost:8080/api/v2/$1" "${@:2}"; }
qb torrents/categories | jq -e 'has("prowlarr")' >/dev/null || \
  qb torrents/createCategory --data-urlencode category=prowlarr --data-urlencode savePath=/data/torrents/prowlarr
cats='[{"clientCategory":"movies","categories":[2000]},{"clientCategory":"tv","categories":[5000]},
       {"clientCategory":"anime","categories":[5070]},{"clientCategory":"music","categories":[3000]},
       {"clientCategory":"books","categories":[7000]},{"clientCategory":"comics","categories":[7030]}]'
cur=$(api prowlarr GET /downloadclient | jq 'first(.[] | select(.name == "qBittorrent")) // empty')
if [ -z "$cur" ]; then
  body=$(api prowlarr GET /downloadclient/schema | jq --argjson c "$cats" '
    first(.[] | select(.implementation == "QBittorrent")) | .name = "qBittorrent" | .enable = true | .categories = $c
    | .fields |= map(if .name == "host" then .value = "localhost" elif .name == "port" then .value = 8080
                     elif .name == "category" then .value = "prowlarr" else . end)')
  api prowlarr POST /downloadclient "$body" >/dev/null
fi
body=$(api prowlarr GET /downloadclient | jq 'first(.[] | select(.name == "qBittorrent"))')
if err=$(try prowlarr /downloadclient/test "$body"); then ok "prowlarr -> qBittorrent (localhost:8080, mapped categories, fallback prowlarr), test passed"
else bad "prowlarr -> qBittorrent test: $err"; fi

echo "== sync to apps"
cmd=$(api prowlarr POST /command '{"name":"ApplicationIndexerSync"}' | jq .id)
for _ in $(seq 60); do
  st=$(api prowlarr GET "/command/$cmd" | jq -r .status)
  [[ $st == completed || $st == failed ]] && break; sleep 2
done
ok "ApplicationIndexerSync: $st"
for app in sonarr radarr lidarr; do
  names=$(api "$app" GET /indexer | jq -r '[.[].name] | sort | join(", ")')
  fails=0
  while read -r id; do
    body=$(api "$app" GET "/indexer/$id")
    err=$(try "$app" /indexer/test "$body") || { fails=$((fails + 1)); bad "$app $(jq -r .name <<<"$body"): $err"; }
  done < <(api "$app" GET /indexer | jq '.[].id')
  ok "$app has: $names ($fails test failures)"
done
