# Jellyfin (CT 222)

Unprivileged Debian 13 LXC, 6 cores, 4 GB RAM. Jellyfin 12.4 is installed **natively** from the official Debian repo, with no Docker, so a GPU can later be handed in with a single line.

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

- `/zeus/data/media` is bind-mounted **read-only** at `/data/media`. Libraries: Movies, Series, Anime, Music, Books.
- Metadata savers are off (`SaveLocalMetadata=false`), so Jellyfin never tries to write `.nfo` files or artwork into the read-only mount. Everything stays in `/var/lib/jellyfin`, on the CT's rootfs, which is in the weekly vzdump.
- The arr stack in [CT 220](../ct-220-arr/) writes the library, and Jellyfin only reads it.

## Transcoding

It's **CPU only** for now. The 5600X has no iGPU, and the GT 610 is too old. The plan is to swap in the lab's Ryzen 7 5700G and then add:

```
dev0: /dev/dri/renderD128,gid=<render gid in the CT>
```

to `/etc/pve/lxc/222.conf` for AMD VA-API (H.264 and HEVC 8/10-bit, no AV1).

## Network

Firewall: inbound DROP, LAN allow for 8096 (web) and udp 7359 (client discovery). Remote access goes through the Cloudflare Tunnel, behind Access.

Requests come from **Seerr** and stats from **Jellystat**; both use their own Jellyfin API keys.
