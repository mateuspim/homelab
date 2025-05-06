# Raspberry PI server

This section provides an overview of my Raspberry Pi server, which is configured to host Pihole with Unbound and a simple Homer Dashboard for all my server applications.

## Setup

### <img width="30" alt="Homer's donut" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/pi-hole.png"> Pihole with Unbound

[Pihole](https://github.com/pi-hole/pi-hole/#one-step-automated-install) in itself is great to serve as a ad-blocking DNS service but it can be enhanced further when paired with [Unbound](https://docs.pi-hole.net/guides/dns/unbound/) to create an All-Around DNS solution for your home LAN. 
However, both setup and management are extensive, so I'll provide a link to a YouTube guide made by [Craft Computing](https://www.youtube.com/@CraftComputing) that explains all the steps to create your own Recursive DNS Server below.

[![You're running Pi-Hole wrong! Setting up your own Recursive DNS Server!](https://img.youtube.com/vi/FnFtWsZ8IP0/0.jpg)](https://www.youtube.com/watch?v=FnFtWsZ8IP0)

### <img width="30" alt="Homer's donut" src="https://cdn.jsdelivr.net/gh/selfhst/icons/png/homer.png"> Homer Dashboard

Homer is a simple static homepage for your server, allowing you to manage services via a [YAML](config.yml) configuration. It can be easily deployed using Docker:

```
# Make sure your local config directory exists
docker run -d \
  --name homer \
  -p 8080:8080 \
  --mount type=bind,source="/path/to/config/dir",target=/www/assets \
  --restart=unless-stopped \
  b4bz/homer:latest
```
Alternatively, you can use [```docker-compose```](compose.yaml)
```
services:
  homer:
    image: b4bz/homer
    container_name: homer
    volumes:
      - /path/to/config/dir:/www/assets # Make sure your local config directory exists
    ports:
      - 8080:8080
    user: 1000:1000 # default
    environment:
      - INIT_ASSETS=1 # default, requires the config directory to be writable for the container user (see user option)
    restart: unless-stopped
```

#### Homer Themes
Homer allows you to customize its appearance with various themes and styles. To apply a theme, download the desired theme files and place them in your configuration directory. You can explore more customization options and themes in the [Homer documentation](https://github.com/bastienwirtz/homer/blob/main/docs/theming.md) or community repositories. 

I personally like the [Homer Theme v2](https://github.com/lammersbjorn/homer-theme), which provides a clean and modern look.

<p align="center">
   <img alt="Homer Theme" src="https://raw.githubusercontent.com/WalkxCode/Homer-Theme/main/preview.png">
</p>