# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/jellyfin.png" align="top"> Jellyfin · CT 222

Where everything gets watched. Jellyfin is installed **natively** from the official repo, with no Docker, so a GPU can later be handed in with one config line.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1`) |
| **Resources** | 6 cores · 4 GB RAM · 16 GB disk |
| **Address** | 192.168.50.222 |
| **Storage** | `zeus/data/media` → `/data/media` (**read-only**) |
| **LAN ports** | 8096 (web), udp 7359 (client discovery) |
| **Public** | yes, through the tunnel, behind Access |
| **Starts** | by [`homelab-unlock`](../host/homelab-unlock) |

## Install

```bash
# deb822 source + keyring, fingerprint 4918 AABC 486C A052 358D 778D 4902 3CD0 1DE2 1A7B
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
cat > /etc/apt/sources.list.d/jellyfin.sources <<EOF
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
apt update && apt install jellyfin          # pulls jellyfin-ffmpeg
usermod -aG pym jellyfin                    # group read on the media
```

## Library

- Libraries: Movies, Series, Anime, Music, Books, all under `/data/media`.
- The mount is **read-only**: the [arr stack](../ct-220-arr/) owns the library, and Jellyfin only reads it. Metadata savers are off (`SaveLocalMetadata=false`), so nothing tries to write `.nfo` files or artwork there. Everything Jellyfin knows lives in `/var/lib/jellyfin` on the CT's rootfs, which is in the weekly vzdump.
- To delete something, use Radarr or Sonarr, not Jellyfin. The files are hardlinked to the torrents, so a delete in Jellyfin wouldn't free any space anyway.

## Look and plugins

The theme is [Jellyfish](https://github.com/n00bcodr/Jellyfish) (midnight palette), set in *Dashboard → Branding → Custom CSS*, plus a lighter CSS layer that turns down blur and animations on slow clients.

| Plugin | Why |
| --- | --- |
| Intro Skipper | Skip intros and credits |
| Home Screen Sections, Media Bar | A better home page. Trailers in the hero bar are off; the background video was the main cause of lag |
| Jellyfin Enhanced | Quality-of-life tweaks, Seerr requests from inside Jellyfin, links to Sonarr, Radarr and Bazarr |
| TMDb Box Sets, Fanart, AniList | Collections and better artwork and anime metadata |
| File Transformation, Plugin Pages | Dependencies of the above |

Deliberately skipped: Playback Reporting (Jellystat in [CT 225](../ct-225-apps/) covers it), subtitle plugins (Bazarr in [CT 220](../ct-220-arr/) does it), Jellyscrub (trickplay is native now).

Plugin repositories have to match Jellyfin's ABI. Check `meta.json` before installing anything, since 12.x is a new major.

## Transcoding

It's **CPU only** for now: the 5600X has no iGPU, and the GT 610 is too old. Once the lab's Ryzen 7 5700G moves in, AMD VA-API (H.264 and HEVC 8/10-bit, no AV1) is one line in `/etc/pve/lxc/222.conf`:

```
dev0: /dev/dri/renderD128,gid=<render gid in the CT>
```

## Operations

```bash
apt update && apt upgrade jellyfin            # updates come from the official repo
journalctl -u jellyfin -f
```

Requests come from **Seerr** ([CT 220](../ct-220-arr/)) and stats from **Jellystat** ([CT 225](../ct-225-apps/)); each has its own Jellyfin API key.
