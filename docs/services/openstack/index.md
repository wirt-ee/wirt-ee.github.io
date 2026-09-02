---
description: "OpenStack private cloud on your hardware: sovereign, live-upgraded since 2016, fully under your control."
---

# Private cloud (OpenStack)

Your own cloud, on your own racks. Fully under your control. If you break it, you can keep all the pieces. Migrating from AWS EC2 or VMware is technically possible; ask first, believe later.

## Benefits of owning an on-prem cloud infrastructure

It's entirely under your control. No one else dictates what happens or when. You're responsible for your own support. Choose your partners wisely.

## Vendor lock-in

It is technically possible to migrate from AWS EC2 or VMware. Ask me what it costs before you assume it is cheap.

## OpenStack cloud Minimum Equipment List

You cannot run a production system without hardware. Below you will find the Non-negotiable MEL. You can go with less, but you will suffer.

- Three controller nodes with dual Ethernet interfaces
- Two compute nodes with dual Ethernet interfaces
- Two VLAN-capable MC-LAG switches
- Distributed storage for cloud images and guest block devices (or three extra nodes for Ceph)

## Operational basic

- Network connectivity (the network is the cloud),
- Power and cooling (within datacenter constraints),
- Hardware and software lifecycle management (including End-of-Life planning),
- Monitoring and alerting systems.

## Fault tolerance

A single piece of hardware is inherently more reliable than a rack full of components: fewer parts mean fewer failure points. The same logic applies to software instances. The trade-off, however, is recoverability: when a standalone component fails, that failure is often final, with no redundant counterpart to take over. In a production-scale OpenStack deployment, some components will always be in a failed or maintenance state, but the system as a whole continues to operate. What is critical is understanding exactly how much failure your deployment can absorb before service starts to degrade.

Let's assume that you have the 3x-replicated database. Losing one replica is not a significant event. Or one of the switches failed. The missing network path is not visible to customers. However, things would be sad if the design decision were to run a hyper-converged cloud infrastructure without redundancy.

## Hours breakdown

Deploying OpenStack cloud solutions involves significant lead times that vary based on selected components. For typical SDN and shared storage upgrades, approximately 70% of effort goes into pre-upgrade testing and preparation. The rest is consumed by post-upgrade activities and addressing various issues.

## Stack of all things

True to its name, OpenStack is a layered technology stack. I provide expertise to help you make optimal decisions at each layer of this stack.

---

*Running one of these, or planning to? [info@wirt.ee](mailto:info@wirt.ee). I do this for a living. [How to hire](../../hire/index.md).*
