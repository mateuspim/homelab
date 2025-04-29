# Storage

This section describes my storage solution running on my homelab. Recently, I had all my ZFS pools managed via TrueNas, however I intend to use Proxmox from now on to manage all my storage needs.

## Proxmox

My current setup involves a single NVMe drive to manage both boot drive and storage for containers and VMs and HDD in ZFS configuration to serve as my NAS.

## Initial Setup

Since I'm using Proxmox for personal purposes, I must disable the enterprise repositories to ensure proper updates.

#### Disable Enterprise Repositories

![](https://github.com/mateuspim/homelab/blob/main/storage/assets/proxmox_enterprise_repo.png?raw=true)

1. Navigate to _Node > Repositories_ Disable the enterprise repositories.
2. Now click Add and enable the no subscription repository. Finally, go _Updates > Refresh_.
3. Upgrade your system by clicking _Upgrade_ above the repository setting page.

#### Enable IOMMU

Enable IOMMU on in grub configuration within _Node > Shell_.

```
nano /etc/default/grub
```

Add `intel_iommu=on` or `amd_iommu=on` to the `GRUB_CMDLINE_LINUX_DEFAULT` line depending on your system

```
# Should look like this
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"
```

![](https://github.com/mateuspim/homelab/blob/main/storage/assets/proxmox_enable_iommu.png?raw=true)
Next run the following commands and reboot your system.

```
update-grub
reboot
```

Now check to make sure everything is enabled.

```
dmesg | grep -e DMAR -e IOMMU
dmesg | grep 'remapping'
```

If a message similar to the one below appears, everything was done correctly. Note that the exact message may vary depending on your system configuration.

```
AMD-Vi: Interrupt remapping enabled
```

Now PCI-Passthrough is enabled and ready for future VMs

## Create ZFS Pools

We will create the main ZFS Pool to serve as the NAS for home lab applications.

First, in the _Node > Disk_ section we must wipe all disks that will be part of the ZFS Pool.

After that, we must go to _Disks > ZFS > Create: ZFS_. This will pop up the screen to create a ZFS pool.

From this screen, select all drives that will be part of the pool, name it and select your RAID level.
![](https://github.com/mateuspim/homelab/blob/main/storage/assets/proxmox_create_zfs.png?raw=true)

#### Some ZFS Commands

The command below lists all ZFS availables on your system

```
zpool list
```

However, this command shows your pools with correct available storage left

```
zfs list
```

## Creating LXC containers

First, we are going to create a LXC to host our mount points from the ZFS pool and share them via SMB. To do so, we must download an CT template so go to _Node > local (node) > CT Template_ and click on _Templates_ this will pop up a screen with various LXC conateiners to choose from, for now I'll pick the Ubuntu 24-10.

Now click on _Create CT_ button on top of the page. Configure the new LXC Container and create it

### Mount Points

Before starting it for the first time, first we must add our data volumes to the LXC Containers by going on _Node > LC container > Resources_ then press _Add_ and select _Mount Point_. In here, I'll create two mount points:

- Media: which will take as much space as possible from the pool
- Docker: for docker configurations files

### SMB Shares

Once inside don't forget to run first the command `sudo apt update && sudo apt upgrade -y` to upgrade your system.

Now for the SMB shares

1. Create an user using `adduser pym && adduser pym sudo `
2. Set permissions of mount points

```
sudo chown -R pym:pym /data
sudo chown -R pym:pym /docker
```

3. Install Samba

```
sudo apt install samba
```

4. Back up default Samba configuration

```
cd /etc/samba
sudo mv smb.conf smb.conf.old
```

5. Edit the Samba configuration file

```
sudo nano smb.conf
```

My Samba configuration file

```
[global]
   # General Samba settings
   server string = Media  # Description of the server
   workgroup = WORKGROUP  # Workgroup name for Windows compatibility
   security = user        # Authentication mode
   map to guest = Bad User  # Map unknown users to guest
   name resolve order = bcast host  # Name resolution order
   hosts allow = 192.168.50.0/24  # Allow access from this subnet
   hosts deny = 0.0.0.0/0         # Deny access from all other addresses

[data]
   # Configuration for the "data" share
   path = /data  # Path to the shared directory
   force user = pym  # Force all file operations to use this user
   force group = pym  # Force all file operations to use this group
   create mask = 0774  # Permissions for newly created files
   force create mode = 0774  # Enforce specific file permissions
   directory mask = 0775  # Permissions for newly created directories
   force directory mode = 0775  # Enforce specific directory permissions
   browseable = yes  # Make the share visible in network browsers
   writable = yes  # Allow write access
   read only = no  # Do not restrict to read-only
   guest ok = no  # Do not allow guest access

[docker]
   # Configuration for the "docker" share
   path = /docker  # Path to the shared directory
   force user = pym  # Force all file operations to use this user
   force group = pym  # Force all file operations to use this group
   create mask = 0774  # Permissions for newly created files
   force create mode = 0774  # Enforce specific file permissions
   directory mask = 0775  # Permissions for newly created directories
   force directory mode = 0775  # Enforce specific directory permissions
   browseable = yes  # Make the share visible in network browsers
   writable = yes  # Allow write access
   read only = no  # Do not restrict to read-only
   guest ok = no  # Do not allow guest access
```

6. Add user to smb

```
sudo smbpasswd -a pym
```

7. Set services to auto start on reboot

```
sudo systemctl enable smbd
8. Allow Samba on the firewall to ensure proper communication between devices on the network. This step is necessary because firewalls can block Samba traffic, preventing file sharing and discovery from functioning correctly.
sudo systemctl restart smbd
sudo systemctl restart nmbd
```

8. Allow samba on firewall if you run into any issues.

```
sudo ufw allow Samba
sudo ufw status
```

9. [Optional] Install wsdd for Windows discovery

`wsdd` (Web Services Dynamic Discovery) allows Samba shares to be discovered by Windows machines on the network, making it easier to access shared resources without manually entering network paths.

```
sudo apt install wsdd
```
