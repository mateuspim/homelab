# Jellyfin Setup
This section describes all my Jellyfin configurations

## Setup

### Installation

The [Jellyfin](https://github.com/jellyfin/jellyfin) server can be installed directly to the OS using a simple [shell script](https://jellyfin.org/docs/general/installation/linux/#debian--ubuntu-and-derivatives) (if using Linux); however, using Docker is recommended as it simplifies updates, provides better isolation, and is easier to set up and maintain.

Below is an example of a simple Docker Compose configuration for Jellyfin
```
  jellyfin:
    image: lscr.io/linuxserver/jellyfin:latest
    container_name: jellyfin
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=America/Sao_Paulo
    volumes:
      - /docker/jellyfin/library:/config
      - /mnt/data/series:/data/tvshows
      - /mnt/data/movies:/data/movies
      - /mnt/data/anime:/data/anime
    ports:
      - 8096:8096
    # - 8920:8920       # Https webUI
      - 7359:7359/udp   # Service Discovery
      - 1900:1900/udp   # Client Discovery
    restart: unless-stopped
```

## Hardware Transcoding

wip

## Plugins

There are a lot of awesome Jellyfin themes and plugins available to use right off the bat with your Jellyfin server. These can be found on [awesome-jellyfin](https://github.com/awesome-jellyfin/awesome-jellyfin). Some of the ones I use are:

- [intro-skipper](https://github.com/intro-skipper/intro-skipper) - Fingerprint audio to automatically detect intro and outro segments in Jellyfin.
- [InPlayerEpisodePreview](https://github.com/Namo2/InPlayerEpisodePreview) - Adds an episode list to the video player.
- [jellyfin-editors-choice-plugin](https://github.com/lachlandcp/jellyfin-editors-choice-plugin) - Adds a Netflix-style, full-width content slider to the home page to feature selected content.
- [jellyfin-icon-metadata](https://github.com/Druidblack/jellyfin-icon-metadata) - Adds metadata provider icons to Jellyfin.
- [jellyfin-plugin-animethemes](https://github.com/EusthEnoptEron/jellyfin-plugin-animethemes?tab=readme-ov-file) - Fetches anime opening and ending themes from AnimeThemes.moe, supporting both audio and video.
- [jellyfin-plugin-home-sections](https://github.com/IAmParadox27/jellyfin-plugin-home-sections) - Allows users to customize the jellyfin-web home screen with dynamic sections like "Because You Watched" and "Latest Movies".
- [jellyfin-plugin-skin-manager](https://github.com/danieladov/jellyfin-plugin-skin-manager)- Helps you to download and install skins.

#### Notes

For some plugins to work correctly it my be necessary to change the permissions of the ```index.html``` file by:

**Note** replace user and group with the user and group of your container
```
docker exec -it --user root jellyfin chown user:group /usr/share/jellyfin/web/index.html && docker restart jellyfin
```

## Tools

To enhance your experience running Jellyfin, I recommend the following tools:

#### Jellyseerr

Jellyseerr is an application for managing requests for your media library. For more info, visit the [Jellyseerr GitHub repository](https://github.com/fallenbagel/jellyseerr).

#### Jellystat
An all-purpose Statistics tool for Jellyfin. For more info, visit the [Jellystat GitHub repository](https://github.com/CyferShepard/Jellystat).
