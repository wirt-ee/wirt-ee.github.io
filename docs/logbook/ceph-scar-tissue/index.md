---
date: 2023-04-04
tags: [ceph, rados, mon, scrub, network, incidents]
description: "Five years of Ceph incidents the cluster survived: the noout trap, stalling monitors, an OOM-killed mon, scrub errors three years running, and the switch loop that fired first."
---

# Ceph: scar tissue

The Ceph field kit elsewhere on this site is what the estate's notes distilled. This entry is what they cost. One cluster, 2019 through 2023 — every scar below has a timestamp or a command output, because scars without evidence are just complaints. Hostnames genericized; the damage is as it happened.

## The noout trap

The oldest lesson, and it is about the flag everyone sets reflexively: `noout` before maintenance. On a pool with `size=2, min_size=1`, shutting down a node probably kills the **primary** OSD of every PG it holds — and with `noout` set, the cluster will not fail over to the secondary. The IO hangs. The notes keep the answer as received wisdom:

> You want `norebalance`, not `noout`. Since you set noout the system does not flip to a secondary copy of the data, so it becomes hung.

`noout` protects the data map; `norebalance` protects the traffic. Know which one you actually need.

## 2019-02-18: the filesystem goes down with the upgrade

The luminous→mimic run is [its own entry](../ceph-luminous-to-mimic/index.md); the scar it left — fifty-six seconds from `insufficient standby` to `MDS_ALL_DOWN` and back — is told there. The lesson in one line: `MDS_ALL_DOWN` is not a state you negotiate with; the standby was taking over before the health check finished changing its mind.

## 2019-07-11: the monitors stall

    Health check update: 10 slow ops, oldest one blocked for 3193 sec,
    daemons [mon.<a>,mon.<b>,mon.<c>] have slow ops. (SLOW_OPS)

Fifty-three minutes, on the monitors, on mimic 13.2.6. The fix in the notes is one line and no diagnosis: `systemctl restart ceph-mon@*` — all cluster monitors. Some days the monitor just stops talking, and the honest answer is a restart and a crash archive:

    ceph crash ls
    2019-07-11_16:11:13...  mon.<host>  *
    2019-07-11_16:15:09...  mon.<host>  *      # two crashes, same afternoon
    2019-12-29_16:24:10...  mon.<host>  *      # and an encore in December
    ceph crash archive <id>

## The OOM-killed monitor

A host hard-reboots after the OOM killer takes a monitor. The monitor comes back and does not join: `ceph daemon mon.<host> mon_status` shows `state: probing, election_epoch: 0` — it cannot even find an election to lose. The recovery ritual from the notes:

1. fix name resolution by hand (`/etc/hosts`, temporarily) — a probing mon that cannot resolve its peers stays probing forever
2. `ceph mon remove <host>` from the quorum side
3. `ceph-deploy --overwrite-conf config push` and `ceph-deploy mon create <host>`
4. restart the surviving quorum monitors
5. revert `/etc/hosts`

The monmap from that recovery says the cluster was created 2016-09-21 — almost four years old at this point, and still capable of losing a member to a memory leak.

## 2019: the rehearsal nobody heeded

A year and a half before the production [EC disaster](../ceph-ec-data-loss/index.md), the same failure shape appeared on the test cluster. The trigger in the notes is plain: an OSD delete and create. Then a PG stuck `active+recovery_unfound+undersized+degraded+remapped`, 3872 seconds and counting, and the same arithmetic at the end: for an EC pool, `mark_unfound_lost revert` is not an option, only `delete`. The notes record the moment with a line that needs no comment:

    echo "Kiss goodby for your EC data"; ceph health detail | grep recovery_unfound \
      | grep unfound$ | awk '/is/ {print $2}' \
      | while read pg_num; do echo ceph pg ${pg_num} mark_unfound_lost delete; done
    Kiss goodby for your EC data
    ceph pg 21.1 mark_unfound_lost delete
    ceph pg 21.2 mark_unfound_lost delete

All the test cluster's VMs were shut down together with it, and the data loss was accepted. In retrospect, it looks like my error. The test cluster had overheated and the power was pulled, and I took the power pull as the root cause. I closed the case as a hardware event. The failure shape underneath was Ceph's own, and it came back on production: the [EC disaster](../ceph-ec-data-loss/index.md) is that entry.

