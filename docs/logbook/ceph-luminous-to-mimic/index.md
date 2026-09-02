---
date: 2019-02-18
tags: [ceph, mds, cephfs, upgrade, mimic]
description: "Ceph luminous to mimic, 2019: the whole upgrade runs clean — until the MDS restart takes the filesystem down with it, and one daemon has to be failed by hand."
---

# Ceph: luminous to mimic

The estate's second by-hand major upgrade — two years after [jewel to luminous](../ceph-jewel-to-luminous/index.md), same pattern, one new trap. Timestamped by the notes to 18-02-2019.

## The run

The familiar discipline, and it goes quietly:

    ceph osd set noout
    vi /etc/apt/sources.list.d/ceph.list          # luminous -> mimic
    apt-get clean && apt-get update
    apt-get install ceph                          # 19 upgraded, 2 newly installed

    systemctl restart ceph-mon.target
    ceph mon feature ls
    #   supported: [kraken,luminous,mimic,osdmap-prune]
    ceph osd versions                             # watch them converge
    systemctl restart ceph-osd.target

## The filesystem goes down with the upgrade

Then the MDS restart — and cephfs leaves the air:

    13:08:39  WRN  Health check failed: insufficient standby MDS daemons available
    13:14:33  WRN  Health check failed: 1 filesystem is degraded (FS_DEGRADED)
    13:14:33  WRN  Health check failed: 1 filesystem has a failed mds daemon (FS_WITH_FAILED_MDS)
    13:14:33  ERR  Health check failed: 1 filesystem is offline (MDS_ALL_DOWN)
    13:14:35  INF  Health check cleared: FS_WITH_FAILED_MDS
    13:14:35  INF  Standby daemon assigned to filesystem cephfs as rank 0
    13:14:38  INF  daemon is now active in filesystem cephfs as rank 0
    13:14:38  INF  Health check cleared: FS_DEGRADED

Fifty-six seconds from first warning to fully offline to back — the standby took rank 0 before the health check finished changing its mind. `MDS_ALL_DOWN` is not a state you negotiate with.

With the filesystem back, the notes do the max_mds dance — one rank, then two, watching each daemon claim its rank and the `MDS_UP_LESS_THAN_MAX` warnings clear one by one. Then the tail of the run:

    systemctl restart ceph-radosgw.target
    ceph osd unset noout
    systemctl restart nova-compute cinder-volume libvirtd

## The stuck rank

Not everything self-healed. `ceph -s` showed `cephfs-2/2/2 up {0=<host>=up:resolve, 1=<host>=up:resolve}` — two ranks, both stuck in `resolve`, and a `FS_DEGRADED` that would not clear. The notes' verdict, translated: *I guess rank 0's daemon failed, so I removed it*:

    ceph mds fail 0
    ceph fs set cephfs max_mds 2
    rm -r /var/lib/ceph/mds/ceph-<failed-daemon>
    ceph-deploy mds create <host>          # and restart all mds

The rank came back active. A daemon stuck in `resolve` does not resolve itself; fail the rank, rebuild the daemon, let the standby claim it clean.

---

*Part of the estate's Ceph arc: [the trail from jewel onward](../ceph-jewel-to-luminous/index.md), the [scars](../ceph-scar-tissue/index.md), the [EC disaster](../ceph-ec-data-loss/index.md), and [Reef to Squid](../ceph-reef-to-squid/index.md). If your cluster upgrades are due — [info@wirt.ee](mailto:info@wirt.ee).*
