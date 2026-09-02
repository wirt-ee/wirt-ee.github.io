# Server hardware: RAID and disks

Commands from the estate's server floors — HP SmartArray, LSI/Broadcom MegaRAID, 3ware, Areca, Dell MD arrays, an ETERNUS, external SAS shelves — and the disks behind them: SAS, SATA, SSD. Controller CLI tools are each a dialect; this page is the phrasebook. Hostnames are placeholders; the numbers in the cache-policy sections are real benchmark results, kept because they settle arguments.

## HP SmartArray (hpacucli / hpssacli / ssacli)

    ctrl all show config
    ctrl all show config detail
    ctrl all show status
    ctrl slot=0 pd all show status
    ctrl slot=0 enclosure all show detail        # free slots

Arrays:

    ctrl slot=0 create type=ld drives=2I:1:8 raid=0 ssdsmartpath=enable
    ctrl slot=0 create type=ld drives=2I:2:4,2I:2:5 raid=1
    ctrl slot=0 create type=ld drives=1I:1:2,1I:1:3,1I:1:4,2I:2:1,2I:2:2,2I:2:3 raid=6
    ctrl slot=0 ld 4 modify led=on               # find it in the dark
    ctrl slot=0 ld 4 delete

The SSD path: Smart Path on, controller write cache on, per-LD cache on:

    ctrl slot=0 array e modify ssdsmartpath=enable
    ctrl slot=0 modify dwc=enable                # controller-wide SSD write cache
    controller slot=0 logicaldrive 5 modify caching=enable

Swapping a spindle for an SSD on a live controller ends in `Last Failure Reason: Hot plug drive type mix` if you improvise. The order that works:

1. delete the logical array
2. pull the HDD
3. install the SSD
4. create the array

And the ceiling nobody reads about: a 3 Gbit SAS link tops at 384 MB/s — slower than the SSD behind it. Cache settings cannot fix physics; on such a port the honest config is cache off (`arrayaccelerator=disable` → `LD Acceleration Method: All disabled`).

## LSI / Broadcom MegaCLI

    megacli -AdpAllInfo -aALL                   # adapter
    megacli -AdpBbuCmd -aALL                    # battery/capacitor pack
    megacli -EncInfo -a0                        # enclosure
    megacli -LdPdInfo -a0                       # physical + virtual
    megacli -AdpEventLog -GetLatest 1000 -f events.log -aALL

