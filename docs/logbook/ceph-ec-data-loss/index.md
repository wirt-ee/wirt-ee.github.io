---
date: 2020-10-08
tags: [ceph, rados, ec, rbd, data-loss]
description: "Ceph octopus, production k4m2 EC pool: objects whose shards disagree on version, the assert crash when you try to glue them, and the countdown to mark_unfound_lost."
---

# Ceph EC pool: the unrecoverable PG

Context: the estate's Ceph, octopus 15.2.5, before the later upgrades in this logbook. An EC pool (`k4m2`, jerasure, reed-solomon, k=4 m=2, host failure domain, SSD class) holding production RBD volumes. The cluster itself was stretched across two datacenters at L2 at the time: the storage was almost full, and the new capacity lived in the second datacenter. The note below is the bug report as filed upstream — issue 48060 — kept as it was written, hostnames genericized. The note carries no calendar day for the onset, but the bounds are hard: the nautilus→octopus upgrade finished 2020-10-07, and the scrub repairs that closed the incident are dated 2020-10-28 in [the scar-tissue entry](../ceph-scar-tissue/index.md). The disaster struck inside that window. The report ends at the countdown; the salvage and the outcome, reconstructed from the estate's own notes, are in the Aftermath below.

## The situation

15 RBD volumes with broken objects. The broken objects contain shards with different versions. Everything the checklist asks for is green:

- all OSDs UP and IN
- no SMART errors
- network latency between components under 0.2 ms (10–40 Gbit bonded)
- more than 20G of RAM per OSD, more than 4 dedicated cores per OSD

About that number: 0.2 ms is the magic one. The full heuristic lives in [the field kit](../../reports/storage/ceph/index.md).

The pool itself is ordinary:

    pool 30 'cinder-data' erasure profile k4m2 size 6 min_size 5 ...
    pg_num 512 pgp_num 512 ... flags hashpspool,ec_overwrites,selfmanaged_snaps

Everything healthy, and the data still gone. That is the part worth writing down.

## The forensics

One PG stuck for 44 hours:

    pg 30.e6 is stuck undersized for 44h, current state
    active+recovery_unfound+undersized+degraded+remapped,
    last acting [45,2147483647,6,2147483647,42,22]

The `2147483647` entries are the tell — acting shards that do not exist where the map says they should. The unfound list names the object and the gap:

    ceph pg 30.e6 list_unfound | egrep '(rbd|need|have)'
        "oid": "rbd_data.29.4ed8dede74eb6f.0000000000000224",
        "need": "364963'36484992",
        "have": "0'0",

Every shard of that object dumped by hand with `ceph-objectstore-tool`, and the versions disagree:

    "version": "363510'36481974",
    "version": "364963'36484992",
    "version": "364963'36484992",
    "version": "364963'36484992",
    "version": "363579'36482218",
    "version": "359913'36472321",
    "version": "359913'36472321",

Three versions across the shards of one object. k=4 means any four agreeing shards reconstruct the object; there is no quorum to be had here.

More than six OSDs were found holding missing object pieces; all OSDs were then rebooted, one at a time, to see whether anything healthy would resurface. Nothing did.

## The question, and the wall

The question the report asks upstream: *is there any command to "glue" broken pieces together and put them back in?*

The test attempt answers it. Injecting a wrong-version shard into a test system:

    /build/ceph-15.2.5/src/osd/osd_types.cc: 5698:
    FAILED ceph_assert(clone_size.count(clone))

A hard assert in OSD type handling — not a polite refusal. And on the broken objects themselves, IO simply hangs: `rbd import/export`, `rados get/put`, all of it. There is no glue. The versions disagree, and the code that would have to pretend otherwise crashes.

## The countdown

With recovery impossible and the PG stuck degrading the pool, the report ends on the only lever left:

    ceph pg 30.e6 mark_unfound_lost delete

Twelve hours to accept permanent data loss. The command does not repair anything — it declares the objects dead so the pool can move on. Green health by honesty: these objects are gone, say so, and stop pretending they are coming back.

## Aftermath: the salvage

The estate's notes carry what the report does not — the days after the countdown, spent trying to raise the dead by hand.

First, the census: which volumes were actually hit. Every volume's prefix grepped against `list_unfound` across the affected PGs — `30.14e`, `30.44`, `30.cd`, `30.ff`, `30.e6` — until every broken object had a volume name attached.

The notes also carry the same lever pulled PG by PG once the surgery ran out, every attempt prefixed with the same two Estonian words, *proovin seda* (trying this):

    #proovin seda: ceph pg 30.171 mark_unfound_lost delete
    pg has 3 objects unfound and apparently lost marking
    #proovin seda: ceph pg 30.13c mark_unfound_lost delete
    pg has 2 objects unfound and apparently lost marking
    #proovin seda: ceph pg 30.e6 mark_unfound_lost delete
    pg has 2 objects unfound and apparently lost marking
    #proovin seda: ceph pg 30.78 mark_unfound_lost delete
    pg has 4 objects unfound and apparently lost marking

