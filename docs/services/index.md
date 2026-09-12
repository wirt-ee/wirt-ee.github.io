---
title: "Services: private cloud, storage, firewalls, on-prem AI"
description: "OpenStack private cloud, Ceph storage, VyOS HA firewalls, managed services, on-prem AI. Built on your hardware by one senior engineer."
---

# Services

I build:

- [Private cloud (OpenStack)](openstack/index.md)
- [Distributed storage (Ceph)](ceph/index.md)
- [Firewalls (VyOS HA)](vyos/index.md)

I keep running:

- [Managed services](managed/index.md) — monitoring, patching, backup verification.
- [On-prem AI](ai/index.md) — open-weight models on your hardware.

All on your hardware. I do not resell hardware: I spec it, you buy it. If you need a vendor in Estonia, I have good experiences with [Kernel AS](https://www.kernel.ee/) in Tartu. No business relationship, just where I would shop.

## Minimum Equipment List

Every build starts from a Minimum Equipment List (MEL): the minimum hardware that lets any component be rebooted without service disruption. The term comes from aircraft maintenance. The lists are on the individual service pages. Anything below the MEL is not a supported configuration.

## Backups

On request. When included, the build ends with a restore performed before handover — demonstrated, not promised. The pipeline: [RBD backups, exported and restored](../reports/storage/rbd-backups/index.md).

Prices and terms: [Hire](../hire/index.md).
