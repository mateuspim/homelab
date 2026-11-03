# <img width="28" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/jellyfin.png" align="top"> Jellyfin · CT 222

Where everything gets watched. Jellyfin is installed **natively** from the official repo, with no Docker, so a GPU can later be handed in with one config line.

| | |
| --- | --- |
| **OS** | Debian 13, unprivileged LXC (`nesting=1`) |
| **Resources** | 6 cores · 4 GB RAM · 16 GB disk |
| **Address** | 192.168.50.222 |
| **Storage** | `zeus/data/media` → `/data/media` (**read-only**) |
| **LAN ports** | 8096 (web), udp 7359 (client discovery) |
| **Public** | yes, through the tunnel, behind Access |
| **Starts** | by [`homelab-unlock`](../host/homelab-unlock) |

## Install

```bash
# deb822 source + keyring, fingerprint 4918 AABC 486C A052 358D 778D 4902 3CD0 1DE2 1A7B
curl -fsSL https://repo.jellyfin.org/jellyfin_team.gpg.key | gpg --dearmor -o /etc/apt/keyrings/jellyfin.gpg
cat > /etc/apt/sources.list.d/jellyfin.sources <<EOF
Types: deb
URIs: https://repo.jellyfin.org/debian
Suites: trixie
Components: main
Architectures: amd64
Signed-By: /etc/apt/keyrings/jellyfin.gpg
EOF
apt update && apt install jellyfin          # pulls jellyfin-ffmpeg
usermod -aG pym jellyfin                    # group read on the media
```

## Library

- Libraries: Movies, Series, Anime, Music, Books, all under `/data/media`.
- The mount is **read-only**: the [arr stack](../ct-220-arr/) owns the library, and Jellyfin only reads it. Metadata savers are off (`SaveLocalMetadata=false`), so nothing tries to write `.nfo` files or artwork there. Everything Jellyfin knows lives in `/var/lib/jellyfin` on the CT's rootfs, which is in the weekly vzdump.
- To delete something, use Radarr or Sonarr, not Jellyfin. The files are hardlinked to the torrents, so a delete in Jellyfin wouldn't free any space anyway.

## Theme

