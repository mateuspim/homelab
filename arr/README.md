# arr (CT 220)

Unprivileged Debian 13 LXC, 4 cores, 4 GB RAM, Docker CE. It finds, downloads and imports media. Jellyfin lives next door in [CT 222](../jellyfin/) and only reads the library.

## Files

| File | What it is |
| --- | --- |
| [`compose.yml`](compose.yml) | The whole stack: gluetun, qBittorrent, Prowlarr, FlareSolverr, Sonarr, Radarr, Lidarr, Bazarr, Seerr, Recyclarr |
| [`.env.example`](.env.example) | The only secret is the WireGuard key from a Proton config made for this box alone |
| [`qBittorrent.conf.seed`](qBittorrent.conf.seed) | Copied in before the first start: save path and the localhost auth bypass gluetun needs |
| [`wire.sh`](wire.sh) | Connects everything through the apps' APIs: qBittorrent categories, root folders, download clients, Prowlarr sync, FlareSolverr, Bazarr, Seerr. Safe to re-run |
| [`indexers.sh`](indexers.sh) | Adds a short list of moderated public indexers to Prowlarr and removes untrusted ones |
| [`recyclarr/`](recyclarr/) | TRaSH quality profiles: `WEB-1080p` for shows, `HD Bluray + WEB` for movies, with my extra rules |

## How it fits together

- **VPN-only downloads.** qBittorrent, Prowlarr and FlareSolverr use `network_mode: service:gluetun`. gluetun's firewall drops all outbound traffic that isn't going into the WireGuard tunnel, so a dropped VPN means no traffic, not a leak.
- **Port forwarding.** gluetun asks Proton for a forwarded port and pushes it into qBittorrent with `VPN_PORT_FORWARDING_UP_COMMAND`. When the port changes, qBittorrent follows.
- **No passwords between apps.** qBittorrent skips auth only for the stack's own Docker network (`172.18.0.0/16`). LAN clients still log in, because Docker forwards their real address. Everything else talks through API keys that `wire.sh` reads from each app's `config.xml` at run time.
- **Hardlinks.** One dataset is mounted at `/data`, with `torrents/<category>` and `media/<type>` as plain directories in it ([TRaSH layout](https://trash-guides.info/File-and-Folder-Structure/)). An import is an instant hardlink, so qBittorrent keeps seeding the same bytes Jellyfin plays.
- **Prowlarr reaches the arr apps by LAN IP** (`192.168.50.220:<port>`), because inside gluetun's namespace Docker's service names don't resolve. `FIREWALL_OUTBOUND_SUBNETS` allows the LAN.

## What gets downloaded

Rules I settled on: nothing unplayable, no fakes, no malware, HDR10/HDR10+ fine, **no Dolby Vision**.

- **Recyclarr** syncs the TRaSH profiles daily. On top of the templates, Dolby Vision (every variant), No-RlsGroup, Obfuscated and Retags are scored −10000, next to the default LQ, BR-DISK, upscaled, AV1, x265 (HD) and 3D rules. CAM/TS/screener qualities aren't allowed at all.
- **qBittorrent never downloads** executables, scripts or disk images (`*.exe`, `*.scr`, `*.lnk`, `*.msi`, `*.ps1`, `*.iso`, …, 30 patterns), the classic "movie.mkv.exe" trick. Anything that does get through is caught by the nightly [ClamAV scan](../host/).
- **Indexers** are a short list of moderated public sources. Open-upload sites and aggregators that mirror them are deliberately left out (the reasons are in the comments of [`indexers.sh`](indexers.sh)).
- **Subtitles:** Bazarr fetches Brazilian Portuguese first, then English, from free providers.

## Running it

```bash
# on CT 220, as pym
cp .env.example .env && chmod 600 .env   # paste the WireGuard key
mkdir -p /opt/appdata/qbittorrent/qBittorrent && cp qBittorrent.conf.seed /opt/appdata/qbittorrent/qBittorrent/qBittorrent.conf
docker compose up -d
bash wire.sh && bash indexers.sh
```

Every linuxserver image runs with `PUID=1000 PGID=1000 UMASK=002`. In an unprivileged LXC, uid 1000 is host uid 101000, which owns the datasets (see [storage](../storage/)).

The LXC needs `nesting=1,keyctl=1` and `/dev/net/tun` passed in (`dev0: /dev/net/tun`). The Docker packages are held (`apt-mark hold`), because a runc or LXC update has broken Docker-in-LXC before. They only get upgraded deliberately, after a vzdump.
