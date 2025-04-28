# Storage
This section describes my storage solution runinng on my homelab. Recently, i had all my ZFS pools managed via TrueNas, however i intend to use Proxmox from now on to manage all my storage needs.

## Proxmox
My current setup involves a single NVMe drive to manage both boot drive and storage for containers and VMs and HDD in ZFS configuration to serve as my NAS.

## Initial Setup
As Im running proxmox for personal i must disable the enterprise repositories for it to update properly down the line. 

#### Disable Enterprise Repositories
![](https://github.com/mateuspim/homelab/blob/main/assets/proxmox_enterprise_repo.png?raw=true)
1. Navigate to _Node > Repositories_ Disable the enterprise repositories.
2. Now click Add and enable the no subscription repository. Finally, go _Updates > Refresh_.
3. Upgrade your system by clicking _Upgrade_ above the repository setting page.

#### Enable IOMMU
Enable IOMMU on in grub configuration within _Node > Shell_.
```
nano /etc/default/grub
```
Add `intel_iommu=on` or `amd_iommu=on` depending on your system
```
# Should look like this
GRUB_CMDLINE_LINUX_DEFAULT="quiet amd_iommu=on"
```
![](https://github.com/mateuspim/homelab/blob/main/assets/proxmox_enable_iommu.png?raw=true)
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
If the following message appears everything was done correctly. It may vary depending on your system
```
AMD-Vi: Interrupt remapping enabled
```
Now PCI-Passthrough is enabled and ready for future VMs

## Create ZFS Pools

Here we are going to create the main ZFS Pool which serves as main NAS for all my home lab applications.

First, in the _Node > Disk_ section we must wipe all disks that will be part of the ZFS Pool.

After that, we must go to _Disks > ZFS > Create: ZFS_. This will pop up the screen to create a ZFS pool.

From this screen, select all drives that will be part of the pool, name it and select your RAID level.
![](https://github.com/mateuspim/homelab)

#### Some ZFS Commands

The above command lists all ZFS availables on your system
```
zpool list
```
However, this command shows your pools with correct available storage left 
```
zfs list
```

Now its all setup for the VMs to come.