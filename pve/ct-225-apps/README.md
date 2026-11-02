# apps (CT 225)

Unprivileged Debian 13 LXC, 6 cores, 10 GB RAM, Docker CE. Everything that isn't the arr stack or Jellyfin lives here, one compose project per app in `/opt/stacks/<app>`, with app data in `/opt/appdata/<app>` on the CT's rootfs (so the weekly vzdump covers it).

## Apps

| App | Folder | Port | Data |
| --- | --- | --- | --- |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/immich.png"> Immich (server, ML, Postgres, Valkey) | [`immich/`](immich/) | 2283 | `/photos` |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/nextcloud.png"> Nextcloud (linuxserver, Postgres, Valkey) | [`nextcloud/`](nextcloud/) | 8443 | `/cloud` |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/romm.png"> RomM + MariaDB | [`romm/`](romm/) | 8080 | `/roms` (read-only) |
| Jellystat + Postgres | [`jellystat/`](jellystat/) | 3000 | app data only |
| <img width="16" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/homarr.png"> Homarr | [`homarr/`](homarr/) | 7575 | app data only |
| File Browser Quantum | [`filebrowser/`](filebrowser/) | 8088 | `/data/media`, `/roms` (read-only) |
| Komga (comics, manga) | [`komga/`](komga/) | 25600 | `/data/media/comics` (read-only) |
| Kavita (ebooks) | [`kavita/`](kavita/) | 5000 | `/data/media/books` (read-only) |
| ClamAV (clamd for Nextcloud) | [`clamav/`](clamav/) | not published | signatures only |

## Mounts

| CT path | Host dataset | Mode |
| --- | --- | --- |
| `/photos` | `apollo/vault/photos` | read-write |
| `/cloud` | `apollo/vault/cloud` | read-write |
| `/roms` | `dionysus/roms` | read-only |
| `/data/media` | `zeus/data/media` | read-only |

The readers and File Browser only ever see the library read-only, so nothing here can damage what the arr stack manages.

## Notes per app

- **Immich** follows the official compose for its release, with the database images pinned by digest. Server and ML run as `user: 1000:1000`, so photos land owned by `pym`. Machine learning (faces, search) runs on the CPU.
- **Nextcloud** was installed with `occ maintenance:install` from [`install.sh`](nextcloud/install.sh), not the web installer: APCu local cache, Redis for distributed cache and locking, cron background jobs, a maintenance window at 03:00. The linuxserver `occ` wrapper eats one level of backslashes, so class names are written `\\OC\\Memcache\\…`.
- **Nextcloud antivirus.** The *Antivirus for files* app runs in daemon mode against the `clamav` container, which is reachable only on Nextcloud's Docker network. An infected upload is refused before it's stored (tested with EICAR). The background scan only logs.
- **RomM** runs as uid 1000 (the stock image runs as root) and mounts the ROM library read-only, so uploads and deletes from the UI are off. Metadata comes from Hasheous and libretro, which need no keys.
- **Jellystat** 1.1.12 on a fresh database ships a half-created config row that makes the first-user setup fail with a duplicate key. Deleting the row (`delete from app_config where "ID"=1 and "APP_USER" is null`) fixes it for good.
- **Homarr** is declared as code: [`board.sh`](homarr/board.sh) upserts every app and PUTs the whole board with stable ids, so re-running it converges. The Docker socket is deliberately **not** mounted, because it would be root over this CT's Docker. Public links in the published copy use `example.com`.
- **File Browser Quantum** re-applies the admin password from `.env` at every start, and refuses to start without one, so `admin/admin` is never live.

## Secrets

Each app has a `.env.example`. The real `.env` is created on the CT with `chmod 600`, and generated secrets (database passwords, JWT and encryption keys) never leave the CT. Firewall: inbound DROP, LAN allow for exactly the ports above.
