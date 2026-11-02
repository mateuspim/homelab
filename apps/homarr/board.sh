#!/usr/bin/env bash
# board.sh — declare the whole Homarr "dashboard" board (apps, sections, layout, theme) via its API.
# Idempotent: apps are upserted by name, the board content is replaced wholesale (stable item/section ids),
# so re-running never duplicates anything. Supersedes tiles.sh.
# Run on CT 225 as pym: bash /opt/stacks/homarr/board.sh [board-name]
# Needs an API key (Homarr → Management → Tools → API) in /opt/stacks/homarr/.api-key (600).
# Tiles open the public hostname (Cloudflare Access off-LAN) when there is one; status pings use the LAN origin.
set -euo pipefail
BOARD=${1:-dashboard}
H=http://localhost:7575/api
K=$(tr -d '[:space:]' < /opt/stacks/homarr/.api-key)
api() { curl -fsS -X "$1" -H "ApiKey: $K" -H 'Content-Type: application/json' "$H$2" ${3:+--data "$3"}; }
ICON=https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg

# Sections: id | title | base x,y,w,h (9 cols) | mobile x,y,w,h (3 cols). Tiles fill each section row-major, 1x1.
SECTIONS=(
  "sec-media|Media|0,1,3,1|0,2,3,1"
  "sec-library|Library|3,1,6,1|0,3,3,2"
  "sec-infra|Infra|0,2,3,2|0,7,3,2"
  "sec-downloads|Downloads & Automation|3,2,6,1|0,5,3,2"
)

# section | name | href | LAN ping ("" = none) | icon | description
# href "@file:<path>" = read at runtime from that file (for URLs carrying a secret: never printed, never in the repo);
# the tile is skipped if the file is missing.
# No ping for self-signed https origins (Vaultwarden cert lacks the IP SAN; Nextcloud, Proxmox): Homarr's fetch rejects them.
TILES=(
  "sec-media|Jellyfin|https://jellyfin.example.com|http://192.168.50.222:8096/health|jellyfin|Muses — movies, shows, music"
  "sec-media|Seerr|https://jellyseerr.example.com|http://192.168.50.220:5055/api/v1/status|seerr|Request movies and shows"
  "sec-media|Jellystat|http://192.168.50.225:3000|http://192.168.50.225:3000/auth/isConfigured|jellystat|Jellyfin playback stats"
  "sec-library|Immich|https://immich.example.com|http://192.168.50.225:2283/api/server/ping|immich|Photos and videos"
  "sec-library|Nextcloud|https://192.168.50.225:8443||nextcloud|Files and sync"
  "sec-library|Kavita|https://kavita.example.com|http://192.168.50.225:5000/api/health|kavita|Ebooks"
  "sec-library|Komga|http://192.168.50.225:25600|http://192.168.50.225:25600/actuator/health|komga|Comics and manga"
  "sec-library|romm|http://192.168.50.225:8080|http://192.168.50.225:8080/api/heartbeat|romm|ROM library"
  "sec-library|Filebrowser|http://192.168.50.225:8088|http://192.168.50.225:8088/health|filebrowser-quantum|Browse media and ROMs (read-only)"
  "sec-infra|Proxmox|https://192.168.50.200:8006||proxmox|Proxmox VE host"
  "sec-infra|Gitea|https://git.example.com|http://192.168.50.21:3000/api/healthz|gitea|Git repos"
  "sec-infra|Vaultwarden|https://vaultwarden.example.com||vaultwarden|Passwords"
  # Temp-whitelist UI on CT 100. Its URL is a secret, read at run time from a local file (not in the repo). No ping.
  "sec-infra|Whitelist IP|@file:/opt/stacks/homarr/.whitelist-url||cloudflare|Temporarily allow an IP through Cloudflare Access"
  "sec-downloads|Sonarr|http://192.168.50.220:8989|http://192.168.50.220:8989/ping|sonarr|TV shows"
  "sec-downloads|Radarr|http://192.168.50.220:7878|http://192.168.50.220:7878/ping|radarr|Movies"
  "sec-downloads|Lidarr|http://192.168.50.220:8686|http://192.168.50.220:8686/ping|lidarr|Music"
  "sec-downloads|Prowlarr|http://192.168.50.220:9696|http://192.168.50.220:9696/ping|prowlarr|Indexers"
  "sec-downloads|Bazarr|https://bazarr.example.com|http://192.168.50.220:6767/|bazarr|Subtitles"
  "sec-downloads|qBittorrent|http://192.168.50.220:8080|http://192.168.50.220:8080/|qbittorrent|Torrents (via gluetun VPN)"
)
# Homarr's onboarding defaults, removed.
DEFAULT_APPS=("Homarr Docs" "Homarr GitHub" "Help Translate" "Support Homarr")

board=$(api GET /boards | jq -er --arg n "$BOARD" 'first(.[] | select(.name == $n)) | .id')
full=$(api GET "/trpc/board.getBoardByName?input=$(jq -rn --arg n "$BOARD" '{json:{name:$n}}|@uri')" | jq -e .result.data.json)
mobile=$(jq -er '.layouts[] | select(.role == "mobile") | .id' <<<"$full")
base=$(jq -er '.layouts[] | select(.role == "base") | .id' <<<"$full")
root=$(jq -er 'first(.sections[] | select(.kind == "empty" and .yOffset == 0)) | .id' <<<"$full")

