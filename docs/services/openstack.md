---
title: OpenStack 
---
## Benefits of owning an on-prem cloud infrastructure
It's entirely under your control. If you break it, you can keep all the pieces. No one else dictates what happens or when. You're responsible for your own support—choose your partners wisely

## Have vendor lock-in 
It is technically possible to migrate from AWS EC2 or VMware.  

## OpenStack cloud Minimum Equipment List  
You cannot run a production system without hardware. Below you will find Non-negotiable MEL. You can go with less, but you will suffer.  

* Three controller nodes with dual Ethernet interfaces  
* Two compute nodes with dual Ethernet interfaces  
* Two VLAN-capable MC-LAG switches  
* Distributed storage for cloud images and guest block devices (or three extra nodes for CEPH)


## Operational basic
* Network connectivity (the network is the cloud),
* Power and cooling (within datacenter constraints),
* Hardware and software lifecycle management (including End-of-Life planning),
* Monitoring and alerting systems


## Fault tolerance
A single piece of hardware is inherently more reliable than a rack full of components — fewer parts mean fewer failure points. The same logic applies to software instances. The trade-off, however, is recoverability: when a standalone component fails, that failure is often final, with no redundant counterpart to take over. In a production-scale OpenStack deployment, some components will always be in a failed or maintenance state — but the system as a whole continues to operate. What is critical is understanding exactly how much failure your deployment can absorb before service starts to degrade.  

Let's assume that you have the 3x-replicated database — losing one replica is not a significant event. Or one of the switches failed — the missing network path is not visible to customers. However, things would be sad if the design decision were to run a hyper-converged cloud infrastructure without redundancy. 

## Hours Breakdown
Deploying OpenStack cloud solutions involves significant lead times that vary based on selected components. For typical SDN and shared storage upgrades, approximately 70% of effort goes into pre-upgrade testing and preparation. The remaining is consumed by post-upgrade activities and addressing various issues.  


## Stack of all things
True to its name, OpenStack is a layered technology stack. We provide expertise to help you make optimal decisions at each layer of this stack.  
![hci](https://lh3.googleusercontent.com/d/11s755rAVysMSDUazS8NKarNdV9NQrbCV) 
