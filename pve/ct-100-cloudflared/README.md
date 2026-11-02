# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/cloudflare.png" align="top"> cloudflared · CT 100

The only door from the internet into the house. A Cloudflare Tunnel makes an outbound connection to Cloudflare, so **no port is open on the router**. Every public hostname sits behind Cloudflare Access.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1,keyctl=1`) |
| **Resources** | 1 core · 512 MB RAM · 2 GB disk |
| **Address** | 192.168.50.231 (DHCP) |
| **Storage** | none |
| **LAN ports** | SSH and the whitelist page, from one desktop only |
| **Starts** | at boot |

## How it works

- **Remotely managed tunnel.** The ingress rules (public hostname → LAN origin) live in the Cloudflare dashboard, not in a local `config.yml`. Each public app points straight at its container:

  | App | Origin |
  | --- | --- |
  | Jellyfin | [CT 222](../ct-222-jellyfin/) |
  | Seerr, Bazarr | [CT 220](../ct-220-arr/) |
  | Immich, Kavita | [CT 225](../ct-225-apps/) |
  | Gitea | [CT 121](../ct-121-gitea/) |
  | Vaultwarden | [CT 201](../ct-201-vaultwarden/) |

- **Access in front of everything.** A request needs an Access login before it ever reaches a container. Sonarr, Radarr, Prowlarr, qBittorrent, Proxmox and Homarr are not published at all; those are LAN or Tailscale only.
- **Temporary IP whitelist.** Native apps can't do an Access login (Jellyfin on a TV, the Bitwarden app away from home). For those, a small Python service puts one IP (IPv4 /32 or IPv6 /128) on an Access bypass list for a few hours, then takes it off. The page is a tile on the Homarr dashboard and needs a token.

## Operations

```bash
journalctl -u cloudflared -f        # tunnel connections, origin errors
# routes come from the dashboard: a change there is live without a restart
```

To add a public app: create the route in the dashboard, add an Access application for it, then check that it redirects to the Access login.

## Gotchas

- **Replacing a Cloudflare list with an empty one doesn't clear it.** The first version of the whitelist service sent `items: []` when the last entry expired, and Cloudflare silently kept the old entries. It now reads the list and PATCHes only the difference.
- The local `/etc/cloudflared/config.yml` is stale and ignored. The dashboard config wins for a remotely managed tunnel.
- DNS is pinned to Cloudflare with `supersede domain-name-servers` in `dhclient.conf`, so a DHCP renewal can't switch it back to the router.