## 2020-09-21: a read error, repaired the same evening

A little over two weeks before the octopus upgrade, still on nautilus, a deep-scrub on the replicated pool found a shard reading garbage and a primary copy gone missing:

    2020-09-21 19:17:29 osd.21 [ERR] 9.1dc shard 21 ... candidate had a read error
    2020-09-21 19:47:20 osd.21 [ERR] 9.1dc missing primary copy ... will try copies on 14,30
    2020-09-21 19:55:25 osd.21 [DBG] 9.1dc deep-scrub starts
    2020-09-21 19:55:55 osd.21 [DBG] 9.1dc deep-scrub ok
    2020-09-21 19:55:57 mon.<host> [INF] Cluster is now healthy

Seventy-four minutes, error to healthy, and the notes move on. The repair worked because the pool was replicated: a bad shard is a shrug when another copy answers. The cluster was on nautilus. The octopus upgrade was two weeks away, the [EC disaster](../ceph-ec-data-loss/index.md) three.

## 2020-10-28: scrub finds what recovery missed

A repair and a funeral on the same day:

    2020-10-28T11:14:56 osd.1 [ERR] 34.6 repair 1 errors, 1 fixed
    2020-10-28T11:47:14 osd.0 [ERR] 34.e deep-scrub 1 errors
    2020-10-28T11:47:16 mon.<host> [ERR] Health check failed: 1 scrub errors (OSD_SCRUB_ERRORS)
    2020-10-28T11:47:16 mon.<host> [ERR] Possible data damage: 1 pg inconsistent (PG_DAMAGED)

    ceph pg 34.e mark_unfound_lost delete
    pg has 1 objects unfound and apparently lost marking
    ...
    pgs:     192 active+clean

One object declared lost, 192 PGs green. Health is a claim about the map, not about the data.

## 2022-06-10: one scrub error, and the workflow that finds the victim

HEALTH_ERR for one inconsistent PG (`9.15a`). The interesting part is not the repair — it is the forensic chain that turns a PG number into a volume name, worth stealing wholesale:

    # find the broken object, take its volume prefix
    rados list-inconsistent-obj 9.15a | egrep -o "rbd_data\.[0-9a-z]+\.[0-9a-z]+" | head -n1
    rbd_data.404e8b3708dc29.000000000005e2d4

    # find which volume carries that prefix
    pref='rbd_data.404e8b3708dc29'; rbd -p cinder-volumes ls | while read l; do
      vol=$(rbd info cinder-volumes/$l | grep $pref); test -n "$vol" && echo $l; vol=''; done

    ceph pg repair 9.15a
    2022-06-10T08:18:32 mon.<host> [INF] Cluster is now healthy

A scrub error is not actionable until you know whose data it is. The prefix walk answers that in two commands.

## 2023-04-04: the network fires first

The newest scar, and the one that vindicates the split theory in [the EC retrospective](../ceph-ec-data-loss/index.md) — a loop detected on a switch, a port err-disabled, and eighty minutes later:

    11:04:00  switch %FDBM-4-LOOP_DETECT: Loops detected in the network
              among ports po31 and po33 - Err-disable on port po33

    ceph -w
    health: HEALTH_ERR
            1 scrub errors
            Possible data damage: 1 pg inconsistent
    ...
    objects: 4.59M objects, 17 TiB
    pgs:     1511 active+clean
             1    active+clean+inconsistent

The inconsistent PG (`9.71`) had one shard with `read_error` — a disk reading garbage while the network event was still in the logs. The repair ran at 12:26 and the cluster was healthy again. But the causality line is the entry's whole point: **the network fired first, and the data damage was found second.** In this estate, that was not a theory.

## The smaller ones

- **Infinite rebalancing**: `Rebalancing after osd.44 marked in (12h)`, progress bar eternally at 90 minutes remaining. Fix: restart the active manager — the mgr had been up six days and had lost the plot.
- **The phantom image**: `rbd ls` shows the volume, `rbd snap ls` answers `No such file or directory`. The fix is to believe the error, not the list: `rbd rm` the image, and it goes.
- **Full ratios out of order**: raising `full_ratio` past `nearfull_ratio` in an emergency makes the cluster refuse the config. The ratios are an ordered set; move them together.

---

*Every scar above has a receipt. If your cluster is writing new ones — [info@wirt.ee](mailto:info@wirt.ee).*
