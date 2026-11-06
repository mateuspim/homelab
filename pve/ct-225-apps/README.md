# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/immich.png" align="top"> apps · CT 225

Everything that isn't the arr stack or Jellyfin: photos, cloud files, retro games, readers, the dashboard. It's one compose project per app, so each can be updated or rolled back on its own.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1,keyctl=1`), Docker CE |
| **Resources** | 6 cores · 10 GB RAM · 48 GB disk |
| **Address** | 192.168.50.225 |
| **Storage** | see [Mounts](#mounts) |
| **LAN ports** | exactly the ports in the table below |
| **Public** | Immich and Kavita, through the tunnel, behind Access |
| **Starts** | by [`homelab-unlock`](../host/homelab-unlock) |

## Apps

| App | Folder | Port | Data |
| --- | --- | --- | --- |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/immich.png"> Immich (server, ML, Postgres, Valkey) | [`immich/`](immich/) | 2283 | `/photos` |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/nextcloud.png"> Nextcloud (linuxserver, Postgres, Valkey) | [`nextcloud/`](nextcloud/) | 8443 | `/cloud` |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/romm.png"> RomM + MariaDB | [`romm/`](romm/) | 8080 | `/roms` (read-only) |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/jellystat.png"> Jellystat + Postgres | [`jellystat/`](jellystat/) | 3000 | app data only |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/homarr.png"> Homarr | [`homarr/`](homarr/) | 7575 | app data only |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/filebrowser-quantum.png"> File Browser Quantum | [`filebrowser/`](filebrowser/) | 8088 | `/data/media`, `/roms` (read-only) |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/komga.png"> Komga (comics, manga) | [`komga/`](komga/) | 25600 | `/data/media/comics` (read-only) |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/kavita.png"> Kavita (ebooks) | [`kavita/`](kavita/) | 5000 | `/data/media/books` (read-only) |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/searxng.png"> SearXNG (private web search) | [`searxng/`](searxng/) | 8082 | app data only |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/clamav.png"> ClamAV (clamd for Nextcloud) | [`clamav/`](clamav/) | not published | signatures only |

## Mounts

| CT path | Host dataset | Mode |
| --- | --- | --- |
| `/photos` | `apollo/vault/photos` | read-write |
| `/cloud` | `apollo/vault/cloud` | read-write |
| `/roms` | `dionysus/roms` | read-only |
| `/data/media` | `zeus/data/media` | read-only |

The readers and File Browser only ever see the library read-only, so nothing here can damage what the [arr stack](../ct-220-arr/) manages. App data (databases, configs, caches) lives in `/opt/appdata/<app>` on the CT's rootfs, which the weekly vzdump covers.

## Notes per app

- **Immich** follows the official compose for its release, with the database images pinned by digest. Server and ML run as `user: 1000:1000`, so photos land owned by `pym`. Machine learning (faces, smart search) runs on the CPU. The storage template files originals by date: `library/<user>/YYYY/MM/DD/`.
- **Nextcloud** was installed with `occ maintenance:install` from [`install.sh`](nextcloud/install.sh), not the web installer: APCu local cache, Redis for distributed cache and locking, cron background jobs, a maintenance window at 03:00.
- **Nextcloud antivirus.** The *Antivirus for files* app runs in daemon mode against the `clamav` container, which is reachable only on Nextcloud's Docker network. An infected upload is refused before it's stored (tested with EICAR). The background scan only logs.
- **RomM** runs as uid 1000 (the stock image runs as root) and mounts the ROMs read-only, so uploads and deletes from the UI are off. Metadata comes from Hasheous and libretro, which need no API keys. Its [`config.yml`](romm/config.yml) keeps non-games out of the library: BIOS dumps, console keys (which must never be downloadable from RomM), and `.txt`/`.nfo` notes. Scan workers are capped at 2, because 4 caused bursts of DNS failures for cover art.
- **Homarr** is declared as code: [`board.sh`](homarr/board.sh) upserts every app and PUTs the whole board with stable ids, so re-running it converges. The Docker socket is deliberately **not** mounted, because it would be root over this CT's Docker. Section tiles open the LAN address (with status pings); apps published through the tunnel also get a `↗` tile in a *Remote* section that opens the Cloudflare Access hostname. The desktop grid is 15 columns, so the six sections pack into two rows under the clock and weather, with a lone SearXNG tile at the end of that top row; mobile is 3 columns. Public links in the published copy use `example.com`.
- **File Browser** sees `/data/media` and `/roms` read-only, and a rule hides the console keys folder, so it's never shown or indexed.
- **SearXNG** is a private, LAN-only metasearch instance with JSON output on, used as the web search backend for opencode on the workstation (a small plugin calls `/search?format=json`). The limiter is off, since it would need Valkey and only LAN clients reach it. Its `settings.yml` (with `secret_key`) lives in `/opt/appdata/searxng`; the repo has [`settings.example.yml`](searxng/settings.example.yml). Don't add `cap_drop: [ALL]`: the entrypoint starts as root and can no longer read the 600 settings file.
- **Komga and Kavita** read `/data/media/{comics,books}`, which the arr side will fill once a comic/book downloader is picked.

## Running an app

```bash
# on CT 225, as pym
cd /opt/stacks/<app>
cp .env.example .env && chmod 600 .env    # fill in or generate the secrets here, never commit them
docker compose up -d
docker compose pull && docker compose up -d   # update
```

## Gotchas

- **Nextcloud's linuxserver `occ` wrapper eats one level of backslashes**, so class names must be written `\\OC\\Memcache\\…`. And `occ` only works after `[ls.io-init] done`.
- **Jellystat 1.1.12 on a fresh database** ships a half-created config row, and creating the first user fails with a duplicate key. `delete from app_config where "ID"=1 and "APP_USER" is null` fixes it for good.
- **File Browser Quantum re-applies the admin password from `.env` at every start**, so changing it in the UI doesn't stick. It also refuses to start without one, so `admin/admin` is never live. Don't put `server.database` in `config.yaml` in v2: it fatals with "old database path".
- **Homarr's REST API has no board GET**; read the board through tRPC `board.getBoardByName` instead (an API key works).
- The Docker packages are held, as on [CT 220](../ct-220-arr/#gotchas).
