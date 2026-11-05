# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/sonarr.png" align="top"> arr · CT 220

Finds, downloads and imports media. Everything that talks to torrent swarms or indexers goes out through a VPN with a kill switch. [Jellyfin](../ct-222-jellyfin/) lives next door and only reads the library this container writes.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1,keyctl=1`), Docker CE |
| **Resources** | 4 cores · 4 GB RAM · 24 GB disk |
| **Address** | 192.168.50.220 |
| **Storage** | `zeus/data` → `/data` (read-write) |
| **Devices** | `/dev/net/tun` (`dev0`) for gluetun |
| **LAN ports** | 8080 qBittorrent · 9696 Prowlarr · 8989 Sonarr · 7878 Radarr · 8686 Lidarr · 6767 Bazarr · 5055 Seerr |
| **Public** | Seerr and Bazarr, through the tunnel, behind Access |
| **Starts** | by [`homelab-unlock`](../host/homelab-unlock) |

## Services

| Service | Role | Network |
| --- | --- | --- |
| gluetun | ProtonVPN (WireGuard) with port forwarding, firewall kill switch | VPN |
| qBittorrent | Downloads | inside gluetun |
| Prowlarr | Indexer manager, synced to the arr apps | inside gluetun |
| FlareSolverr | Gets Prowlarr past Cloudflare challenges on some indexers | inside gluetun |
| Sonarr / Radarr / Lidarr | Shows and anime / movies / music | bridge |
| Bazarr | Subtitles: Brazilian Portuguese first, then English | bridge |
| Seerr | Requests from Jellyfin users | bridge |
| Recyclarr | Daily sync of the TRaSH quality profiles | bridge |

## Files

| File | What it is |
| --- | --- |
| [`compose.yml`](compose.yml) | The whole stack |
| [`.env.example`](.env.example) | The only secret: the WireGuard key from a Proton config made for this box alone |
| [`qBittorrent.conf.seed`](qBittorrent.conf.seed) | Copied in before the first start: save path, plus the localhost auth bypass gluetun needs to set the port |
| [`wire.sh`](wire.sh) | Connects everything through the apps' APIs: qBittorrent categories, root folders, download clients, Prowlarr sync, FlareSolverr, Bazarr, Seerr. Safe to re-run |
| [`indexers.sh`](indexers.sh) | The public indexers in Prowlarr, with priorities and per-indexer filters. It also removes the ones I decided against |
| [`qbit-tune.sh`](qbit-tune.sh) | qBittorrent queue and seeding limits (run by `wire.sh`). It backs up only the settings it changes |
| [`recyclarr/`](recyclarr/) | `WEB-1080p` for shows; `HD Bluray + WEB` (default) and `UHD Bluray + WEB` for movies; plus my extra rules |

## How it works

- **VPN-only downloads.** qBittorrent, Prowlarr and FlareSolverr use `network_mode: service:gluetun`. gluetun's firewall drops all outbound traffic that isn't going into the WireGuard tunnel, so a dropped VPN means no traffic, not a leak.
- **Port forwarding.** gluetun asks Proton for a forwarded port and pushes it into qBittorrent with `VPN_PORT_FORWARDING_UP_COMMAND`. When the port changes, qBittorrent follows.
- **No passwords between apps.** qBittorrent skips auth only for the stack's own Docker network (`172.18.0.0/16`). LAN clients still log in, because Docker forwards their real address. Everything else talks through API keys that `wire.sh` reads from each app's `config.xml` at run time.
- **Hardlinks.** One dataset is mounted at `/data`, with `torrents/<category>` and `media/<type>` as plain directories in it ([TRaSH layout](https://trash-guides.info/File-and-Folder-Structure/)). An import is an instant hardlink, so qBittorrent keeps seeding the same bytes Jellyfin plays, and a file takes space once.

## What gets downloaded

The rules I settled on: nothing unplayable, no fakes, no malware, HDR10/HDR10+ fine, **no Dolby Vision**.

- **Recyclarr** syncs the TRaSH profiles daily. On top of the templates, Dolby Vision (every variant), No-RlsGroup, Obfuscated and Retags are scored −10000, next to the default LQ, BR-DISK, upscaled, AV1, x265 (HD) and 3D rules. CAM/TS/screener qualities aren't allowed at all.
- **qBittorrent never downloads** executables, scripts or disk images (`*.exe`, `*.scr`, `*.lnk`, `*.msi`, `*.ps1`, `*.iso`, …, 30 patterns), the classic "movie.mkv.exe" trick. Anything that does get through is caught by the nightly [ClamAV scan](../README.md#antivirus-av-scan).
- **4K is opt-in.** Movies default to 1080p. `UHD Bluray + WEB` (HDR10/HDR10+, still no Dolby Vision) is picked per request in Seerr, for titles worth it on the 4K TV.
- **Indexers:** Nyaa (trusted uploads only, anime category), SubsPlease and EZTV, plus 1337x. 1337x is open-upload and can't be limited to trusted uploaders, so it sits last and leans on everything else: the release filters above, the file-name blocklist and a 5-seeder minimum against fresh fakes. Other open-upload sites and the aggregators that mirror them are left out; the reasons are in the comments of [`indexers.sh`](indexers.sh).
- **Seeding:** download first. Up to 20 active downloads and 3 uploads, slow torrents don't count against the queue, and seeding stops at ratio 1 or after 24 h ([`qbit-tune.sh`](qbit-tune.sh)). That's fine for public trackers; a private tracker would need its own limits.

## Running it

```bash
# on CT 220, as pym, in /opt/stacks/arr
cp .env.example .env && chmod 600 .env   # paste the WireGuard key
mkdir -p /opt/appdata/qbittorrent/qBittorrent
cp qBittorrent.conf.seed /opt/appdata/qbittorrent/qBittorrent/qBittorrent.conf
docker compose up -d
bash wire.sh && bash indexers.sh
```

Updating: `docker compose pull && docker compose up -d`. Every linuxserver image runs with `PUID=1000 PGID=1000 UMASK=002`; uid 1000 here is host uid 101000, which owns the datasets ([storage](../../docs/storage.md#ownership)).

## Gotchas

- **Prowlarr can't use Docker service names.** Inside gluetun's network namespace they don't resolve, so Prowlarr reaches the arr apps at `192.168.50.220:<port>`, which `FIREWALL_OUTBOUND_SUBNETS` allows.
- **Recyclarr has no `:latest` tag** on ghcr. The image is pinned to the major version (`:8`).
- **Docker packages are held** (`apt-mark hold docker-ce docker-ce-cli containerd.io`). runc and LXC updates have broken Docker-in-LXC before, so they're upgraded deliberately, after a vzdump.
