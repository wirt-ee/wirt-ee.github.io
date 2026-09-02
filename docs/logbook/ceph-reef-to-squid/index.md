---
date: 2026-08-31
tags: [ceph, storage, upgrade]
description: "Manual Ceph upgrade from Reef to Squid without cephadm, on Ubuntu 24.04 / UCA packages. Real bugs, real fixes."
---

# Ceph Reef to Squid

Manual cluster, distro packages via Ubuntu Cloud Archive, no cephadm — the
deployment style the official docs have quietly abandoned. Almost everything
written about this upgrade assumes `cephadm`; this is the other path. The
estate's Ceph had walked this path before — [jewel to luminous, by hand,
in 2017](../ceph-jewel-to-luminous/index.md).

Versions in play:

- from: Reef (`https://download.ceph.com/debian-reef`)
- to: Squid `19.2.3-0ubuntu0.24.04.2~cloud0` (UCA, Ubuntu 24.04)

The one usable reference found online was the Proxmox wiki:
<https://pve.proxmox.com/wiki/Ceph_Reef_to_Squid>. Cluster runs CephFS, hence
the MDS dance at the end.

These are reconstructed notes, not a transcript. Read before pasting.

## Preparation

Stop OSDs from being marked out while hosts restart:

    ceph osd set noout

Purge leftovers from the cephadm era (I never cephadm'ed this cluster, but
the package was present):

    apt purge cephadm

If OSD-only hosts still have MDS packages installed, remove `ceph-mds` there
only.

Comment out non-distro ceph sources — one sed, no mercy:

    sed -i -E '/^[[:space:]]*#/!{/^[[:space:]]*$/!s/^([[:space:]]*)/\1# /}' /etc/apt/sources.list.d/ceph.*

Backup. Dated directory, full copies — cheap insurance, you will not need it
right up until you do:

    dir='20260831'; mkdir "${dir}"
    cp -r -p /var/lib/ceph "${dir}"/
    cp -r -p /etc "${dir}"/

Install:

    apt update
    NEEDRESTARTMODE=l apt-get -y install ceph ceph-fuse

(`NEEDRESTART_MODE=l` keeps needrestart from interrupting with interactive
service-restart prompts.)

## Bug 1: apt offers Ceph 17

After commenting the upstream sources, apt still wanted to install an ancient
Ceph 17. Two leftovers:

    # stale source file
    rm -f /etc/apt/sources.list.d/ceph.sources
    # OpenStack-Ansible-style pin file pinning src:ceph
    sed -i '/src:ceph/,+2d' /etc/apt/preferences.d/openstack_hosts_pin.pref

Verify before trusting:

    apt update
    apt-cache policy ceph-base

## Bug 2: radosgw dpkg error

    Errors were encountered while processing:
     /tmp/apt-dpkg-install-*/10-radosgw_19.2.3-*_amd64.deb

Fix:

    apt-get -o Dpkg::Options::="--force-overwrite" -f install ceph radosgw ceph-osd

## Monitors, then managers

    systemctl restart ceph-mon.target
    ceph mon dump | grep min_mon_release

Expect `min_mon_release 19 (squid)`.

    systemctl restart ceph-mgr.target

## Bug 3: `Module 'xmltodict' is not installed` on one node

One mgr node failed after restart, the others were fine:

    ceph-mgr[...]: ERROR:root:Module 'xmltodict' is not installed.

Dashboard module wants it. Dashboard is not used on this cluster, so:

    apt-get remove ceph-mgr-dashboard

If you actually use the dashboard, this is the wrong fix for you — find a way
to feed the module its python package instead.

Confirm the monmap:

    ceph mon dump | grep min_mon_release
    # min_mon_release 19 (squid)

## OSDs

    ceph osd require-osd-release squid
    systemctl restart ceph-osd.target
    ceph status

## MDS: the standby-replay dance

With CephFS, the sequence from the release notes applies:

Disable standby replay first:

    ceph fs get cephfs | grep -o allow_standby_replay
    ceph fs set cephfs allow_standby_replay false

Collapse ranks to 1:

    ceph fs get cephfs | grep max_mds
    # max_mds 2
    ceph fs set cephfs max_mds 1

Take all standby MDS daemons offline, restart the active one, then bring the
standbys back:

    systemctl stop ceph-mds.target
    ceph status
    systemctl restart ceph-mds.target
    systemctl start ceph-mds.target

Restore the rank count (and your original `allow_standby_replay` value):

    ceph fs set cephfs max_mds 2
    # ceph fs set cephfs allow_standby_replay <original>

## Finish

Release the OSDs:

    ceph osd unset noout

Do not forget this one — a cluster left in `noout` will happily run degraded
forever without telling you.

    ceph status
    # HEALTH_OK
---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
