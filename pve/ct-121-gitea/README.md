# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/gitea.png" align="top"> Gitea · CT 121

My private git, with CI next to it. Personal and work-in-progress repos live here; this public repo is the curated snapshot.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1,keyctl=1`) |
| **Resources** | 2 cores · 4 GB RAM · 32 GB disk |
| **Address** | 192.168.50.21 |
| **LAN ports** | 22, 3000 |
| **Public** | yes, through the tunnel, behind Access |
| **Starts** | at boot |

## How it works

- **Gitea 28** with a **Gitea Actions runner** in the same container, so CI runs on the homelab and the [lab](../../lab/) node only does interactive work.
- **Nightly `gitea dump`** (`gitea-dump.timer`) keeps 7 days of full dumps (repos, database, config). Those dumps also land in the weekly vzdump, so they reach the off-site copy ([backups](../../docs/backups.md)).

## Operations

```bash
systemctl list-timers gitea-dump.timer      # last and next dump
journalctl -u gitea -f
```
