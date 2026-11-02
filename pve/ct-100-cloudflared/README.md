# cloudflared (CT 100)

Unprivileged Debian 13 LXC, 1 core, 512 MB. It runs the **Cloudflare Tunnel**, the only way in from the internet. No port is open on the router.

- **Remotely managed tunnel.** The ingress rules (public hostname → LAN origin) live in the Cloudflare dashboard, not in a local `config.yml`. Each public app points straight at its container: Jellyfin at CT 222, Seerr and Bazarr at CT 220, Immich and Kavita at CT 225, plus Gitea and Vaultwarden.
- **Everything is behind Cloudflare Access.** Every public hostname needs an Access login first. Apps with their own clients (Jellyfin on a TV, the Bitwarden app) go through the bypass below.
- **Temporary IP whitelist.** A small Python service adds one IP (IPv4 /32 or IPv6 /128) to an Access bypass list for a few hours, then removes it. It syncs only the difference with Cloudflare's list. A full replace of the list with an empty one had silently left old entries behind, so it no longer does that. Its page is reachable only from one desktop on the LAN, and it needs a token.
- Firewall: inbound DROP, except SSH and the whitelist page from that one desktop, plus ICMP.
- DNS is pinned to Cloudflare (`supersede domain-name-servers` in `dhclient.conf`), so a DHCP renewal can't switch it back to the router.