Eleven objects across four PGs, and every one of them had a VM name written next to it in the notes. The names stay off this page.

Then the shard surgery, object by object, with `ceph-objectstore-tool`. The missing shard's home answers politely and emptily:

    Error getting attr on : 30.e6s3_head,... (61) No data available

Trying to inject a shard from a surviving OSD into the hole fails on the object metadata: `No object id 'set' found or invalid JSON specified`. And `--op fix-lost` on the holding OSD does not fail politely:

    ceph-objectstore-tool --data-path /var/lib/ceph/osd/ceph-17 --pgid 30.e6 --op fix-lost
    *** Caught signal (Segmentation fault) **
     in thread ... thread_name:ceph-objectstore
     ceph version 15.2.5 ... octopus (stable)
     BlueStore::collection_list(...)
    Segmentation fault (core dumped)

A core dump is also an answer. The same object is dumped from every surviving shard and compared, byte by byte, looking for one version that could be trusted. There is none; that is what divergent versions mean.

The last act is not recovery but reconstruction. The broken object was block 1544 of a VM's disk (`echo $((16#608))`), and a 4M object is exactly one block — so the image was rebuilt *around its hole*:

    dd if=/dev/nbd0 of=<backup-path> bs=4M count=1543    # before the hole
    #     <<<<< the broken 4M area >>>>>
    dd if=/dev/nbd0 of=<backup-path> skip=1545 seek=1545 bs=4M   # after it

A domain-named VM, salvaged minus one 4-megabyte square. The notes also carry the arithmetic that was never used — k=4 means shards 0..3 hold data, 4..5 hold parity, so four honest shards would rebuild the block — marked **NOT TESTED**, because there were never four honest shards to try it with.

And the ending, in one response line the notes kept: the comment above it reads *"slight chance the VM failed to commit and the filesystem is still consistent"* — and then:

    ceph pg 30.e6 mark_unfound_lost delete
    pg has 2 objects unfound and apparently lost marking

The countdown ran out. The last two objects were declared lost, by hand, by me.

And the ending the pool's map does not know about: **I stitched the block storage back together with dd.** The image, rebuilt block by block around its hole, came up — and the missing 4-megabyte squares had landed in the operating system, not in the database. The OS had holes; the data did not. Nothing was lost at the end of the day. The shard surgery had failed; the dd surgery is what saved the night. Luck chose where the hole landed — the stitching was done on purpose. That is the whole point of rebuilding around a hole instead of walking away: you get to see what the hole hit.

## Retrospective

The root cause was never proven. But the architecture that week is a fact: a cluster stretched across two datacenters at L2, because the storage was almost full and the new capacity lived in the other DC. A stretched cluster is slow on its best day. This one was slow as hell, and the notes show it: cluster-wide slow OSD heartbeat warnings, 1.2 to 1.9 seconds on the back network. For scale: fine is 0.2 ms, and 0.4 already feels slow. That week read in seconds. Then the network between the datacenters broke. Shards holding different versions of one object is the signature of writes landing on different sides of a partition, and this architecture had a partition seam built into it. That is my operating theory, and the whole week points at it. What it cannot be is proof: the assert crash means the version history cannot be interrogated after the fact, and I will not dress a theory up as one.

The calendar adds one fact the theory has to live with: the nautilus→octopus upgrade finished on 2020-10-07, and this disaster struck inside the three weeks that followed. I am not drawing a line between those two dates. I am just writing them next to each other. The day after the upgrade finished, osd.6 was marked dead at map e344565 while still running, and the monitor heartbeat grace had to be doubled, 20 to 40 seconds. That is what the week after the upgrade looked like.

And the rehearsal was not close in time, as memory first had it: the test cluster had shown the same failure shape in 2019, and I had read it as overheating and a pulled power cord. That receipt is in [the scar-tissue entry](../ceph-scar-tissue/index.md), together with the last repair that did work — a replicated-pool read error fixed on 2020-09-21, two weeks before the upgrade.

What is not a theory: **the architecture was never repeated.** k4m2 was a value-saving choice — 1.5× storage overhead instead of replication's 3× — and on paper EC-for-RBD is fine. After this, no EC pool ever carried RBD volumes on this estate again. The capacity saved was not worth standing at that prompt; replicated pools cost more disk and sleep better. And for a while after the crash, Ceph did not carry the VMs at all: the estate leaned on [GPFS](../../reports/storage/gpfs/index.md) as VM storage — a filesystem built for the HPC cluster's throughput, not for keeping stable VMs alive — before Ceph, replicated-only, took the work back.

Where the estate's Ceph went after this — Jewel-era beginnings through the by-hand Reef-to-Squid trail, no cephadm — is in [the Ceph entry](../ceph-reef-to-squid/index.md). What this page is: the reason "an untested backup is a rumour" is written elsewhere on this site without a smile.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
