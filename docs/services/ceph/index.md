---
title: "Ceph distributed storage: block, file and object"
description: "Ceph distributed storage: block, file and object on your disks. Live-upgraded since 2016 (Jewel)."
---

# Distributed storage (Ceph)

Block, file and object storage pooled from your disks. Running Ceph since 2016 (Jewel). Every major upgrade done by hand, no cephadm. Latest: [Reef to Squid](../../logbook/ceph-reef-to-squid/index.md).

The trade: local NVMe gives lowest latency but is limited to one chassis. Ceph pools disks across nodes at the cost of higher latency. Commercial arrays bill per terabyte; Ceph bills in engineering time.

## Minimum Equipment List

- Three monitor nodes with dual Ethernet interfaces
- Three storage nodes with dual Ethernet interfaces
- Two VLAN-capable MC-LAG switches

No RAID, no LUNs, no consumer-grade SSDs.

## Placement

Ceph fault tolerance depends on the physical location of the disks. Decide what you can lose — datacenter, rack, host, disk — and make it a conscious decision.

## Replicated vs erasure coded

Replicated 3x is the default and generally fine. Erasure coding is a different setup: k data chunks, m coding chunks. The minimal supported EC pool is k=2, m=1.

Fault tolerance of a 3x replicated pool: one disk lost is not an event. Two disks: recovery runs at maximum IOPS. Three disks: downtime and restore from backup.

## Block, file, object

Under the hood it is an object store. Block device for a VM, file share for a log collector, S3/Swift object storage — same pool.

Questions, quotes: [info@wirt.ee](mailto:info@wirt.ee). [How to hire](../../hire/index.md).
