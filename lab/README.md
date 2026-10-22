# lab

My personal shed: a second Proxmox node (Ryzen 7 5700G, 16 GB, 1 TB SSD, Proxmox VE 9.2) for running AI coding agents and work dev environments. It's kept apart from the homelab, so a runaway build or agent can never take Jellyfin or the NAS down with it.

## How it's used

- **One LXC per workspace.** Each project or client gets its own container with its own CPU, memory and swap limits, its own repos, credentials and agent config. Nothing is shared between them.
- **Agents run headless.** Claude Code, Codex and opencode run inside tmux/herdr sessions in the container. I attach over SSH (through Tailscale when I'm away) from the desktop, the laptop or my phone.
- **Docker inside the workspace** for project stacks (databases, queues, dev servers). Heavy one-off jobs run in a memory-capped systemd slice so they can't OOM the whole container.
- **Gitea runner.** CI for my private Gitea runs on the homelab (CT 121), so the lab only does interactive work.

## Backups

Workspaces are backed up at the file level (repos, configs, credentials, `/etc`, scripts) every day to the homelab NAS over a dedicated backup-only Samba share. Caches, `node_modules`, toolchains and Docker volumes are excluded because they can be rebuilt. See [backups](../backups/).

## Plans

- [ ] RAM: it's a single 16 GB stick right now, and the busiest workspace is what hits the limit
- [ ] NVMe for build and container scratch, so the single SATA SSD stops being the bottleneck
- [ ] Possible CPU swap: the 5700G goes to the homelab for Jellyfin VA-API and the 5600X comes here, with the GT 610 for console output
