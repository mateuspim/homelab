# host (`pve`)

What runs on the Proxmox host itself, outside any guest.

## One-passphrase unlock: [`homelab-unlock`](homelab-unlock)

The data pools are ZFS-encrypted with `keyformat=passphrase`, so nothing is readable after a reboot until a person types the passphrase. All three encryption roots (`poseidon/backup`, `zeus/data`, `apollo/vault`) use the **same** passphrase, so one prompt is enough:

```bash
ssh -t homelab homelab-unlock
```

It imports the pools, asks once, loads every key, mounts everything, **checks every mountpoint**, and only then starts the guests that bind-mount the data (202 → 220 → 222 → 225). If any mount is missing, it refuses to start them. Re-running it is safe: guests that are already up are only restarted if keys were just loaded.

Two guards stop data from landing on the wrong disk while the pools are locked:

- **Those guests have `onboot=0`.** Otherwise they'd boot with their bind mounts pointing at empty directories on the root SSD.
- **`homelab-unlock --guard`** (run once, while locked) makes the empty mountpoint directories immutable (`chattr +i`). The backup storage is marked `is_mountpoint 1`, so vzdump refuses to run instead of writing into the empty directory.

## Alerts

Everything mails root, and root's mail goes through Proxmox's notification system to an **SMTP target** (Gmail, port 587; the ISP blocks 25). The `default-matcher` routes all notifications there. Every subject starts with **`[homelab]`** and the mail goes to a `+homelab` address, so one mail filter files all of it.

| Source | How it's set up |
| --- | --- |
| Proxmox (backups, updates, replication) | Subject overrides in `/etc/pve/notification-templates/default/*-subject.txt.hbs` (`[homelab] ` + the stock subject) |
| SMART | `smartd.conf`: `DEVICESCAN -a -W 4,50,55 -s (S/../.././02\|L/../0[1-7]/7/03) -m root -M exec /usr/local/sbin/smartd-mail`: a short test nightly, a long test the first Sunday of the month, warn at 50 °C, critical at 55 °C. [`smartd-mail`](smartd-mail) formats the mail and names the pool the disk belongs to |
| ZFS (ZED) | `ZED_EMAIL_OPTS="-s '[homelab] @SUBJECT@' @ADDRESS@"` in `zed.rc` |
| Antivirus | [`av-scan`](av-scan), see below |

## Antivirus: [`av-scan`](av-scan)

ClamAV on the host (`clamav` + `clamav-freshclam`, no daemon). [`av-scan.timer`](av-scan.timer) runs nightly at 04:30 and scans every file whose **ctime** changed in the last 26 h under `/zeus/data/torrents`, `/apollo/vault/stuff` and `/apollo/vault/cloud`. A download can't backdate ctime, and the media library is just hardlinks of the torrents. It runs at idle priority, uses about 1 GB of RAM only while scanning, **never deletes or moves anything**, and mails on a detection or a scan error. While the pools are locked it skips quietly.

Together with qBittorrent's file-name blocklist ([arr](../arr/)) and Nextcloud's on-upload scanning ([apps](../apps/)), that covers the three ways files get in: torrents, uploads and SMB.

## Stability workarounds

The host had been freezing hard every few weeks: the journal just stops, with no panic and no shutdown. Ryzen 5000 CPUs are known for idle freezes on Linux, so for now:

- [`disable-cc6.service`](disable-cc6.service) turns off the deepest CPU idle state (C2, i.e. CC6) on every thread at boot. It costs a few watts at idle.
- [`90-hang-reboot.conf`](90-hang-reboot.conf) (`/etc/sysctl.d/`): a detected soft or hard lockup panics, and the box reboots after 10 s instead of sitting dead until someone notices. The guests then wait for `homelab-unlock`.

The onboard Realtek NIC (r8169) also logs an occasional `NETDEV WATCHDOG` transmit timeout. The driver resets it within seconds, so it's just noted for now.

## Firewall

The Proxmox firewall is on for the host and every guest: inbound DROP, then explicit LAN rules per port in `/etc/pve/firewall/<vmid>.fw`. Nothing is open to the internet; the public endpoints go through the Cloudflare Tunnel, behind Access.
