---
description: "Ceph distributed storage on your disks: block, file and object, live-upgraded since 2016 (Jewel)."
---

# Distributed storage (Ceph)

Block, file and object storage pooled from your own disks. Commercial arrays bill per terabyte; Ceph bills in engineering. Running it since 2016 (Jewel). Latest live upgrade: Reef → Squid by hand, no cephadm, [documented here](../../logbook/ceph-reef-to-squid/index.md).

## Local vs distributed storage

Local NVMe offers the lowest latency and highest throughput. The issue is that the available space is limited to a single chassis.

Ceph distributed software defined storage takes a different approach. It pools block devices across storage nodes into a distributed object store, presenting a unified storage pool to hypervisors. The tradeoff is increased latency.

## Ceph storage Minimum Equipment List

You cannot run a production system without hardware. Below you will find Non-negotiable MEL. Avoid RAID, LUN and consumer grade SSDs.

- Three controller nodes with dual Ethernet interfaces
- Three storage nodes with dual Ethernet interfaces
- Two VLAN-capable MC-LAG switches

## Placement

Ceph fault tolerance depends on its disks' physical location. It is essential to figure out what the fault tolerance assumptions are. Then you can decide what you can lose (datacenter, rack, host, disk). It has to be a conscious decision.

## Replicated vs. erasure encoded

Replicated is what the name says: replicated X times. Generally, 3x is fine. Erasure encoding is an entirely different setup. On its basic level, a decision is needed on how many coding chunks and data chunks are required.

Let's use K data chunks and M coding chunks. You need to use one coding chunk for two data chunks to set up a minimal supported EC pool. In literature, it is called the "k=2 m=1" schema.

## Fault tolerance

Let's take a trivial example. Cloud storage is 3x replicated. Losing one disk is not a significant event. Losing two disks prioritizes maximum recovery IOPS. Losing three disks means downtime and restoring from backup.

## Block vs. file vs. object

Under the hood, it's an object store. The translation layer allows it to present as block, file or object. For an OpenStack VM, it's a block device. For the journal log collector, it is a file. For S3 and Swift, it is an object.

---

*Storage gone quiet, or an upgrade you'd rather not rehearse on production? [info@wirt.ee](mailto:info@wirt.ee). I do this for a living. [How to hire](../../hire/index.md).*
