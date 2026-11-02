# Gitea (CT 121)

Unprivileged Debian 13 LXC, 2 cores, 4 GB. Gitea 28 is my private git, with a **Gitea Actions runner** next to it for CI, so the lab node only does interactive work.

- `gitea-dump.timer` runs `gitea dump` nightly and keeps 7 days. Those dumps also end up in the weekly vzdump ([backups](../../docs/backups.md)).
- Public access goes through the Cloudflare Tunnel, behind Access.
