# Jellyfin Setup
This section describes all my Jellyfin configurations

## Setup

### Installation

The [Jellyfin](https://github.com/jellyfin/jellyfin) server can be installed directly to the OS using a simple [shell script](https://jellyfin.org/docs/general/installation/linux/#debian--ubuntu-and-derivatives) (if using Linux); however, Docker simplifies updates, provides better isolation, and is easier to maintain compared to direct installation.

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

When using the Device Passthrough feature in Proxmox VMs, the resource becomes tied to a specific VM and cannot be shared with others. To enable multiple VMs to share the same resource, it is necessary to switch to using LXC Containers, which is the approach I am now adopting.

Setting up a new LXC Container is as simple as pressing the _Create CT_ button at the top of the page.

- **Note:** Ensure **Unprivileged Container** is **unchecked** for enabling hardware transcoding later.
![Create CT Example](../assets/proxmox_create_container.png)

**Note** If this is the first LXC container you are creating, I recommend refraining from installing Jellyfin for now. Instead, install all necessary NVIDIA software, such as the NVIDIA drivers and CUDA toolkit, so you can later clone this container for new LXC containers as needed.

## Hardware Transcoding

This section will focus on transcoding with NVIDIA GPUS. 
![Promox Transcoding Example](../assets/proxmox_transcoding.png)

### Proxmox + LXC container Setup

Installing NVIDIA Drivers is a lengthy process, and there is ample documentation on the web. Key steps include installing the NVIDIA drivers in the host system, and configuring the LXC container to allow GPU passthrough by modifying its configuration file to include the necessary device mappings. 
To do so, I checked the following guides for detailed instructions:
* [NVidia Proxmox + LXC](https://gist.github.com/egg82/90164a31db6b71d36fa4f4056bbee2eb) guide for enabling the NVIDIA GPU on LXC Containers
* [HWA Tutorial On NVIDIA GPU](https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/nvidia/) guide on the Jellyfin page, which covers enabling hardware acceleration, configuring the NVIDIA GPU, and optimizing transcoding settings for better performance.

#### Notes

##### Nvidia Drivers
Proxmox VE 7.0 or greater defaults to the pure cgroupv2 environment, which is the next-generation Linux control group system used for resource management. This change is relevant to Jellyfin's hardware transcoding setup because cgroupv2 introduces a new way of managing device access, which requires updated configuration for GPU passthrough in LXC containers. It offers improved performance and flexibility compared to cgroupv1, which is being phased out in systemd and other tools. As a result, I had to modify the guide to reflect this change by updating the lines from:
```
lxc.cgroup.devices.allow: c <number from previous step>:* rwm
lxc.cgroup.devices.allow: c <number from previous step>:* rwm
lxc.cgroup.devices.allow: c <number from previous step>:* rwm
```
to:
```
lxc.cgroup2.devices.allow: c <number from previous step>:* rwm
lxc.cgroup2.devices.allow: c <number from previous step>:* rwm
lxc.cgroup2.devices.allow: c <number from previous step>:* rwm
```

Source: [Typhox/Proxmox-forum](https://forum.proxmox.com/threads/pve-7-0-lxc-intel-quick-sync-passtrough-not-working-anymore.92025/)

##### SSH in LXC Container
Enabling ssh in LXC Container without SSL Keys by modifying the `/etc/ssh/sshd_config` file by changing:
```
#PermitRootLogin NoPassword
to
PermitRootLogin yes
```
Then after runinng: 
```
sudo service sshd restart
```

### Important: Rollback SSH Configuration

**Warning:** After completing all configurations, you must **rollback the SSH configuration** for better security. Ensure you revert the changes made to the `/etc/ssh/sshd_config` file by setting:
```
PermitRootlogin yes
to
#PermitRootLogin NoPassword
```

## Mount Points

There are two ways to enable your SMB shares in an LXC container: you can add them directly through `/etc/fstab`, or you can add them as **Mount Points** in Proxmox. To do this, go to _Datacenter → Storage → Add → SMB/CIFS_. After entering all the correct information, the share dropdown menu will allow you to select the desired SMB shares from that server. Repeat this process for each share you want to add.

**Note:** Make sure **Content** is set to **Disk image**.  
![Add SMB/CIFS share to Proxmox](../assets/proxmox_add_smb-cifs-share.png)

After completing this step, you need to add new lines to the `/etc/pve/lxc/<container-id>.conf` file as shown below:

**Note:** Performing this step will "disable" cloning of this LXC container, as Proxmox does not clone mount points.
```
mp0: /mnt/pve/docker,mp=/docker
mp1: /mnt/pve/data,mp=/data
```

## Permissions

Changing permissions are only necessary for the OS install of jellyfin.
Now after all configured and setup just spin up the machine.
But first we must fix the permissions of the Jellyfin user by:

1. Stop the Jellyfin service. `sudo systemctl stop jellyfin` 
2. Edit the Jellyfin service configuration to reflect your user. `sudo nano /lib/systemd/system/jellyfin.service`. Now change the `user` and `group` to your main user. You can run the `id` command if you're unsure.

```
[Unit]
Description = Jellyfin Media Server
After = network-online.target

[Service]
Type = simple
EnvironmentFile = /etc/default/jellyfin
User = user # Change this user
Group = group # Change this group
WorkingDirectory = /var/lib/jellyfin
ExecStart = /usr/bin/jellyfin $JELLYFIN_WEB_OPT $JELLYFIN_FFMPEG_OPT $JELLYFIN_SERVICE_O>
Restart = on-failure
TimeoutSec = 15
SuccessExitStatus=0 143

[Install]
WantedBy = multi-user.target
```

3. Now change the permissions of the Jellyfin files and folders.

```
sudo chown -R user:group /etc/default/jellyfin
sudo chown -R user:group /usr/bin/jellyfin
sudo chown -R user:group /var/lib/jellyfin/
sudo chown -R user:group /etc/jellyfin/
sudo chown -R user:group /var/log/jellyfin/
sudo chown -R user:group /var/cache/jellyfin/
sudo chown -R user:group /usr/share/jellyfin
sudo chown -R user:group /usr/share/jellyfin-ffmpeg
sudo chown -R user:group /usr/lib/jellyfin/
sudo chown -R user:group /usr/lib/jellyfin-ffmpeg/
sudo chown -R user:group /tmp/jellyfin/
```

4. Reload the daemon and restart jellyfin
```
sudo systemctl daemon-reload
sudo systemctl restart jellyfin
```

5. Check the user that is running Jellyfin
```
ps -aux | grep jellyfin
```

Source: [tteck/Proxmox#286](https://github.com/tteck/Proxmox/discussions/286)

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

For some plugins to work correctly with the Docker Container it may be necessary to change the permissions of the ```index.html``` file by:

**Note** replace `user` and `group` with the `user` and `group` of your container
```
docker exec -it --user root jellyfin chown user:group /usr/share/jellyfin/web/index.html && docker restart jellyfin
```

## Tools

To enhance your experience running Jellyfin, I recommend the following tools:

#### Jellyseerr

Jellyseerr is an application for managing requests for your media library. For more info, visit the [Jellyseerr GitHub repository](https://github.com/fallenbagel/jellyseerr).

#### Jellystat
An all-purpose Statistics tool for Jellyfin. For more info, visit the [Jellystat GitHub repository](https://github.com/CyferShepard/Jellystat).
