---
title: Generic
---

## Disk Destroyer
There is no better tool to arrange your bits to oblivian. But if a precise cut is needed, some commands are more valuable than others.
If your specific block size calculation is incorrect, you will lose your data!

## RAID
Metadata information is usually at the end of the device. If you want to re-use the device, you need to wipe it out. You have the option to wait and overwrite the entire disk:
```
root@demo:~# dd if=/dev/zero of=/dev/sdX bs=1M status=progress
```
Or zero out only parts Raid controller bothers to check:
```
root@demo:~# DEV='/dev/sdX'; dd if=/dev/zero of=$DEV bs=512 seek=$(( $(blockdev --getsz $DEV) - 1024 )) count=1024
```

## Software RAID and UEFI
If RAID card is not present but you need FAT for EFI boot and some redundancy:  
```
/dev/sda1 is efi and /dev/sdb1 is empty
root@demo:~# dd if=/dev/sda1 of=/dev/sdb1
root@demo:~# mkdir /boot/efi2
root@demo:~# blkid /dev/sda1
/dev/sda1: UUID="xxxx-xxxx" TYPE="vfat" PARTUUID="xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
root@demo:~# blkid /dev/sdb1
/dev/sdb1: UUID="xxxx-xxxx" TYPE="vfat" PARTUUID="yyyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyy"
root@demo:~# cat /etc/fstab  | grep efi
PARTUUID=xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx  /boot/efi       vfat    umask=0077      0       1
PARTUUID=xxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx  /boot/efi2      vfat    umask=0077      0       1
root@demo:~# efibootmgr -c -d /dev/sdb -p 1 -L "Ubuntu-AltDrv" -l '\EFI\ubuntu\shimx64.efi'
```

## Copy block device over network
Let's assume you already have a healthy dose of SSH in your bloodstream. Copy block device /dev/sdX content from one machine to another machine /dev/sdY with the command:
```
root@demo:~# ssh root@source.example "dd if=/dev/sdX" bs=1M | dd of=/dev/sdY bs=1M
```

## Swap to the resque
If you constantly get OOM killed and are happy to run your system randomly on glacier speed, then you can virtually add some RAM on the fly.  
'pv' may be needed to avoid killing already slow storage. Example how to add 32G to swap:   
```
root@demo:~# dd if=/dev/zero | pv --rate-limit 60m | dd iflag=fullblock of=/swapfile bs=1G count=32 #32G swap
root@demo:~# dd if=/dev/zero of=/swapfile bs=4k count=8388608
root@demo:~# mkswap /swapfile
root@demo:~# chmod 0600 /swapfile
root@demo:~# /sbin/swapon /var/swapfile; #'swapoff' if needed
```  
### Stretch Rocky Linux partion and filesystem
```
sfdisk --delete ${dev} 1
sfdisk ${dev} << EOF
2048,,83
EOF
mount ${dev}p1 /mnt
xfs_growfs /mnt
umount /mnt

```
### Stretch Ubuntu Linux partion and filesystem 
```
#growpart /dev/sda 1 # if available
sgdisk -d 1 /dev/rbdX
sgdisk -N 1 /dev/rbdX
e2fsck -y /dev/rbdXp1
resize2fs /dev/rbdXp1

#grow filesystem in VM
partprobe /dev/sda
growpart /dev/sda  1
resize2fs /dev/sda1
```

