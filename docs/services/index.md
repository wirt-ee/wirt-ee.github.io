---
description: "What Wirt OÜ builds and keeps running: OpenStack private cloud, Ceph storage, VyOS HA firewalls, managed care, on-prem AI. All on your hardware."
---

# Services

Three things I build. Two things I keep running. All on your hardware. Every build ships with its **custom backup pipeline**, restore-proven before handover. [What that looks like](../reports/storage/rbd-backups/index.md).

- [Private cloud (OpenStack)](openstack/index.md): your own EC2, minus the invoice surprises.
- [Distributed storage (Ceph)](ceph/index.md): block, file and object on your disks, replicated your way.
- [Firewalls (VyOS HA)](vyos/index.md): stateful, redundant, conntrack-synced.
- [Managed care](managed/index.md): monitoring, patching, backup verification. A cluster nobody watches fails quietly.
- [On-prem AI](ai/index.md): open models run locally. The hardware decides how big.

## Hardware

I do not resell hardware. I spec it, you buy it. If you need a vendor in Estonia, I have good experiences with [Kernel AS](https://www.kernel.ee/) in Tartu for machines, network gear and components. No business relationship, just where I would shop.

## The MEL rule

Every build starts from a Minimum Equipment List: the minimum that lets **any component be rebooted without service disruption**. Backups are on request. When ordered, the build ends with the pipeline demonstrated, not promised: a restore performed before handover. You can order less, but you will suffer, and I will probably decline to watch. Lists are on the individual service pages.
