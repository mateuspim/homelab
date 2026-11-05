#!/usr/bin/env bash
# wire.sh — connect the arr stack on CT 220 through each app's API. Safe to re-run: skips what exists.
# Run on CT 220 as pym: bash /opt/stacks/arr/wire.sh   (needs curl + jq)
# Indexers, Prowlarr's own download client and app sync routing live in indexers.sh (run it after this).
set -euo pipefail
LAN=192.168.50.220
key() { grep -oP '(?<=<ApiKey>)[^<]+' "/opt/appdata/$1/config.xml"; }
declare -A PORT=([sonarr]=8989 [radarr]=7878 [lidarr]=8686 [prowlarr]=9696)
declare -A VER=([sonarr]=v3 [radarr]=v3 [lidarr]=v1 [prowlarr]=v1)
api() { # api <app> <GET|POST> <path> [json]
  local a=$1 m=$2 p=$3
  curl -fsS -X "$m" -H "X-Api-Key: $(key "$a")" -H 'Content-Type: application/json' \
    "http://localhost:${PORT[$a]}/api/${VER[$a]}$p" ${4:+--data "$4"}
}
has() { api "$1" GET "$2" | jq -e --arg v "$4" "any(.[]; .$3 == \$v)" >/dev/null; } # has <app> <path> <field> <value>
ok() { printf '  ok   %s\n' "$*"; }

