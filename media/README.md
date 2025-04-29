# Media Server
This section describes my self hosted media server. Running on a VM in Proxmox with Debian 12

## Setup

### Installation

First we must download the Debian ISO, to do so go to _Node > local (node) > ISO Images_ in this step you can both upload your own ISO image or Download from URL as shown below:
![](https://github.com/mateuspim/homelab/blob/main/media/assets/proxmox_download_iso.png?raw=true)

After the ISO downloads/uploads, we must create a VM and install the Ubuntu Server, to do so simply press the _Create VM_ on top of the page and follow the instructions to create a VM.
![](https://github.com/mateuspim/homelab/blob/main/media/assets/proxmox_create_vm.png?raw=true)

Then just start the newly created VM and run normally torugh the installation of the Ubuntu server. If a message appears on the end saying [FAILED] Failed unmounting cdrom.mount, stop the VM and manually check if the ISO mount was removed correctly on _VM > Hardware_, if not remove it.

Once inside don't forget to run first the command `sudo apt update && sudo apt upgrade -y` to upgrade your system.

### Adding Mount Points

So now we must add our Samba share to auto mount everytime this VM boots in order to do this we must:

1. Create an entry for the mount points
```
sudo mkdir /mnt/data /mnt/docker
```

3. Edit ```/etc/fstab``` and add: 
```
//192.168.50.202/data /mnt/data cifs credentials=/home/pym/.smbcredentials,uid=1000,gid=1000 0 0
```

2. Create the ```~/.smbcredentials``` file in your home directory:
```
username=pym
password=password
domain=media
```

3. Make sure you secure your ```~/.smbcredentials``` file:
```
chmod 0600 ~/.smbcredentials
```

4. Mount with:
```
sudo mount -a
```