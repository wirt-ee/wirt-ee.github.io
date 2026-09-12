---
description: "OpenStack private cloud on your hardware. Live-upgraded in place since 2016, never rebuilt."
---

# Private cloud (OpenStack)

I build and upgrade OpenStack private clouds. Production since 2016, Mitaka onward. One environment, upgraded in place release by release, never rebuilt. The receipts are public: [the upgrade trail](../../logbook/openstack-trail/index.md).

Migrating from AWS EC2 or VMware is technically possible.

## Minimum Equipment List

- Three controller nodes with dual Ethernet interfaces
- Two compute nodes with dual Ethernet interfaces
- Two VLAN-capable MC-LAG switches
- Distributed storage for cloud images and guest block devices (or three extra nodes for Ceph)

You also need: network connectivity, power and cooling, hardware and software lifecycle management including End-of-Life planning, monitoring and alerting.

## Fault tolerance

In a production-scale deployment some components are always failed or in maintenance; the system keeps operating. With a 3x-replicated database, losing one replica is not an event. A failed MC-LAG switch member is invisible to customers. Hyper-converged without redundancy is the failure case.

Questions, quotes: [info@wirt.ee](mailto:info@wirt.ee). [How to hire](../../hire/index.md).
