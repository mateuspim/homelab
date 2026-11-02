# NAS (CT 202)

Unprivileged Ubuntu 22.04 LXC, 4 cores, 4 GB. It runs Samba over the ZFS datasets, plus the off-site backup timers.

| Share | Dataset | Notes |
| --- | --- | --- |
| `data` | `zeus/data` | Torrents and the media library: the same files the arr stack and Jellyfin see |
| `stuff` | `apollo/vault/stuff` | Personal files |
| `backup` | `poseidon/backup` | vzdump archives (and the lab's backups) |
| `roms` | `dionysus/roms` | ROM library |
| (hidden) | `poseidon/backup/lab` | Backup-only share for the lab node, with its own account |

- `security = user`, `map to guest = Never`, SMB2 minimum, `hosts allow` limited to the LAN, named users only.
- Every share forces user and group `pym` (uid 1000 → host 101000), with `0774` files and `0775` directories, so anything written over SMB has the same owner the containers use ([storage](../../docs/storage.md)).
- `onboot=0`: [`homelab-unlock`](../host/homelab-unlock) starts it only after the encrypted datasets are mounted.
- Off-site: `vzdump-offsite.timer` and `roms-offsite.timer` push encrypted copies to Google Drive with `rclone crypt` ([backups](../../docs/backups.md)).
