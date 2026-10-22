# Media VM

VM 205 on the homelab node: Debian 13, 8 vCPU, 12 GB RAM, Docker. It holds everything media related, from downloading to watching.

## Compose projects

| File | Project | Containers |
| --- | --- | --- |
| [`compose.yml`](compose.yml) | `media` | gluetun, deunhealth, qBittorrent, Prowlarr, FlareSolverr, Sonarr, Radarr, Lidarr, Bazarr, Kapowarr, Jellyseerr, Kavita, File Browser |
| [`jellyfin/compose.yaml`](jellyfin/compose.yaml) | `jellyfin` | Jellyfin, Jellystat + Postgres |
| [`homarr/compose.yaml`](homarr/compose.yaml) | `homarr` | Homarr, docker-socket-proxy (read-only, containers only) |
| [`../roms/compose.yml`](../roms/compose.yml) | `roms` | RomM + MariaDB |

Immich and Nextcloud use their upstream compose files ([Immich](https://immich.app/docs/install/docker-compose), [Nextcloud](https://hub.docker.com/_/nextcloud)) and are not copied here.

## How it fits together

- **VPN-only egress for downloads.** qBittorrent, Prowlarr and FlareSolverr run with `network_mode: service:gluetun`, so they share gluetun's network namespace. If the tunnel drops, they have no internet at all. gluetun publishes their web UIs on the LAN, and `FIREWALL_OUTBOUND_SUBNETS` lets them reach the LAN and the `servarrnetwork` bridge.
- **Self-healing.** gluetun and qBittorrent have healthchecks, and [deunhealth](https://github.com/qdm12/deunhealth) restarts any container labelled `deunhealth.restart.on.unhealthy=true` when it turns unhealthy.
- **Fixed IPs on `servarrnetwork` (172.22.0.0/24)**, so the arr apps can always find each other and qBittorrent (via gluetun at `172.22.0.2`).
- **Hardlinks.** Sonarr and Radarr see the whole `/mnt/data` as `/data` as well as their library folders. Imports from `downloads/qbittorrent` therefore become hardlinks instead of copies.

## Storage

The ZFS datasets on the host reach the VM through **virtiofs**, not SMB. That's faster, and there's no network stack in the way. The VM's `/etc/fstab` mounts them at:

```
/mnt/data       movies, series, anime, music, books, comics, downloads
/mnt/docker     app config (appdata)
/mnt/roms       ROM library (RomM)
/mnt/backup     same-host backup disk (read-only in File Browser)
/mnt/media      apollo (encrypted): media, being migrated to
/mnt/downloads  apollo (encrypted): downloads, being migrated to
/mnt/stuff      apollo (encrypted): the whole dataset, for File Browser
```

The datasets are owned by the unprivileged NAS container's user, which maps to host uid **101000**. That's why every container runs with `PUID=101000` / `PGID=101000`. See [storage](../storage/).

## Jellyfin

Jellyfin currently **transcodes in software**. The homelab CPU is a 5600X with no iGPU, and the GT 610 is too old to be useful. The plan is to move the lab's Ryzen 7 5700G into this machine and give Jellyfin `/dev/dri/renderD128` (AMD VA-API: H.264 and HEVC 8/10-bit, no AV1). Jellystat keeps playback history in its own Postgres.

## Secrets

Credentials live only in `.env` files next to the data (`/mnt/docker/gluetun/.env`, `/mnt/docker/jellyfin/.env`, `/docker/romm/.env`, the Homarr `.env`). They are never committed.
