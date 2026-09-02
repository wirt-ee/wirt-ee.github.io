---
date: 2017-10-05
tags: [ceph, rados, rbd, openstack, upgrade]
description: "Ceph jewel to luminous on xenial: the libvirt/libnl trap, the kernel ladder to EC-pool RBD, rbd default features = 5, and the daemon nobody had yet — the mgr."
---

# Ceph: jewel to luminous

The estate's Ceph production, jewel 10.2.9, on xenial 16.04, with OpenStack VMs on top. This was the first by-hand major upgrade the cluster ever took — eight years before the last one, [Reef to Squid](../ceph-reef-to-squid/index.md). The notes carry it in timestamps: October 2017 for the upgrade and the fuse mounts, February 2018 for the cephfs capacity note.

Before anything: the OpenStack-ansible client role still pointed at hammer — one sed moves it to jewel:

    sed -i 's/hammer/jewel/g' playbooks/roles/ceph_client/defaults/main.yml

Then empty the hypervisors — every VM somewhere else:

    nova hypervisor-servers <hypervisor>
    ceph osd set sortbitwise
    ceph osd set noout

## The rehearsal: jewel to kraken

A centos7 rig had walked this path first, jewel to kraken, and left a warning for production:

    sed -i 's/jewel/kraken/g' /etc/yum.repos.d/ceph.repo
    ceph-deploy upgrade                        # deploy host first

    [ceph_deploy][ERROR ] RuntimeError: Failed to execute command:
      rpm -Uvh --replacepkgs https://download.ceph.com/rpm-kraken/el7/noarch/ceph-release-1-0.el7.noarch.rpm

The lesson, written in the notes with three exclamation marks: **do every host separately — do it three times.** A one-shot `ceph-deploy install --release kraken` across `ceph-node-[1..3]` was how not to do it. Finish with the gate:

    ceph osd set require_kraken_osds

## The production run: mons first, and the libvirt trap

The order is in the notes in caps: **mon daemons must be upgraded first.** On a box that holds both a mon and OSDs there is no such thing as upgrading only the mon — `apt-get upgrade ceph-mon` takes the whole stack, and:

    Errors were encountered while processing:
      libvirt-daemon-system
      libvirt-bin

After the ceph upgrade, **libvirtd will not start.** The notes walk the rabbit hole: the culprit was `libnl1:amd64 1.1-8ubuntu1` (launchpad bug 1673491). The clean fix is `apt-get remove libnl1` and reinstall the casualties; the ugly fix, also in the notes, was scp'ing a newer `libnl-3.so.200.16.1` from a working box and symlinking `libnl-3.so.200` by hand. Both are recorded because both were used.

Luminous also brings a daemon that did not exist in jewel — the mgr — so the run continues:

    ceph-deploy gatherkeys
    ceph-deploy mgr create <host>
    systemctl restart ceph-mon.target
    systemctl restart ceph-mgr.target
    systemctl restart ceph-osd.target
    systemctl stop nova-compute
    systemctl stop cinder-volume

## The kernel ladder

With the cluster on luminous, the hypervisors still could not map RBD images — and the reason was not Ceph. The 4.4 kernels had *never* been upgraded because the `linux-image-generic` metapackage was not installed. Then a ladder, each step recorded in the notes:

- `4.8.0-58` — rbd map works on the **replicated** pool
- `4.10.0-38` — still cannot map a volume on the **EC** pool
- `4.13.0-16` — EC pool volumes map, with `--image-feature layering`

And the config-side answer that made old clients survivable in general:

    # rbd default features = 5      (default was 61)

Layering (1) and exclusive-lock (4) only; object-map (8), fast-diff (16) and deep-flatten (32) disabled — the features old kernels cannot negotiate.

## Locking it in

    ceph osd versions
    {
        "ceph version 12.2.0 (...) luminous (rc)": 6
    }
    ceph osd require-osd-release luminous

All six OSDs on the new release, then the flag that keeps stragglers honest.

## What luminous unlocked

The follow-up work, dated by the notes to October 2017 through February 2018:

- erasure-code profiles with device classes: `k=2 m=1`, reed_sol_van, failure domain host — and `allow_ec_overwrites true` for the data pool
- cephfs on an EC data pool (`cephfs_metadata` replicated, `cephfs_data` erasure), with a capacity note from 2018-02-20: 4.5 T free
- restricted caps for cephfs users — `allow rw path=/home, allow r path=/` for mds, read-only mon/mgr, `allow rw` on the two pools; never the admin key
- and the mount lesson: **the 4.4 LTS kernel cannot mount cephfs at all** — `mount.ceph` times out (error 110); `ceph-fuse` against `:6789` is the answer, with an fstab line carrying three mon addresses and `_netdev,noauto,x-systemd.automount`

The EC pool behind RBD story that ended badly two years later is [its own entry](../ceph-ec-data-loss/index.md) — written after, remembered because of.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
