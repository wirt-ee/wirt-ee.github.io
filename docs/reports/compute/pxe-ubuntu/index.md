# PXE: Ubuntu live-server over TFTP

Install servers without touching a USB stick: the firmware fetches grub over TFTP, grub fetches kernel and initrd over TFTP, and the installer fetches the live ISO over HTTP. One tftp server, one web server, and a machine that installs itself.

## Server side

    apt-get install tftpd-hpa            # the TFTP service
    apt install tftp-hpa                 # for local testing
    apt-get install apache2              # for the live filesystem

The netboot EFI binaries — the firmware's entry point:

    cd /srv/tftp/EFI/BOOT
    wget https://releases.ubuntu.com/24.04/netboot/amd64/grubx64.efi
    wget https://releases.ubuntu.com/24.04/netboot/amd64/bootx64.efi

Kernel and initrd from the ISO you intend to serve:

    wget https://releases.ubuntu.com/24.04.3/ubuntu-24.04.3-live-server-amd64.iso -P /var/www/html/
    mkdir /var/www/html/ubuntu24.04 /srv/tftp/ubuntu24.04
    mount -o ro ubuntu-24.04.3-live-server-amd64.iso /mnt
    cp /mnt/casper/vmlinuz /mnt/casper/initrd /srv/tftp/ubuntu24.04/

## The grub menu

`/srv/tftp/grub/grub.cfg` — a local-drive entry first, the installer second:

    set timeout=10

    menuentry "Boot from local drive" {
        set root=(hd0,gpt1)
        chainloader /EFI/ubuntu/grubx64.efi
    }

    menuentry "Install Ubuntu Server 24.04" {
        linux (tftp)/ubuntu24.04/vmlinuz ip=dhcp \
            url=http://<server>/ubuntu-24.04.3-live-server-amd64.iso
        initrd (tftp)/ubuntu24.04/initrd
    }

The `url=` parameter is what makes the *live* installer network-fetched — no squashfs on the TFTP side, just the two small files.

## Permissions and the smoke test

    chown -R tftp:tftp /srv/tftp
    chmod -R 755 /srv/tftp
    find /srv/tftp -type f -exec chmod 644 {} \;
    chmod 755 /srv/tftp/EFI/BOOT/*.efi

    tftp localhost
    tftp> binary
    tftp> get EFI/BOOT/bootx64.efi
    tftp> quit

If the local test passes and real machines still hang, it is permissions on the TFTP root far more often than anything else.

## Testing without hardware

A libvirt VM with UEFI firmware boots PXE exactly like the metal does:

    <os>
      <type arch='x86_64' machine='pc-q35-6.2'>hvm</type>
      <loader readonly='yes' type='pflash'>/usr/share/OVMF/OVMF_CODE.fd</loader>
      <nvram>/var/lib/libvirt/qemu/nvram/vm-name_VARS.fd</nvram>
      <bootmenu enable='yes'/>
    </os>

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