[Jellyfish](https://github.com/n00bcodr/Jellyfish) with the **midnight** palette, pasted into *Dashboard → General → Custom CSS*. The full sheet is in [`custom.css`](custom.css).

The imports are **pinned to a commit** (`Jellyfish@206f50d80a29`). Without a pin jsDelivr serves the branch head, so upstream changes reached the server without anyone noticing. To update, bump the SHA on purpose and check the home page on a phone and a desktop.

| Layer | Why |
| --- | --- |
| `theme.css` | The base. Of the themes I tried, Jellyfish was the only one that explicitly supports Jellyfin 12's new Modern (React/MUI) layout, and it's actively maintained |
| `colors/midnight.css` | Royal-blue accent on near-black |
| `jellyfin-enhanced.css` | Styles the Jellyfin Enhanced panels to match |
| `lite.css` | Less blur, fewer shadows and entrance animations. The browser felt laggy while the server sat idle |
| Media Bar hero, desktop/tablet (≥768 px wide, >600 px tall) | Lifts the hero (logo, Play, dots) clear of the first home row. With Jellyfish's header, the Play button landed on the first row title |
| Media Bar hero, phone portrait | Drops Media Bar's glass card, which hid the artwork, in favor of a bottom scrim that fades into the page. The hero sits right above the rows, with a smaller logo, and pause/settings sit under the header with a shadow so they stay visible. The info line lets the genre shrink before the age rating gets cut off, and screens ≤400 px drop the critics score |
| Media Bar hero, short landscape (≤600 px tall) | Keeps the hero below the floating header: tighter spacing, smaller logo, no plot |

Checked in headless Chromium at 360, 390 and 440 px phones, 844×390 landscape, 768×1024 and 1024×768 tablets, 1366×768 and 1920×1080.

Rejected: **ElegantFin** (needs a "temporary" companion sheet on the Modern layout), **Finimalism** (targets 10.11), **Ultrachromic** (Modern layout unverified). Jellyfish's `slideshow-compact-mobile.css` was tried and removed, because it made the first row overlap the hero.

## Plugins

Every plugin's target ABI was checked in its `meta.json`. 12.x is a new major, and an old plugin just fails to load.

| Plugin | Version | What it's for | Settings changed |
| --- | --- | --- | --- |
| [Intro Skipper](https://github.com/intro-skipper/intro-skipper) | 12.0.6 | Detects intros, credits, recaps and previews | Auto-skip intro and credits on |
| [Home Screen Sections](https://github.com/IAmParadox27/jellyfin-plugin-home-sections) | 3.0.4 | Netflix-style home rows | **Enabled** (it ships off), lazy load on. Rows: Continue Watching/Next Up → Recently Added Movies → Recently Added Shows → Because You Watched ×2 → Genre ×2 → Collections → My Media last. Users can override. Upcoming rows need Sonarr/Radarr keys in its settings (not set yet) |
| [Media Bar](https://github.com/IAmParadox27/jellyfin-plugin-media-bar) | 3.0.2 | Featured carousel on the home page | Trailers and slide animation **off**: the background YouTube trailer and the pan/zoom were the hero lag. It requests artwork at full size (a 4K backdrop is 422 KB, versus 77 KB at 1280 px WebP), about 1–2 MB per slide, with no setting to change it |
| [Jellyfin Enhanced](https://github.com/n00bcodr/Jellyfin-Enhanced) | 12.14 | Quality-of-life suite | Seerr search and requests (users are auto-imported into Seerr), links to Sonarr/Radarr/Bazarr, audio-language flags and resolution/HDR badges on posters, and "remove from Continue Watching". Its own auto-skip stays off (Intro Skipper does that), analytics off |
| [InPlayerEpisodePreview](https://github.com/Namo2/InPlayerEpisodePreview) | 2.5.0 | Episode list inside the player | defaults |
| [TMDb Box Sets](https://github.com/jellyfin/jellyfin-plugin-tmdbboxsets) | 15 | Automatic movie collections | defaults |
| [Fanart](https://github.com/jellyfin/jellyfin-plugin-fanart) | 15 | Logos, clearart, extra backdrops | defaults |
| [AniList](https://github.com/jellyfin/jellyfin-plugin-anilist) | 15 | Anime metadata | defaults |
| [File Transformation](https://github.com/IAmParadox27/jellyfin-plugin-file-transformation), [Plugin Pages](https://github.com/IAmParadox27/jellyfin-plugin-pages) | 3.0.3 | Dependencies of the plugins above | defaults |

Plugin repositories added next to the stable one:

```
https://intro-skipper.org/manifest.json
https://www.iamparadox.dev/jellyfin/plugins/manifest.json
https://raw.githubusercontent.com/n00bcodr/jellyfin-plugins/main/manifest.json
https://raw.githubusercontent.com/Namo2/InPlayerEpisodePreview/master/manifest.json
```

The Intro Skipper manifest only answers requests from a Jellyfin server, so opening it in a browser looks broken. That's expected.

Deliberately skipped:

| Plugin | Why |
| --- | --- |
| Playback Reporting | Jellystat in [CT 225](../ct-225-apps/) covers it |
| Open Subtitles, Subtitle Extract | Bazarr in [CT 220](../ct-220-arr/) does subtitles |
| Jellyscrub | Trickplay is native now, and its last ABI is 10.10 |
| Chapter Segments Provider | Overlaps Intro Skipper |
| Skin Manager | Abandoned (ABI 10.7) |

## Playback preferences

Some releases carry several audio tracks with the "wrong" one flagged as default. Each user has `AudioLanguagePreference=eng` and `PlayDefaultAudioTrack=false`, so the preferred language wins over the file's flag. *Remember audio selections* stays on, so a series already started in another language keeps it until it's switched once in the player.

## Transcoding

It's **CPU only** for now: the 5600X has no iGPU, and the GT 610 is too old. Once the lab's Ryzen 7 5700G moves in, AMD VA-API (H.264 and HEVC 8/10-bit, no AV1) is one line in `/etc/pve/lxc/222.conf`:

```
dev0: /dev/dri/renderD128,gid=<render gid in the CT>
```

Because it's CPU-only, **throttling** and **segment deletion** are on: ffmpeg pauses once it's far enough ahead of the player instead of transcoding the whole file flat out. Trickplay (scrub previews) uses **keyframe-only extraction**, which is much faster on CPU and looks nearly the same.

## Clients

The web client runs a ~5.6 MB bandwidth test (`/Playback/BitrateTest`) every time it opens while *Maximum streaming quality* is on Auto. On the LAN that's wasted, so pick a fixed quality in each device's Playback settings.

## Operations

```bash
apt update && apt upgrade jellyfin            # updates come from the official repo
journalctl -u jellyfin -f
```

Requests come from **Seerr** ([CT 220](../ct-220-arr/)) and stats from **Jellystat** ([CT 225](../ct-225-apps/)); each has its own Jellyfin API key.
