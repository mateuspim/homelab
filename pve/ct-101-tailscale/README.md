# Tailscale (CT 101)

Unprivileged Debian 13 LXC, 1 core, 512 MB, with `/dev/net/tun` allowed (`lxc.cgroup2.devices.allow: c 10:200 rwm`).

- **Subnet router** for `192.168.50.0/24`: from any of my devices, the whole LAN (both nodes, every guest) is reachable as if I were home, without installing Tailscale on each guest.
- **Exit node:** on untrusted Wi-Fi, a device can send all its traffic out through home.
- Access is controlled by the tailnet policy, so only my devices are in it.