echo "== qbittorrent"
qb() { docker exec qbittorrent curl -fsS "http://localhost:8080/api/v2/$1" "${@:2}"; }
qb app/setPreferences --data-urlencode 'json={"bypass_auth_subnet_whitelist_enabled":true,"bypass_auth_subnet_whitelist":"172.18.0.0/16","auto_tmm_enabled":true,"save_path":"/data/torrents","temp_path_enabled":false}'
ok "auth bypass for 172.18.0.0/16, automatic torrent management, save path /data/torrents"
# Never download executables/scripts inside torrents (malware). Archives (.zip/.rar/.7z) stay allowed for legit releases.
excl='*.exe *.scr *.com *.bat *.cmd *.msi *.lnk *.vbs *.vbe *.js *.jse *.wsf *.wsh *.ps1 *.pif *.cpl *.jar *.apk *.dll *.iso.exe *.zipx *.arj *.lzh *.ace'
qb app/setPreferences --data-urlencode "json=$(jq -nc --arg l "${excl// /$'\n'}" '{excluded_file_names_enabled:true, excluded_file_names:$l}')"
ok "excluded file names: executables/scripts never downloaded"
bash "$(dirname "${BASH_SOURCE[0]}")/qbit-tune.sh"
cats=$(qb torrents/categories)
for c in movies tv anime music books comics; do
  ep=createCategory; jq -e --arg c "$c" 'has($c)' <<<"$cats" >/dev/null && ep=editCategory
  qb "torrents/$ep" --data-urlencode "category=$c" --data-urlencode "savePath=/data/torrents/$c"
  ok "category $c -> /data/torrents/$c"
done

echo "== root folders"
for rf in "sonarr /data/media/tv" "sonarr /data/media/anime" "radarr /data/media/movies"; do
  set -- $rf
  has "$1" /rootfolder path "$2" || api "$1" POST /rootfolder "{\"path\":\"$2\"}" >/dev/null
  ok "$1 $2"
done
if ! has lidarr /rootfolder path /data/media/music; then
  qp=$(api lidarr GET /qualityprofile | jq '.[0].id'); mp=$(api lidarr GET /metadataprofile | jq '.[0].id')
  api lidarr POST /rootfolder "{\"name\":\"Music\",\"path\":\"/data/media/music\",\"defaultQualityProfileId\":$qp,\"defaultMetadataProfileId\":$mp}" >/dev/null
fi
ok "lidarr /data/media/music"

echo "== download clients"
# Blank username/password: qBit bypasses auth for this Docker network.
for dc in "sonarr tvCategory tv" "radarr movieCategory movies" "lidarr musicCategory music"; do
  set -- $dc
  if ! has "$1" /downloadclient name qBittorrent; then
    body=$(api "$1" GET /downloadclient/schema | jq --arg f "$2" --arg c "$3" '
      first(.[] | select(.implementation == "QBittorrent")) | .name = "qBittorrent" | .enable = true
      | .fields |= map(if .name == "host" then .value = "gluetun" elif .name == "port" then .value = 8080
                       elif .name == $f then .value = $c else . end)')
    api "$1" POST /downloadclient "$body" >/dev/null
  fi
  ok "$1 -> qBittorrent (gluetun:8080, category $3)"
done

echo "== prowlarr"
if ! api prowlarr GET /tag | jq -e 'any(.[]; .label == "flaresolverr")' >/dev/null; then
  api prowlarr POST /tag '{"label":"flaresolverr"}' >/dev/null
fi
tag=$(api prowlarr GET /tag | jq 'first(.[] | select(.label == "flaresolverr")) | .id')
if ! has prowlarr /indexerproxy name FlareSolverr; then
  body=$(api prowlarr GET /indexerproxy/schema | jq --argjson t "$tag" '
    first(.[] | select(.implementation == "FlareSolverr")) | .name = "FlareSolverr" | .tags = [$t]
    | .fields |= map(if .name == "host" then .value = "http://localhost:8191/" else . end)')
  api prowlarr POST /indexerproxy "$body" >/dev/null
fi
ok "FlareSolverr proxy (tag flaresolverr = use it on Cloudflare-protected indexers)"
for app in sonarr radarr lidarr; do
  impl=${app^}
  if ! has prowlarr /applications name "$impl"; then
    body=$(api prowlarr GET /applications/schema | jq --arg i "$impl" --arg u "http://$LAN:${PORT[$app]}" --arg k "$(key "$app")" '
      first(.[] | select(.implementation == $i)) | .name = $i | .syncLevel = "fullSync"
      | .fields |= map(if .name == "prowlarrUrl" then .value = "http://gluetun:9696"
                       elif .name == "baseUrl" then .value = $u elif .name == "apiKey" then .value = $k else . end)')
    api prowlarr POST /applications "$body" >/dev/null
  fi
  ok "prowlarr -> $app (full sync)"
done

echo "== bazarr"
# Same form POST the Bazarr UI uses. Sonarr/Radarr are reached by container name on the compose network.
bkey=$(sed -n '/^auth:/,/^[a-z]/s/^  apikey: //p' /opt/appdata/bazarr/config/config.yaml)
curl -fsS -o /dev/null -X POST -H "X-API-KEY: $bkey" http://localhost:6767/api/system/settings \
  --data-urlencode settings-general-use_sonarr=true --data-urlencode settings-general-use_radarr=true \
  --data-urlencode settings-sonarr-ip=sonarr --data-urlencode settings-sonarr-port=8989 \
  --data-urlencode "settings-sonarr-apikey=$(key sonarr)" \
  --data-urlencode settings-radarr-ip=radarr --data-urlencode settings-radarr-port=7878 \
  --data-urlencode "settings-radarr-apikey=$(key radarr)"
ok "bazarr -> sonarr:8989, radarr:7878"
# Subtitles: one profile pt-BR then English, default for new series/movies; only providers that need no account.
# (opensubtitlescom needs the user's own login: add it in the UI.)
it() { printf '{"id":%s,"language":"%s","audio_exclude":"False","audio_only_include":"False","hi":"False","forced":"False"}' "$1" "$2"; }
prof="[{\"profileId\":1,\"name\":\"pt-BR + English\",\"items\":[$(it 1 pb),$(it 2 en)],\"cutoff\":null,\"mustContain\":[],\"mustNotContain\":[],\"originalFormat\":false,\"tag\":null}]"
bargs=(--data-urlencode languages-enabled=pb --data-urlencode languages-enabled=en --data-urlencode "languages-profiles=$prof"
  --data-urlencode settings-general-serie_default_enabled=true --data-urlencode settings-general-serie_default_profile=1
  --data-urlencode settings-general-movie_default_enabled=true --data-urlencode settings-general-movie_default_profile=1)
cur=$(sed -n '/^general:/,/^[a-z]/p' /opt/appdata/bazarr/config/config.yaml | sed -n '/^  enabled_providers:/,/^  [a-z]/s/^  - //p')
for p in embeddedsubtitles yifysubtitles gestdown tvsubtitles animetosho $(grep -x opensubtitlescom <<<"$cur"); do
  bargs+=(--data-urlencode "settings-general-enabled_providers=$p")
done
curl -fsS -o /dev/null -X POST -H "X-API-KEY: $bkey" http://localhost:6767/api/system/settings "${bargs[@]}"
ok "bazarr subtitles: profile pt-BR + English (default), free providers"

echo "== seerr"
# Needs the Seerr setup wizard done first (the Jellyfin login is typed by the user). Profiles come from recyclarr.
seerr() { # seerr <GET|POST> <path> [json]
  local k; k=$(docker exec seerr cat /app/config/settings.json | jq -r .main.apiKey)
  curl -fsS -X "$1" -H "X-Api-Key: $k" -H 'Content-Type: application/json' "http://localhost:5055/api/v1$2" ${3:+--data "$3"}
}
if [ "$(docker exec seerr cat /app/config/settings.json | jq .public.initialized)" != true ]; then
  echo "  skip seerr: run its setup wizard at http://$LAN:5055 first"
else
  pid() { api "$1" GET /qualityprofile | jq --arg n "$2" 'first(.[] | select(.name == $n)) | .id'; }
  if [ "$(seerr GET /settings/radarr | jq length)" = 0 ]; then
    seerr POST /settings/radarr "$(jq -n --arg k "$(key radarr)" --argjson p "$(pid radarr 'HD Bluray + WEB')" '{
      name:"Radarr", hostname:"radarr", port:7878, apiKey:$k, useSsl:false, baseUrl:"",
      activeProfileId:$p, activeProfileName:"HD Bluray + WEB", activeDirectory:"/data/media/movies",
      minimumAvailability:"released", tags:[], is4k:false, isDefault:true,
      externalUrl:"http://192.168.50.220:7878", syncEnabled:true, preventSearch:false}')" >/dev/null
  fi
  ok "seerr -> radarr (HD Bluray + WEB, /data/media/movies)"
  if [ "$(seerr GET /settings/sonarr | jq length)" = 0 ]; then
    p=$(pid sonarr WEB-1080p)
    seerr POST /settings/sonarr "$(jq -n --arg k "$(key sonarr)" --argjson p "$p" '{
      name:"Sonarr", hostname:"sonarr", port:8989, apiKey:$k, useSsl:false, baseUrl:"",
      activeProfileId:$p, activeProfileName:"WEB-1080p", activeDirectory:"/data/media/tv",
      activeAnimeProfileId:$p, activeAnimeProfileName:"WEB-1080p", activeAnimeDirectory:"/data/media/anime",
      seriesType:"standard", animeSeriesType:"anime", tags:[], animeTags:[], enableSeasonFolders:true,
      is4k:false, isDefault:true, externalUrl:"http://192.168.50.220:8989", syncEnabled:true, preventSearch:false}')" >/dev/null
  fi
  ok "seerr -> sonarr (WEB-1080p, tv -> /data/media/tv, anime -> /data/media/anime)"
fi

echo "== connection tests"
for app in sonarr radarr lidarr; do
  id=$(api "$app" GET /downloadclient | jq 'first(.[] | select(.name == "qBittorrent")) | .id')
  api "$app" POST /downloadclient/test "$(api "$app" GET "/downloadclient/$id")" >/dev/null && ok "$app -> qBittorrent test passed"
done
for app in Sonarr Radarr Lidarr; do
  body=$(api prowlarr GET /applications | jq --arg n "$app" 'first(.[] | select(.name == $n))')
  api prowlarr POST /applications/test "$body" >/dev/null && ok "prowlarr -> $app test passed"
done
