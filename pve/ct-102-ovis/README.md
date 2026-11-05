# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/debian.png" align="top"> Ovis · CT 102

A small always-on box for Ovis, my agent workspace. It runs as a plugin of the Herdr server, so the sessions keep going when my laptop sleeps, and I open it from any of my devices over Tailscale.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1`) |
| **Resources** | 2 cores · 2 GB RAM · 512 MB swap · 8 GB disk |
| **Address** | 192.168.50.206 |
| **LAN ports** | 22 (SSH) and ICMP; 7317 is loopback only |
| **Devices** | `/dev/net/tun` passed through (`dev0`), for its own Tailscale node |
| **Starts** | at boot |

## How it works

- **Ovis runs as a Herdr plugin.** The `ovis-herdr` systemd service starts Herdr and the plugin at boot, under a dedicated unprivileged account.
- **Ovis listens on `127.0.0.1:7317` only.** Nothing on the LAN can reach it directly.
- **Two ways in, both private:** an SSH tunnel (`ssh -L 7317:127.0.0.1:7317 …`), or Tailscale Serve on the CT's own Tailscale node (separate from the [subnet router](../ct-101-tailscale/)), which publishes the loopback port as HTTPS to my tailnet only. The tailnet policy decides which devices get there.
- **Firewall:** inbound DROP, then two rules: TCP 22 from `192.168.50.0/24` and ICMP. Outbound is open.
- No data bind mounts: it doesn't touch the media, photos or files pools.

## Operations

```bash
pct exec 102 -- systemctl status ovis-herdr
pct exec 102 -- curl -s http://127.0.0.1:7317/api/health
```

## Gotchas

- **Don't publish port 7317 on the LAN.** The SSH tunnel and Tailscale Serve are the only ways in, on purpose.
- Like [CT 101](../ct-101-tailscale/#gotchas), an unprivileged LXC has no `/dev/net/tun` by default; without the passthrough `tailscaled` can't create its interface.
