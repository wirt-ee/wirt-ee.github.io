---
date: 2011-05-20
tags: [netapp, ontap, san, fcp, dr, mysql]
description: "The DR test: clone production SQL database LUNs from a nightly snapshot, boot them on a test server over FCP, prove it lives, destroy everything."
---

# NetApp DR test: LUN clones over FCP

Context: an earlier role, 2011 — NetApp filers, SAN fabrics, data backup, where the only proof of a backup is a restore. A backup that has never been restored is a rumour, and the only honest answer to "can we recover this?" is to do it. These notes are the proof-of-recoverability runs: clone a production database — 7.3 TB of LUNs — from a nightly snapshot onto a test server, boot it, bring the database up, then erase every trace. Filer, server and domain names below are genericized; LUN and snapshot names are placeholders; serials and ticket numbers never appear. Commands and errors are as they happened.

## The idea

Nothing is copied. A LUN clone on Data ONTAP is copy-on-write: `-o noreserve`, based on a snapshot, ready in seconds regardless of size. The snapshot is the backup; the clone is the proof.

    lun clone create /vol/<vol>/<db>_sqldata_test -o noreserve \
        -b /vol/<vol>/<db>_qt/sqldata <snapshot>

Four LUNs per test: the database (clone), the operating system (clone), and two fresh 10G LUNs for MySQL's binlog and tmp — a cloned server should not write its binary logs into history that belongs to production.

## The mechanics that bite

**A LUN must go offline before its serial can change** — the clone inherits the donor's serial, and two identical serials on one fabric is the kind of quiet that ends loudly:

    lun offline /vol/<vol>/<db>_sqldata_test
    lun serial   /vol/<vol>/<db>_sqldata_test <serial>
    lun online   /vol/<vol>/<db>_sqldata_test

**The igroup decides who sees what** — `-f` for FCP, `-i` for iSCSI; the ALUA notice on creation means the multipath policy arrived too (the switches underneath: [Brocade Fabric OS, the cheat sheet](../../reports/network/fibre-channel-brocade/index.md)):

    igroup create -t linux -f rec_test_dell
    igroup add rec_test_dell <mac>:24:C0

**Boot order is LUN order.** The OS LUN must be LUN ID 0 or the test server boots into the wrong disk's grub. The fix is the blunt one — unmap both, map the OS first:

    lun unmap /vol/<vol>/<db>_sqldata_test rec_test_dell
    lun unmap /vol/<vol>/<db>_os_test      rec_test_dell
    lun map  /vol/<vol>/<db>_os_test       rec_test_dell 0
    lun map  /vol/<vol>/<db>_sqldata_test  rec_test_dell 1

## The grub detour

The cloned OS LUN needs its `menu.lst` edited for serial-console boot before the test server can be driven headless — and the test server has no CD drive, no other disk, no nothing. The screwdriver is the backup server: unmap the OS LUN from the test igroup, map it into the backup server's igroup at the next free LUN ID, rescan the SCSI bus by hand, mount, edit, detach:

    ssh <backup-server>
    lsscsi                                   # pick the last LUN id + 1
    lun unmap /vol/<vol>/<db>_os_test rec_test_dell
    lun map  /vol/<vol>/<db>_os_test backup_fcp 24
    echo "- - -" > /sys/class/scsi_host/host3/scan
    mount -o rw /dev/sdx1 /mnt/backup
    vi menu.lst                              # serial console per the iDRAC manual, p. 91
    echo 1 > /sys/block/sdz/device/delete
    lun unmap /vol/<vol>/<db>_os_test backup_fcp
    lun map  /vol/<vol>/<db>_os_test rec_test_dell 0

On the fabric side, `ql-dynamic-tgt-lun-disc` finds the newly mapped LUNs when the driver does not.

## Bringing it up

The iDRAC first: serial communication **on with serial redirection** (`ALT+q`, `F2`), so the rest happens over a console. Then two host-side fixes a cloned machine always needs:

- **the network identity is the donor's** — the clone's `70-persistent-net.rules` still names the production NICs; rewrite them for the static test address;
- **the database gets the test server's memory, not the donor's** — `innodb_buffer_pool_size` at roughly 70% of what the box actually has (`3000M` on the test server).

Then `mysqld` starts, and the database answers, and the ticket can be closed with a date and a machine name instead of an opinion.

## The cleanup brigade

A DR test that leaves artifacts behind is not finished. In order, every time:

    /etc/init.d/mysqld stop
    halt -p
    lun unmap   <all four test LUNs>
    lun offline <all four test LUNs>
    lun destroy <all four test LUNs>

Unmap, offline, destroy — in that order, because a destroyed LUN that is still mapped is somebody else's bad week.

## The same pattern, smaller

The note file shows the same skeleton scaled down, all through 2011:

- **Single-file restores** — a user's file vanishes from the file server; the whole file LUN is cloned from an hourly snapshot, mounted on the backup server, the file copied out, clone destroyed. One user's `.xls`, the heavyweight way, because the file server had no shadows of its own.
- **The mail database, partially** (July): clone from a nightly snapshot, mount, extract, destroy.
- **The other site's whole production database into the same test server** (August) — the second run, same runbook, the clone names now carrying their dates.
- **A container variant** — for the smallest tests, an OpenVZ container from the template cache (`vzctl create`, quota off, the donor's UBC memory parameters), which needs no SAN at all.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