Find which virtual drive owns `/dev/sdd` — the mapping is `scsi-H:B:T:L` against the target id:

    megacli -LDInfo -Lall -a0 | grep -E 'Virtual Drive|Device Id'
    targetId=0; dev=`ls -l /dev/disk/by-path/ | grep -E "scsi-[0-9]:[0-9]:${targetId}:[0-9] " | awk '{print($11)}'`; echo ${dev##*\/}

Create, blink, silence, delete:

    megacli -CfgLdAdd -r0[252:2,252:3] -a0      # raid0, one disk per VD for ceph
    megacli -CfgLdAdd -r1[64:2,64:3] -a0
    megacli -PdLocate -start -physdrv\[E:S\] -aALL
    megacli -AdpSetProp AlarmSilence -aALL      # the alarm knows something you don't yet
    megacli -CfgLdDel -L2 -a0
    megacli -GetPreservedCacheList -aALL        # orphaned write cache check

### Cache policy, measured

Two presets from production, settled by `ceph tell osd.N bench`, not by documentation:

**SSD VD — everything off** (bench: 293 MB/s, the disks' own speed):

    megacli -LDSetProp -WT -Immediate -L1 -a0
    megacli -LDSetProp -NORA -Immediate -L1 -a0   # NB! may not activate on first attempt
    megacli -LDSetProp -Direct -Immediate -L1 -a0
    megacli -LDSetProp NoCachedBadBBU -Immediate -L1 -a0
    megacli -LDSetProp -EnDskCache -Immediate -L1 -a0

**Spindle VD — everything on** (bench: 1222 MB/s, sequential reads where cache is king):

    megacli -LDSetProp WB -L1 -a0
    megacli -LDSetProp RA -L1 -a0
    megacli -LDSetProp -Direct -Immediate -L1 -a0
    megacli -LDSetProp NoCachedBadBBU -Immediate -L1 -a0
    megacli -LDSetProp -EnDiskCache -Immediate -L1 -a0

The `CachedBadBBU` / `NoCachedBadBBU` pair is the durability switch: write through a dead battery, or don't. The estate's answer was don't.

## SMART behind a controller

Disks behind a RAID controller are invisible to plain `smartctl` — address them by controller slot:

    # LSI: sat+megaraid,N or megaraid,N
    megacli -PDlist -a0 | grep '^Device Id:'
    smartctl -a -d sat+megaraid,1 /dev/sda | less
    for i in {0..30}; do smartctl -a -d sat+megaraid,$i /dev/sdb; done | egrep '(Model|Capacity)'

    # HP: cciss,N
    smartctl -a -d cciss,7 /dev/sg0 | egrep '(Wear_Leveling_Count|Total_LBAs_Written)'

The sweep earns its keep. One fleet check of two identical enterprise SSDs:

    Device Model:     LITEON IT ECE-400NAS
    SMART overall-health self-assessment test result: PASSED
    232 Available_Reservd_Space ... 028 ... In_the_past

    Device Model:     LITEON IT ECE-400NAS
    SMART overall-health self-assessment test result: FAILED!
    232 Available_Reservd_Space ... 006 ... FAILING_NOW

Same model, same batch, one at 6% reserved space and failing now. Without `-d megaraid,N`, the controller reported both as healthy.

Long tests and the fleet-wide spare check:

    smartctl -t long /dev/sdX                  # 1092 minutes on a big spindle; run it, forget it, read it tomorrow
    for i in {1..20}; do s=$(timeout 1 ssh node${i} "smartctl -a /dev/sda | grep 'Available Spare:'"); echo node$i: ${s}; done

## mdadm: the disk that left without a word

A raid1 with `Total Devices : 1`, one member simply gone — no failed state, just `removed`. Bringing it home:

    mdadm --zero-superblock /dev/sdb2          # clear whatever it last believed
    mdadm /dev/md0 --add /dev/sdb2
    mdadm -D /dev/md0                          # clean, degraded, recovering

And when a disk leaves md metadata behind that confuses the next installer, the blunt eraser — the last 1024 sectors:

    DEV='/dev/sdd'; dd if=/dev/zero of=$DEV bs=512 seek=$(( $(blockdev --getsz $DEV) - 1024 )) count=1024

## Secure erase and over-provisioning

The SSD that came back from the dead slow — 30 MB/s, 100 IOPS — is a firmware state, not a broken disk. What worked and what didn't, on the estate's Samsung enterprise SSDs:

- `blkdiscard /dev/sdX` — works, including on 7.68 TB Samsungs
- `hdparm --user-master u --security-erase` — **does not work** on them (`SECURITY_ERASE: Invalid argument`, kernel lacks the ioctl); on the disks where it did work, it took a 30 MB/s disk back to 500 MB/s
- Samsung DC Toolkit for real control:

        # over-provisioning: 6.7% is default, adding 13.3%
        ./Samsung_SSD_DC_Toolkit_for_Linux_V2.1 -d 2 -E           # erase
        ./Samsung_SSD_DC_Toolkit_for_Linux_V2.1 -d 2 -M -s 6526284578
        #   Disk Capacity updated to 3111GB. SET MAX Operation Completed.
        #   PowerCycle the disk.        <- a physical power pull, not a reboot

After the OP change the raw device wrote at 31 MB/s (`dd`, zeroing) while the OSD on top benched at 509 MB/s — because the dd was re-trimming freshly-narrowed cells and the bench was reading what the extra reserve now absorbed.

## Firmware walls

Three walls, hit at speed:

- **IBM x3750 M4, ServeRAID M5110e**: the BOMC-built update ISO contains the wrong files — the flasher answers `Controller 0 is an unknown type, or is not supported by this update` on the exact controller it was built for. No flash.
- **Lenovo SR850, ThinkSystem RAID 930-8i**: virtual disks not detected at install time — check the Ubuntu certification page before believing the controller.
- **Samsung PM863a and PM883**: *data corruption can occur during background operations* because the firmware clears the UECC flag by mistake (Lenovo advisory HT507431). Firmware on storage is not cosmetic; it is part of the data path.

## External SAS shelves

The shelf bring-up ritual: multipath on, then make the host look:

    dnf install device-mapper-multipath.x86_64 pciutils
    mpathconf --enable --with_multipathd y
    lsscsi --wwn
    echo "- - -" > /sys/class/scsi_host/host1/scan
    echo "- - -" > /sys/class/scsi_host/host6/scan

The WWN trail in `dmesg` — HBA sas_addr, SSP device, enclosure logical id, slot — is the shelf telling you where everything lives; capture it once and the multipath.conf aliases write themselves.

At end of life the shelves bit back: CentOS 8 dropped SAS-2 HBA support from `mpt3sas`, and the fix is a driver update disk:

    wget https://elrepo.org/linux/dud/el8/x86_64/dd-mpt3sas-<ver>-1.el8_0.elrepo.iso
    mount -o loop dd-mpt3sas-<ver>-1.el8_0.elrepo.iso /mnt
    rpm -i /mnt/rpms/x86_64/kmod-mpt3sas-<ver>-1.el8_0.elrepo.x86_64.rpm
    rmmod mpt3sas && modprobe mpt3sas

Older shelves speak VxWorks on their management port — telnet in, `netCfgShow` — a different century of management, documented here because it still answered.

## Dell MD arrays (SMcli)

The one worth remembering: after a power outage, every logical drive `Failed`, yet every physical disk `Optimal`. The controller had lost confidence, not the disks. Parity check refuses to run in that state (`Error 38` — fix the non-optimal drives first, it says, pointing at drives with nothing wrong). The command that brings the array back:

    SMcli <controller> -c 'revive array["8"];'

The Estonian comment in the notes, translated: *it raises all logical drives at once, since the disks underneath show no fault — otherwise each disk would have to be brought up one by one.* An array that fails on power, with healthy disks, is a metadata problem; `revive` is the metadata saying so.

Around it, the usual interrogation:

    SMcli <controller> -c "show logicalDrives;"
    SMcli <controller> -c 'show controller [a] summary;'
    SMcli <controller> -c 'show AllDrives;' | grep Status | grep -v Optimal

## The smaller dialects

**3ware (tw-cli):** `tw-cli /c4 show` lists units and ports; `/c4/u0 show` the members. A RAID-1 pair of Hitachis on a 9650SE, status at a glance.

**Areca (cli64):** a disk showing `Failed` with 0.0GB after a hiccup — `disk activate drv=3` and it rejoins the raid set; `rsf info` to watch the rebuild. Sometimes a disk is not broken, merely sulking.

---

*Every page in these reports is a compressed incident report. If your estate has shelves that speak VxWorks and controllers that lie about batteries — [info@wirt.ee](mailto:info@wirt.ee).*

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
