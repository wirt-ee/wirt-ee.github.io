---
date: 2022-05-07
tags: [ceph, octopus, pacific, upgrade, bluestore]
description: "Ceph nautilus to pacific, via octopus: two hops in one entry — the octopus step that removed the last ceph-mgr-ssh, and the pacific step whose workarounds are both marked 'BUG: not using cephadm'."
---

# Ceph: nautilus to pacific

Two hops in one entry, because that is how the notes keep them: the octopus step is eight lines, the pacific step is where the walls are. Timestamped to 07-05-2022. Between these two hops sits the [EC disaster](../ceph-ec-data-loss/index.md) — it happened on octopus 15.2.5, and this entry is the road on either side of it.

## Nautilus to octopus

    deb https://download.ceph.com/debian-octopus/ bionic main
    ceph osd set noout
    apt-get install ceph
    # all monitors separately
    systemctl restart ceph-mon.target

One artifact of the era: the old ssh orchestrator plugin still installed — octopus wants cephadm or nothing, and this estate chose nothing:

    apt-get remove ceph-mgr-ssh
    systemctl restart ceph-mgr.target

Then the OSD hosts, `apt-get install ceph` one at a time.

## Octopus to pacific

The docs for this hop assume cephadm so thoroughly that the non-cephadm path is all workarounds — the notes mark two of them with the same label, **BUG: not using cephadm**:

    # 1. bluestore wants to fsck-and-fix everything on mount — turn it off for the hop
    ceph config set osd bluestore_fsck_quick_fix_on_mount false
    # ...after the upgrade:
    ceph config set osd bluestore_fsck_quick_fix_on_mount true

    # 2. the monitor's mds sanity check aborts the upgrade on a mixed mds fleet
    ceph config set mon mon_mds_skip_sanity true
    # ...after the upgrade:
    ceph config rm mon mon_mds_skip_sanity

A safety check disabled to get through the door, then re-armed behind you — that is the whole non-cephadm upgrade style in two commands. Four years later the [Reef to Squid](../ceph-reef-to-squid/index.md) run would fight the same assumption ("the deployment style the official docs have quietly abandoned"); this entry is where that fight started.

The run itself:

    sed -i 's/octopus/pacific/' /etc/apt/sources.list.d/* && apt-get clean && apt-get update
    apt-cache policy ceph                        # confirm what is about to happen
    ceph osd set noout
    apt-get install ceph

And one sequence the notes flag as *not expected* — the active manager restarting itself mid-run:

    2022-05-07T20:46:39 mon.<host> [INF] Active manager daemon <host> restarted
    2022-05-07T20:46:39 mon.<host> [INF] Activating manager daemon <host>
    2022-05-07T20:46:45 mon.<host> [INF] Manager daemon <host> is now available

A manager that restarts itself during a package upgrade is usually just systemd doing dependency ordering — but "usually" is not a word to use inside a production upgrade, so it went into the notes. Then the monitors, then the OSDs, host by host, and `noout` off.

## The gap after this entry

The notes between this hop and [Reef to Squid](../ceph-reef-to-squid/index.md) are thin: pacific→quincy exists as reference links, quincy→reef as a test-cloud exercise with a HEALTH_OK at the end. What the production estate did in those years is [the quincy-era material](../ceph-scar-tissue/index.md) — autoscaler fights, pg-per-osd tuning — recorded as scars, not as runs. The trail resumes in force at Reef.

---

*Part of the estate's Ceph arc: [jewel to luminous](../ceph-jewel-to-luminous/index.md), [luminous to mimic](../ceph-luminous-to-mimic/index.md), [mimic to nautilus](../ceph-mimic-to-nautilus/index.md), the [EC disaster](../ceph-ec-data-loss/index.md) between the hops, [the scars](../ceph-scar-tissue/index.md), and [Reef to Squid](../ceph-reef-to-squid/index.md). If your cluster must cross releases without cephadm — [info@wirt.ee](mailto:info@wirt.ee).*