# 1. Apps: create missing, patch existing to the declared state.
apps=$(api GET /apps)
declare -A APPID
ACTIVE=()
for t in "${TILES[@]}"; do
  IFS='|' read -r sec name href ping icon desc <<<"$t"
  shown=$href
  if [[ $href == @file:* ]]; then
    f=${href#@file:}
    if [[ ! -s $f ]]; then printf '  skip %s (%s missing)\n' "$name" "$f"; continue; fi
    href=$(tr -d '\n' < "$f"); shown="(from $f)"
  fi
  ACTIVE+=("$t")
  body=$(jq -n --arg n "$name" --arg h "$href" --arg p "$ping" --arg i "$ICON/$icon.svg" --arg d "$desc" \
    '{name:$n, description:$d, iconUrl:$i, href:$h, pingUrl:(if $p == "" then null else $p end)}')
  id=$(jq -r --arg n "$name" 'first(.[] | select(.name == $n)) | .id // empty' <<<"$apps")
  if [[ -n $id ]]; then
    api PATCH "/apps/$id" "$body" >/dev/null; printf '  sync %s\n' "$name"
  else
    id=$(api POST /apps "$body" | jq -er .id); printf '  new  %s -> %s\n' "$name" "$shown"
  fi
  APPID[$name]=$id
done

# 2. Layouts: 9-column base (3 | 6 split), 3-column mobile.
api PUT "/boards/$board/layouts" "$(jq -c --argjson c 9 '{layouts: [.layouts[] | if .role == "base" then .columnCount = $c else . end]}' <<<"$full")" >/dev/null

# 3. Content: replaced wholesale, so anything not declared here (old tiles, bookmarks widget) disappears.
tiles=$(for t in "${ACTIVE[@]}"; do
  IFS='|' read -r sec name _ <<<"$t"
  jq -nc --arg s "$sec" --arg n "$name" --arg a "${APPID[$name]}" '{sec:$s, name:$n, app:$a}'
done | jq -sc .)
secs=$(printf '%s\n' "${SECTIONS[@]}" | jq -Rsc 'split("\n") | map(select(. != "") | split("|")
  | {id:.[0], title:.[1], b:(.[2]|split(",")|map(tonumber)), m:(.[3]|split(",")|map(tonumber))})')
content=$(jq -nc --argjson tiles "$tiles" --argjson secs "$secs" --arg root "$root" --arg base "$base" --arg mob "$mobile" '
  def lay($l; $s; $x; $y; $w; $h): {layoutId:$l, xOffset:$x, yOffset:$y, width:$w, height:$h, sectionId:$s};
  def adv: {title:null, customCssClasses:[], borderColor:""};
  {
    sections: ([{id:$root, kind:"empty", xOffset:0, yOffset:0}] + [ $secs[] | {
      id, kind:"container", collapsed:false,
      options:{title, customCssClasses:[], borderColor:"", showLabel:true, collapsible:false, showOpenAll:false, scrollable:false},
      layouts:[ {layoutId:$base, xOffset:.b[0], yOffset:.b[1], width:.b[2], height:.b[3], parentSectionId:$root},
                {layoutId:$mob,  xOffset:.m[0], yOffset:.m[1], width:.m[2], height:.m[3], parentSectionId:$root} ] } ]),
    items: (
      [ {id:"w-clock", kind:"clock", integrationIds:[], advancedOptions:adv,
         options:{is24HourFormat:true, showDate:true, dateFormat:"dddd, D MMMM", showSeconds:false, useCustomTimezone:false},
         layouts:[lay($base;$root;0;0;3;1), lay($mob;$root;0;0;3;1)]},
        {id:"w-weather", kind:"weather", integrationIds:[], advancedOptions:adv,
         options:{location:{name:"São Paulo", latitude:-23.5505, longitude:-46.6333}, isFormatFahrenheit:false,
                  showCity:true, showCurrentWindSpeed:false, hasForecast:true, forecastDayCount:5, showHumidity:false},
         layouts:[lay($base;$root;3;0;6;1), lay($mob;$root;0;1;3;1)]} ]
      + [ $secs[] as $s | [ $tiles[] | select(.sec == $s.id) ] | to_entries[] | .key as $i | .value | {
          id:("app-" + (.name | ascii_downcase | gsub("[^a-z0-9]"; ""))), kind:"app", integrationIds:[], advancedOptions:adv,
          options:{appId:.app, openIn:"newTab", showTitle:true},
          layouts:[ lay($base; $s.id; $i % $s.b[2]; ($i / $s.b[2] | floor); 1; 1),
                    lay($mob;  $s.id; $i % $s.m[2]; ($i / $s.m[2] | floor); 1; 1) ] } ] )
  }')
api PUT "/boards/$board/content" "$content" >/dev/null
printf '  board: %s sections, %s items\n' "$(jq '.sections|length' <<<"$content")" "$(jq '.items|length' <<<"$content")"

# 4. Drop the onboarding link apps (no longer on the board).
apps=$(api GET /apps)
for n in "${DEFAULT_APPS[@]}"; do
  id=$(jq -r --arg n "$n" 'first(.[] | select(.name == $n)) | .id // empty' <<<"$apps")
  if [[ -n $id ]]; then api DELETE "/apps/$id" >/dev/null; printf "  del  %s\n" "$n"; fi
done

# 5. Theme: violet/cyan over a starry-mountain night sky, translucent tiles.
api PATCH "/boards/$board/settings" "$(jq -n '{
  pageTitle:"homelab", metaTitle:"homelab",
  logoImageUrl:"https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/svg/homarr.svg",
  faviconImageUrl:"https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/homarr.png",
  backgroundImageUrl:"https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&w=2560&q=80",
  backgroundImageAttachment:"fixed", backgroundImageRepeat:"no-repeat", backgroundImageSize:"cover",
  primaryColor:"#7c5cff", secondaryColor:"#22b8cf", opacity:80, itemRadius:"lg", iconColor:null, disableStatus:false,
  customCss:""}')" >/dev/null
printf '  theme applied\n'
