---
date: 2019-12-01
tags: [ceph, nautilus, msgr2, crush, cephfs, upgrade]
description: "Ceph mimic to nautilus: the firefly standoff — legacy CRUSH tunables, hammer-era kernel clients hunted through monitor sessions, and a cephfs that would not mount until every daemon agreed."
---

# Ceph: mimic to nautilus

The estate's third by-hand upgrade. The notes carry no calendar date for this run; the anchors are mimic 13.2.6 (July 2019, [the stalling monitors](../ceph-scar-tissue/index.md)) before it and a nautilus monmap from August 2020 after it — dated here to the winter between. Ask me for the real date and this entry moves.

## The run

    sed -i 's/mimic/nautilus/g' /etc/apt/sources.list.d/ceph.list
    apt-get clean && apt-get update
    # mon first, then mgr, then mds — then the OSDs, host by host
    apt-get install ceph && systemctl restart ceph-mon.target
    systemctl restart ceph-mgr.target
    systemctl restart ceph-mds.target

## The firefly standoff

Nautilus refuses to finish while the CRUSH map still speaks a dead dialect:

    BUG: crush map has legacy tunables (require firefly, min is hammer)

    ceph osd crush tunables optimal
    Error EINVAL: new crush map requires client version jewel
      but require_min_compat_client is firefly

    ceph osd set-require-min-compat-client jewel
    Error EPERM: cannot set require_min_compat_client to jewel:
      3 connected client(s) look like hammer
      (missing 0x400000000000000)

Three clients, still speaking hammer, are holding the whole cluster's CRUSH map hostage. Finding them is a detective story the notes record step by step: raise the monitor's debug level, ask it for its sessions, and grep:

    ceph daemon mon.<host> config set debug_mon 10/10
    ceph daemon mon.<host> sessions | grep hammer
    "MonSession(client.1355111464 v1:<ip>:0/259769999 is open allow *,
       features 0x107b84a842aca (hammer))"

Sessions, not hosts — a client id is not a machine name. The suspects were cephfs kernel clients, and their version was found **by trial and error**, the notes' own method: boot the kernel, check the feature set. Ubuntu 16.04 kernels, measured:

    4.4.0-148-generic  →  hammer
    4.15.0-72-generic  →  jewel

The eviction that follows is polite and total: evict the client from the mds, unmount cephfs everywhere, **reboot the mounting hosts** — and only then:

    ceph osd set-require-min-compat-client jewel
    ceph osd crush tunables optimal
    ceph osd crush set-all-straw-buckets-to-straw2

Two workarounds from the same standoff, kept because they generalize:

- switching cephfs clients to fuse is *not* an answer here — the notes measure it at **33 MB/s**. Kernel client or nothing.
- for the old kernels that must stay connected, the escape hatch is `ceph fs set cephfs min_compat_client hammer` and CRUSH tunables pinned to hammer — the cluster bends to its oldest client, whether you like it or not.

## msgr2, and the part nobody warns about

    BUG: 3 monitors have not enabled msgr2
    FIX:  ceph mon enable-msgr2

One command. But the notes carry the corollary that costs an afternoon if missed: once v2 exists, every `mon_host` in every `ceph.conf` on every client needs to speak it or at least tolerate it — the estate's answer was to pin explicit `v2:<ip>:3300, v1:<ip>:6789` forms rather than rely on defaults.

## The cephfs that would not mount

With the cluster on nautilus, cephfs still refused clients:

    BUG: cephfs still not mount @mds.log
         'connect protocol version mismatch, my 34 != 33'

The daemons disagreed about their own protocol — a mixed-version mds fleet (13.2.4 and 13.2.5 on different hosts, visible in `ceph fs status`). The fix is the blunt one, and the notes state its price:

    upgrade all ceph to version 13.2.5    # cephfs will be down during the process

Full agreement, or no filesystem. There are no partial protocol versions.

## One daemon, failed by hand — again

The same pattern as [luminous to mimic](../ceph-luminous-to-mimic/index.md), one release later: a rank stuck (`up:resolve`), `ceph fs dump` naming the daemon that failed, and the same trio — `ceph mds fail 0`, remove the daemon's data directory, `ceph-deploy mds create` — bringing it home. Two upgrades in a row, the same scar; [bugs repeat](../openstack-trail/index.md), and so do their fixes.

---

*Part of the estate's Ceph arc. If your upgrade path crosses a dialect boundary — [info@wirt.ee](mailto:info@wirt.ee).*
