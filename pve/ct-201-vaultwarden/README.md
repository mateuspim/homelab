# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/vaultwarden.png" align="top"> Vaultwarden · CT 201

The house password manager (Bitwarden-compatible). It's deliberately tiny and boring: Alpine, a distro package, no Docker.

| | |
| --- | --- |
| **OS** | Alpine, unprivileged LXC |
| **Resources** | 1 core · 256 MB RAM · 1 GB disk |
| **Address** | 192.168.50.201 (DHCP) |
| **LAN ports** | 8000 (HTTPS) |
| **Public** | yes, through the tunnel, behind Access |
| **Starts** | at boot |

## How it works

- Vaultwarden comes from Alpine's own packages and runs under OpenRC's `supervise-daemon` as its own user. Settings live in `/etc/conf.d/vaultwarden`.
- **TLS is native** (Rocket, `ROCKET_TLS`), with a self-signed certificate that covers the LAN IP as well as its names. That's what lets the Bitwarden CLI talk to it directly on the LAN.
- From outside, it's reached through the [tunnel](../ct-100-cloudflared/), behind Access. cloudflared talks to the origin with `noTLSVerify`, so rotating the self-signed certificate never breaks the public side.

## Using the CLI on the LAN

The `bw` CLI can't get through Cloudflare Access, so a second CLI profile points at the LAN address and pins the certificate:

```bash
alias bwl='BITWARDENCLI_APPDATA_DIR=~/.config/bw-lan NODE_EXTRA_CA_CERTS=~/.config/vaultwarden-lan.crt bw'
bwl config server https://192.168.50.201:8000    # once
bwu()  { local s; s=$(bwl unlock --raw) && export BW_SESSION="$s"; }   # unlock, never print the key
bwlk() { bwl lock; unset BW_SESSION; }
```

The plain `bw` profile keeps using the public URL.

## Gotchas

- **The off-site backup keys can't live only in here.** The vzdump archives include this container, so a vault that holds the only copy of their keys would be locked inside its own backup. They also have an offline copy ([backups](../../docs/backups.md)).
- Alpine's `udhcpc` rewrites `/etc/resolv.conf` on every lease. `RESOLV_CONF=no` in `/etc/udhcpc/udhcpc.conf` keeps the DNS pinned.
