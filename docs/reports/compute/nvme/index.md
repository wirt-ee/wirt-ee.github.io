# Old server, new NVMe

An old server, an NVMe drive that works fine, and a BIOS that simply does not have "NVMe" in its boot devices list. The firmware can see the disk with a driver — it just cannot boot from it. The fix is a boot chain that loads the driver first: a Clover/rEFIND USB stick carrying `NvmExpressDxe.efi`.

## The stick

    dd if=Refind_with_NVMEExpressDxe.img of=/dev/sda bs=4M status=progress

## In the UEFI shell

Boot the stick into the UEFI shell, then load the driver, remap, and boot the disk's own EFI loader:

    ls fs0:\efi\clover\drivers\uefi
    load -nc fs0:\efi\clover\drivers\uefi\NvmExpressDxe.efi
    map -r
    fs0:\efi\boot\bootx64.efi

After `map -r` the NVMe partitions appear as filesystems — the EFI partition may be the first one after the remap. From there the disk's own bootloader takes over, and the machine boots its real OS from the drive the BIOS insists does not exist.

The trick, and where the details live:

- [Booting NVMe on an older PC with rEFInd — Hamish MB](https://www.hamishmb.com/blog/booting-nvme-older-pc-refind/)
- [Loading the NVMe driver in a UEFI shell — ntzyz.io](https://ntzyz.io/post/load-nvme-driver-in-uefi-shell?prefer-language=en)

Caveat from the bench: every reboot walks the whole chain again — UEFI shell, driver load, remap — unless the firmware can be coaxed into remembering it. Three machines like this run my test OpenStack nodes today. They live with it.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
