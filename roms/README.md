# ROMs

[RomM](https://github.com/rommapp/romm) is my retro game library. It scans the ROM collection, pulls metadata and cover art (IGDB / Hasheous) and plays many systems in the browser.

- Runs on the Media VM: [`compose.yml`](compose.yml) has RomM and MariaDB on their own `rommnetwork` bridge, with the web UI on port `2000`.
- The library lives on the `dionysus` pool (~620 GB, about 10k files) and is mounted into the VM at `/mnt/roms`.
- DB and auth secrets come from `/docker/romm/.env`, which is not committed.
- The whole library is backed up, encrypted, to Google Drive every week. See [backups](../backups/).
