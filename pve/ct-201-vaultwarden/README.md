# Vaultwarden (CT 201)

Unprivileged **Alpine** LXC, 1 core, 256 MB. Vaultwarden comes from Alpine's own packages and runs under OpenRC's `supervise-daemon` as its own user: no Docker, a tiny footprint.

- **TLS is native** (Rocket). The certificate is self-signed and covers the LAN IP as well as its names, so the Bitwarden CLI works directly over the LAN. The CLI trusts it through `NODE_EXTRA_CA_CERTS`, with a separate CLI profile for the LAN, while the normal profile uses the public URL.
- From outside, it's reached through the Cloudflare Tunnel, behind Access. cloudflared talks to the origin with `noTLSVerify`, so rotating the self-signed certificate never breaks the public side.
- The crypt keys for the off-site backups are **not only** in here: the vzdump archives include Vaultwarden itself (see [backups](../../docs/backups.md)).
- DNS is pinned (`RESOLV_CONF=no` for udhcpc), so a DHCP renewal can't switch it back to the router.
