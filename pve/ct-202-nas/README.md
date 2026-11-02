# <img width="28" src="https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png/samba-server.png" align="top"> NAS · CT 202

Samba over the ZFS datasets, for the desktops, laptops and the lab node. It also runs the off-site backup timers.

| | |
| --- | --- |
| **OS** | Ubuntu 22.04, unprivileged LXC (`nesting=1`) |
| **Resources** | 4 cores · 4 GB RAM · 8 GB disk |
| **Address** | 192.168.50.202 |
| **Storage** | `zeus/data`, `apollo/vault/stuff`, `poseidon/backup`, `dionysus/roms` (bind mounts) |
| **LAN ports** | 139, 445 |
| **Starts** | by [`homelab-unlock`](../host/homelab-unlock), after the encrypted datasets are mounted |

## Shares

| Share | Dataset | What's in it |
| --- | --- | --- |
| `data` | `zeus/data` | Torrents and the media library: the same files the arr stack and Jellyfin see |
| `stuff` | `apollo/vault/stuff` | Personal files |
| `backup` | `poseidon/backup` | vzdump archives |
| `roms` | `dionysus/roms` | ROM library (~566 GB) |
| hidden | `poseidon/backup/lab` | Backup-only share for the [lab](../../lab/) node, with its own account |

## How it works

- `security = user`, `map to guest = Never`, SMB2 minimum, `hosts allow` limited to the LAN, named users only.
- **One owner everywhere.** Every share forces user and group `pym` with `0774` files and `0775` directories. uid 1000 in this unprivileged CT is 101000 on the host, the same owner every other container writes as. A file dropped into `data` over SMB is immediately usable by the arr stack ([storage](../../docs/storage.md#ownership)).
- `onboot=0`: if it started before the datasets were unlocked, its shares would point at the empty mountpoint directories.
- **Off-site:** `vzdump-offsite.timer` (Sun 09:00) and `roms-offsite.timer` (Sun 12:00) push encrypted copies to Google Drive with `rclone crypt` ([backups](../../docs/backups.md)).

## Operations

```bash
testparm -s                       # effective config
pdbedit -L                        # Samba users
smbpasswd -a <user>               # add or reset a Samba password
systemctl list-timers '*offsite*'
```
