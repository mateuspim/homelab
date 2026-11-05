# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/tailscale.png" align="top"> Tailscale · CT 101

How I reach home from anywhere. One container advertises the whole LAN to my tailnet, so no guest needs its own Tailscale install, and nothing has to be published to the internet to be usable on the road.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1,keyctl=1`) |
| **Resources** | 1 core · 512 MB RAM · 2 GB disk |
| **Address** | 192.168.50.101 |
| **Devices** | `/dev/net/tun`: `lxc.cgroup2.devices.allow: c 10:200 rwm` + `lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file` |
| **Starts** | at boot |

## How it works

- **Subnet router** for `192.168.50.0/24`: from my laptop or phone, both nodes and every guest answer on their LAN address as if I were home. That's how the arr UIs, Proxmox and Homarr stay off the public internet.
- **Exit node:** on untrusted Wi-Fi, a device can send all of its traffic out through home.
- Who can reach what is set in the tailnet policy. Only my devices are in it.

## Operations

```bash
tailscale status                    # peers, and whether routes are advertised
tailscale up --advertise-routes=192.168.50.0/24 --advertise-exit-node
```

New routes need approving once in the Tailscale admin console.

## Gotchas

- An unprivileged LXC has no `/dev/net/tun` by default. It needs both lines above (allow the device, then bind it in), or `tailscaled` can't create its interface.
